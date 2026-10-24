"""Cheap, deterministic first pass: decide which log lines are suspicious,
then fold repeats into incidents so the LLM sees one problem, not 200 lines."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import StrEnum


class Level(StrEnum):
    ERR = "err"
    WRN = "wrn"
    INF = "inf"
    DBG = "dbg"


class Signal(StrEnum):
    OOM = "oom"
    CRASH = "crash"  # non-zero exit
    BOOT = "boot"  # process start, used for crash-loop detection
    HTTP_5XX = "http_5xx"
    MEMORY = "memory"
    CONNECTION = "connection"
    TIMEOUT = "timeout"
    ERROR = "error"
    WARNING = "warning"


_RULES: list[tuple[Signal, re.Pattern[str]]] = [
    (Signal.OOM, re.compile(r"OOMKilled|out of memory|code 137|JavaScript heap out of memory", re.I)),
    (Signal.CRASH, re.compile(r"exited with (status|code) [1-9]\d*|segmentation fault|panic:|Traceback \(most recent", re.I)),
    (Signal.BOOT, re.compile(r"^(starting|booting|listening on|server started)", re.I)),
    (Signal.HTTP_5XX, re.compile(
        r"(?:\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+\S+\s+|\bstatus[=: ]+|HTTP/\d(?:\.\d)?\"?\s+)5\d\d\b")),
    (Signal.MEMORY, re.compile(r"memory (usage|limit)|heap (usage|limit)|\bMemory usage\b", re.I)),
    (Signal.CONNECTION, re.compile(r"ECONNREFUSED|ECONNRESET|connection (refused|reset)|could not connect", re.I)),
    (Signal.TIMEOUT, re.compile(r"timed? ?out|timeout|ETIMEDOUT", re.I)),
    (Signal.ERROR, re.compile(r"\b(error|err|fatal|exception|critical)\b", re.I)),
    (Signal.WARNING, re.compile(r"\b(warn|warning|deprecated)\b", re.I)),
]

_MEM_PCT = re.compile(r"(\d+(?:\.\d+)?)\s*(MB|MiB|GB|GiB)\s*/\s*(\d+(?:\.\d+)?)\s*(MB|MiB|GB|GiB)", re.I)

SERIOUS = {Signal.OOM, Signal.CRASH, Signal.HTTP_5XX, Signal.CONNECTION, Signal.TIMEOUT, Signal.ERROR}


@dataclass
class Line:
    id: str
    ts: datetime
    message: str
    level: Level
    signals: set[Signal] = field(default_factory=set)

    @property
    def suspicious(self) -> bool:
        return bool(self.signals - {Signal.BOOT})


def _memory_high(message: str) -> bool:
    m = _MEM_PCT.search(message)
    if not m:
        return False
    used, total = float(m.group(1)), float(m.group(3))
    return total > 0 and used / total >= 0.9


def classify(
    line_id: str,
    ts: datetime,
    message: str,
    render_level: str | None,
    status_code: str | None = None,
) -> Line:
    signals: set[Signal] = set()
    for signal, pattern in _RULES:
        if pattern.search(message):
            signals.add(signal)
    if status_code and status_code.startswith("5"):
        signals.add(Signal.HTTP_5XX)
    if Signal.MEMORY in signals and not _memory_high(message):
        signals.discard(Signal.MEMORY)
    lvl = (render_level or "").lower()
    if lvl.startswith("err") or lvl in {"fatal", "critical"} or signals & {Signal.OOM, Signal.CRASH}:
        level = Level.ERR
        signals.add(Signal.ERROR)
    elif lvl.startswith("warn") or Signal.WARNING in signals or Signal.MEMORY in signals:
        level = Level.WRN
    elif Signal.ERROR in signals or Signal.HTTP_5XX in signals:
        level = Level.ERR
    elif lvl.startswith("debug"):
        level = Level.DBG
    else:
        level = Level.INF
    return Line(line_id, ts, message, level, signals)


_NORMALIZERS = [
    (re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", re.I), "<uuid>"),
    (re.compile(r"\b\d{4}-\d{2}-\d{2}[T ][\d:.]+Z?\b"), "<ts>"),
    (re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"), "<ip>"),
    (re.compile(r"\b[0-9a-f]{12,}\b", re.I), "<hex>"),
    (re.compile(r"\d+(\.\d+)?"), "<n>"),
    (re.compile(r"\s+"), " "),
]


def normalize(message: str) -> str:
    out = message
    for pattern, repl in _NORMALIZERS:
        out = pattern.sub(repl, out)
    return out.strip()[:200]


_CRASH_FAMILY = {Signal.OOM, Signal.CRASH, Signal.MEMORY}


def fingerprint(service_id: str, line: Line, crash_loop: bool = False) -> str:
    # In a crash loop, OOM / exit / memory-pressure lines are one problem.
    if crash_loop and line.signals & _CRASH_FAMILY:
        return hashlib.sha1(f"{service_id}|crash_loop".encode()).hexdigest()[:16]
    # The dominant signal keeps related variants (502 vs 503) in one incident.
    primary = next((s for s in (Signal.OOM, Signal.CRASH, Signal.HTTP_5XX, Signal.CONNECTION,
                                Signal.TIMEOUT, Signal.MEMORY) if s in line.signals), None)
    key = f"{service_id}|{primary or normalize(line.message)}"
    return hashlib.sha1(key.encode()).hexdigest()[:16]


@dataclass
class IncidentDraft:
    fingerprint: str
    service_id: str
    lines: list[Line]

    @property
    def count(self) -> int:
        return len(self.lines)

    @property
    def signals(self) -> set[Signal]:
        out: set[Signal] = set()
        for l in self.lines:
            out |= l.signals
        return out


def group(service_id: str, lines: list[Line], crash_loop: bool = False) -> list[IncidentDraft]:
    buckets: dict[str, IncidentDraft] = {}
    for line in lines:
        if not line.suspicious:
            continue
        fp = fingerprint(service_id, line, crash_loop)
        buckets.setdefault(fp, IncidentDraft(fp, service_id, [])).lines.append(line)
    return list(buckets.values())


def is_crash_loop(lines: list[Line], window: timedelta = timedelta(minutes=10), min_cycles: int = 3) -> bool:
    """Several boot → crash cycles inside the window."""
    if not lines:
        return False
    cutoff = lines[-1].ts - window
    recent = [l for l in lines if l.ts >= cutoff]
    boots = sum(1 for l in recent if Signal.BOOT in l.signals)
    crashes = sum(1 for l in recent if l.signals & {Signal.OOM, Signal.CRASH})
    return boots >= min_cycles and crashes >= min_cycles


def should_triage(draft: IncidentDraft, total_count: int, crash_loop: bool) -> bool:
    """Serious signals triage on the first hit; noisier ones need repetition."""
    s = draft.signals
    if s & {Signal.OOM, Signal.CRASH} or (crash_loop and s & _CRASH_FAMILY):
        return True
    if s & {Signal.HTTP_5XX, Signal.CONNECTION, Signal.TIMEOUT}:
        return total_count >= 3
    if Signal.ERROR in s:
        return total_count >= 5
    return total_count >= 20  # warnings / memory pressure


def health_for(lines: list[Line], window_minutes: int, crash_loop: bool) -> tuple[str, str]:
    """(health, vitals) shown on the Overview. Rates are per hour."""
    errors = sum(1 for l in lines if l.level == Level.ERR)
    per_hour = round(errors * 60 / max(window_minutes, 1))
    five_xx = sum(1 for l in lines if Signal.HTTP_5XX in l.signals)
    last_exit = next((l for l in reversed(lines) if l.signals & {Signal.OOM, Signal.CRASH}), None)
    parts = [f"{per_hour} err/h"]
    if last_exit is not None:
        parts.append("OOMKilled" if Signal.OOM in last_exit.signals else "crashed")
    if five_xx:
        parts.append(f"{five_xx} 5xx")
    vitals = " · ".join(parts)
    if crash_loop or per_hour >= 50:
        return "down", vitals
    if per_hour >= 5 or five_xx:
        return "degraded", vitals
    return "healthy", vitals
