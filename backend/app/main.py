"""API process: `uvicorn app.main:app`."""

import asyncio
import logging
from contextlib import asynccontextmanager, suppress

import httpx
import structlog
from fastapi import FastAPI

from .config import get_settings
from .firebase import db
from .routers import account, alerts, logs
from .watcher import run_forever

settings = get_settings()
logging.basicConfig(level=settings.log_level)
structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(logging.getLevelName(settings.log_level)))
log = structlog.get_logger()


async def keep_awake(url: str, stop: asyncio.Event) -> None:
    """Hit our own public URL so the free instance never idles out."""
    async with httpx.AsyncClient(timeout=30) as client:
        while not stop.is_set():
            with suppress(TimeoutError):
                await asyncio.wait_for(stop.wait(), timeout=settings.keepalive_seconds)
                return
            try:
                await client.get(f"{url.rstrip('/')}/healthz")
            except httpx.HTTPError as e:
                log.warning("keepalive.failed", error=str(e))


@asynccontextmanager
async def lifespan(_: FastAPI):
    if not settings.run_watcher_in_api:
        yield
        return
    stop = asyncio.Event()
    tasks = [asyncio.create_task(run_forever(stop))]
    if settings.render_external_url:
        tasks.append(asyncio.create_task(keep_awake(settings.render_external_url, stop)))
    log.info("api.embedded_watcher", keepalive=bool(settings.render_external_url))
    try:
        yield
    finally:
        stop.set()
        await asyncio.gather(*tasks, return_exceptions=True)


app = FastAPI(title="Render Watcher API", version="0.1.0", lifespan=lifespan)
app.include_router(account.router)
app.include_router(alerts.router)
app.include_router(logs.router)


@app.get("/healthz")
async def healthz():
    await db().collection("_health").document("ping").get()
    return {"ok": True, "actions_enabled": settings.actions_enabled}
