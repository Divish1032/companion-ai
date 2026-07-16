from app.telemetry import CostRateCard, TurnMetricsCollector, llm_cost_micro_inr, stt_cost_micro_inr, tts_cost_micro_inr


def test_sarvam_costs_use_integer_micro_inr_and_request_rounding() -> None:
    card = CostRateCard()
    assert stt_cost_micro_inr(provider="sarvam", audio_millis=1, card=card) == (8_333, "estimated")
    assert tts_cost_micro_inr(model="bulbul:v3", billed_chars=320, card=card) == (960_000, "estimated")
    assert llm_cost_micro_inr(
        provider="sarvam", model="sarvam-30b", input_tokens=1_000_000,
        cached_input_tokens=200_000, output_tokens=100_000, card=card, usage_reported=True,
    ) == (3_300_000, "provider_reported")


def test_unknown_cost_makes_terminal_envelope_incomplete() -> None:
    collector = TurnMetricsCollector("session_1")
    metric = collector.turn("turn_1")
    metric.add_cost("memory_extraction", 0, "unknown")
    envelope = collector.terminal("turn_1", "completed")
    assert envelope["schema"] == "telemetry_envelope_v1"
    assert envelope["cost_complete"] is False
    assert "text" not in envelope


def test_cost_overage_uses_active_audio_minutes() -> None:
    collector = TurnMetricsCollector("session_1")
    metric = collector.turn("turn_1")
    metric.counts["tts_audio_ms"] = 60_000
    metric.add_cost("tts", 2_800_000, "estimated")
    envelope = collector.terminal("turn_1", "completed")
    assert envelope["statuses"]["cost_overage"] == "true"


def test_memory_judge_operation_appends_without_overwriting_voice_terminal() -> None:
    collector = TurnMetricsCollector("session_1")
    collector.turn("turn_1").add_cost("tts", 100, "estimated")
    voice = collector.terminal("turn_1", "completed")

    operation = collector.memory_judge_operation(
        "turn_1",
        outcome="accepted",
        accepted_count=1,
        window_turn_count=2,
        attempt_count=1,
        request_started_at_ms=10,
        completed_at_ms=20,
        cost_source="unknown",
        cost_micro_inr=0,
        input_tokens=812,
        output_tokens=96,
    )

    assert operation["schema"] == "telemetry_envelope_v1"
    assert operation["terminal_outcome"] == "memory_judge_accepted"
    assert operation["statuses"]["record_kind"] == "memory_judge_operation"
    assert operation["counts"]["memory_judge_window_turn_count"] == 2
    assert operation["counts"]["memory_judge_attempt_count"] == 1
    # An unpriced judge dependency is cost-incomplete, never silently zero.
    assert operation["cost_sources"]["memory_judge"] == "unknown"
    assert operation["cost_complete"] is False
    # The voice terminal record stays immutable: the collector's stored turn
    # keeps its outcome and cost, and the operation is a separate envelope.
    assert collector.turn("turn_1").terminal_outcome == "completed"
    assert voice["terminal_outcome"] == "completed"
    assert "memory_judge" not in collector.turn("turn_1").costs_micro_inr


def test_memory_judge_operation_reports_labelled_provider_cost() -> None:
    collector = TurnMetricsCollector("session_1")
    operation = collector.memory_judge_operation(
        "turn_1",
        outcome="superseded",
        accepted_count=1,
        window_turn_count=2,
        attempt_count=1,
        request_started_at_ms=10,
        completed_at_ms=20,
        cost_source="provider_reported",
        cost_micro_inr=4_500,
        input_tokens=1_000,
        output_tokens=200,
    )
    assert operation["costs_micro_inr"]["memory_judge"] == 4_500
    assert operation["cost_sources"]["memory_judge"] == "provider_reported"
    assert operation["cost_complete"] is True
