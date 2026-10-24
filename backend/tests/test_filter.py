from app.pipeline.filter import (Level, Signal, classify, group, health_for, is_crash_loop,
                                 normalize, should_triage)

from .conftest import ts


def _crash_loop_lines():
    lines = []
    for cycle in range(4):
        base = 20 - cycle * 2
        lines += [
            classify(f"s{cycle}", ts(base), "Starting billing-worker v2.14.0", "info"),
            classify(f"l{cycle}", ts(base - 0.3), "Loading 1,284,330 invoices into batch", "info"),
            classify(f"m{cycle}", ts(base - 0.6), "Memory usage 501MB / 512MB", None),
            classify(f"x{cycle}", ts(base - 0.7), "Process exited with code 137 (OOMKilled)", None),
        ]
    return sorted(lines, key=lambda l: l.ts)


def test_classify_oom_is_error():
    line = classify("1", ts(0), "Process exited with code 137 (OOMKilled)", None)
    assert line.level == Level.ERR
    assert Signal.OOM in line.signals and line.suspicious


def test_memory_only_flags_when_high():
    assert Signal.MEMORY in classify("1", ts(0), "Memory usage 498MB / 512MB", None).signals
    assert Signal.MEMORY not in classify("2", ts(0), "Memory usage 120MB / 512MB", None).signals


def test_5xx_needs_http_context():
    assert Signal.HTTP_5XX in classify("1", ts(0), "POST /checkout 502 upstream timeout 30001ms", None).signals
    assert Signal.HTTP_5XX not in classify("2", ts(0), "found 503 rows in 512ms", None).signals
    assert Signal.HTTP_5XX in classify("3", ts(0), "request done", None, status_code="503").signals


def test_healthy_lines_are_not_suspicious():
    line = classify("1", ts(0), "GET /health 200 3ms", "info")
    assert line.level == Level.INF and not line.suspicious


def test_normalize_folds_variable_parts():
    a = normalize("retry 3/3 billing-worker:10000 ECONNREFUSED 10.0.0.12")
    b = normalize("retry 1/3 billing-worker:10000 ECONNREFUSED 10.0.0.99")
    assert a == b


def test_repeats_group_into_one_incident():
    lines = _crash_loop_lines()
    incidents = group("billing", lines)
    oom = [i for i in incidents if Signal.OOM in i.signals]
    assert len(oom) == 1 and oom[0].count == 4


def test_crash_loop_folds_memory_and_exit_lines():
    lines = _crash_loop_lines()
    incidents = group("billing", lines, crash_loop=True)
    assert len(incidents) == 1 and incidents[0].count == 8


def test_crash_loop_and_health():
    lines = _crash_loop_lines()
    assert is_crash_loop(lines)
    health, vitals = health_for(lines, 20, True)
    assert health == "down" and "OOMKilled" in vitals


def test_triage_thresholds():
    lines = _crash_loop_lines()
    oom = next(i for i in group("billing", lines) if Signal.OOM in i.signals)
    assert should_triage(oom, 1, False)
    warn = group("api", [classify("w", ts(0), "deprecated option used", "warning")])[0]
    assert not should_triage(warn, 3, False)
    assert should_triage(warn, 25, False)
