from datetime import UTC, datetime

from app.llm import TriageResult, VerifyResult
from app.llm.gemini import EvidencePick
from app.models import Mandate
from app.notify import in_quiet_hours
from app.pipeline.filter import classify, group
from app.pipeline.triage import decide, gate, split_highlight

from .conftest import ts


class FakeTriager:
    def __init__(self, confidence=0.94, refuted=False):
        self.confidence = confidence
        self.refuted = refuted
        self.seen_context = None

    async def triage(self, context):
        self.seen_context = context
        return TriageResult(
            severity="critical", confidence=self.confidence, title="Crash loop detected",
            headline="billing-worker is crash-looping", summary="Exits on boot with OOMKilled.",
            cause="Memory hits the limit.", suggestion="Suggested: roll back.",
            evidence=[EvidencePick(index=len(context["lines"]) - 1, highlight="OOMKilled")],
        )

    async def verify(self, context, diagnosis):
        return VerifyResult(refuted=self.refuted, alternative="host issue",
                            adjusted_confidence=0.5 if self.refuted else 0.9, note="checked")


def _draft():
    lines = [classify(f"x{i}", ts(10 - i), "Process exited with code 137 (OOMKilled)", None) for i in range(3)]
    return group("billing", lines)[0], lines


async def _decide(triager, mandate=Mandate()):
    draft, lines = _draft()
    return await decide(triager, mandate, service_id="billing", service_name="billing-worker",
                        service_type="background_worker", draft=draft, total_count=18,
                        first_seen=lines[0].ts, crash_loop=True, context_lines=lines)


def test_split_highlight():
    assert split_highlight("exited (OOMKilled)", "OOMKilled") == ("exited (", "OOMKilled", ")")
    assert split_highlight("abc", "zzz") == ("abc", "", "")


def test_gate():
    m = Mandate(gate=75)
    assert gate(0.94, m) and gate(0.75, m) and not gate(0.58, m)


async def test_confident_and_verified_alerts_directly():
    d = await _decide(FakeTriager(0.94))
    a = d.alert
    assert not a.needs_review and a.verified and a.confidence == 0.94
    assert a.occurrences == 18
    assert a.evidence[0].highlight == "OOMKilled"


async def test_low_confidence_asks_user():
    d = await _decide(FakeTriager(0.58))
    assert d.alert.needs_review


async def test_refuted_lowers_confidence_and_asks():
    d = await _decide(FakeTriager(0.94, refuted=True))
    assert d.alert.needs_review and not d.alert.verified and d.alert.confidence == 0.5


async def test_log_lines_are_fenced_as_untrusted():
    t = FakeTriager()
    await _decide(t, Mandate(verifier=False))
    assert t.seen_context["crash_loop_detected"] is True
    assert all(isinstance(l, str) for l in t.seen_context["lines"])


def test_quiet_hours_span_midnight():
    m = Mandate(quiet_start="23:00", quiet_end="07:00", timezone="UTC")
    assert in_quiet_hours(m, datetime(2026, 10, 23, 23, 30, tzinfo=UTC))
    assert in_quiet_hours(m, datetime(2026, 10, 24, 6, 59, tzinfo=UTC))
    assert not in_quiet_hours(m, datetime(2026, 10, 24, 12, 0, tzinfo=UTC))
