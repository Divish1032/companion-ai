"""Redacted Sprint 8 turn telemetry and deterministic INR cost calculations.

This module intentionally contains no transcript, memory, device, provider payload,
or audio-byte fields.  It is safe to serialize to the diagnostics channel.
"""

from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass, field
from typing import Literal


MICRO_INR = 1_000_000
CostSource = Literal["provider_reported", "estimated", "unknown", "none"]


@dataclass(frozen=True)
class CostRateCard:
    """Effective-dated provider and infrastructure assumptions in micro-INR."""

    version: str = "sarvam_2026_07_v1"
    effective_from: str = "2026-07-15"
    stt_micro_inr_per_second: int = 8_333  # Rs30/hour, charged per started second.
    tts_v2_micro_inr_per_char: int = 1_500
    tts_v3_micro_inr_per_char: int = 3_000
    llm_30b_input_micro_inr_per_million: int = 2_500_000
    llm_30b_cached_input_micro_inr_per_million: int = 1_500_000
    llm_30b_output_micro_inr_per_million: int = 10_000_000
    natural_voice_target_micro_inr_per_minute: int = 1_800_000

    @property
    def fingerprint(self) -> str:
        payload = json.dumps(self.__dict__, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]

    @property
    def natural_voice_overage_micro_inr_per_minute(self) -> int:
        return self.natural_voice_target_micro_inr_per_minute * 3 // 2


def ceil_div(numerator: int, denominator: int) -> int:
    return (numerator + denominator - 1) // denominator


def stt_cost_micro_inr(*, provider: str, audio_millis: int, card: CostRateCard) -> tuple[int, CostSource]:
    if provider == "vosk":
        return 0, "none"
    if provider == "sarvam":
        return ceil_div(max(audio_millis, 0), 1000) * card.stt_micro_inr_per_second, "estimated"
    return 0, "unknown"


def tts_cost_micro_inr(*, model: str, billed_chars: int, card: CostRateCard) -> tuple[int, CostSource]:
    if model == "bulbul:v2":
        return max(billed_chars, 0) * card.tts_v2_micro_inr_per_char, "estimated"
    if model == "bulbul:v3":
        return max(billed_chars, 0) * card.tts_v3_micro_inr_per_char, "estimated"
    return 0, "unknown"


def llm_cost_micro_inr(
    *,
    provider: str,
    model: str,
    input_tokens: int,
    cached_input_tokens: int,
    output_tokens: int,
    card: CostRateCard,
    usage_reported: bool,
) -> tuple[int, CostSource]:
    if provider in {"persona_local", "mock"}:
        return 0, "none"
    if provider != "sarvam" or model != "sarvam-30b":
        return 0, "unknown"
    regular_input = max(input_tokens - cached_input_tokens, 0)
    total = (
        regular_input * card.llm_30b_input_micro_inr_per_million
        + max(cached_input_tokens, 0) * card.llm_30b_cached_input_micro_inr_per_million
        + max(output_tokens, 0) * card.llm_30b_output_micro_inr_per_million
    ) // 1_000_000
    return total, "provider_reported" if usage_reported else "estimated"


@dataclass
class TurnMetrics:
    """Canonical, content-free turn record exported as ``TelemetryEnvelope v1``."""

    session_id: str
    turn_id: str
    rate_card_version: str
    rate_card_fingerprint: str
    timestamps_ms: dict[str, int] = field(default_factory=dict)
    durations_ms: dict[str, int] = field(default_factory=dict)
    counts: dict[str, int] = field(default_factory=dict)
    statuses: dict[str, str] = field(default_factory=dict)
    costs_micro_inr: dict[str, int] = field(default_factory=dict)
    cost_sources: dict[str, CostSource] = field(default_factory=dict)
    terminal_outcome: str | None = None

    def mark(self, name: str, timestamp_ms: int | None = None) -> None:
        self.timestamps_ms[name] = timestamp_ms if timestamp_ms is not None else monotonic_ms()

    def add_cost(self, name: str, amount: int, source: CostSource) -> None:
        self.costs_micro_inr[name] = self.costs_micro_inr.get(name, 0) + max(amount, 0)
        previous = self.cost_sources.get(name)
        self.cost_sources[name] = _combined_cost_source(previous, source)

    def finish(self, outcome: str) -> None:
        self.terminal_outcome = outcome
        self.mark("terminal")

    def envelope(self) -> dict[str, object]:
        known_sources = set(self.cost_sources.values())
        return {
            "schema": "telemetry_envelope_v1",
            "session_id": self.session_id,
            "turn_id": self.turn_id,
            "rate_card_version": self.rate_card_version,
            "rate_card_fingerprint": self.rate_card_fingerprint,
            "timestamps_ms": self.timestamps_ms,
            "durations_ms": self.durations_ms,
            "counts": self.counts,
            "statuses": self.statuses,
            "costs_micro_inr": self.costs_micro_inr,
            "cost_sources": self.cost_sources,
            "total_cost_micro_inr": sum(self.costs_micro_inr.values()),
            "cost_complete": "unknown" not in known_sources,
            "terminal_outcome": self.terminal_outcome,
        }


