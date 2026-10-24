import os
from datetime import datetime, timedelta

import pytest
from cryptography.fernet import Fernet

os.environ.setdefault("FIREBASE_PROJECT_ID", "test-project")
os.environ.setdefault("ENCRYPTION_KEY", Fernet.generate_key().decode())
os.environ.setdefault("GEMINI_API_KEY", "test")

from app.models import Activity, Alert, Mandate, RenderConnection, WatchedService, now  # noqa: E402


class FakeStore:
    """In-memory stand-in for app.store.Store, same method surface."""

    def __init__(self):
        self.users: dict[str, dict] = {}
        self.watched: dict[str, dict[str, WatchedService]] = {}
        self.alerts: dict[str, dict[str, Alert]] = {}
        self.incidents: dict[str, dict[str, dict]] = {}
        self.activity: dict[str, list[Activity]] = {}
        self.devices: dict[str, set[str]] = {}
        self.slots: dict[str, int] = {}
        self._seq = 1000

    async def upsert_user(self, uid, email, github_login):
        return self.users.setdefault(uid, {"email": email, "github_login": github_login, "mandate": Mandate().model_dump()})

    async def get_user(self, uid):
        return self.users.get(uid, {})

    async def get_mandate(self, uid):
        return Mandate(**self.users.get(uid, {}).get("mandate", {}))

    async def set_mandate(self, uid, m):
        self.users.setdefault(uid, {})["mandate"] = m.model_dump()

    async def get_render(self, uid):
        raw = self.users.get(uid, {}).get("render")
        return RenderConnection(**raw) if raw else None

    async def set_render(self, uid, conn):
        self.users.setdefault(uid, {})["render"] = conn.model_dump()

    async def clear_render(self, uid):
        self.users.get(uid, {}).pop("render", None)
        self.watched.pop(uid, None)

    async def list_watched(self, uid):
        return list(self.watched.get(uid, {}).values())

    async def set_watched(self, uid, services):
        cur = self.watched.setdefault(uid, {})
        for k in list(cur):
            if k not in {s.id for s in services}:
                del cur[k]
        for s in services:
            cur.setdefault(s.id, s)

    async def update_watched(self, uid, sid, fields):
        w = self.watched[uid][sid]
        self.watched[uid][sid] = w.model_copy(update=fields)

    async def bump_incident(self, uid, fp, service_id, count, first_seen, last_seen, samples):
        inc = self.incidents.setdefault(uid, {}).get(fp)
        if inc:
            inc["count"] += count
            inc["last_seen"] = last_seen
        else:
            inc = {"service_id": service_id, "count": count, "first_seen": first_seen,
                   "last_seen": last_seen, "sample_lines": samples, "alert_id": None}
            self.incidents[uid][fp] = inc
        return dict(inc)

    async def link_incident(self, uid, fp, alert_id):
        self.incidents[uid][fp]["alert_id"] = alert_id

    async def create_alert(self, uid, alert):
        self._seq += 1
        a = alert.model_copy(update={"id": f"al{self._seq}", "code": f"#A-{self._seq}"})
        self.alerts.setdefault(uid, {})[a.id] = a
        return a

    async def get_alert(self, uid, alert_id):
        return self.alerts.get(uid, {}).get(alert_id)

    async def update_alert(self, uid, alert_id, fields):
        a = self.alerts[uid][alert_id]
        self.alerts[uid][alert_id] = a.model_copy(update=fields)

    async def list_alerts(self, uid, limit=100):
        return sorted(self.alerts.get(uid, {}).values(), key=lambda a: a.created_at, reverse=True)[:limit]

    async def open_alerts_seen_before(self, uid, service_id, cutoff):
        return [a for a in self.alerts.get(uid, {}).values()
                if a.service_id == service_id and a.state == "open" and a.last_seen < cutoff]

    async def add_activity(self, uid, entry):
        self.activity.setdefault(uid, []).insert(0, entry.model_copy(update={"id": f"ac{len(self.activity.get(uid, []))}"}))

    async def list_activity(self, uid, limit=50, before=None):
        items = [a for a in self.activity.get(uid, []) if before is None or a.created_at < before]
        return items[:limit]

    async def add_device(self, uid, token, platform, tz):
        self.devices.setdefault(uid, set()).add(token)

    async def remove_device(self, uid, token):
        self.devices.get(uid, set()).discard(token)

    async def device_tokens(self, uid):
        return list(self.devices.get(uid, set()))

    async def take_alert_slot(self, uid, max_per_hour):
        n = self.slots.get(uid, 0)
        if n >= max_per_hour:
            return False
        self.slots[uid] = n + 1
        return True


@pytest.fixture
def store():
    return FakeStore()


def ts(minutes_ago: float) -> datetime:
    return now() - timedelta(minutes=minutes_ago)
