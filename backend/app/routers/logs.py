"""Live tail: the app never sees the Render key, so we proxy Render's log
websocket. Sends a short backfill first so the player isn't empty."""

import asyncio
from collections import defaultdict
from datetime import timedelta

import structlog
from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect

from ..deps import get_store, render_factory
from ..models import now
from ..pipeline.filter import SERIOUS, classify
from ..render_client import RenderLog
from ..security import decrypt_secret, verify_token

router = APIRouter()
log = structlog.get_logger()


def _out(index: int, r: RenderLog) -> dict:
    line = classify(r.id, r.timestamp, r.message, r.level, r.labels.get("statusCode"))
    return {
        "index": index,
        "time": r.timestamp.isoformat(),
        "level": line.level.value,
        "service_id": r.resource,
        "message": r.message[:2000],
        "flagged": bool(line.signals & SERIOUS),
    }


@router.websocket("/logs/stream")
async def stream(ws: WebSocket, token: str):
    try:
        user = await verify_token(token)
    except HTTPException:
        await ws.close(code=4401)
        return
    store = get_store()
    conn = await store.get_render(user.uid)
    watched = await store.list_watched(user.uid)
    if conn is None or not watched:
        await ws.close(code=4409)
        return
    await ws.accept()
    key = decrypt_secret(conn.encrypted_key)
    factory = render_factory()
    counter = 0

    by_owner: dict[str, list[str]] = defaultdict(list)
    for w in watched:
        by_owner[w.owner_id].append(w.id)

    async with factory(key) as render:
        # Backfill: last 15 minutes, newest 50 lines per service.
        backfill: list[RenderLog] = []
        for w in watched:
            try:
                backfill += await render.query_logs(w.owner_id, w.id, now() - timedelta(minutes=15), now(),
                                                    direction="backward", max_pages=1)
            except Exception:
                log.warning("logs.backfill_failed", service=w.id)
        for r in sorted(backfill, key=lambda r: r.timestamp):
            await ws.send_json(_out(counter, r))
            counter += 1

        queue: asyncio.Queue[RenderLog] = asyncio.Queue(maxsize=1000)

        async def pump(owner: str, ids: list[str]):
            async for r in render.subscribe_logs(owner, ids):
                if queue.full():
                    queue.get_nowait()  # drop oldest rather than stall
                await queue.put(r)

        async def client_watch():
            while True:
                await ws.receive_text()  # pings / close; content ignored

        tasks = [asyncio.create_task(pump(o, ids)) for o, ids in by_owner.items()]
        tasks.append(asyncio.create_task(client_watch()))
        try:
            while True:
                getter = asyncio.create_task(queue.get())
                done, _ = await asyncio.wait([getter, *tasks], return_when=asyncio.FIRST_COMPLETED)
                if getter not in done:
                    getter.cancel()
                    break  # Render socket closed or client left; app reconnects
                await ws.send_json(_out(counter, getter.result()))
                counter += 1
        except WebSocketDisconnect:
            pass
        finally:
            for t in tasks:
                t.cancel()
    try:
        await ws.close(code=1011)
    except RuntimeError:
        pass
