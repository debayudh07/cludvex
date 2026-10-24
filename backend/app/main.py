"""API process: `uvicorn app.main:app`."""

import logging

import structlog
from fastapi import FastAPI

from .config import get_settings
from .firebase import db
from .routers import account, alerts, logs

settings = get_settings()
logging.basicConfig(level=settings.log_level)
structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(logging.getLevelName(settings.log_level)))

app = FastAPI(title="Render Watcher API", version="0.1.0")
app.include_router(account.router)
app.include_router(alerts.router)
app.include_router(logs.router)


@app.get("/healthz")
async def healthz():
    await db().collection("_health").document("ping").get()
    return {"ok": True, "actions_enabled": settings.actions_enabled}
