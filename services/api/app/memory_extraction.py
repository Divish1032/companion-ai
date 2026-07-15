from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Literal, Protocol

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator


CandidateKind = Literal[
    "profile",
    "preference",
    "relationship",
    "routine",
    "goal",
    "boundary",
    "episode",
    "open_thread",
    "assistant_commitment",
]
CandidateAction = Literal["ADD", "REINFORCE", "SUPERSEDE", "EXPIRE", "NOOP"]


class ExtractionTurn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    turn_id: str = Field(min_length=1, max_length=128)
    role: Literal["user", "assistant"]
    text: str = Field(min_length=1, max_length=1200)
    created_at_ms: int = Field(ge=0)
    status: str = Field(default="final", max_length=64)
    confidence: float | None = Field(default=None, ge=0, le=1)


class MemoryCandidate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    candidate_kind: CandidateKind
    subject: str = Field(min_length=1, max_length=100)
    predicate: str = Field(min_length=1, max_length=100)
    object_text: str = Field(min_length=1, max_length=500)
    event_start_at_ms: int | None = Field(ge=0)
    event_end_at_ms: int | None = Field(ge=0)
    temporal_status: Literal["current", "past", "future", "uncertain"]
    explicitness: Literal["explicit", "implied", "assistant_only"]
    confidence: float = Field(ge=0, le=1)
    future_utility: float = Field(ge=0, le=1)
    sensitivity: Literal["normal", "sensitive", "highly_sensitive"]
    source_turn_ids: list[str] = Field(min_length=1, max_length=8)
    evidence_role: Literal["user", "mixed", "assistant"]
    suggested_action: CandidateAction
    follow_up_allowed: bool
    proactive_allowed: bool


class MemoryExtractionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    job_id: str = Field(min_length=1, max_length=160)
    extraction_version: str = Field(min_length=1, max_length=32)
    language: str = Field(default="hi-IN", max_length=32)
    turns: list[ExtractionTurn] = Field(min_length=1, max_length=24)

    @model_validator(mode="after")
    def validate_unique_turn_ids(self) -> MemoryExtractionRequest:
        turn_ids = [turn.turn_id for turn in self.turns]
        if len(turn_ids) != len(set(turn_ids)):
            raise ValueError("turn IDs must be unique")
        return self


class MemoryExtractionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    job_id: str
    extraction_version: str
    candidates: list[MemoryCandidate] = Field(max_length=16)


class MemoryExtractionUnavailable(RuntimeError):
    """The optional extractor failed without admitting any memory."""


class MemoryCandidateExtractor(Protocol):
    async def extract(self, request: MemoryExtractionRequest) -> list[MemoryCandidate]: ...


_SENSITIVE_EVIDENCE_MARKERS = (
    "suicide",
    "mar jaana",
    "mar jana",
    "jaan dena",
    "khud ko maar",
    "khud ko nuksan",
    "doctor",
    "medical",
    "diagnosis",
    "cancer",
    "diabetes",
    "therapy",
    "medicine",
    "medication",
    "dawai",
    "legal",
    "lawyer",
    "court case",
    "police case",
    "loan",
    "investment",
    "salary",
    "bank account",
    "account number",
    "credit card",
    "debit card",
    "upi pin",
    "aadhaar",
    "aadhar",
    "pan number",
    "password",
    "otp",
    "sexual",
    "religion",
    "caste",
    "political party",
    "address is",
    "phone number",
    "email is",
)


