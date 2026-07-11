from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


MemoryRoute = Literal[
    "none",
    "core_profile",
    "semantic",
    "episodic",
    "summary",
    "safety",
    "broad_safe",
]


@dataclass(frozen=True)
class MemoryRoutingDecision:
    route: MemoryRoute
    confidence: float
    reason: str
    max_blocks: int


def route_memory_query(text: str) -> MemoryRoutingDecision:
    normalized = text.casefold().strip()
    if normalized in {"hi", "hello", "hey", "namaste", "नमस्ते", "haan", "हाँ"}:
        return MemoryRoutingDecision("none", 0.95, "greeting_or_ack", 0)
    if _contains_any(normalized, ("suicide", "mar jaana", "आत्महत्या", "khud ko maar")):
        return MemoryRoutingDecision("safety", 0.95, "safety_intent", 0)
    if _contains_any(
        normalized,
        ("naam", "नाम", "name", "language", "भाषा", "style", "pasand", "पसंद", "prefer"),
    ):
        return MemoryRoutingDecision("core_profile", 0.88, "profile_or_preference_recall", 3)
    if _contains_any(normalized, ("office", "work", "kaam", "ऑफिस", "काम")):
        return MemoryRoutingDecision("semantic", 0.82, "work_context", 6)
    if _contains_any(normalized, ("kal", "yesterday", "last time", "pichli", "पिछली")):
        return MemoryRoutingDecision("episodic", 0.78, "temporal_recall", 6)
    if _contains_any(normalized, ("summary", "summarize", "kya yaad", "what do you remember")):
        return MemoryRoutingDecision("summary", 0.72, "broad_memory_summary", 6)
    # Ambiguous/topic-changing turns must not inherit an unrelated session
    # summary.  Explicit profile, temporal, semantic, and summary intents
    # above are the only deterministic routes allowed to request memory.
    return MemoryRoutingDecision("broad_safe", 0.45, "ambiguous_query", 0)


def _contains_any(text: str, needles: tuple[str, ...]) -> bool:
    return any(needle in text for needle in needles)
