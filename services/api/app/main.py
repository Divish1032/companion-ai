import asyncio
from contextlib import asynccontextmanager
from datetime import timedelta
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from livekit import api
from pydantic import BaseModel, Field

from app.agent_assignment import AgentAssigner, AgentAssignmentFailed
from app.config import Settings
from app.embedding_service import (
    EmbeddingInputType,
    ModelServingService,
    ModelServingUnavailable,
    RetrievalPlan,
)
from app.memory_extraction import (
    MemoryCandidateExtractor,
    MemoryExtractionRequest,
    MemoryExtractionResult,
    MemoryExtractionUnavailable,
    MemoryJudgeCost,
    MemoryJudgeResponse,
    OpenAICompatibleMemoryCandidateExtractor,
    build_judge_decision,
    filter_source_safe_candidates,
)
from app.session_store import RateLimitExceeded, SessionStore
from app.telemetry_store import TelemetryStore, TelemetryValidationError
from app.voice_catalog import load_voice_catalog

settings = Settings()
store = SessionStore(settings.durable_store_path)
agent_assigner = AgentAssigner(settings)
model_serving = ModelServingService(
    embedding_enabled=settings.enable_memory_embeddings,
    embedding_model_name=settings.memory_embedding_model,
    embedding_model_revision=settings.memory_embedding_revision,
    embedding_dimension=settings.memory_embedding_dimension,
    embedding_backend=settings.memory_embedding_backend,
    embedding_model_path=settings.memory_embedding_model_path,
    reranker_enabled=settings.enable_memory_reranker,
    reranker_model_name=settings.memory_reranker_model,
    planner_enabled=settings.enable_memory_planner,
    planner_model_name=settings.memory_planner_model,
)
memory_candidate_extractor: MemoryCandidateExtractor = OpenAICompatibleMemoryCandidateExtractor(
    base_url=settings.memory_extraction_base_url,
    api_key=settings.memory_extraction_api_key,
    model=settings.memory_extraction_model,
    timeout_seconds=settings.memory_extraction_timeout_seconds,
)
telemetry_store = TelemetryStore(settings.telemetry_store_path)
voice_catalog = load_voice_catalog(settings.voice_catalog)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    warmup_task = asyncio.create_task(model_serving.warm_up())
    try:
        yield
    finally:
        warmup_task.cancel()
        await asyncio.gather(warmup_task, return_exceptions=True)


app = FastAPI(title="Companion AI API", version="0.1.0", lifespan=lifespan)
app.mount(
    "/v1/tts-previews",
    StaticFiles(directory="app/static/tts-previews", check_dir=False),
    name="tts-previews",
)


@app.exception_handler(RequestValidationError)
async def request_validation_error(
    _request: Request, error: RequestValidationError
) -> JSONResponse:
    """Return and log field paths only; rejected bodies may contain user text."""

    fields = [
        ".".join(str(part) for part in issue.get("loc", ()))
        for issue in error.errors()
    ][:16]
    print("api_request_validation_error", {"fields": fields}, flush=True)
    return JSONResponse(
        status_code=422,
        content={"detail": {"code": "invalid_request", "fields": fields}},
    )


class RecentTranscriptItem(BaseModel):
    turn_id: str = Field(min_length=1, max_length=128)
    role: str = Field(pattern="^(user|ai|assistant)$")
    text: str = Field(min_length=1, max_length=1000)
    status: str = Field(default="final", max_length=64)
    confidence: float | None = Field(default=None, ge=0, le=1)
    source: str = Field(default="recent_turns", max_length=64)
    created_at_ms: int


class MemoryContextItem(BaseModel):
    memory_id: str = Field(min_length=1, max_length=160)
    kind: str = Field(
        pattern="^(stable_fact|core_profile|semantic|episodic|session_summary|procedural|safety_ephemeral)$"
    )
    label: str = Field(min_length=1, max_length=80)
    content: str = Field(min_length=1, max_length=800)
    original_text: str = Field(default="", max_length=1000)
    canonical_text: str = Field(default="", max_length=1000)
    language: str = Field(default="hi-IN", max_length=32)
    script: str = Field(default="mixed", max_length=32)
    source_turn_ids: list[str] = Field(default_factory=list, max_length=8)
    source_role: str = Field(max_length=32)
    transcript_status: str = Field(max_length=128)
    stt_confidence: float | None = Field(default=None, ge=0, le=1)
    created_at_ms: int
    updated_at_ms: int
    last_used_at_ms: int | None = None
    confidence_score: float = Field(ge=0, le=1)
    importance_score: float = Field(ge=0, le=1)
    recurrence_count: int = Field(default=1, ge=0, le=1000)
    sensitivity: str = Field(default="normal", max_length=64)
    temporal_status: str = Field(default="current", max_length=64)
    receipt_state: str = Field(default="implicit", max_length=64)
    evidence_summary: str = Field(default="", max_length=500)


class CreateSessionRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    language: str = Field(default="hi-IN", min_length=2, max_length=32)
    voice_id: str | None = Field(default=None, min_length=1, max_length=80)
    recent_transcript_context: list[RecentTranscriptItem] = Field(default_factory=list)
    memory_context: list[MemoryContextItem] = Field(default_factory=list)


class CreateSessionResponse(BaseModel):
    session_id: str
    room_name: str
    livekit_url: str
    expires_at_ms: int
    language: str
    voice_id: str


class TokenRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    session_id: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    token: str
    livekit_url: str
    room_name: str
    expires_in_seconds: int


class EndSessionRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    session_id: str = Field(min_length=1, max_length=128)


class EmbeddingsRequest(BaseModel):
    texts: list[str] = Field(min_length=1, max_length=32)
    model: str | None = Field(default=None, max_length=120)
    dimension: int | None = Field(default=None, ge=128, le=768)
    input_type: EmbeddingInputType = "document"


class EmbeddingsResponse(BaseModel):
    model: str
    dimension: int
    embeddings: list[list[float]]


class RerankCandidate(BaseModel):
    id: str = Field(min_length=1, max_length=160)
    text: str = Field(min_length=1, max_length=1000)


class RerankRequest(BaseModel):
    query: str = Field(min_length=1, max_length=1000)
    candidates: list[RerankCandidate] = Field(min_length=1, max_length=64)
    model: str | None = Field(default=None, max_length=120)


class RerankResult(BaseModel):
    id: str
    score: float


class RerankResponse(BaseModel):
    model: str
    results: list[RerankResult]


class PlannerRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1000)
    model: str | None = Field(default=None, max_length=120)


class PlannerResponse(BaseModel):
    need_memory: bool
    route: str
    memory_types: list[str]
    entities: list[str]
    time_hint: str
    top_k: int


def get_store() -> SessionStore:
    return store


def get_agent_assigner() -> AgentAssigner:
    return agent_assigner


def get_model_serving() -> ModelServingService:
    return model_serving


def get_memory_candidate_extractor() -> MemoryCandidateExtractor:
    return memory_candidate_extractor


def get_telemetry_store() -> TelemetryStore:
    return telemetry_store


@app.get("/health")
async def health() -> dict[str, object]:
    return {"status": "ok", "service": settings.service_name}


@app.get("/readiness")
async def readiness() -> dict[str, object]:
    embedding = model_serving.embedding_readiness()
    if embedding["enabled"] and embedding["state"] != "ready":
        raise HTTPException(status_code=503, detail={"status": "not_ready", **embedding})
    return {"status": "ready", "embedding": embedding}


@app.get("/v1/config")
async def config() -> dict[str, object]:
    return {
        "environment": settings.environment,
        "livekit_url": settings.livekit_url,
        "tts": voice_catalog.public_payload(),
    }


class TelemetryIngestRequest(BaseModel):
    envelope: dict[str, object]


@app.post("/v1/telemetry/ingest")
async def ingest_telemetry(
    request: TelemetryIngestRequest,
    store: Annotated[TelemetryStore, Depends(get_telemetry_store)],
    x_telemetry_ingest_token: Annotated[str | None, Header()] = None,
) -> dict[str, bool]:
    if settings.telemetry_ingest_token and x_telemetry_ingest_token != settings.telemetry_ingest_token:
        raise HTTPException(status_code=401, detail={"code": "telemetry_ingest_unauthorized"})
    try:
        store.ingest(request.envelope)
    except TelemetryValidationError as error:
        raise HTTPException(status_code=422, detail={"code": "invalid_redacted_telemetry"}) from error
    return {"accepted": True}


@app.get("/v1/telemetry/sessions/{session_id}")
async def telemetry_session_summary(
    session_id: str,
    store: Annotated[TelemetryStore, Depends(get_telemetry_store)],
) -> dict[str, object]:
    return store.session_summary(session_id)


@app.post("/v1/telemetry/purge")
async def purge_telemetry(
    store: Annotated[TelemetryStore, Depends(get_telemetry_store)],
    x_telemetry_ingest_token: Annotated[str | None, Header()] = None,
) -> dict[str, int]:
    if settings.telemetry_ingest_token and x_telemetry_ingest_token != settings.telemetry_ingest_token:
        raise HTTPException(status_code=401, detail={"code": "telemetry_ingest_unauthorized"})
    import time
    cutoff = int(time.time() * 1000) - settings.telemetry_raw_retention_days * 86_400_000
    return {"purged": store.purge_before(cutoff)}


