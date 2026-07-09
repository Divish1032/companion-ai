from datetime import timedelta
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from livekit import api
from pydantic import BaseModel, Field

from app.agent_assignment import AgentAssigner, AgentAssignmentFailed
from app.config import Settings
from app.session_store import ActiveSessionExists, RateLimitExceeded, SessionStore

settings = Settings()
app = FastAPI(title="Companion AI API", version="0.1.0")
store = SessionStore(settings.durable_store_path)
agent_assigner = AgentAssigner(settings)


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
    kind: str = Field(pattern="^(stable_fact|session_summary)$")
    label: str = Field(min_length=1, max_length=80)
    content: str = Field(min_length=1, max_length=800)
    source_turn_ids: list[str] = Field(default_factory=list, max_length=8)
    source_role: str = Field(max_length=32)
    transcript_status: str = Field(max_length=128)
    stt_confidence: float | None = Field(default=None, ge=0, le=1)
    created_at_ms: int
    updated_at_ms: int
    last_used_at_ms: int | None = None
    confidence_score: float = Field(ge=0, le=1)
    importance_score: float = Field(ge=0, le=1)


class CreateSessionRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    recent_transcript_context: list[RecentTranscriptItem] = Field(default_factory=list)
    memory_context: list[MemoryContextItem] = Field(default_factory=list)


class CreateSessionResponse(BaseModel):
    session_id: str
    room_name: str
    livekit_url: str
    expires_at_ms: int


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


def get_store() -> SessionStore:
    return store


def get_agent_assigner() -> AgentAssigner:
    return agent_assigner


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": settings.service_name}


@app.get("/v1/config")
async def config() -> dict[str, str]:
    return {
        "environment": settings.environment,
        "livekit_url": settings.livekit_url,
    }


@app.post("/v1/session", response_model=CreateSessionResponse)
async def create_session(
    request: CreateSessionRequest,
    session_store: Annotated[SessionStore, Depends(get_store)],
    assigner: Annotated[AgentAssigner, Depends(get_agent_assigner)],
) -> CreateSessionResponse:
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
        )
    except ActiveSessionExists as error:
        raise HTTPException(
            status_code=409,
            detail={
                "code": "active_session_exists",
                "session_id": error.session.session_id,
                "room_name": error.session.room_name,
            },
        ) from error
    except RateLimitExceeded as error:
        raise HTTPException(status_code=429, detail={"code": "rate_limited"}) from error

    try:
        await assigner.assign(session=session)
    except AgentAssignmentFailed as error:
        session_store.end_session(
            session_id=session.session_id,
            device_id=request.device_id,
        )
        raise HTTPException(
            status_code=503,
            detail={"code": "agent_assignment_failed"},
        ) from error

    return CreateSessionResponse(
        session_id=session.session_id,
        room_name=session.room_name,
        livekit_url=settings.livekit_url,
        expires_at_ms=session.expires_at_ms,
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
) -> dict[str, bool]:
    ended = session_store.end_session(
        session_id=request.session_id,
        device_id=request.device_id,
    )
    return {"ended": ended}
