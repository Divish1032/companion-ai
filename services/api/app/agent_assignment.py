from __future__ import annotations

import asyncio
from urllib.parse import urlsplit, urlunsplit

import httpx

from app.config import Settings
from app.session_store import SessionRecord


class AgentAssignmentFailed(Exception):
    pass


def agent_cancel_url(assignment_url: str) -> str:
    """Return the sibling cancellation endpoint without corrupting host ports."""
    parsed = urlsplit(assignment_url)
    path = parsed.path
    if path.endswith("/assign"):
        path = f"{path[: -len('/assign')]}/cancel"
    else:
        path = f"{path.rstrip('/')}/cancel"
    return urlunsplit((parsed.scheme, parsed.netloc, path, parsed.query, parsed.fragment))


class AgentAssigner:
    def __init__(
        self,
        settings: Settings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.settings = settings
        self.transport = transport

    async def assign(self, *, session: SessionRecord) -> None:
        if not self.settings.agent_assignment_url:
            return

        attempts = min(3, max(1, self.settings.agent_assignment_max_attempts))
        retry_delay = min(
            1.0,
            max(0.0, self.settings.agent_assignment_retry_delay_seconds),
        )
        payload = {
            "session_id": session.session_id,
            "room_name": session.room_name,
            "expires_at_ms": session.expires_at_ms,
            "recent_context": session.recent_context(),
            "language": getattr(session, "language", "hi-IN"),
            "voice_id": getattr(session, "voice_id", None),
        }
        async with httpx.AsyncClient(
            timeout=self.settings.agent_assignment_timeout_seconds,
            transport=self.transport,
        ) as client:
            for attempt in range(1, attempts + 1):
                try:
                    response = await client.post(
                        self.settings.agent_assignment_url,
                        json=payload,
                    )
                except httpx.TransportError as error:
                    if attempt == attempts:
                        raise AgentAssignmentFailed(str(error)) from error
                    _log_assignment_retry(attempt=attempt, error_type=type(error).__name__)
                    await asyncio.sleep(retry_delay)
                    continue

                if response.status_code < 400:
                    return
                if response.status_code not in {502, 503, 504} or attempt == attempts:
                    raise AgentAssignmentFailed(response.text)
                _log_assignment_retry(
                    attempt=attempt,
                    error_type=f"http_{response.status_code}",
                )
                await asyncio.sleep(retry_delay)

    async def cancel(self, *, session_id: str) -> bool:
        if not self.settings.agent_assignment_url:
            return False
        try:
            async with httpx.AsyncClient(
                timeout=min(
                    1.0,
                    max(0.1, self.settings.agent_assignment_timeout_seconds),
                ),
                transport=self.transport,
            ) as client:
                response = await client.post(
                    agent_cancel_url(self.settings.agent_assignment_url),
                    json={"session_id": session_id},
                )
        except httpx.TransportError as error:
            print(
                "agent_cancellation_failed",
                {"error_type": type(error).__name__},
                flush=True,
            )
            return False
        return response.status_code < 400


def _log_assignment_retry(*, attempt: int, error_type: str) -> None:
    print(
        "agent_assignment_retry",
        {"completed_attempt": attempt, "error_type": error_type},
        flush=True,
    )