@app.post("/v1/embeddings", response_model=EmbeddingsResponse)
async def embeddings(
    request: EmbeddingsRequest,
    serving: Annotated[ModelServingService, Depends(get_model_serving)],
) -> EmbeddingsResponse:
    if request.model not in {None, settings.memory_embedding_model}:
        raise HTTPException(status_code=400, detail={"code": "unsupported_embedding_model"})
    if request.dimension not in {None, settings.memory_embedding_dimension}:
        raise HTTPException(status_code=400, detail={"code": "unsupported_embedding_dimension"})
    try:
        vectors = await asyncio.wait_for(
            serving.embed(request.texts, input_type=request.input_type),
            timeout=settings.embedding_timeout_seconds,
        )
    except TimeoutError as error:
        raise HTTPException(status_code=504, detail={"code": "embedding_timeout"}) from error
    except ModelServingUnavailable as error:
        raise HTTPException(status_code=503, detail={"code": "embedding_unavailable"}) from error
    return EmbeddingsResponse(
        model=settings.memory_embedding_model,
        dimension=settings.memory_embedding_dimension,
        embeddings=vectors,
    )


@app.post("/v1/rerank", response_model=RerankResponse)
async def rerank_candidates(
    request: RerankRequest,
    serving: Annotated[ModelServingService, Depends(get_model_serving)],
) -> RerankResponse:
    if request.model not in {None, settings.memory_reranker_model}:
        raise HTTPException(status_code=400, detail={"code": "unsupported_reranker_model"})
    try:
        scores = await asyncio.wait_for(
            serving.rerank(request.query, [candidate.text for candidate in request.candidates]),
            timeout=settings.reranker_timeout_seconds,
        )
    except TimeoutError as error:
        raise HTTPException(status_code=504, detail={"code": "reranker_timeout"}) from error
    except ModelServingUnavailable as error:
        raise HTTPException(status_code=503, detail={"code": "reranker_unavailable"}) from error
    ranked = sorted(
        [
            RerankResult(id=candidate.id, score=score)
            for candidate, score in zip(request.candidates, scores, strict=True)
        ],
        key=lambda result: result.score,
        reverse=True,
    )
    return RerankResponse(model=settings.memory_reranker_model, results=ranked)


@app.post("/v1/memory-plan", response_model=PlannerResponse)
async def memory_plan(
    request: PlannerRequest,
    serving: Annotated[ModelServingService, Depends(get_model_serving)],
) -> PlannerResponse:
    if request.model not in {None, settings.memory_planner_model}:
        raise HTTPException(status_code=400, detail={"code": "unsupported_planner_model"})
    try:
        plan: RetrievalPlan = await asyncio.wait_for(
            serving.plan(request.text), timeout=settings.planner_timeout_seconds
        )
    except TimeoutError as error:
        raise HTTPException(status_code=504, detail={"code": "planner_timeout"}) from error
    except ModelServingUnavailable as error:
        raise HTTPException(status_code=503, detail={"code": "planner_unavailable"}) from error
    return PlannerResponse(
        need_memory=plan.need_memory,
        route=plan.route,
        memory_types=list(plan.memory_types),
        entities=list(plan.entities),
        time_hint=plan.time_hint,
        top_k=plan.top_k,
    )


def _judge_cost(result: MemoryExtractionResult) -> MemoryJudgeCost:
    """Never silently report zero for an unpriced external judge dependency."""

    input_tokens = result.usage_input_tokens
    output_tokens = result.usage_output_tokens
    input_rate = settings.memory_judge_input_micro_inr_per_million_tokens
    output_rate = settings.memory_judge_output_micro_inr_per_million_tokens
    if input_tokens is None or output_tokens is None:
        return MemoryJudgeCost(
            source="unknown",
            input_tokens=input_tokens or 0,
            output_tokens=output_tokens or 0,
            estimated_micro_inr=0,
        )
    if input_rate <= 0 or output_rate <= 0:
        # Usage is provider-reported but the rate is not reviewed; the INR
        # figure stays unknown/incomplete rather than a fabricated zero.
        return MemoryJudgeCost(
            source="unknown",
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_micro_inr=0,
        )
    estimated = (input_tokens * input_rate + output_tokens * output_rate) // 1_000_000
    return MemoryJudgeCost(
        source="provider_reported",
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        estimated_micro_inr=estimated,
    )


