"""Firestore document shapes. Field names are what the app sees over the API."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Literal

from pydantic import BaseModel, Field


def now() -> datetime:
    return datetime.now(UTC)


Severity = Literal["critical", "warning", "info"]
AlertState = Literal["open", "ignored", "silenced", "resolved"]
Health = Literal["down", "degraded", "healthy"]
Actor = Literal["agent", "verifier", "you"]


class Mandate(BaseModel):
    gate: int = Field(75, ge=50, le=95)
    push_alerts: bool = True
    verifier: bool = True
    group_lines: bool = True
    auto_restart: bool = False
    max_alerts_per_hour: int = Field(6, ge=1, le=60)
    quiet_start: str | None = "23:00"  # local "HH:MM"; critical still gets through
    quiet_end: str | None = "07:00"
    timezone: str = "UTC"


class RenderConnection(BaseModel):
    encrypted_key: str
    key_last4: str
    owner_ids: list[str]
    connected_at: datetime = Field(default_factory=now)


class WatchedService(BaseModel):
    id: str  # Render service id
    uid: str
    owner_id: str
    name: str
    type: str
    region: str | None = None
    health: Health = "healthy"
    vitals: str = "waiting for logs"
    last_cursor_ts: datetime = Field(default_factory=now)
    lease_until: datetime = Field(default_factory=lambda: datetime.fromtimestamp(0, UTC))
    updated_at: datetime = Field(default_factory=now)


class Evidence(BaseModel):
    ts: datetime
    level: Literal["err", "wrn", "inf", "dbg"]
    before: str
    highlight: str = ""
    after: str = ""


class Alert(BaseModel):
    id: str = ""
    code: str = ""
    incident_id: str
    service_id: str
    service_name: str
    severity: Severity
    confidence: float
    title: str
    headline: str
    summary: str
    cause: str
    suggestion: str
    occurrences: int
    verified: bool = False
    verifier_note: str | None = None
    needs_review: bool = False
    state: AlertState = "open"
    silenced_until: datetime | None = None
    evidence: list[Evidence] = []
    first_seen: datetime
    last_seen: datetime
    created_at: datetime = Field(default_factory=now)


class Activity(BaseModel):
    id: str = ""
    actor: Actor
    action: str
    detail: str
    meta: str = ""
    alert_id: str | None = None
    created_at: datetime = Field(default_factory=now)
