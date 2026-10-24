"""All Firestore access. Layout:

users/{uid}                      profile, mandate, render, alert_seq
users/{uid}/watched/{serviceId}  WatchedService
users/{uid}/incidents/{fp}       grouped repeats
users/{uid}/alerts/{id}          Alert
users/{uid}/activity/{id}        Activity (audit log)
users/{uid}/devices/{token}      FCM tokens
users/{uid}/counters/rate        alerts sent this hour
"""

from __future__ import annotations

from datetime import datetime, timedelta

from google.cloud import firestore
from google.cloud.firestore import AsyncClient, AsyncTransaction
from google.cloud.firestore_v1.base_query import FieldFilter

from .models import Activity, Alert, Mandate, RenderConnection, WatchedService, now


class Store:
    def __init__(self, client: AsyncClient):
        self.db = client

    def _user(self, uid: str):
        return self.db.collection("users").document(uid)

    # ---- users
    async def upsert_user(self, uid: str, email: str | None, github_login: str | None) -> dict:
        ref = self._user(uid)
        snap = await ref.get()
        if not snap.exists:
            data = {
                "email": email,
                "github_login": github_login,
                "mandate": Mandate().model_dump(),
                "alert_seq": 1000,
                "created_at": now(),
            }
            await ref.set(data)
            return data
        data = snap.to_dict() or {}
        if github_login and data.get("github_login") != github_login:
            await ref.update({"github_login": github_login})
        return data

    async def get_user(self, uid: str) -> dict:
        snap = await self._user(uid).get()
        return snap.to_dict() or {}

    async def get_mandate(self, uid: str) -> Mandate:
        return Mandate(**(await self.get_user(uid)).get("mandate", {}))

    async def set_mandate(self, uid: str, mandate: Mandate) -> None:
        await self._user(uid).set({"mandate": mandate.model_dump()}, merge=True)

    # ---- render connection
    async def get_render(self, uid: str) -> RenderConnection | None:
        raw = (await self.get_user(uid)).get("render")
        return RenderConnection(**raw) if raw else None

    async def set_render(self, uid: str, conn: RenderConnection) -> None:
        await self._user(uid).set({"render": conn.model_dump()}, merge=True)

    async def clear_render(self, uid: str) -> None:
        await self._user(uid).update({"render": firestore.DELETE_FIELD})
        async for doc in self._user(uid).collection("watched").stream():
            await doc.reference.delete()

    # ---- watched services
    async def list_watched(self, uid: str) -> list[WatchedService]:
        return [WatchedService(**d.to_dict()) async for d in self._user(uid).collection("watched").stream()]

    async def set_watched(self, uid: str, services: list[WatchedService]) -> None:
        col = self._user(uid).collection("watched")
        keep = {s.id for s in services}
        async for doc in col.stream():
            if doc.id not in keep:
                await doc.reference.delete()
        for s in services:
            ref = col.document(s.id)
            if not (await ref.get()).exists:
                await ref.set(s.model_dump())

    async def update_watched(self, uid: str, service_id: str, fields: dict) -> None:
        await self._user(uid).collection("watched").document(service_id).update({**fields, "updated_at": now()})

    async def lease_due(self, lease_seconds: int, limit: int = 25) -> list[WatchedService]:
        """Claims due services across all users. Safe with several watchers."""
        t = now()
        q = (self.db.collection_group("watched")
             .where(filter=FieldFilter("lease_until", "<", t))
             .limit(limit))
        claimed: list[WatchedService] = []
        async for snap in q.stream():
            transaction = self.db.transaction()
            if await _claim(transaction, snap.reference, t, lease_seconds):
                claimed.append(WatchedService(**snap.to_dict()))
        return claimed

    # ---- incidents
    async def bump_incident(self, uid: str, fp: str, service_id: str, count: int,
                            first_seen: datetime, last_seen: datetime, samples: list[str]) -> dict:
        ref = self._user(uid).collection("incidents").document(fp)
        snap = await ref.get()
        if snap.exists:
            cur = snap.to_dict() or {}
            data = {
                "count": cur.get("count", 0) + count,
                "last_seen": last_seen,
                "sample_lines": (cur.get("sample_lines", []) + samples)[-20:],
            }
            await ref.update(data)
            return {**cur, **data}
        data = {"service_id": service_id, "count": count, "first_seen": first_seen,
                "last_seen": last_seen, "sample_lines": samples[-20:], "alert_id": None}
        await ref.set(data)
        return data

    async def link_incident(self, uid: str, fp: str, alert_id: str) -> None:
        await self._user(uid).collection("incidents").document(fp).update({"alert_id": alert_id})

    # ---- alerts
    async def create_alert(self, uid: str, alert: Alert) -> Alert:
        transaction = self.db.transaction()
        seq = await _next_seq(transaction, self._user(uid))
        ref = self._user(uid).collection("alerts").document()
        alert = alert.model_copy(update={"id": ref.id, "code": f"#A-{seq}"})
        await ref.set(alert.model_dump(exclude={"id"}))
        return alert

    async def get_alert(self, uid: str, alert_id: str) -> Alert | None:
        snap = await self._user(uid).collection("alerts").document(alert_id).get()
        return Alert(id=snap.id, **snap.to_dict()) if snap.exists else None

    async def update_alert(self, uid: str, alert_id: str, fields: dict) -> None:
        await self._user(uid).collection("alerts").document(alert_id).update(fields)

    async def list_alerts(self, uid: str, limit: int = 100) -> list[Alert]:
        q = (self._user(uid).collection("alerts")
             .order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit))
        return [Alert(id=d.id, **d.to_dict()) async for d in q.stream()]

    async def open_alerts_seen_before(self, uid: str, service_id: str, cutoff: datetime) -> list[Alert]:
        q = (self._user(uid).collection("alerts")
             .where(filter=FieldFilter("service_id", "==", service_id))
             .where(filter=FieldFilter("state", "==", "open")))
        return [a async for a in _alerts(q) if a.last_seen < cutoff]

    # ---- activity
    async def add_activity(self, uid: str, entry: Activity) -> None:
        await self._user(uid).collection("activity").add(entry.model_dump(exclude={"id"}))

    async def list_activity(self, uid: str, limit: int = 50, before: datetime | None = None) -> list[Activity]:
        q = self._user(uid).collection("activity").order_by("created_at", direction=firestore.Query.DESCENDING)
        if before:
            q = q.where(filter=FieldFilter("created_at", "<", before))
        return [Activity(id=d.id, **d.to_dict()) async for d in q.limit(limit).stream()]

    # ---- devices
    async def add_device(self, uid: str, token: str, platform: str, tz: str | None) -> None:
        await self._user(uid).collection("devices").document(token).set({"platform": platform, "updated_at": now()})
        if tz:
            await self._user(uid).set({"mandate": {"timezone": tz}}, merge=True)

    async def remove_device(self, uid: str, token: str) -> None:
        await self._user(uid).collection("devices").document(token).delete()

    async def device_tokens(self, uid: str) -> list[str]:
        return [d.id async for d in self._user(uid).collection("devices").stream()]

    # ---- rate limit
    async def take_alert_slot(self, uid: str, max_per_hour: int) -> bool:
        transaction = self.db.transaction()
        return await _take_slot(transaction, self._user(uid).collection("counters").document("rate"), max_per_hour)


async def _alerts(q):
    async for d in q.stream():
        yield Alert(id=d.id, **d.to_dict())


@firestore.async_transactional
async def _claim(transaction: AsyncTransaction, ref, t: datetime, lease_seconds: int) -> bool:
    snap = await ref.get(transaction=transaction)
    if not snap.exists or snap.get("lease_until") >= t:
        return False  # someone else got it
    transaction.update(ref, {"lease_until": t + timedelta(seconds=lease_seconds)})
    return True


@firestore.async_transactional
async def _next_seq(transaction: AsyncTransaction, user_ref) -> int:
    snap = await user_ref.get(transaction=transaction)
    seq = int((snap.to_dict() or {}).get("alert_seq", 1000)) + 1
    transaction.set(user_ref, {"alert_seq": seq}, merge=True)
    return seq


@firestore.async_transactional
async def _take_slot(transaction: AsyncTransaction, ref, max_per_hour: int) -> bool:
    hour = now().strftime("%Y%m%d%H")
    snap = await ref.get(transaction=transaction)
    data = snap.to_dict() or {}
    count = data.get("count", 0) if data.get("hour") == hour else 0
    if count >= max_per_hour:
        return False
    transaction.set(ref, {"hour": hour, "count": count + 1})
    return True