@app.post("/v1/memory-judge", response_model=MemoryJudgeResponse)
async def memory_judge(
    request: MemoryExtractionRequest,
    extractor: Annotated[MemoryCandidateExtractor, Depends(get_memory_candidate_extractor)],
) -> MemoryJudgeResponse:
    if not settings.enable_memory_extraction:
        raise HTTPException(status_code=503, detail={"code": "memory_extraction_disabled"})
    try:
        result = await extractor.extract(request)
    except MemoryExtractionUnavailable as error:
        raise HTTPException(
            status_code=503, detail={"code": "memory_extraction_unavailable"}
        ) from error
    safe_candidates = filter_source_safe_candidates(request, result.candidates)
    return MemoryJudgeResponse(
        job_id=request.job_id,
        contract_version="memory_judge_v1",
        cost=_judge_cost(result),
        decisions=[
            build_judge_decision(request.job_id, candidate) for candidate in safe_candidates
        ],
    )


@app.post("/v1/session", response_model=CreateSessionResponse)
async def create_session(
    request: CreateSessionRequest,
    session_store: Annotated[SessionStore, Depends(get_store)],
    assigner: Annotated[AgentAssigner, Depends(get_agent_assigner)],
) -> CreateSessionResponse:
    if request.language != voice_catalog.language:
        raise HTTPException(status_code=422, detail={"code": "unsupported_language"})
    try:
        selected_voice = voice_catalog.require(request.voice_id)
    except ValueError as error:
        raise HTTPException(status_code=422, detail={"code": "unsupported_voice"}) from error
    bounded_context = [
        item.model_dump()
        for item in request.recent_transcript_context[-settings.max_recent_context_messages :]
    ]
    bounded_memory = [
        item.model_dump() for item in request.memory_context[-settings.max_memory_context_blocks :]
    ]
    try:
        session = session_store.create_session(
            device_id=request.device_id,
            max_session_seconds=settings.max_session_seconds,
            recent_context={
                "recent_turns": bounded_context,
                "memory_blocks": bounded_memory,
            },
            session_create_limit_per_day=settings.session_create_limit_per_day,
            language=request.language,
            voice_id=selected_voice.id,
        )
    except RateLimitExceeded as error:
        raise HTTPException(status_code=429, detail={"code": "rate_limited"}) from error

    try:
        await assigner.assign(session=session)
    except AgentAssignmentFailed as error:
        await assigner.cancel(session_id=session.session_id)
        session_store.end_session(
            session_id=session.session_id,
            device_id=request.device_id,
        )
        raise HTTPException(
            status_code=503,
            detail={"code": "agent_assignment_failed"},
        ) from error
    session_store.clear_session_context(session_id=session.session_id)

    return CreateSessionResponse(
        session_id=session.session_id,
        room_name=session.room_name,
        livekit_url=settings.livekit_url,
        expires_at_ms=session.expires_at_ms,
        language=session.language,
        voice_id=session.voice_id or voice_catalog.default_voice_id,
    )


@app.post("/v1/livekit/token", response_model=TokenResponse)
async def livekit_token(
    request: TokenRequest,
    session_store: Annotated[SessionStore, Depends(get_store)],
) -> TokenResponse:
    if not settings.livekit_api_key or not settings.livekit_api_secret:
        raise HTTPException(
            status_code=503,
            detail={"code": "livekit_credentials_not_configured"},
        )

    session = session_store.get_active_session(
        session_id=request.session_id,
        device_id=request.device_id,
    )
    if session is None:
        raise HTTPException(status_code=404, detail={"code": "session_not_found"})

    try:
        session_store.record_token_mint(
            session_id=session.session_id,
            limit=settings.token_mint_limit_per_session,
        )
    except RateLimitExceeded as error:
        raise HTTPException(status_code=429, detail={"code": "rate_limited"}) from error

    identity = f"device_{request.device_id[:48]}"
    token = (
        api.AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(identity)
        .with_name("Companion mobile user")
        .with_ttl(timedelta(seconds=settings.livekit_token_ttl_seconds))
        .with_grants(
            api.VideoGrants(
                room_join=True,
                room=session.room_name,
                can_publish=True,
                can_publish_data=True,
                can_subscribe=True,
            )
        )
        .to_jwt()
    )
    return TokenResponse(
        token=token,
        livekit_url=settings.livekit_url,
        room_name=session.room_name,
        expires_in_seconds=settings.livekit_token_ttl_seconds,
    )


@app.post("/v1/session/end")
async def end_session(
    request: EndSessionRequest,
    session_store: Annotated[SessionStore, Depends(get_store)],
    assigner: Annotated[AgentAssigner, Depends(get_agent_assigner)],
) -> dict[str, bool]:
    ended = session_store.end_session(
        session_id=request.session_id,
        device_id=request.device_id,
    )
    if ended:
        await assigner.cancel(session_id=request.session_id)
    return {"ended": ended}
