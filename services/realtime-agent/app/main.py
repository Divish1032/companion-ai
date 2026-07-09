from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app.config import Settings, load_provider_routing
from app.lifecycle import AgentAssignment, AgentAssignmentError, AgentSupervisor

settings = Settings()
supervisor = AgentSupervisor(settings)
app = FastAPI(title="Companion AI Realtime Agent", version="0.1.0")


class AgentAssignRequest(BaseModel):
    session_id: str = Field(min_length=1, max_length=128)
    room_name: str = Field(min_length=1, max_length=128)
    expires_at_ms: int
    recent_context: dict[str, object] | list[dict[str, object]] = Field(default_factory=dict)


class AgentCancelRequest(BaseModel):
    session_id: str = Field(min_length=1, max_length=128)


@app.get("/health")
async def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": settings.service_name,
        "active_agents": str(supervisor.active_count()),
    }


@app.post("/v1/agent/assign")
async def assign_agent(request: AgentAssignRequest) -> dict[str, str]:
    try:
        await supervisor.assign(
            AgentAssignment(
                session_id=request.session_id,
                room_name=request.room_name,
                expires_at_ms=request.expires_at_ms,
                recent_context=request.recent_context,
            )
        )
    except AgentAssignmentError as error:
        raise HTTPException(
            status_code=503,
            detail={"code": "agent_assignment_failed", "message": str(error)},
        ) from error
    except TimeoutError as error:
        raise HTTPException(
            status_code=503,
            detail={"code": "agent_start_timeout"},
        ) from error
    return {"status": "assigned"}


@app.post("/v1/agent/cancel")
async def cancel_agent(request: AgentCancelRequest) -> dict[str, bool]:
    return {"cancelled": supervisor.cancel(request.session_id)}


@app.get("/debug/provider-route/{language}")
async def provider_route(language: str) -> dict[str, str]:
    route = load_provider_routing().for_language(language)

    return {
        "language": language,
        "stt": route.stt,
        "llm": route.llm,
        "tts": route.tts,
    }
