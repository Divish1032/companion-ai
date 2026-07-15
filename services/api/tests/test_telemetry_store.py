import pytest

from app.telemetry_store import TelemetryStore, TelemetryValidationError, percentile_summary


def _envelope() -> dict[str, object]:
    return {
        "schema": "telemetry_envelope_v1", "session_id": "session_1", "turn_id": "turn_1",
        "terminal_outcome": "completed", "total_cost_micro_inr": 10, "cost_complete": True,
        "timestamps_ms": {}, "durations_ms": {}, "counts": {}, "statuses": {},
        "costs_micro_inr": {}, "cost_sources": {}, "rate_card_version": "v1", "rate_card_fingerprint": "abc",
    }


def test_store_rejects_content_and_summarizes(tmp_path) -> None:
    store = TelemetryStore(str(tmp_path / "telemetry.sqlite"))
    store.ingest(_envelope())
    assert store.session_summary("session_1")["total_cost_micro_inr"] == 10
    invalid = _envelope()
    invalid["text"] = "must never persist"
    with pytest.raises(TelemetryValidationError):
        store.ingest(invalid)


def test_late_memory_operation_appends_instead_of_overwriting_turn(tmp_path) -> None:
    store = TelemetryStore(str(tmp_path / "telemetry.sqlite"))
    first = _envelope()
    first["record_id"] = "voice-terminal"
    store.ingest(first)
    later = _envelope()
    later["record_id"] = "memory-judge-operation"
    later["terminal_outcome"] = "memory_judge"
    later["cost_complete"] = False
    later["cost_sources"] = {"memory_judge": "unknown"}
    store.ingest(later)
    summary = store.session_summary("session_1")
    assert summary["turn_count"] == 2
    assert summary["cost_complete"] is False


def test_percentile_summary_marks_small_samples_insufficient() -> None:
    assert percentile_summary([1, 2, 3])["p95_sufficient"] is False
