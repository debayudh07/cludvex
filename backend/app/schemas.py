"""API response/request shapes, aligned with the Flutter models."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from .models import Activity, Alert, Evidence, Mandate, WatchedService

ServiceKind = Literal["web", "worker", "static_site", "cron", "postgres"]


def kind_for(render_type: str) -> ServiceKind:
    return {
        "web_service": "web",
        "private_service": "web",
        "background_worker": "worker",
        "static_site": "static_site",
        "cron_job": "cron",
    }.get(render_type, "web")  # type: ignore[return-value]


class ServiceOut(BaseModel):
    id: str
    name: str
    kind: ServiceKind
    region: str | None
    health: Literal["down", "degraded", "healthy"] = "healthy"
    vitals: str = ""
    watched: bool = False

    @classmethod
    def from_watched(cls, w: WatchedService) -> "ServiceOut":
        return cls(id=w.id, name=w.name, kind=kind_for(w.type), region=w.region,
                   health=w.health, vitals=w.vitals, watched=True)


class AlertOut(BaseModel):
    id: str
    code: str
    title: str
    headline: str
    service_id: str
    service_name: str
    severity: Literal["critical", "warning", "info", "resolved"]
    state: str
    confidence: float
    occurrences: int
    summary: str
    cause: str
    suggestion: str
    verified: bool
    needs_review: bool
    first_seen: datetime
    last_seen: datetime
    created_at: datetime
    evidence: list[Evidence] = []

    @classmethod
    def of(cls, a: Alert, with_evidence: bool = False) -> "AlertOut":
        return cls(
            id=a.id, code=a.code, title=a.title, headline=a.headline,
            service_id=a.service_id, service_name=a.service_name,
            severity="resolved" if a.state == "resolved" else a.severity,
            state=a.state, confidence=a.confidence, occurrences=a.occurrences,
            summary=a.summary, cause=a.cause, suggestion=a.suggestion,
            verified=a.verified, needs_review=a.needs_review,
            first_seen=a.first_seen, last_seen=a.last_seen, created_at=a.created_at,
            evidence=a.evidence if with_evidence else [],
        )


class ActivityOut(BaseModel):
    id: str
    actor: str
    action: str
    detail: str
    meta: str
    created_at: datetime

    @classmethod
    def of(cls, a: Activity) -> "ActivityOut":
        return cls(id=a.id, actor=a.actor, action=a.action, detail=a.detail, meta=a.meta, created_at=a.created_at)


class MeOut(BaseModel):
    uid: str
    email: str | None
    github_login: str | None
    render_connected: bool
    key_last4: str | None
    watched_count: int
    actions_enabled: bool
    max_watched_services: int


class ConnectIn(BaseModel):
    api_key: str = Field(min_length=8, max_length=200)


class WatchedIn(BaseModel):
    ids: list[str]


class OverviewOut(BaseModel):
    services: list[ServiceOut]
    open_alerts: int
    critical: int
    warning: int
    your_call: int
    activity: list[ActivityOut]


class SilenceIn(BaseModel):
    minutes: int = Field(60, ge=5, le=24 * 60)


class DeviceIn(BaseModel):
    token: str
    platform: Literal["android", "ios", "web"]
    timezone: str | None = None


MandateIO = Mandate
