"""Thin client for the Render public API. Every Render-specific detail
(paths, pagination, label names) lives here."""

from collections.abc import AsyncIterator
from dataclasses import dataclass
from datetime import datetime
import json
from urllib.parse import urlencode

import httpx
import websockets

from .config import get_settings


class RenderError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(f"Render API {status}: {message}")
        self.status = status


class RenderAuthError(RenderError):
    pass


@dataclass
class RenderOwner:
    id: str
    name: str
    type: str


@dataclass
class RenderServiceInfo:
    id: str
    name: str
    type: str  # web_service | private_service | background_worker | cron_job | static_site
    owner_id: str
    region: str | None
    suspended: bool


@dataclass
class RenderLog:
    id: str
    message: str
    timestamp: datetime
    labels: dict[str, str]

    @property
    def level(self) -> str | None:
        return self.labels.get("level")

    @property
    def resource(self) -> str | None:
        return self.labels.get("resource")


def _parse_log(raw: dict) -> RenderLog:
    return RenderLog(
        id=raw["id"],
        message=raw.get("message", ""),
        timestamp=datetime.fromisoformat(raw["timestamp"].replace("Z", "+00:00")),
        labels={l["name"]: l["value"] for l in raw.get("labels", [])},
    )


def _iso(dt: datetime) -> str:
    return dt.isoformat().replace("+00:00", "Z")


class RenderClient:
    def __init__(self, api_key: str, transport: httpx.AsyncBaseTransport | None = None):
        self._key = api_key
        self._base = get_settings().render_api_base
        self._http = httpx.AsyncClient(
            base_url=self._base,
            headers={"Authorization": f"Bearer {api_key}", "Accept": "application/json"},
            timeout=httpx.Timeout(20.0),
            transport=transport,
        )

    async def __aenter__(self) -> "RenderClient":
        return self

    async def __aexit__(self, *exc) -> None:
        await self._http.aclose()

    async def _get(self, path: str, params: list[tuple[str, str]] | None = None):
        r = await self._http.get(path, params=params)
        if r.status_code in (401, 403):
            raise RenderAuthError(r.status_code, "API key rejected")
        if r.status_code >= 400:
            raise RenderError(r.status_code, r.text[:300])
        return r.json()

    async def list_owners(self) -> list[RenderOwner]:
        data = await self._get("/owners", [("limit", "100")])
        return [RenderOwner(o["owner"]["id"], o["owner"]["name"], o["owner"]["type"]) for o in data]

    async def list_services(self, owner_id: str) -> list[RenderServiceInfo]:
        out: list[RenderServiceInfo] = []
        cursor: str | None = None
        while True:
            params = [("ownerId", owner_id), ("limit", "100"), ("includePreviews", "false")]
            if cursor:
                params.append(("cursor", cursor))
            page = await self._get("/services", params)
            for item in page:
                s = item["service"]
                details = s.get("serviceDetails") or {}
                out.append(RenderServiceInfo(
                    id=s["id"],
                    name=s["name"],
                    type=s["type"],
                    owner_id=s["ownerId"],
                    region=details.get("region"),
                    suspended=s.get("suspended") == "suspended",
                ))
            if len(page) < 100:
                return out
            cursor = page[-1]["cursor"]

    async def query_logs(
        self,
        owner_id: str,
        resource_id: str,
        start: datetime,
        end: datetime,
        *,
        direction: str = "forward",
        max_pages: int = 5,
    ) -> list[RenderLog]:
        """Logs for one resource in [start, end], following hasMore pages."""
        logs: list[RenderLog] = []
        params_start, params_end = start, end
        for _ in range(max_pages):
            page = await self._get("/logs", [
                ("ownerId", owner_id),
                ("resource", resource_id),
                ("startTime", _iso(params_start)),
                ("endTime", _iso(params_end)),
                ("direction", direction),
                ("limit", "100"),
            ])
            logs.extend(_parse_log(l) for l in page.get("logs", []))
            if not page.get("hasMore"):
                break
            params_start = datetime.fromisoformat(page["nextStartTime"].replace("Z", "+00:00"))
            params_end = datetime.fromisoformat(page["nextEndTime"].replace("Z", "+00:00"))
        return logs

    async def subscribe_logs(self, owner_id: str, resource_ids: list[str]) -> AsyncIterator[RenderLog]:
        """Live tail via Render's websocket. Yields until the socket closes."""
        query = urlencode([("ownerId", owner_id)] + [("resource", r) for r in resource_ids])
        url = f"{get_settings().render_ws_base}/logs/subscribe?{query}"
        async with websockets.connect(
            url, additional_headers={"Authorization": f"Bearer {self._key}"}, ping_interval=20
        ) as ws:
            async for msg in ws:
                try:
                    yield _parse_log(json.loads(msg))
                except (KeyError, ValueError):
                    continue

    async def restart_service(self, service_id: str) -> None:
        r = await self._http.post(f"/services/{service_id}/restart")
        if r.status_code in (401, 403):
            raise RenderAuthError(r.status_code, "API key rejected")
        if r.status_code >= 400:
            raise RenderError(r.status_code, r.text[:300])
