from __future__ import annotations

import httpx

from app.config import Settings
from app.session_store import SessionRecord


class AgentAssignmentFailed(Exception):
    pass


class AgentAssigner:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def assign(self, *, session: SessionRecord) -> None:
        if not self.settings.agent_assignment_url:
            return

        try:
            async with httpx.AsyncClient(
                timeout=self.settings.agent_assignment_timeout_seconds
            ) as client:
                response = await client.post(
                    self.settings.agent_assignment_url,
                    json={
                        "session_id": session.session_id,
                        "room_name": session.room_name,
                        "expires_at_ms": session.expires_at_ms,
                        "recent_context": session.recent_context(),
                    },
                )
        except httpx.HTTPError as error:
            raise AgentAssignmentFailed(str(error)) from error

        if response.status_code >= 400:
            raise AgentAssignmentFailed(response.text)
