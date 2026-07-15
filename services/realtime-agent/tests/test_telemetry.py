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
