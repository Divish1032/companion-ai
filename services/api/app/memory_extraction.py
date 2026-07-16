from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
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
JudgeAction = Literal["accept", "update", "supersede", "reject"]

_SUGGESTED_ACTION_TO_JUDGE_ACTION: dict[str, JudgeAction] = {
    "ADD": "accept",
    "REINFORCE": "update",
    "SUPERSEDE": "supersede",
    "EXPIRE": "update",
    "NOOP": "reject",
}


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
    judge_contract_version: Literal["memory_judge_v1"] = "memory_judge_v1"
    language: str = Field(default="hi-IN", max_length=32)
    # The bounded cited window: at most 4 exchanges / 8 messages. The judge
    # never receives unbounded history.
    turns: list[ExtractionTurn] = Field(min_length=1, max_length=8)

    @model_validator(mode="after")
    def validate_unique_turn_role_pairs(self) -> MemoryExtractionRequest:
        # A voice turn normally has one user message and one assistant reply
        # sharing its turn ID. Reject only duplicate messages of the same role.
        turn_roles = [(turn.turn_id, turn.role) for turn in self.turns]
        if len(turn_roles) != len(set(turn_roles)):
            raise ValueError("turn ID and role pairs must be unique")
        return self


class MemoryJudgeProposal(BaseModel):
    """Untrusted structured proposal; only fields the phone validates locally."""

    model_config = ConfigDict(extra="forbid")

    kind: CandidateKind
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


class MemoryJudgeDecision(BaseModel):
    """Untrusted decision; the phone resolves targets and commits locally.

    ``update``/``supersede`` carry no target ID on purpose: the phone resolves
    the local target by normalized state key/predicate and provenance and never
    trusts a model-supplied database ID.
    """

    model_config = ConfigDict(extra="forbid")

    decision_id: str = Field(min_length=16, max_length=160)
    action: JudgeAction
    proposal: MemoryJudgeProposal


