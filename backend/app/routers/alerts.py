from datetime import datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status

from ..config import get_settings
from ..deps import get_store, render_conn, render_factory, render_key, user_ctx
from ..models import Activity, Alert, RenderConnection, now
from ..render_client import RenderError
from ..schemas import ActivityOut, AlertOut, OverviewOut, ServiceOut, SilenceIn
from ..security import CurrentUser
from ..store import Store

router = APIRouter()

Filter = Literal["all", "critical", "warning", "your_call", "resolved"]


def _visible(a: Alert) -> bool:
    if a.state == "ignored":
        return False
    if a.state == "silenced" and a.silenced_until and a.silenced_until > now():
        return False
    return True


def _matches(a: Alert, f: Filter) -> bool:
    open_ = a.state != "resolved"
    return {
        "all": True,
        "critical": open_ and a.severity == "critical",
        "warning": open_ and a.severity == "warning",
        "your_call": open_ and a.needs_review,
        "resolved": not open_,
    }[f]


async def _alert_or_404(store: Store, uid: str, alert_id: str) -> Alert:
    a = await store.get_alert(uid, alert_id)
    if a is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Alert not found")
    return a


@router.get("/overview", response_model=OverviewOut)
async def overview(user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    services = [ServiceOut.from_watched(w) for w in await store.list_watched(user.uid)]
    alerts = [a for a in await store.list_alerts(user.uid) if _visible(a) and a.state != "resolved"]
    activity = await store.list_activity(user.uid, limit=3)
    order = {"down": 0, "degraded": 1, "healthy": 2}
    return OverviewOut(
        services=sorted(services, key=lambda s: order[s.health]),
        open_alerts=len(alerts),
        critical=sum(a.severity == "critical" for a in alerts),
        warning=sum(a.severity == "warning" for a in alerts),
        your_call=sum(a.needs_review for a in alerts),
        activity=[ActivityOut.of(a) for a in activity],
    )


@router.get("/alerts", response_model=list[AlertOut])
async def list_alerts(filter: Filter = "all", user: CurrentUser = Depends(user_ctx),
                      store: Store = Depends(get_store)):
    alerts = [a for a in await store.list_alerts(user.uid) if _visible(a) and _matches(a, filter)]
    alerts.sort(key=lambda a: (a.state == "resolved", a.created_at.timestamp() * -1))
    return [AlertOut.of(a) for a in alerts]


@router.get("/alerts/{alert_id}", response_model=AlertOut)
async def get_alert(alert_id: str, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    return AlertOut.of(await _alert_or_404(store, user.uid, alert_id), with_evidence=True)


@router.post("/alerts/{alert_id}/ignore", response_model=AlertOut)
async def ignore(alert_id: str, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    a = await _alert_or_404(store, user.uid, alert_id)
    await store.update_alert(user.uid, a.id, {"state": "ignored"})
    await store.add_activity(user.uid, Activity(actor="you", action="You ignored an alert",
                                                detail=f"{a.title} on {a.service_name}.", meta=a.code, alert_id=a.id))
    return AlertOut.of(a.model_copy(update={"state": "ignored"}))


@router.post("/alerts/{alert_id}/unignore", response_model=AlertOut)
async def unignore(alert_id: str, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    a = await _alert_or_404(store, user.uid, alert_id)
    await store.update_alert(user.uid, a.id, {"state": "open", "silenced_until": None})
    await store.add_activity(user.uid, Activity(actor="you", action="You restored an alert",
                                                detail=f"{a.title} on {a.service_name}.", meta=a.code, alert_id=a.id))
    return AlertOut.of(a.model_copy(update={"state": "open"}))


@router.post("/alerts/{alert_id}/silence", response_model=AlertOut)
async def silence(alert_id: str, body: SilenceIn, user: CurrentUser = Depends(user_ctx),
                  store: Store = Depends(get_store)):
    a = await _alert_or_404(store, user.uid, alert_id)
    until = now() + timedelta(minutes=body.minutes)
    await store.update_alert(user.uid, a.id, {"state": "silenced", "silenced_until": until})
    await store.add_activity(user.uid, Activity(actor="you", action="You silenced an alert",
                                                detail=f"{a.title} for {body.minutes} min.", meta=a.code, alert_id=a.id))
    return AlertOut.of(a.model_copy(update={"state": "silenced", "silenced_until": until}))


@router.post("/alerts/{alert_id}/restart", status_code=202)
async def restart(alert_id: str, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store),
                  conn: RenderConnection = Depends(render_conn), factory=Depends(render_factory)):
    if not get_settings().actions_enabled:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Restart is disabled on this server (v1 is notify-only)")
    a = await _alert_or_404(store, user.uid, alert_id)
    try:
        async with factory(render_key(conn)) as render:
            await render.restart_service(a.service_id)
    except RenderError as e:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Render refused the restart ({e.status})")
    await store.add_activity(user.uid, Activity(
        actor="you", action="You restarted a service",
        detail=f"{a.service_name} restart sent to Render.",
        meta=f"evidence: {a.occurrences} lines · {a.code}", alert_id=a.id))
    return {"status": "restart_requested"}


@router.get("/activity", response_model=list[ActivityOut])
async def activity(before: datetime | None = Query(None), limit: int = Query(50, ge=1, le=100),
                   user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    return [ActivityOut.of(a) for a in await store.list_activity(user.uid, limit, before)]
