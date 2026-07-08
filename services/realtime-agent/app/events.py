from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from itertools import count
from typing import Any


@dataclass
class EventSequencer:
    session_id: str
    _counter: count = field(default_factory=lambda: count(1))

    def next(
        self,
        *,
        event_type: str,
        turn_id: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return {
            **(payload or {}),
            "type": event_type,
            "sequence": next(self._counter),
            "session_id": self.session_id,
            **({"turn_id": turn_id} if turn_id else {}),
            "schema_version": 1,
            "timestamp_ms": int(time.time() * 1000),
        }

    def encode(
        self,
        *,
        event_type: str,
        turn_id: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> bytes:
        return json.dumps(
            self.next(event_type=event_type, turn_id=turn_id, payload=payload),
            separators=(",", ":"),
        ).encode("utf-8")


class TurnIdFactory:
    def __init__(self, session_id: str) -> None:
        self._session_id = session_id
        self._counter = count(1)

    def next(self) -> str:
        return f"{self._session_id}:turn:{next(self._counter):04d}"
