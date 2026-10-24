from app import watcher
from app.models import Mandate, RenderConnection, WatchedService
from app.render_client import RenderLog
from app.security import encrypt_secret

from .conftest import ts
from .test_triage import FakeTriager


def _logs():
    out = []
    for c in range(4):
        base = 12 - c * 2
        out += [
            RenderLog(f"s{c}", "Starting billing-worker v2.14.0", ts(base), {"level": "info"}),
            RenderLog(f"m{c}", "Memory usage 501MB / 512MB", ts(base - 0.5), {}),
            RenderLog(f"x{c}", "Process exited with code 137 (OOMKilled)", ts(base - 0.6), {}),
        ]
    out.append(RenderLog("ok", "GET /health 200 3ms", ts(1), {"level": "info"}))
    return out


class FakeRender:
    def __init__(self, key):
        assert key == "rnd_goodkey123"

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        pass

    async def query_logs(self, owner, sid, start, end):
        return _logs()


async def _setup(store, mandate=Mandate()):
    await store.upsert_user("u1", None, "dev")
    await store.set_mandate("u1", mandate)
    await store.set_render("u1", RenderConnection(encrypted_key=encrypt_secret("rnd_goodkey123"),
                                                  key_last4="y123", owner_ids=["own1"]))
    svc = WatchedService(id="srv-billing", uid="u1", owner_id="own1", name="billing-worker",
                         type="background_worker", last_cursor_ts=ts(15))
    await store.set_watched("u1", [svc])
    return svc


async def test_crash_loop_becomes_one_alert(store, monkeypatch):
    monkeypatch.setattr(watcher, "RenderClient", FakeRender)
    pushes = []

    async def fake_push(store_, uid, alert, mandate):
        pushes.append(alert)
        return "sent to 1 device(s)"

    monkeypatch.setattr(watcher, "push_alert", fake_push)
    svc = await _setup(store)

    await watcher.process_service(store, FakeTriager(0.94), svc)

    alerts = await store.list_alerts("u1")
    assert len(alerts) == 1 and len(pushes) == 1
    a = alerts[0]
    assert a.severity == "critical" and not a.needs_review and a.verified
    w = (await store.list_watched("u1"))[0]
    assert w.health == "down"
    actions = [x.action for x in store.activity["u1"]]
    assert "Alert sent" in actions and "Verifier agreed" in actions

    # Second poll with the same incident: count updates, no second push.
    await watcher.process_service(store, FakeTriager(0.94), w)
    assert len(await store.list_alerts("u1")) == 1 and len(pushes) == 1


async def test_unsure_agent_asks(store, monkeypatch):
    monkeypatch.setattr(watcher, "RenderClient", FakeRender)

    async def fake_push(*_):
        return "sent"

    monkeypatch.setattr(watcher, "push_alert", fake_push)
    svc = await _setup(store, Mandate(verifier=False))
    await watcher.process_service(store, FakeTriager(0.58), svc)
    a = (await store.list_alerts("u1"))[0]
    assert a.needs_review
    assert store.activity["u1"][0].action == "Asked for your call"
