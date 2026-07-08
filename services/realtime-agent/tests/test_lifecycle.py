import asyncio
import json
import time

from app.config import Settings
from app.lifecycle import (
    AgentAssignment,
    MemoryAgentTransport,
    RealtimeAgentSession,
    _wait_until_started,
)


def test_agent_emits_state_sequence_and_filler_before_fake_audio() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_session_started")
        await _wait_for_events(transport, minimum=6)
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    states = [event.get("state") for event in events if event["type"] == "session_state"]
    filler_states = [event.get("state") for event in events if event["type"] == "filler_audio"]

    assert states[:4] == ["listening", "thinking", "speaking", "listening"]
    assert filler_states == ["started", "stopped"]
    assert transport.audio_publications == 1
    assert transport.disconnected is True
    assert all("sequence" in event for event in events)
    assert any(str(event.get("turn_id", "")).endswith("turn:0001") for event in events)


def test_cancellation_primitive_cancels_current_turn() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(recent_context=[]),
        settings=_settings(),
        transport=transport,
    )

    async def scenario() -> bool:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_session_started")
        await _wait_for_state(transport, "thinking")
        cancelled = session.cancel_current_turn()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        return cancelled

    assert asyncio.run(scenario()) is True


def test_safety_override_runs_before_fake_audio() -> None:
    transport = MemoryAgentTransport()
    session = RealtimeAgentSession(
        assignment=_assignment(
            recent_context=[
                {
                    "role": "user",
                    "text": "suicide",
                    "turn_id": "turn_1",
                    "created_at_ms": 1,
                }
            ]
        ),
        settings=_settings(),
        transport=transport,
    )

    async def scenario() -> None:
        task = asyncio.create_task(session.run())
        await session.started.wait()
        await transport.activity.put("client_session_started")
        await _wait_for_events(transport, minimum=4)
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    asyncio.run(scenario())

    events = [_decode(event) for event in transport.events]
    assert [event["type"] for event in events].count("filler_audio") == 0
    assert any(event.get("safety_reason") == "crisis_keyword" for event in events)
    assert transport.audio_publications == 1


def test_wait_until_started_does_not_cancel_agent_task() -> None:
    async def scenario() -> bool:
        started = asyncio.Event()

        async def long_running_agent() -> None:
            started.set()
            await asyncio.Event().wait()

        task = asyncio.create_task(long_running_agent())
        await _wait_until_started(task, started)
        still_running = not task.done()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        return still_running

    assert asyncio.run(scenario()) is True


def _assignment(*, recent_context: list[dict[str, object]]) -> AgentAssignment:
    return AgentAssignment(
        session_id="session_test",
        room_name="companion_session_test",
        expires_at_ms=int(time.time() * 1000) + 60_000,
        recent_context=recent_context,
    )


def _settings() -> Settings:
    return Settings(
        livekit_api_key="devkey",
        livekit_api_secret="secret",
        enable_livekit_rtc=False,
        max_idle_seconds=1,
        fake_audio_ms=20,
    )


async def _wait_for_events(transport: MemoryAgentTransport, *, minimum: int) -> None:
    for _ in range(50):
        if len(transport.events) >= minimum:
            return
        await asyncio.sleep(0.01)
    raise AssertionError(f"expected at least {minimum} events, saw {len(transport.events)}")


async def _wait_for_state(transport: MemoryAgentTransport, state: str) -> None:
    for _ in range(50):
        if any(_decode(event).get("state") == state for event in transport.events):
            return
        await asyncio.sleep(0.01)
    raise AssertionError(f"expected state {state}")


def _decode(data: bytes) -> dict[str, object]:
    decoded = json.loads(data.decode("utf-8"))
    assert isinstance(decoded, dict)
    return decoded