class TurnMetricsCollector:
    def __init__(self, session_id: str, card: CostRateCard | None = None) -> None:
        self.card = card or CostRateCard()
        self.session_id = session_id
        self._turns: dict[str, TurnMetrics] = {}

    def turn(self, turn_id: str) -> TurnMetrics:
        return self._turns.setdefault(
            turn_id,
            TurnMetrics(
                session_id=self.session_id,
                turn_id=turn_id,
                rate_card_version=self.card.version,
                rate_card_fingerprint=self.card.fingerprint,
            ),
        )

    def terminal(self, turn_id: str, outcome: str) -> dict[str, object]:
        metric = self.turn(turn_id)
        metric.finish(outcome)
        active_audio_ms = metric.counts.get("stt_audio_ms", 0) + metric.counts.get("tts_audio_ms", 0)
        total = sum(metric.costs_micro_inr.values())
        if active_audio_ms > 0:
            per_minute = total * 60_000 // active_audio_ms
            metric.counts["provider_cost_micro_inr_per_active_minute"] = per_minute
            metric.statuses["cost_overage"] = (
                "true" if per_minute > self.card.natural_voice_overage_micro_inr_per_minute else "false"
            )
        else:
            metric.statuses["cost_overage"] = "not_applicable"
        return metric.envelope()

    def memory_judge_operation(
        self,
        turn_id: str,
        *,
        outcome: str,
        accepted_count: int,
        window_turn_count: int,
        attempt_count: int,
        request_started_at_ms: int,
        completed_at_ms: int,
        cost_source: CostSource,
        cost_micro_inr: int,
        input_tokens: int,
        output_tokens: int,
    ) -> dict[str, object]:
        """Immutable memory-judge operation record.

        This is a separate append-only observation: it never touches the
        voice turn's ``TurnMetrics`` and therefore can never overwrite the
        immutable terminal voice record. It contains only timestamps,
        bounded-window/attempt counters, the outcome, and cost metadata.
        """

        record = TurnMetrics(
            session_id=self.session_id,
            turn_id=turn_id,
            rate_card_version=self.card.version,
            rate_card_fingerprint=self.card.fingerprint,
        )
        record.statuses["record_kind"] = "memory_judge_operation"
        record.statuses["memory_judge_outcome"] = outcome
        record.counts["memory_judge_accepted_count"] = max(accepted_count, 0)
        record.counts["memory_judge_window_turn_count"] = max(window_turn_count, 0)
        record.counts["memory_judge_attempt_count"] = max(attempt_count, 0)
        record.counts["memory_judge_input_tokens"] = max(input_tokens, 0)
        record.counts["memory_judge_output_tokens"] = max(output_tokens, 0)
        record.timestamps_ms["memory_judge_request_started"] = max(request_started_at_ms, 0)
        record.timestamps_ms["memory_judge_completed"] = max(completed_at_ms, 0)
        # An unpriced external judge stays unknown/incomplete, never zero.
        record.add_cost("memory_judge", cost_micro_inr, cost_source)
        record.finish(f"memory_judge_{outcome}")
        return record.envelope()


def monotonic_ms() -> int:
    return time.monotonic_ns() // 1_000_000


def _combined_cost_source(previous: CostSource | None, current: CostSource) -> CostSource:
    if previous == "unknown" or current == "unknown":
        return "unknown"
    if previous == "estimated" or current == "estimated":
        return "estimated"
    if previous == "provider_reported" or current == "provider_reported":
        return "provider_reported"
    return "none"
