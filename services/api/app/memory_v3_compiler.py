from __future__ import annotations

import hashlib
import json
import re
import time
from dataclasses import dataclass, field
from typing import Annotated, Literal, Protocol

import httpx
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    ValidationError,
    model_validator,
)


MemoryV3JobId = Annotated[
    str,
    StringConstraints(pattern=r"^memory_compile_[A-Za-z0-9_-]{8,160}$"),
]
MemoryV3CandidateId = Annotated[
    str,
    StringConstraints(pattern=r"^candidate_[A-Za-z0-9_-]{8,128}$"),
]
ObservationKind = Literal[
    "profile",
    "relationship",
    "preference",
    "routine",
    "goal",
    "value",
    "boundary",
    "episode",
    "open_thread",
    "assistant_commitment",
]
CompilerRequestProfileV3 = Literal[
    "openai_json_schema",
    "deepseek_json_object",
    "deepseek_json_object_thinking",
]
EntityType = Literal[
    "user",
    "person",
    "organization",
    "place",
    "event",
    "goal",
    "preference",
    "routine",
    "topic",
    "value",
]
Predicate = Literal[
    "preferred_name",
    "has_relationship",
    "response_language",
    "response_length",
    "support_style",
    "likes",
    "dislikes",
    "avoids_topic",
    "follows_routine",
    "pursues_goal",
    "holds_value",
    "experienced_event",
    "event_outcome",
    "open_thread",
    "assistant_commitment",
    "works_at",
    "profile_association",
    "relationship_association",
    "episode_association",
    "causes_stress",
]

_PREDICATES_BY_KIND: dict[str, set[str]] = {
    "profile": {"preferred_name", "works_at", "profile_association"},
    "relationship": {"has_relationship", "relationship_association"},
    "preference": {
        "response_language",
        "response_length",
        "support_style",
        "likes",
        "dislikes",
    },
    "routine": {"follows_routine"},
    "goal": {"pursues_goal"},
    "value": {"holds_value"},
    "boundary": {"avoids_topic"},
    "episode": {
        "experienced_event",
        "event_outcome",
        "causes_stress",
        "episode_association",
    },
    "open_thread": {"open_thread"},
    "assistant_commitment": {"assistant_commitment"},
}

_KIND_BY_PREDICATE: dict[str, ObservationKind] = {
    predicate: kind  # type: ignore[misc]
    for kind, predicates in _PREDICATES_BY_KIND.items()
    for predicate in predicates
}


class CompileTurnV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    turn_id: str = Field(min_length=1, max_length=128)
    role: Literal["user", "assistant"]
    text: str = Field(min_length=1, max_length=1600)
    status: Literal["final", "final_corrected", "safety_override"]
    language: str | None = Field(default=None, max_length=32)
    script: Literal["latin", "devanagari", "mixed", "unknown"] | None = None
    stt_confidence: float | None = Field(default=None, ge=0, le=1)
    stt_provider: str | None = Field(default=None, max_length=80)
    stt_model: str | None = Field(default=None, max_length=120)
    created_at_ms: int = Field(ge=0)

    @model_validator(mode="after")
    def assistant_has_no_stt_metadata(self) -> CompileTurnV3:
        if "language" in self.model_fields_set and self.language is None:
            raise ValueError("turn language cannot be explicit null")
        if "script" in self.model_fields_set and self.script is None:
            raise ValueError("turn script cannot be explicit null")
        if self.role == "assistant" and (
            self.stt_confidence is not None
            or self.stt_provider is not None
            or self.stt_model is not None
        ):
            raise ValueError("assistant turns cannot carry STT metadata")
        return self


class MemoryCompileRequestV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal[3]
    job_id: MemoryV3JobId
    language: str = Field(min_length=2, max_length=32)
    timezone: str = Field(min_length=1, max_length=64)
    now_ms: int = Field(ge=0)
    turns: list[CompileTurnV3] = Field(min_length=1, max_length=12)

    @model_validator(mode="after")
    def bounded_unique_turns(self) -> MemoryCompileRequestV3:
        turn_ids = [turn.turn_id for turn in self.turns]
        if len(turn_ids) != len(set(turn_ids)):
            raise ValueError("turn IDs must be unique")
        if not any(turn.role == "user" for turn in self.turns):
            raise ValueError("compiler window must contain a user turn")
        return self


class SemanticEvidenceV3(BaseModel):
    """Exact source quote selected by the model; role and offsets are local facts."""

    model_config = ConfigDict(extra="forbid")

    turn_id: str = Field(min_length=1, max_length=128)
    quote: str = Field(min_length=1, max_length=500)


