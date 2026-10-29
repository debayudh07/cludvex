"""Watcher worker: `python -m app.watcher`.

Each cycle leases due services, reads new Render logs, filters and groups
them, triages new incidents with Gemini, writes alerts + audit entries and
pushes. Run it somewhere other than Render so it survives a Render outage."""

from __future__ import annotations

import asyncio
import signal
from datetime import timedelta

import structlog

from .config import get_settings
from .firebase import db
from .llm import GeminiTriager, Triager
from .models import Activity, WatchedService, now
from .notify import push_alert
from .pipeline.filter import classify, group, health_for, is_crash_loop, should_triage
from .pipeline.triage import decide
from .render_client import RenderAuthError, RenderClient, RenderError
from .security import decrypt_secret
from .store import Store

log = structlog.get_logger()


async def process_service(store: Store, triager: Triager, svc: WatchedService) -> None:
    s = get_settings()
    conn = await store.get_render(svc.uid)
    if conn is None:
        return
    start = svc.last_cursor_ts
    end = now()
    async with RenderClient(decrypt_secret(conn.encrypted_key)) as render:
        try:
            raw = await render.query_logs(svc.owner_id, svc.id, start, end)
        except RenderAuthError:
            await store.update_watched(svc.uid, svc.id, {"vitals": "Render key rejected"})
            await store.add_activity(svc.uid, Activity(
                actor="agent", action="Render key rejected",
                detail="The agent can no longer read logs. Reconnect Render.", meta=svc.name))
            return

    lines = [classify(r.id, r.timestamp, r.message, r.level, r.labels.get("statusCode")) for r in raw]
    lines.sort(key=lambda l: l.ts)
    crash_loop = is_crash_loop(lines)
    window_min = max(1, int((end - start).total_seconds() // 60))
    health, vitals = health_for(lines, window_min, crash_loop)
    await store.update_watched(svc.uid, svc.id, {
        "last_cursor_ts": lines[-1].ts + timedelta(milliseconds=1) if lines else end,
        "lease_until": now() + timedelta(seconds=s.watch_poll_seconds),
        "health": health,
        "vitals": vitals,
    })

    mandate = await store.get_mandate(svc.uid)
    for draft in group(svc.id, lines, crash_loop):
        inc = await store.bump_incident(
            svc.uid, draft.fingerprint, svc.id, draft.count,
            draft.lines[0].ts, draft.lines[-1].ts, [l.message[:300] for l in draft.lines[-5:]])
        total = inc["count"]

        if inc.get("alert_id"):
            # Already alerted: keep the count fresh, don't push again.
            existing = await store.get_alert(svc.uid, inc["alert_id"])
            if existing and existing.state in ("open", "silenced"):
                await store.update_alert(svc.uid, existing.id, {"occurrences": total, "last_seen": draft.lines[-1].ts})
                continue
            if existing and existing.state == "ignored":
                continue

        if not should_triage(draft, total, crash_loop):
            continue

        try:
            d = await decide(
                triager, mandate,
                service_id=svc.id, service_name=svc.name, service_type=svc.type,
                draft=draft, total_count=total, first_seen=inc["first_seen"],
                crash_loop=crash_loop, context_lines=lines,
            )
        except Exception:
            log.exception("triage.failed", uid=svc.uid, service=svc.id)
            continue

        alert = await store.create_alert(svc.uid, d.alert)
        await store.link_incident(svc.uid, draft.fingerprint, alert.id)
        pct = round(alert.confidence * 100)
        if d.verify is not None:
            await store.add_activity(svc.uid, Activity(
                actor="verifier",
                action="Verifier disagreed" if d.verify.refuted else "Verifier agreed",
                detail=d.verify.note, meta=f"evidence: {total} lines · {alert.code}", alert_id=alert.id))
        delivery = await push_alert(store, svc.uid, alert, mandate)
        await store.add_activity(svc.uid, Activity(
            actor="agent",
            action="Asked for your call" if alert.needs_review else "Alert sent",
            detail=f"{alert.title} on {svc.name}, {pct}% sure"
                   + (f", under your {mandate.gate}% gate." if alert.needs_review else "."),
            meta=f"evidence: {total} lines · {alert.code} · {delivery}", alert_id=alert.id))

    # Auto-resolve alerts whose incident went quiet.
    cutoff = now() - timedelta(minutes=s.resolve_after_minutes)
    for stale in await store.open_alerts_seen_before(svc.uid, svc.id, cutoff):
        await store.update_alert(svc.uid, stale.id, {"state": "resolved"})
        await store.add_activity(svc.uid, Activity(
            actor="agent", action="Marked resolved",
            detail=f"{stale.title} on {svc.name} stopped recurring.", meta=stale.code, alert_id=stale.id))


async def run_forever(stop: asyncio.Event | None = None) -> None:
    """Standalone: owns SIGINT/SIGTERM. Embedded in the API (pass `stop`):
    leaves signals to uvicorn and exits when the caller sets `stop`."""
    s = get_settings()
    store = Store(db())
    triager = GeminiTriager()
    if stop is None:
        stop = asyncio.Event()
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                loop.add_signal_handler(sig, stop.set)
            except NotImplementedError:  # Windows
                pass

    log.info("watcher.start", poll=s.watch_poll_seconds)
    while not stop.is_set():
        try:
            due = await store.lease_due(lease_seconds=s.watch_poll_seconds * 2)
            results = await asyncio.gather(
                *(process_service(store, triager, svc) for svc in due), return_exceptions=True)
            for svc, r in zip(due, results):
                if isinstance(r, RenderError):
                    log.warning("render.error", service=svc.id, error=str(r))
                elif isinstance(r, Exception):
                    log.error("service.failed", service=svc.id, error=repr(r))
        except Exception:
            log.exception("watcher.cycle_failed")
        try:
            await asyncio.wait_for(stop.wait(), timeout=s.watch_poll_seconds)
        except TimeoutError:
            pass


if __name__ == "__main__":
    asyncio.run(run_forever())