def filter_source_safe_candidates(
    request: MemoryExtractionRequest,
    candidates: list[MemoryCandidate],
) -> list[MemoryCandidate]:
    """Apply stateless defense-in-depth before candidates reach the phone."""

    turns_by_id = {turn.turn_id: turn for turn in request.turns}
    safe: list[MemoryCandidate] = []
    for candidate in candidates:
        if candidate.sensitivity != "normal":
            continue
        cited = [turns_by_id.get(turn_id) for turn_id in candidate.source_turn_ids]
        if any(turn is None for turn in cited):
            continue
        roles = {turn.role for turn in cited if turn is not None}
        if candidate.candidate_kind == "assistant_commitment":
            if "assistant" not in roles or candidate.evidence_role not in {
                "assistant",
                "mixed",
            }:
                continue
        elif "user" not in roles or candidate.evidence_role == "assistant":
            continue
        evidence = " ".join(
            [
                candidate.subject,
                candidate.predicate,
                candidate.object_text,
                *(turn.text for turn in cited if turn is not None),
            ]
        ).casefold()
        if any(marker in evidence for marker in _SENSITIVE_EVIDENCE_MARKERS):
            continue
        safe.append(candidate)
    return safe


@dataclass(frozen=True)
class OpenAICompatibleMemoryCandidateExtractor:
    """Stateless strict-JSON adapter for an explicitly configured LLM endpoint."""

    base_url: str
    api_key: str
    model: str
    timeout_seconds: float
    transport: httpx.AsyncBaseTransport | None = None

    async def extract(self, request: MemoryExtractionRequest) -> list[MemoryCandidate]:
        if not self.base_url or not self.api_key or not self.model:
            raise MemoryExtractionUnavailable("memory extraction is not configured")
        schema = _candidate_envelope_schema()
        payload = {
            "model": self.model,
            "temperature": 0,
            "store": False,
            "messages": [
                {"role": "system", "content": _EXTRACTION_SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": json.dumps(
                        {
                            "language": request.language,
                            "turns": [turn.model_dump() for turn in request.turns],
                        },
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ),
                },
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "memory_candidates",
                    "strict": True,
                    "schema": schema,
                },
            },
        }
        try:
            async with httpx.AsyncClient(
                timeout=self.timeout_seconds,
                transport=self.transport,
            ) as client:
                response = await client.post(
                    f"{self.base_url.rstrip('/')}/chat/completions",
                    headers={
                        "authorization": f"Bearer {self.api_key}",
                        "content-type": "application/json",
                    },
                    json=payload,
                )
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            decoded = json.loads(content)
            envelope = _CandidateEnvelope.model_validate(decoded)
        except (
            httpx.HTTPError,
            KeyError,
            IndexError,
            TypeError,
            json.JSONDecodeError,
            ValidationError,
        ) as error:
            raise MemoryExtractionUnavailable(
                "extractor returned no valid candidate envelope"
            ) from error
        return envelope.candidates


class _CandidateEnvelope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    candidates: list[MemoryCandidate] = Field(max_length=16)


def _candidate_envelope_schema() -> dict[str, object]:
    schema = _CandidateEnvelope.model_json_schema()
    # Most strict-schema APIs reject local definitions referenced outside the
    # supplied root. Pydantic's complete schema is nevertheless self-contained.
    return schema


_EXTRACTION_SYSTEM_PROMPT = """You extract candidate long-term memories from a short dialogue window.
Return only the required JSON schema. Be conservative: an empty candidates list is correct when nothing
will help a future conversation. User turns are the only evidence for user facts. Assistant turns may
clarify dialogue context and supply assistant_commitment candidates, but never prove a user fact.
Do not infer diagnoses, protected traits, relationship closeness, or unstated preferences. Mark sensitive
material accurately. Preserve the user's language and exact names/key nouns in object_text so evidence can
be checked locally. Use assistant_only explicitness/evidence for assistant-only commitments. Use NOOP
when the text is merely conversational, hypothetical, quoted, uncertain, or low-confidence. A future
plan or promised follow-up is open_thread. An event worth remembering as an experience is episode.
Use SUPERSEDE only for an explicit changed routine or goal, keeping subject and predicate identical to
the prior concept; otherwise use ADD or REINFORCE. Never use SUPERSEDE for identity or relationship data.
proactive_allowed must be false unless the user explicitly asked the assistant to follow up."""
