from datetime import timedelta
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from livekit import api
from pydantic import BaseModel, Field

from app.config import Settings
from app.session_store import ActiveSessionExists, RateLimitExceeded, SessionStore

settings = Settings()
app = FastAPI(title="Companion AI API", version="0.1.0")
store = SessionStore(settings.durable_store_path)


class RecentTranscriptItem(BaseModel):
    turn_id: str = Field(min_length=1, max_length=128)
    role: str = Field(pattern="^(user|ai)$")
    text: str = Field(min_length=1, max_length=1000)
    created_at_ms: int


class CreateSessionRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    recent_transcript_context: list[RecentTranscriptItem] = Field(default_factory=list)


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
) -> CreateSessionResponse:
    bounded_context = [
        item.model_dump()
        for item in request.recent_transcript_context[-settings.max_recent_context_messages :]
    ]
    try:
        session = session_store.create_session(
            device_id=request.device_id,
            max_session_seconds=settings.max_session_seconds,
            recent_context=bounded_context,
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