class SemanticEntityV3(BaseModel):
    """Entity semantics only; non-user mentions must be evidence-grounded."""

    model_config = ConfigDict(extra="forbid")

    entity_type: EntityType
    mention: str = Field(min_length=1, max_length=120)
    relationship_hint: str | None = Field(default=None, max_length=80)


class SemanticAffectV3(BaseModel):
    """Categorical affect hint converted to bounded values deterministically."""

    model_config = ConfigDict(extra="forbid")

    emotion: Literal[
        "joy",
        "sadness",
        "anger",
        "fear",
        "frustration",
        "loneliness",
        "anxiety",
        "shame",
        "relief",
        "pride",
        "excitement",
        "disappointment",
        "tiredness",
        "neutral",
        "other",
    ]
    intensity: Literal["low", "medium", "high"]
    target_quote: str | None = Field(default=None, max_length=160)
    cause_quote: str | None = Field(default=None, max_length=240)


class MemorySemanticAtomV3(BaseModel):
    """Small untrusted semantic proposal; it is never a durable observation."""

    model_config = ConfigDict(extra="forbid")

    predicate: Predicate
    subject: SemanticEntityV3
    object_quote: str = Field(min_length=1, max_length=500)
    target_entity: SemanticEntityV3 | None = None
    evidence: list[SemanticEvidenceV3] = Field(min_length=1, max_length=4)
    modality: Literal["asserted", "negated", "hypothetical", "quoted"]
    explicitness: Literal["explicit", "implied"]
    temporal_class: Literal["current", "past", "future", "uncertain"]
    temporal_expression_quote: str | None = Field(default=None, max_length=120)
    normalized_value: str | float | bool | None = None
    assessment: Literal["positive", "negative", "neutral"] | None = None
    sensitivity_hint: Literal["normal", "restricted", "forbidden"]
    affect: SemanticAffectV3 | None = None


class MemorySemanticEnvelopeV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    atoms: list[MemorySemanticAtomV3] = Field(max_length=24)
    no_atom_reason: str | None = Field(default=None, max_length=240)


class EntityMentionV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    entity_type: EntityType
    mention: str = Field(min_length=1, max_length=120)
    relationship_hint: str | None = Field(default=None, max_length=80)


class ObjectValueV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str = Field(min_length=1, max_length=500)
    normalized_value: str | float | bool | None = None
    target_entity: EntityMentionV3 | None = None
    user_assessment: str | None = Field(default=None, max_length=240)


class EvidenceV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    turn_id: str = Field(min_length=1, max_length=128)
    role: Literal["user", "assistant"]
    fragment: str = Field(min_length=1, max_length=500)
    start_char: int | None = Field(default=None, ge=0)
    end_char: int | None = Field(default=None, ge=1)

    @model_validator(mode="after")
    def valid_offsets(self) -> EvidenceV3:
        if (self.start_char is None) != (self.end_char is None):
            raise ValueError("evidence offsets must be both present or both absent")
        if (
            self.start_char is not None
            and self.end_char is not None
            and self.end_char <= self.start_char
        ):
            raise ValueError("evidence offsets are reversed")
        return self


class TemporalV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Literal["current", "past", "future", "uncertain"]
    event_start_at_ms: int | None = Field(default=None, ge=0)
    event_end_at_ms: int | None = Field(default=None, ge=0)
    raw_expression: str | None = Field(default=None, max_length=120)
    resolution_confidence: float = Field(ge=0, le=1)

    @model_validator(mode="after")
    def valid_time_range(self) -> TemporalV3:
        if (
            self.event_start_at_ms is not None
            and self.event_end_at_ms is not None
            and self.event_end_at_ms < self.event_start_at_ms
        ):
            raise ValueError("observation time range is reversed")
        return self


class EpistemicV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    explicitness: Literal["explicit", "implied", "assistant_only"]
    confidence: float = Field(ge=0, le=1)
    negated: bool
    hypothetical: bool
    quoted: bool


class AffectV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    emotion: Literal[
        "joy",
        "sadness",
        "anger",
        "fear",
        "frustration",
        "loneliness",
        "anxiety",
        "shame",
        "relief",
        "pride",
        "excitement",
        "disappointment",
        "tiredness",
        "neutral",
        "other",
    ]
    valence: float = Field(ge=-1, le=1)
    arousal: float = Field(ge=0, le=1)
    intensity: float = Field(ge=0, le=1)
    target: str | None = Field(default=None, max_length=160)
    cause: str | None = Field(default=None, max_length=240)
    confidence: float = Field(ge=0, le=1)


class UtilityV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    salience: float = Field(ge=0, le=1)
    future_utility: float = Field(ge=0, le=1)
    proactive_allowed: bool
    confirmation_required: bool


class PrivacyV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    sensitivity: Literal["normal", "restricted", "forbidden"]
    durable_eligibility: Literal["automatic", "explicit_only", "ephemeral", "never"]
    reason: str | None = Field(default=None, max_length=240)


