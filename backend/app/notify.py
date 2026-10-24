"""FCM delivery with the user's noise limits applied."""

from __future__ import annotations

from datetime import UTC, datetime, time
from zoneinfo import ZoneInfo

import structlog
from fastapi.concurrency import run_in_threadpool
from firebase_admin import messaging

from .firebase import firebase_app
from .models import Alert, Mandate, now
from .store import Store

log = structlog.get_logger()

ANDROID_CHANNEL = "critical_alerts"
IOS_CATEGORY = "ALERT_ACTIONS"  # registered in the app with Ignore / Show logs


def in_quiet_hours(m: Mandate, at: datetime | None = None) -> bool:
    if not m.quiet_start or not m.quiet_end:
        return False
    try:
        tz = ZoneInfo(m.timezone)
    except Exception:
        tz = UTC
    local = (at or now()).astimezone(tz).time()
    start = time.fromisoformat(m.quiet_start)
    end = time.fromisoformat(m.quiet_end)
    if start <= end:
        return start <= local < end
    return local >= start or local < end  # spans midnight


async def push_alert(store: Store, uid: str, alert: Alert, mandate: Mandate) -> str:
    """Returns why it was or wasn't sent, for the audit log."""
    if not mandate.push_alerts:
        return "push disabled in mandate"
    if alert.severity != "critical" and in_quiet_hours(mandate):
        return "held for quiet hours"
    if not await store.take_alert_slot(uid, mandate.max_alerts_per_hour):
        return f"rate limit ({mandate.max_alerts_per_hour}/h) reached"
    tokens = await store.device_tokens(uid)
    if not tokens:
        return "no registered devices"

    confidence = round(alert.confidence * 100)
    title = f"{alert.severity.upper()} · {alert.service_name}"
    body = (f"{alert.title}. Not sure, can you check? {confidence}% confident"
            if alert.needs_review else f"{alert.headline} · {confidence}% sure")
    data = {
        "type": "alert",
        "alert_id": alert.id,
        "severity": alert.severity,
        "service_id": alert.service_id,
        "service_name": alert.service_name,
        "title": title,
        "body": body,
        "confidence": str(confidence),
    }
    msg = messaging.MulticastMessage(
        tokens=tokens,
        data=data,
        # Android: data-only so the app renders it with action buttons.
        android=messaging.AndroidConfig(priority="high"),
        # iOS: needs an alert payload to display in the background; the
        # category gives it the same action buttons.
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
            payload=messaging.APNSPayload(aps=messaging.Aps(
                alert=messaging.ApsAlert(title=title, body=body),
                category=IOS_CATEGORY,
                sound="default",
                mutable_content=True,
                thread_id=alert.service_id,
            )),
        ),
    )
    resp = await run_in_threadpool(messaging.send_each_for_multicast, msg, False, firebase_app())
    for token, r in zip(tokens, resp.responses):
        if not r.success and isinstance(r.exception, messaging.UnregisteredError):
            await store.remove_device(uid, token)
    log.info("push.sent", uid=uid, alert=alert.id, ok=resp.success_count, failed=resp.failure_count)
    return f"sent to {resp.success_count} device(s)"
