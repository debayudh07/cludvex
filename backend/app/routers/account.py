import time
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Response, status

from ..config import get_settings
from ..deps import get_store, render_conn, render_factory, render_key, user_ctx
from ..models import Activity, Mandate, RenderConnection, WatchedService, now
from ..render_client import RenderAuthError, RenderError, RenderServiceInfo
from ..schemas import ConnectIn, DeviceIn, MeOut, ServiceOut, WatchedIn, kind_for
from ..security import CurrentUser, encrypt_secret
from ..store import Store

router = APIRouter()

# Small per-user cache so the picker doesn't hammer Render's rate limit.
_services_cache: dict[str, tuple[float, list[RenderServiceInfo]]] = {}


async def _fetch_services(uid: str, key: str, owner_ids: list[str], factory) -> list[RenderServiceInfo]:
    hit = _services_cache.get(uid)
    if hit and time.monotonic() - hit[0] < 60:
        return hit[1]
    out: list[RenderServiceInfo] = []
    async with factory(key) as render:
        for owner in owner_ids:
            out.extend(await render.list_services(owner))
    _services_cache[uid] = (time.monotonic(), out)
    return out


@router.get("/me", response_model=MeOut)
async def me(user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    s = get_settings()
    conn = await store.get_render(user.uid)
    watched = await store.list_watched(user.uid) if conn else []
    return MeOut(
        uid=user.uid, email=user.email, github_login=user.github_login,
        render_connected=conn is not None, key_last4=conn.key_last4 if conn else None,
        watched_count=len(watched), actions_enabled=s.actions_enabled,
        max_watched_services=s.max_watched_services,
    )


@router.post("/render/connect", response_model=list[ServiceOut])
async def connect_render(body: ConnectIn, user: CurrentUser = Depends(user_ctx),
                         store: Store = Depends(get_store), factory=Depends(render_factory)):
    key = body.api_key.strip()
    try:
        async with factory(key) as render:
            owners = await render.list_owners()
    except RenderAuthError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Render rejected this API key")
    except RenderError as e:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Render is unavailable ({e.status})")
    if not owners:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This key has no workspaces")

    await store.set_render(user.uid, RenderConnection(
        encrypted_key=encrypt_secret(key), key_last4=key[-4:], owner_ids=[o.id for o in owners]))
    _services_cache.pop(user.uid, None)
    services = await _fetch_services(user.uid, key, [o.id for o in owners], factory)
    await store.add_activity(user.uid, Activity(
        actor="you", action="You connected Render",
        detail=f"Key ending ••••{key[-4:]}. {len(services)} services found.", meta="from: onboarding"))
    return [ServiceOut(id=s.id, name=s.name, kind=kind_for(s.type), region=s.region) for s in services]


@router.delete("/render/connect", status_code=204)
async def disconnect_render(user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    await store.clear_render(user.uid)
    _services_cache.pop(user.uid, None)
    await store.add_activity(user.uid, Activity(
        actor="you", action="You removed the Render key",
        detail="The agent stopped watching all services.", meta="from: mandate"))
    return Response(status_code=204)


@router.get("/services", response_model=list[ServiceOut])
async def list_services(user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store),
                        conn: RenderConnection = Depends(render_conn), factory=Depends(render_factory)):
    try:
        services = await _fetch_services(user.uid, render_key(conn), conn.owner_ids, factory)
    except RenderAuthError:
        raise HTTPException(status.HTTP_409_CONFLICT, "Render key was revoked; reconnect Render")
    watched = {w.id: w for w in await store.list_watched(user.uid)}
    out = []
    for s in services:
        w = watched.get(s.id)
        out.append(ServiceOut.from_watched(w) if w else
                   ServiceOut(id=s.id, name=s.name, kind=kind_for(s.type), region=s.region))
    return out


@router.put("/services/watched", response_model=list[ServiceOut])
async def set_watched(body: WatchedIn, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store),
                      conn: RenderConnection = Depends(render_conn), factory=Depends(render_factory)):
    s = get_settings()
    ids = list(dict.fromkeys(body.ids))
    if len(ids) > s.max_watched_services:
        raise HTTPException(422,
                            f"You can watch up to {s.max_watched_services} services")
    by_id = {x.id: x for x in await _fetch_services(user.uid, render_key(conn), conn.owner_ids, factory)}
    unknown = [i for i in ids if i not in by_id]
    if unknown:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Unknown services: {', '.join(unknown)}")
    start = now() - timedelta(minutes=5)
    watched = [WatchedService(id=i, uid=user.uid, owner_id=by_id[i].owner_id, name=by_id[i].name,
                              type=by_id[i].type, region=by_id[i].region, last_cursor_ts=start) for i in ids]
    await store.set_watched(user.uid, watched)
    await store.add_activity(user.uid, Activity(
        actor="you", action="You changed watched services",
        detail=", ".join(w.name for w in watched) or "None", meta="from: services"))
    return [ServiceOut.from_watched(w) for w in await store.list_watched(user.uid)]


@router.get("/mandate", response_model=Mandate)
async def get_mandate(user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    return await store.get_mandate(user.uid)


@router.put("/mandate", response_model=Mandate)
async def put_mandate(body: Mandate, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    if body.auto_restart and not get_settings().actions_enabled:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Agent actions are disabled on this server (v1 is notify-only)")
    before = await store.get_mandate(user.uid)
    await store.set_mandate(user.uid, body)
    changes = [f"{k}: {getattr(before, k)} → {v}" for k, v in body.model_dump().items()
               if getattr(before, k) != v and k != "timezone"]
    if changes:
        await store.add_activity(user.uid, Activity(
            actor="you", action="You changed the mandate", detail="; ".join(changes), meta="from: mandate"))
    return body


@router.post("/devices", status_code=204)
async def add_device(body: DeviceIn, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    await store.add_device(user.uid, body.token, body.platform, body.timezone)
    return Response(status_code=204)


@router.delete("/devices/{token}", status_code=204)
async def remove_device(token: str, user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)):
    await store.remove_device(user.uid, token)
    return Response(status_code=204)