class MemoryObservationV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal[3]
    candidate_id: MemoryV3CandidateId
    kind: ObservationKind
    subject: EntityMentionV3
    predicate: Predicate
    object: ObjectValueV3
    evidence: list[EvidenceV3] = Field(min_length=1, max_length=12)
    temporal: TemporalV3
    epistemic: EpistemicV3
    affect: AffectV3 | None = None
    utility: UtilityV3
    privacy: PrivacyV3
    proposed_operation: Literal["ADD"]

    @model_validator(mode="after")
    def coherent_candidate(self) -> MemoryObservationV3:
        evidence_keys = [
            (item.turn_id, item.role, item.start_char, item.end_char, item.fragment)
            for item in self.evidence
        ]
        if len(evidence_keys) != len(set(evidence_keys)):
            raise ValueError("observation evidence must be unique")
        if self.kind == "assistant_commitment":
            if (
                self.predicate != "assistant_commitment"
                or self.epistemic.explicitness != "assistant_only"
                or any(item.role != "assistant" for item in self.evidence)
            ):
                raise ValueError("assistant commitment provenance is invalid")
        elif self.epistemic.explicitness == "assistant_only" or any(
            item.role != "user" for item in self.evidence
        ):
            raise ValueError("user observations require only user evidence")
        return self


class CompilerModelV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    provider: str = Field(min_length=1, max_length=80)
    model: str = Field(min_length=1, max_length=160)
    prompt_version: str = Field(min_length=1, max_length=80)
    usage_source: Literal["provider_reported", "estimated", "unknown"]
    input_tokens: int = Field(ge=0)
    output_tokens: int = Field(ge=0)
    estimated_micro_inr: int | None = Field(default=None, ge=0)


