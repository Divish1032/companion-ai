import asyncio
from types import SimpleNamespace

import httpx
import pytest

from app.agent_assignment import AgentAssigner, AgentAssignmentFailed, agent_cancel_url
from app.config import Settings


def test_agent_cancel_url_replaces_endpoint_suffix_without_trimming_port() -> None:
    assert (
        agent_cancel_url("http://realtime-agent:8001/v1/agent/assign")
        == "http://realtime-agent:8001/v1/agent/cancel"
    )


def test_agent_cancel_url_preserves_base_path() -> None:
    assert (
        agent_cancel_url("https://example.test/companion/v1/agent/assign")
        == "https://example.test/companion/v1/agent/cancel"
    )


def test_assignment_retries_transport_loss_with_same_session() -> None:
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if len(requests) == 1:
            raise httpx.ReadError("response lost", request=request)
        return httpx.Response(200, json={"status": "assigned"})

    assigner = AgentAssigner(
        _settings(),
        transport=httpx.MockTransport(handler),
    )

    asyncio.run(assigner.assign(session=_session()))

    assert len(requests) == 2
    assert requests[0].content == requests[1].content


def test_assignment_retries_transient_agent_failure() -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        return httpx.Response(
            503 if attempts == 1 else 200,
            json={"status": "assigned"},
        )

    assigner = AgentAssigner(
        _settings(),
        transport=httpx.MockTransport(handler),
    )

    asyncio.run(assigner.assign(session=_session()))

    assert attempts == 2


def test_assignment_does_not_retry_non_transient_rejection() -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        return httpx.Response(400, json={"detail": "invalid"})

    assigner = AgentAssigner(
        _settings(),
        transport=httpx.MockTransport(handler),
    )

    with pytest.raises(AgentAssignmentFailed):
        asyncio.run(assigner.assign(session=_session()))

    assert attempts == 1


def test_assignment_cancel_calls_sibling_endpoint() -> None:
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, json={"cancelled": True})

    assigner = AgentAssigner(
        _settings(),
        transport=httpx.MockTransport(handler),
    )

    cancelled = asyncio.run(assigner.cancel(session_id="session-1"))

    assert cancelled is True
    assert requests[0].url == "https://agent.test/v1/agent/cancel"


def _settings() -> Settings:
    return Settings(
        agent_assignment_url="https://agent.test/v1/agent/assign",
        agent_assignment_max_attempts=2,
        agent_assignment_retry_delay_seconds=0,
    )


def _session() -> SimpleNamespace:
    return SimpleNamespace(
        session_id="session-1",
        room_name="room-1",
        expires_at_ms=123,
        recent_context=lambda: {"recent_turns": [], "memory_blocks": []},
    )
