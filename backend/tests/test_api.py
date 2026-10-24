import pytest
from fastapi.testclient import TestClient

from app import deps
from app.config import get_settings
from app.main import app
from app.models import Alert, now
from app.render_client import RenderAuthError, RenderOwner, RenderServiceInfo
from app.security import CurrentUser, current_user


class FakeRender:
    valid_key = "rnd_goodkey123"
    restarted: list[str] = []

    def __init__(self, key):
        self.key = key

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        pass

    async def list_owners(self):
        if self.key != self.valid_key:
            raise RenderAuthError(401, "bad key")
        return [RenderOwner("own1", "Acme", "team")]

    async def list_services(self, owner_id):
        return [
            RenderServiceInfo("srv-billing", "billing-worker", "background_worker", owner_id, "frankfurt", False),
            RenderServiceInfo("srv-api", "api-gateway", "web_service", owner_id, "oregon", False),
        ]

    async def restart_service(self, sid):
        FakeRender.restarted.append(sid)


@pytest.fixture
def client(store):
    app.dependency_overrides[deps.get_store] = lambda: store
    app.dependency_overrides[deps.render_factory] = lambda: FakeRender
    app.dependency_overrides[current_user] = lambda: CurrentUser("u1", "dev@example.com", "dev")
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_connect_rejects_bad_key(client):
    r = client.post("/render/connect", json={"api_key": "rnd_wrongkey"})
    assert r.status_code == 400


def test_connect_watch_and_me(client, store):
    r = client.post("/render/connect", json={"api_key": FakeRender.valid_key})
    assert r.status_code == 200 and len(r.json()) == 2
    raw = store.users["u1"]["render"]
    assert FakeRender.valid_key not in raw["encrypted_key"] and raw["key_last4"] == "y123"

    r = client.put("/services/watched", json={"ids": ["srv-billing"]})
    assert r.status_code == 200 and r.json()[0]["kind"] == "worker"

    me = client.get("/me").json()
    assert me["render_connected"] and me["watched_count"] == 1 and me["actions_enabled"] is False


def test_watch_limit(client):
    client.post("/render/connect", json={"api_key": FakeRender.valid_key})
    r = client.put("/services/watched", json={"ids": ["a", "b", "c", "d"]})
    assert r.status_code == 422


def _seed_alert(store, **kw):
    a = Alert(id="al1", code="#A-1", incident_id="fp", service_id="srv-billing", service_name="billing-worker",
              severity="critical", confidence=0.94, title="Crash loop detected", headline="h", summary="s",
              cause="c", suggestion="g", occurrences=18, first_seen=now(), last_seen=now(), **kw)
    store.alerts.setdefault("u1", {})["al1"] = a


def test_alert_ignore_unignore_and_filters(client, store):
    _seed_alert(store)
    assert len(client.get("/alerts").json()) == 1
    assert client.get("/alerts", params={"filter": "your_call"}).json() == []
    assert client.post("/alerts/al1/ignore").status_code == 200
    assert client.get("/alerts").json() == []
    client.post("/alerts/al1/unignore")
    assert client.get("/alerts/al1").json()["state"] == "open"
    actions = [a["action"] for a in client.get("/activity").json()]
    assert "You ignored an alert" in actions and "You restored an alert" in actions


def test_restart_disabled_by_default(client, store):
    client.post("/render/connect", json={"api_key": FakeRender.valid_key})
    _seed_alert(store)
    assert client.post("/alerts/al1/restart").status_code == 403


def test_restart_when_enabled(client, store, monkeypatch):
    monkeypatch.setattr(get_settings(), "actions_enabled", True)
    client.post("/render/connect", json={"api_key": FakeRender.valid_key})
    _seed_alert(store)
    assert client.post("/alerts/al1/restart").status_code == 202
    assert "srv-billing" in FakeRender.restarted


def test_mandate_rejects_auto_restart_when_disabled(client):
    m = client.get("/mandate").json()
    assert m["gate"] == 75
    m["auto_restart"] = True
    assert client.put("/mandate", json=m).status_code == 403
    m["auto_restart"] = False
    m["gate"] = 85
    assert client.put("/mandate", json=m).json()["gate"] == 85


def test_requires_auth(store):
    app.dependency_overrides[deps.get_store] = lambda: store
    r = TestClient(app).get("/me")
    app.dependency_overrides.clear()
    assert r.status_code == 401