class MemoryJudgeCost(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: Literal["provider_reported", "estimated", "unknown"]
    input_tokens: int = Field(ge=0)
    output_tokens: int = Field(ge=0)
    estimated_micro_inr: int = Field(ge=0)


class MemoryJudgeResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    job_id: str
    contract_version: Literal["memory_judge_v1"]
    cost: MemoryJudgeCost
    decisions: list[MemoryJudgeDecision] = Field(max_length=16)


def build_judge_decision(job_id: str, candidate: MemoryCandidate) -> MemoryJudgeDecision:
    """Deterministic, idempotency-safe decision ID from job plus content."""

    canonical = json.dumps(candidate.model_dump(), sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(f"{job_id}|{canonical}".encode()).hexdigest()[:40]
    return MemoryJudgeDecision(
        decision_id=f"mjd_{digest}",
        action=_SUGGESTED_ACTION_TO_JUDGE_ACTION[candidate.suggested_action],
        proposal=MemoryJudgeProposal(
            kind=candidate.candidate_kind,
            subject=candidate.subject,
            predicate=candidate.predicate,
            object_text=candidate.object_text,
            event_start_at_ms=candidate.event_start_at_ms,
            event_end_at_ms=candidate.event_end_at_ms,
            temporal_status=candidate.temporal_status,
            explicitness=candidate.explicitness,
            confidence=candidate.confidence,
            future_utility=candidate.future_utility,
            sensitivity=candidate.sensitivity,
            source_turn_ids=candidate.source_turn_ids,
            evidence_role=candidate.evidence_role,
            suggested_action=candidate.suggested_action,
            follow_up_allowed=candidate.follow_up_allowed,
            proactive_allowed=candidate.proactive_allowed,
        ),
    )


@dataclass(frozen=True)
class MemoryExtractionResult:
    """Candidates plus provider-reported usage when the provider exposes it."""

    candidates: list[MemoryCandidate] = field(default_factory=list)
    usage_input_tokens: int | None = None
    usage_output_tokens: int | None = None


class MemoryExtractionUnavailable(RuntimeError):
    """The optional extractor failed without admitting any memory."""


class MemoryCandidateExtractor(Protocol):
    async def extract(self, request: MemoryExtractionRequest) -> MemoryExtractionResult: ...


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

    # A voice turn's user message and assistant reply share one turn ID, so a
    # cited turn maps to a list of messages, never a single collapsed entry.
    turns_by_id: dict[str, list[ExtractionTurn]] = {}
    for turn in request.turns:
        turns_by_id.setdefault(turn.turn_id, []).append(turn)
    safe: list[MemoryCandidate] = []
    for candidate in candidates:
        if candidate.sensitivity != "normal":
            continue
        cited_lists = [turns_by_id.get(turn_id) for turn_id in candidate.source_turn_ids]
        if any(turns is None for turns in cited_lists):
            continue
        cited = [turn for turns in cited_lists if turns is not None for turn in turns]
        roles = {turn.role for turn in cited}
        if candidate.candidate_kind == "assistant_commitment":
            if "assistant" not in roles or candidate.evidence_role not in {
                "assistant",
                "mixed",
            } or candidate.explicitness != "assistant_only":
                continue
        else:
            if (
                "user" not in roles
                or candidate.evidence_role == "assistant"
                or candidate.explicitness == "assistant_only"
            ):
                continue
            if candidate.evidence_role == "user" and any(
                turns is not None and all(turn.role != "user" for turn in turns)
                for turns in cited_lists
            ):
                # An assistant-only turn cited as user evidence is a
                # provenance violation even when other cited turns are fine.
                continue
            if candidate.evidence_role == "mixed" and roles != {"user", "assistant"}:
                continue
        evidence = " ".join(
            [
                candidate.subject,
                candidate.predicate,
                candidate.object_text,
                *(turn.text for turn in cited),
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

    async def extract(self, request: MemoryExtractionRequest) -> MemoryExtractionResult:
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
            body = response.json()
            content = body["choices"][0]["message"]["content"]
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
        usage = body.get("usage") if isinstance(body, dict) else None
        input_tokens = usage.get("prompt_tokens") if isinstance(usage, dict) else None
        output_tokens = usage.get("completion_tokens") if isinstance(usage, dict) else None
        return MemoryExtractionResult(
            candidates=envelope.candidates,
            usage_input_tokens=input_tokens if isinstance(input_tokens, int) and input_tokens >= 0 else None,
            usage_output_tokens=output_tokens
            if isinstance(output_tokens, int) and output_tokens >= 0
            else None,
        )


class _CandidateEnvelope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    candidates: list[MemoryCandidate] = Field(max_length=16)


def _candidate_envelope_schema() -> dict[str, object]:
    schema = _CandidateEnvelope.model_json_schema()
    # Most strict-schema APIs reject local definitions referenced outside the
    # supplied root. Pydantic's complete schema is nevertheless self-contained.
    return schema


_EXTRACTION_SYSTEM_PROMPT = """You extract candidate long-term memories from a short dialogue window.
Return only the required JSON schema. Be conservative: when evidence is insufficient, ambiguous,
hypothetical, quoted, or low-confidence you must reject by omitting the candidate entirely; an empty
candidates list is correct when nothing will help a future conversation. User turns are the only
evidence for user facts. Assistant turns may clarify dialogue context and supply assistant_commitment
candidates, but never prove a user fact; never propose a user fact whose only evidence is assistant text.
Do not infer diagnoses, protected traits, relationship closeness, or unstated preferences. Never propose
sensitive or high-risk facts, including medical, legal, financial, sexual, crisis, precise-contact, or
protected-trait information; reject them instead of guessing. Mark sensitive
material accurately. Preserve the user's language and exact names/key nouns in object_text so evidence can
be checked locally. Use assistant_only explicitness/evidence for assistant-only commitments. Use NOOP
when the text is merely conversational, hypothetical, quoted, uncertain, or low-confidence. A future
plan or promised follow-up is open_thread. An event worth remembering as an experience is episode.
A concrete completed personal milestone or recent experience explicitly stated by the user—such as an
interview, exam, new job, trip, achievement, loss, or important project—is normally a useful episode.
Capture both the event and the user's explicit assessment of it. For example, if the user says they had
a design interview and the system-design round felt difficult, create one grounded past episode that
preserves those key nouns and assessment. Do not invent an exact date when a relative date cannot be
safely resolved.
For every non-assistant memory with evidence_role=user, source_turn_ids must contain user turns only;
never cite an assistant question or paraphrase as user evidence. Always cite exactly the turn(s) in which
the user actually made the statement, never a recall question such as "mera naam kya hai" and never a
turn that merely repeats the topic.
When the user explicitly states or corrects their own name — for example "mera naam Amit hai" or
"nahi, mera naam Amit hai" — return candidate_kind=profile with subject "user", predicate
"preferred_name", and object_text containing only the stated name itself (no sentence around it),
suggested_action ADD, explicitness explicit, citing only the turn(s) where the user stated the name.
A garbled, uncertain, or joke name ("shayad", laughter, non-name words) must be rejected instead.
object_text must be a standalone,
complete recall-worthy statement containing all important explicit details and the user's assessment,
not merely a topic label. Use a stable semantic predicate such as had_difficult_interview_round, never
conversational question wording such as kaisa_gaya. Ordinary career and education events—including an
interview, exam, project, or the user's assessment that a round was difficult—have sensitivity=normal
unless the actual evidence contains medical, financial, legal, precise-contact, protected-trait,
sexual, or crisis information.
For a newly stated, grounded completed episode with useful future context, suggested_action must be ADD,
not NOOP. Reserve NOOP for content that does not qualify as a useful memory under the rules above.
Use SUPERSEDE only for an explicit changed routine or goal, keeping subject and predicate identical to
the prior concept; otherwise use ADD or REINFORCE. Never use SUPERSEDE for identity or relationship data.
proactive_allowed must be false unless the user explicitly asked the assistant to follow up."""