class MemoryCompileResponseV3(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal[3]
    job_id: MemoryV3JobId
    contract_version: Literal["memory_compile_v3_1"]
    candidates: list[MemoryObservationV3] = Field(max_length=24)
    no_memory_reason: str | None = Field(default=None, max_length=240)
    model: CompilerModelV3


@dataclass(frozen=True)
class SemanticConstructionOutcomeV3:
    atom_index: int
    disposition: Literal["constructed", "rejected"]
    reason: str


@dataclass(frozen=True)
class MemoryCompileResultV3:
    candidates: list[MemoryObservationV3] = field(default_factory=list)
    no_memory_reason: str | None = None
    provider: str = "unknown"
    model: str = "unknown"
    prompt_version: str = "memory_semantic_atoms_v3_1"
    usage_input_tokens: int | None = None
    usage_output_tokens: int | None = None
    semantic_atoms: list[MemorySemanticAtomV3] = field(default_factory=list)
    construction_outcomes: list[SemanticConstructionOutcomeV3] = field(default_factory=list)
    provider_model: str | None = None
    system_fingerprint: str | None = None


class MemoryV3CompilerUnavailable(RuntimeError):
    """Typed optional compiler failure without phone-state mutation."""

    def __init__(
        self,
        error_code: str,
        *,
        http_status: int | None = None,
        latency_ms: int | None = None,
        usage_input_tokens: int | None = None,
        usage_output_tokens: int | None = None,
        provider_model: str | None = None,
        system_fingerprint: str | None = None,
        diagnostics: tuple[str, ...] = (),
    ) -> None:
        super().__init__(error_code)
        self.error_code = error_code
        self.http_status = http_status
        self.latency_ms = latency_ms
        self.usage_input_tokens = usage_input_tokens
        self.usage_output_tokens = usage_output_tokens
        self.provider_model = provider_model
        self.system_fingerprint = system_fingerprint
        self.diagnostics = diagnostics


class MemoryV3Compiler(Protocol):
    async def compile(self, request: MemoryCompileRequestV3) -> MemoryCompileResultV3: ...


@dataclass(frozen=True)
class OpenAICompatibleMemoryV3Compiler:
    base_url: str
    api_key: str
    model: str
    timeout_seconds: float
    provider: str = "openai_compatible"
    prompt_version: str = "memory_semantic_atoms_v3_1"
    request_profile: CompilerRequestProfileV3 = "openai_json_schema"
    transport: httpx.AsyncBaseTransport | None = None

    async def compile(self, request: MemoryCompileRequestV3) -> MemoryCompileResultV3:
        if not self.base_url or not self.api_key or not self.model:
            raise MemoryV3CompilerUnavailable("not_configured")
        provider_prompt = _MEMORY_V3_SEMANTIC_PROMPT
        if self.request_profile.startswith("deepseek_json_object"):
            provider_prompt += (
                "\n\nExact output JSON Schema (follow field names and enum values "
                "literally):\n"
                + json.dumps(
                    _strict_provider_compile_schema(),
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
            )
        payload: dict[str, object] = {
            "model": self.model,
            "max_tokens": 4096,
            "messages": [
                {"role": "system", "content": provider_prompt},
                {
                    "role": "user",
                    "content": json.dumps(
                        request.model_dump(),
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ),
                },
            ],
        }
        if self.request_profile.startswith("deepseek_json_object"):
            # DeepSeek V4 defaults to thinking mode and supports JSON Object,
            # not OpenAI's strict json_schema response format. Formation is
            # constrained extraction; local typed parsing remains mandatory.
            thinking_enabled = self.request_profile.endswith("_thinking")
            payload.update(
                {
                    "thinking": {"type": "enabled" if thinking_enabled else "disabled"},
                    "response_format": {"type": "json_object"},
                }
            )
            if thinking_enabled:
                payload["reasoning_effort"] = "high"
            else:
                payload["temperature"] = 0
        else:
            payload.update(
                {
                    "temperature": 0,
                    # Some OpenAI-compatible providers otherwise spend the
                    # completion budget on hidden reasoning and return null.
                    "reasoning_effort": None,
                    "n": 1,
                    "seed": 7,
                    "response_format": {
                        "type": "json_schema",
                        "json_schema": {
                            "name": "memory_semantic_atoms_v3_1",
                            "strict": True,
                            "schema": _strict_provider_compile_schema(),
                        },
                    },
                }
            )
        started_at = time.perf_counter()
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
        except httpx.RequestError as error:
            raise MemoryV3CompilerUnavailable(
                "network_error",
                latency_ms=_elapsed_ms(started_at),
            ) from error
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise MemoryV3CompilerUnavailable(
                f"provider_http_{response.status_code}",
                http_status=response.status_code,
                latency_ms=_elapsed_ms(started_at),
            ) from error
        try:
            body = response.json()
        except json.JSONDecodeError as error:
            raise MemoryV3CompilerUnavailable(
                "invalid_provider_json",
                latency_ms=_elapsed_ms(started_at),
            ) from error
        usage = body.get("usage") if isinstance(body, dict) else None
        input_tokens = usage.get("prompt_tokens") if isinstance(usage, dict) else None
        output_tokens = usage.get("completion_tokens") if isinstance(usage, dict) else None
        valid_input_tokens = (
            input_tokens if isinstance(input_tokens, int) and input_tokens >= 0 else None
        )
        valid_output_tokens = (
            output_tokens if isinstance(output_tokens, int) and output_tokens >= 0 else None
        )
        actual_model = body.get("model") if isinstance(body, dict) else None
        fingerprint = body.get("system_fingerprint") if isinstance(body, dict) else None
        error_metadata = {
            "latency_ms": _elapsed_ms(started_at),
            "usage_input_tokens": valid_input_tokens,
            "usage_output_tokens": valid_output_tokens,
            "provider_model": actual_model if isinstance(actual_model, str) else None,
            "system_fingerprint": fingerprint if isinstance(fingerprint, str) else None,
        }
        try:
            content = body["choices"][0]["message"]["content"]
            if not isinstance(content, str) or not content.strip():
                raise TypeError("empty provider content")
        except (KeyError, IndexError, TypeError) as error:
            raise MemoryV3CompilerUnavailable(
                "missing_provider_content",
                **error_metadata,
            ) from error
        try:
            semantic_json = json.loads(content)
        except json.JSONDecodeError as error:
            raise MemoryV3CompilerUnavailable(
                "invalid_semantic_json",
                **error_metadata,
            ) from error
        try:
            envelope = MemorySemanticEnvelopeV3.model_validate(semantic_json)
        except ValidationError as error:
            diagnostics = tuple(
                f"{'.'.join(str(part) for part in item['loc'])}:{item['type']}"
                for item in error.errors(include_input=False, include_url=False)[:24]
            )
            raise MemoryV3CompilerUnavailable(
                "invalid_semantic_schema",
                diagnostics=diagnostics,
                **error_metadata,
            ) from error
        candidates, outcomes = construct_memory_observations(request, envelope.atoms)
        no_memory_reason = envelope.no_atom_reason
        if envelope.atoms and not candidates:
            no_memory_reason = "all_semantic_atoms_failed_local_construction"
        return MemoryCompileResultV3(
            candidates=candidates,
            no_memory_reason=no_memory_reason,
            provider=self.provider,
            model=self.model,
            prompt_version=self.prompt_version,
            usage_input_tokens=(valid_input_tokens),
            usage_output_tokens=(valid_output_tokens),
            semantic_atoms=envelope.atoms,
            construction_outcomes=outcomes,
            provider_model=actual_model if isinstance(actual_model, str) else None,
            system_fingerprint=fingerprint if isinstance(fingerprint, str) else None,
        )


def construct_memory_observations(
    request: MemoryCompileRequestV3,
    atoms: list[MemorySemanticAtomV3],
) -> tuple[list[MemoryObservationV3], list[SemanticConstructionOutcomeV3]]:
    """Turn untrusted semantic atoms into policy-bounded observation candidates."""

    candidates: list[MemoryObservationV3] = []
    outcomes: list[SemanticConstructionOutcomeV3] = []
    for index, atom in enumerate(atoms):
        try:
            candidate = _construct_memory_observation(request, atom, index)
        except ValueError as error:
            outcomes.append(
                SemanticConstructionOutcomeV3(
                    atom_index=index,
                    disposition="rejected",
                    reason=str(error),
                )
            )
            continue
        candidates.append(candidate)
        outcomes.append(
            SemanticConstructionOutcomeV3(
                atom_index=index,
                disposition="constructed",
                reason="deterministic_construction_passed",
            )
        )
    return candidates, outcomes


def _construct_memory_observation(
    request: MemoryCompileRequestV3,
    atom: MemorySemanticAtomV3,
    index: int,
) -> MemoryObservationV3:
    if atom.modality != "asserted":
        raise ValueError(f"unsupported_modality_{atom.modality}")
    turns = {turn.turn_id: turn for turn in request.turns}
    evidence: list[EvidenceV3] = []
    seen_sources: set[tuple[str, int, int]] = set()
    cited_fragments: list[str] = []
    cited_turns: list[CompileTurnV3] = []
    for item in atom.evidence:
        turn = turns.get(item.turn_id)
        if turn is None:
            raise ValueError("unknown_evidence_turn")
        if turn.status == "safety_override":
            raise ValueError("safety_ephemeral_source")
        start = turn.text.find(item.quote)
        if start < 0:
            raise ValueError("evidence_quote_mismatch")
        if turn.text.rfind(item.quote) != start:
            raise ValueError("ambiguous_evidence_quote")
        end = start + len(item.quote)
        key = (turn.turn_id, start, end)
        if key in seen_sources:
            raise ValueError("duplicate_evidence_reference")
        seen_sources.add(key)
        cited_fragments.append(item.quote)
        cited_turns.append(turn)
        evidence.append(
            EvidenceV3(
                turn_id=turn.turn_id,
                role=turn.role,
                fragment=item.quote,
                start_char=start,
                end_char=end,
            )
        )

    kind = _KIND_BY_PREDICATE[atom.predicate]
    roles = {turn.role for turn in cited_turns}
    if kind == "assistant_commitment":
        if roles != {"assistant"}:
            raise ValueError("invalid_assistant_commitment_provenance")
        explicitness: Literal["explicit", "implied", "assistant_only"] = "assistant_only"
    else:
        if roles != {"user"}:
            raise ValueError("assistant_to_user_contamination")
        explicitness = atom.explicitness

    cited_text = " ".join(cited_fragments)
    if not any(atom.object_quote in fragment for fragment in cited_fragments):
        raise ValueError("object_not_evidence_grounded")
    if atom.subject.entity_type != "user" or atom.subject.mention != "user":
        if atom.subject.mention not in cited_text:
            raise ValueError("subject_not_evidence_grounded")
    if (
        atom.subject.relationship_hint is not None
        and atom.subject.relationship_hint not in cited_text
    ):
        raise ValueError("subject_relationship_not_evidence_grounded")
    target = atom.target_entity
    if target is not None and target.mention not in cited_text:
        raise ValueError("target_not_evidence_grounded")
    if (
        target is not None
        and target.relationship_hint is not None
        and target.relationship_hint not in cited_text
    ):
        raise ValueError("target_relationship_not_evidence_grounded")
    raw_expression = atom.temporal_expression_quote
    if raw_expression is not None and raw_expression not in cited_text:
        raise ValueError("temporal_expression_not_evidence_grounded")

    local_sensitivity = classify_local_memory_sensitivity(cited_text)
    sensitivity = _max_sensitivity(local_sensitivity, atom.sensitivity_hint)
    if sensitivity != "normal":
        raise ValueError(f"local_{sensitivity}_content")

    user_turns = [turn for turn in cited_turns if turn.role == "user"]
    confidence_known = all(turn.stt_confidence is not None for turn in user_turns)
    minimum_stt = min((turn.stt_confidence or 0.5) for turn in user_turns) if user_turns else 1.0
    epistemic_confidence = min(
        0.95 if explicitness != "implied" else 0.65,
        minimum_stt,
    )
    temporal_status = atom.temporal_class
    if user_turns and (not confidence_known or minimum_stt < 0.78):
        temporal_status = "uncertain"
    temporal_confidence = _temporal_resolution_confidence(
        temporal_status,
        raw_expression,
        minimum_stt,
    )
    instruction_like = looks_instruction_like_memory(atom.object_quote)
    utility = _utility_for_predicate(atom.predicate, explicitness, instruction_like)
    affect = _construct_affect(atom.affect, cited_text, epistemic_confidence)
    candidate_hash = hashlib.sha256(
        (
            request.job_id
            + "|"
            + str(index)
            + "|"
            + json.dumps(
                atom.model_dump(mode="json"),
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
        ).encode("utf-8")
    ).hexdigest()[:32]
    return MemoryObservationV3(
        schema_version=3,
        candidate_id=f"candidate_{candidate_hash}",
        kind=kind,
        subject=EntityMentionV3(**atom.subject.model_dump()),
        predicate=atom.predicate,
        object=ObjectValueV3(
            text=atom.object_quote,
            normalized_value=_deterministic_normalized_value(atom),
            target_entity=(EntityMentionV3(**target.model_dump()) if target is not None else None),
            user_assessment=(
                f"{atom.assessment} assessment"
                if atom.assessment in {"positive", "negative"}
                else None
            ),
        ),
        evidence=evidence,
        temporal=TemporalV3(
            status=temporal_status,
            raw_expression=raw_expression,
            resolution_confidence=temporal_confidence,
        ),
        epistemic=EpistemicV3(
            explicitness=explicitness,
            confidence=epistemic_confidence,
            negated=False,
            hypothetical=False,
            quoted=False,
        ),
        affect=affect,
        utility=utility,
        privacy=PrivacyV3(
            sensitivity="normal",
            durable_eligibility="explicit_only" if instruction_like else "automatic",
            reason="instruction_like_content" if instruction_like else None,
        ),
        proposed_operation="ADD",
    )


def filter_grounded_observations(
    request: MemoryCompileRequestV3,
    candidates: list[MemoryObservationV3],
) -> list[MemoryObservationV3]:
    """Compatibility helper for tests; new compilation uses semantic construction."""

    turns = {(item.turn_id, item.role): item for item in request.turns}
    grounded: list[MemoryObservationV3] = []
    for candidate in candidates:
        if candidate.predicate not in _PREDICATES_BY_KIND[candidate.kind]:
            continue
        valid = True
        cited_fragments: list[str] = []
        for evidence in candidate.evidence:
            turn = turns.get((evidence.turn_id, evidence.role))
            if turn is None or evidence.fragment not in turn.text:
                valid = False
                break
            if evidence.start_char is not None and evidence.end_char is not None:
                if evidence.end_char > len(turn.text) or (
                    turn.text[evidence.start_char : evidence.end_char] != evidence.fragment
                ):
                    valid = False
                    break
            cited_fragments.append(evidence.fragment)
        cited_text = " ".join(cited_fragments)
        if candidate.object.text not in cited_text:
            valid = False
        target = candidate.object.target_entity
        if target is not None and target.mention not in cited_text:
            valid = False
        if valid:
            grounded.append(candidate)
    return grounded


def compile_model_metadata(result: MemoryCompileResultV3) -> CompilerModelV3:
    input_tokens = result.usage_input_tokens
    output_tokens = result.usage_output_tokens
    usage_known = input_tokens is not None and output_tokens is not None
    return CompilerModelV3(
        provider=result.provider,
        model=result.model,
        prompt_version=result.prompt_version,
        usage_source="provider_reported" if usage_known else "unknown",
        input_tokens=input_tokens or 0,
        output_tokens=output_tokens or 0,
        estimated_micro_inr=None,
    )


def _strict_provider_compile_schema() -> dict[str, object]:
    """Produce the all-fields-required schema expected by strict APIs.

    Nullable fields remain nullable, but the provider must emit them. FastAPI
    removes nulls again before returning the public phone contract.
    """

    schema: dict[str, object] = MemorySemanticEnvelopeV3.model_json_schema()

    def visit(value: object) -> None:
        if isinstance(value, dict):
            value.pop("default", None)
            properties = value.get("properties")
            if isinstance(properties, dict):
                value["required"] = list(properties)
            for nested in value.values():
                visit(nested)
        elif isinstance(value, list):
            for nested in value:
                visit(nested)

    visit(schema)
    return schema


def _elapsed_ms(started_at: float) -> int:
    return max(0, round((time.perf_counter() - started_at) * 1000))


def _max_sensitivity(
    first: Literal["normal", "restricted", "forbidden"],
    second: Literal["normal", "restricted", "forbidden"],
) -> Literal["normal", "restricted", "forbidden"]:
    order = {"normal": 0, "restricted": 1, "forbidden": 2}
    return first if order[first] >= order[second] else second


def classify_local_memory_sensitivity(
    value: str,
) -> Literal["normal", "restricted", "forbidden"]:
    """Deterministic privacy floor mirrored by the phone validator."""

    text = value.lower()
    if re.search(
        r"\b(password|passcode|otp|pin|cvv|api[ _-]?key|secret key|seed phrase)\b"
        r"|पासवर्ड|ओटीपी|पिन",
        text,
    ):
        return "forbidden"
    if re.search(
        r"\b(suicide|suicidal|self[ -]?harm|kill myself|end my life)\b"
        r"|आत्महत्या|खुदकुशी|खुद को मार|मरना चाहता|मरना चाहती",
        text,
    ):
        return "forbidden"
    if re.search(
        r"\b(diagnos|medication|therapy|therapist|psychiatr|doctor|hospital|"
        r"lawsuit|lawyer|legal case|bank account|salary|debt|religion|caste|"
        r"sexual orientation|home address)\b"
        r"|इलाज|दवाई|बीमारी|वकील|अदालत|जाति|धर्म|तनख्वाह|कर्ज",
        text,
    ):
        return "restricted"
    if re.search(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", value, re.IGNORECASE):
        return "restricted"
    if re.search(r"(?<!\d)(?:\+?91[ -]?)?[6-9]\d{9}(?!\d)", value):
        return "restricted"
    if re.search(r"(?<!\d)\d{12,19}(?!\d)", value):
        return "restricted"
    return "normal"


def looks_instruction_like_memory(value: str) -> bool:
    return bool(
        re.search(
            r"ignore (all |the )?(previous|prior) instructions|system prompt|"
            r"developer message|call me administrator|act as (an? )?administrator",
            value,
            re.IGNORECASE,
        )
    )


def _temporal_resolution_confidence(
    status: Literal["current", "past", "future", "uncertain"],
    raw_expression: str | None,
    minimum_stt: float,
) -> float:
    if status == "uncertain":
        base = 0.5
    elif status == "current":
        base = 0.9
    elif raw_expression:
        base = 0.9
    else:
        base = 0.75
    return min(base, minimum_stt)


_UTILITY_BY_PREDICATE: dict[str, tuple[float, float]] = {
    "preferred_name": (0.9, 0.95),
    "has_relationship": (0.82, 0.85),
    "relationship_association": (0.78, 0.8),
    "response_language": (0.9, 0.95),
    "response_length": (0.85, 0.9),
    "support_style": (0.9, 0.95),
    "likes": (0.7, 0.75),
    "dislikes": (0.7, 0.75),
    "avoids_topic": (0.9, 0.95),
    "follows_routine": (0.75, 0.82),
    "pursues_goal": (0.82, 0.88),
    "holds_value": (0.8, 0.85),
    "experienced_event": (0.65, 0.65),
    "event_outcome": (0.75, 0.72),
    "open_thread": (0.85, 0.9),
    "assistant_commitment": (0.9, 0.95),
    "works_at": (0.82, 0.85),
    "profile_association": (0.7, 0.72),
    "episode_association": (0.65, 0.65),
    "causes_stress": (0.82, 0.86),
}


def _utility_for_predicate(
    predicate: Predicate,
    explicitness: Literal["explicit", "implied", "assistant_only"],
    instruction_like: bool,
) -> UtilityV3:
    salience, future_utility = _UTILITY_BY_PREDICATE[predicate]
    if explicitness == "implied":
        salience = min(salience, 0.6)
        future_utility = min(future_utility, 0.65)
    return UtilityV3(
        salience=salience,
        future_utility=future_utility,
        proactive_allowed=False,
        confirmation_required=instruction_like,
    )


def _deterministic_normalized_value(atom: MemorySemanticAtomV3) -> str | float | bool:
    """Keep canonicalization useful without accepting arbitrary model prose."""

    text = atom.object_quote.casefold()
    if atom.predicate == "support_style":
        no_solutions = bool(
            re.search(
                r"\b(no advice|advice mat|solutions? mat)\b|सलाह मत|समाधान मत",
                text,
            )
        )
        validate_first = bool(
            re.search(r"\b(validate|validation)\b|मान्यता|समझ", text)
        )
        if no_solutions and validate_first:
            return "validate first; no solutions"
        if no_solutions:
            return "no solutions"
        if re.search(r"\b(quiet|silence|chup|bas saath)\b|चुप|साथ रह", text):
            return "quiet company"
        if re.search(r"\b(listen|suno|sun lo|baat sun)\b|सुनो|बात सुन", text):
            return "listen before advice"
    if atom.predicate == "response_length":
        if re.search(r"\b(short|brief|chhota|concise)\b|छोटा|संक्षिप्त", text):
            return "brief"
        if re.search(r"\b(long|detail|detailed)\b|विस्तार", text):
            return "detailed"
    if atom.predicate == "response_language":
        if "hinglish" in text:
            return "Hinglish"
        if re.search(r"\bhindi\b|हिंदी", text):
            return "Hindi"
        if re.search(r"\benglish\b|अंग्रेज", text):
            return "English"
    if atom.predicate == "preferred_name":
        return atom.object_quote
    if isinstance(atom.normalized_value, (bool, float)):
        return atom.normalized_value
    return atom.object_quote


_AFFECT_VALUES: dict[str, tuple[float, float]] = {
    "joy": (0.8, 0.65),
    "sadness": (-0.75, 0.4),
    "anger": (-0.8, 0.8),
    "fear": (-0.8, 0.85),
    "frustration": (-0.65, 0.7),
    "loneliness": (-0.75, 0.35),
    "anxiety": (-0.7, 0.75),
    "shame": (-0.75, 0.45),
    "relief": (0.65, 0.35),
    "pride": (0.75, 0.6),
    "excitement": (0.8, 0.9),
    "disappointment": (-0.65, 0.45),
    "tiredness": (-0.35, 0.2),
    "neutral": (0.0, 0.2),
    "other": (0.0, 0.5),
}
_AFFECT_INTENSITY = {"low": 0.35, "medium": 0.65, "high": 0.9}


def _construct_affect(
    affect: SemanticAffectV3 | None,
    cited_text: str,
    epistemic_confidence: float,
) -> AffectV3 | None:
    if affect is None:
        return None
    if affect.target_quote is not None and affect.target_quote not in cited_text:
        return None
    if affect.cause_quote is not None and affect.cause_quote not in cited_text:
        return None
    valence, arousal = _AFFECT_VALUES[affect.emotion]
    return AffectV3(
        emotion=affect.emotion,
        valence=valence,
        arousal=arousal,
        intensity=_AFFECT_INTENSITY[affect.intensity],
        target=affect.target_quote,
        cause=affect.cause_quote,
        confidence=min(epistemic_confidence, 0.85),
    )


_MEMORY_V3_SEMANTIC_PROMPT = """You extract minimal semantic memory atoms from a bounded Hindi/Hinglish companion conversation.
Return only JSON matching the supplied schema. You are an untrusted, stateless semantic proposal engine. The phone owns durable truth and mutation.

Do:
- Extract one atom per atomic assertion that may help a future conversation.
- Use subject {"entity_type":"user","mention":"user"} for facts, events,
  preferences, relationships, and commitments about this user. Put a named
  person, organization, place, event, or topic in target_entity when the
  assertion is about the user's link to that entity.
- Copy object_quote, evidence quotes, entity mentions, temporal expressions, and affect target/cause quotes exactly from the supplied turns.
- Cite the smallest sufficient exact quote and its turn_id. Do not translate or paraphrase quote fields.
- Represent negated, hypothetical, and merely quoted claims with the correct modality. Do not silently convert them into asserted facts.
- Use explicitness=implied only when the meaning is strongly supported but not directly stated.
- Use sensitivity_hint conservatively. Secrets and crisis content are forbidden; medical, legal, financial, protected-trait, or precise-contact content is restricted.
- Return an empty atoms list for filler, recall questions, unsupported interpretations, or content with no future conversational utility.

Ontology (each predicate has exactly one kind, applied locally):
- profile: preferred_name, works_at, profile_association
- relationship: has_relationship, relationship_association
- preference: response_language, response_length, support_style, likes, dislikes
- routine: follows_routine
- goal: pursues_goal
- value: holds_value
- boundary: avoids_topic
- episode: experienced_event, event_outcome, causes_stress, episode_association
- open_thread: open_thread
- assistant commitment: assistant_commitment

Boundaries:
- response_language, response_length, and support_style require an explicit preference about how the companion responds.
- has_relationship is for a stated personal relationship; relationship_association is for another grounded person-role link such as a manager.
- profile_association is for a durable user/profile link not covered by preferred_name or works_at.
- experienced_event is a completed notable incident; event_outcome is its stated result or explicit assessment.
- causes_stress requires explicit causal attribution, not merely an unpleasant event.
- open_thread is a future result, appointment, test, or follow-up worth revisiting.
- assistant_commitment cites assistant turns only. Every other predicate cites user turns only.
- Do not infer recurrence, diagnoses, identity merges, relationship closeness, or historical mutation.
- A correction proposes only the newly asserted value. A repeated fact is still just the current evidence-backed atom.
- normalized_value and assessment may summarize semantics but must not contradict evidence.
- Affect is optional, episode-local, and evidence-grounded; it is never a personality trait.

Do not generate candidate IDs, kinds, offsets, numeric confidence, utility, privacy admission, durable operations, database IDs, or mutations. Local deterministic code owns those fields."""
