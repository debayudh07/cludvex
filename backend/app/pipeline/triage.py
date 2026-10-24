"""Incident → LLM triage → optional verifier → confidence gate → alert."""

from __future__ import annotations

from dataclasses import dataclass

from ..llm import Triager, TriageResult, VerifyResult
from ..models import Alert, Evidence, Mandate
from .filter import IncidentDraft, Line


@dataclass
class Decision:
    alert: Alert
    triage: TriageResult
    verify: VerifyResult | None


def split_highlight(message: str, highlight: str) -> tuple[str, str, str]:
    if highlight:
        i = message.find(highlight)
        if i >= 0:
            return message[:i], highlight, message[i + len(highlight):]
    return message, "", ""


def gate(confidence: float, mandate: Mandate) -> bool:
    """True when the agent is sure enough to state the alert as fact."""
    return round(confidence * 100) >= mandate.gate


def build_context(service_name: str, service_type: str, draft: IncidentDraft, total_count: int,
                  crash_loop: bool, context_lines: list[Line]) -> tuple[dict, list[Line]]:
    """Lines shown to the model: the incident's lines plus nearby context, capped."""
    picked = {l.id: l for l in draft.lines[-20:]}
    for l in context_lines[-30:]:
        picked.setdefault(l.id, l)
    lines = sorted(picked.values(), key=lambda l: l.ts)[-40:]
    ctx = {
        "service": service_name,
        "service_type": service_type,
        "occurrences_total": total_count,
        "occurrences_this_poll": draft.count,
        "signals": sorted(s.value for s in draft.signals),
        "crash_loop_detected": crash_loop,
        "lines": [f"{l.ts.strftime('%H:%M:%S')} {l.level.value.upper()} {l.message[:400]}" for l in lines],
    }
    return ctx, lines


async def decide(
    triager: Triager,
    mandate: Mandate,
    *,
    service_id: str,
    service_name: str,
    service_type: str,
    draft: IncidentDraft,
    total_count: int,
    first_seen,
    crash_loop: bool,
    context_lines: list[Line],
) -> Decision:
    ctx, lines = build_context(service_name, service_type, draft, total_count, crash_loop, context_lines)
    t = await triager.triage(ctx)

    v: VerifyResult | None = None
    confidence = t.confidence
    if mandate.verifier:
        v = await triager.verify(ctx, t)
        if v.refuted:
            confidence = min(confidence, v.adjusted_confidence)

    evidence: list[Evidence] = []
    for pick in t.evidence[:6]:
        if 0 <= pick.index < len(lines):
            line = lines[pick.index]
            before, hl, after = split_highlight(line.message, pick.highlight)
            evidence.append(Evidence(ts=line.ts, level=line.level.value, before=before, highlight=hl, after=after))
    if not evidence:
        evidence = [Evidence(ts=l.ts, level=l.level.value, before=l.message) for l in draft.lines[-4:]]

    alert = Alert(
        incident_id=draft.fingerprint,
        service_id=service_id,
        service_name=service_name,
        severity=t.severity,
        confidence=round(confidence, 2),
        title=t.title,
        headline=t.headline,
        summary=t.summary,
        cause=t.cause,
        suggestion=t.suggestion,
        occurrences=total_count,
        verified=bool(v and not v.refuted),
        verifier_note=v.note if v else None,
        needs_review=not gate(confidence, mandate) or bool(v and v.refuted),
        evidence=evidence,
        first_seen=first_seen,
        last_seen=draft.lines[-1].ts,
    )
    return Decision(alert, t, v)
