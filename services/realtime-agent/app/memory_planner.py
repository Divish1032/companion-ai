from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Protocol

import httpx

from app.memory_router import MemoryRoutingDecision


class MemoryPlanner(Protocol):
    async def plan(self, text: str) -> MemoryRoutingDecision | None: ...


@dataclass(frozen=True)
class HttpMemoryPlanner:
    base_url: str
    model: str
    timeout_seconds: float

    async def plan(self, text: str) -> MemoryRoutingDecision | None:
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                response = await client.post(
                    f"{self.base_url.rstrip('/')}/v1/memory-plan",
                    json={"text": text, "model": self.model},
                )
            if response.status_code != 200:
                return None
            return _parse_plan(response.json())
        except (httpx.HTTPError, ValueError, TypeError):
            return None


def _parse_plan(payload: object) -> MemoryRoutingDecision | None:
    if not isinstance(payload, dict):
        return None
    allowed_routes = {"none", "core_profile", "semantic", "episodic", "summary", "broad_safe"}
    need_memory = payload.get("need_memory")
    route = payload.get("route")
    top_k = payload.get("top_k")
    if (
        not isinstance(need_memory, bool)
        or route not in allowed_routes
        or not isinstance(top_k, int)
        or not 0 <= top_k <= 6
        or (not need_memory and (route != "none" or top_k != 0))
        or (need_memory and (route == "none" or top_k == 0))
    ):
        return None
    typed_route: Literal["none", "core_profile", "semantic", "episodic", "summary", "broad_safe"] = route
    return MemoryRoutingDecision(
        route=typed_route,
        confidence=0.6,
        reason="planner_low_confidence_route",
        max_blocks=top_k,
    )
