from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4


@dataclass(frozen=True)
class SessionRecord:
    session_id: str
    device_id: str
    room_name: str
    created_at_ms: int
    expires_at_ms: int
    status: str
    recent_context_json: str

    def recent_context(self) -> dict[str, object]:
        data = json.loads(self.recent_context_json)
        if isinstance(data, dict):
            recent_turns = data.get("recent_turns")
            memory_blocks = data.get("memory_blocks")
            return {
                "recent_turns": recent_turns if isinstance(recent_turns, list) else [],
                "memory_blocks": memory_blocks if isinstance(memory_blocks, list) else [],
            }
        if not isinstance(data, list):
            return {"recent_turns": [], "memory_blocks": []}
        return {
            "recent_turns": [item for item in data if isinstance(item, dict)],
            "memory_blocks": [],
        }


class SessionStore:
    def __init__(self, path: str) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA journal_mode = WAL")
        return connection

    def _init_schema(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS sessions (
                    session_id TEXT PRIMARY KEY,
                    device_id TEXT NOT NULL,
                    room_name TEXT NOT NULL,
                    created_at_ms INTEGER NOT NULL,
                    expires_at_ms INTEGER NOT NULL,
                    status TEXT NOT NULL,
                    recent_context_json TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_sessions_device_status
                ON sessions(device_id, status);

                CREATE TABLE IF NOT EXISTS counters (
                    bucket TEXT NOT NULL,
                    key TEXT NOT NULL,
                    value INTEGER NOT NULL,
                    updated_at_ms INTEGER NOT NULL,
                    PRIMARY KEY(bucket, key)
                );
                """
            )

    def create_session(
        self,
        *,
        device_id: str,
        max_session_seconds: int,
        recent_context: dict[str, object] | list[dict[str, object]],
        session_create_limit_per_day: int,
    ) -> SessionRecord:
        now = datetime.now(UTC)
        now_ms = _to_ms(now)
        expires_at_ms = _to_ms(now + timedelta(seconds=max_session_seconds))
        day_key = now.strftime("%Y-%m-%d")

        with self._connect() as connection:
            self._expire_old_sessions(connection, now_ms)
            active = connection.execute(
                """
                SELECT * FROM sessions
                WHERE device_id = ? AND status = 'active' AND expires_at_ms > ?
                LIMIT 1
                """,
                (device_id, now_ms),
            ).fetchone()
            if active is not None:
                raise ActiveSessionExists(_row_to_session(active))

            counter_value = self._increment_counter(
                connection,
                bucket="session_create_per_device_day",
                key=f"{device_id}:{day_key}",
                now_ms=now_ms,
            )
            if counter_value > session_create_limit_per_day:
                raise RateLimitExceeded("session creation limit reached")

            session_id = f"session_{uuid4().hex}"
            room_name = f"companion_{session_id}"
            record = SessionRecord(
                session_id=session_id,
                device_id=device_id,
                room_name=room_name,
                created_at_ms=now_ms,
                expires_at_ms=expires_at_ms,
                status="active",
                recent_context_json=json.dumps(recent_context, separators=(",", ":")),
            )
            connection.execute(
                """
                INSERT INTO sessions (
                    session_id, device_id, room_name, created_at_ms,
                    expires_at_ms, status, recent_context_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.session_id,
                    record.device_id,
                    record.room_name,
                    record.created_at_ms,
                    record.expires_at_ms,
                    record.status,
                    record.recent_context_json,
                ),
            )
            return record

    def get_active_session(self, *, session_id: str, device_id: str) -> SessionRecord | None:
        now_ms = _to_ms(datetime.now(UTC))
        with self._connect() as connection:
            self._expire_old_sessions(connection, now_ms)
            row = connection.execute(
                """
                SELECT * FROM sessions
                WHERE session_id = ? AND device_id = ? AND status = 'active'
                AND expires_at_ms > ?
                LIMIT 1
                """,
                (session_id, device_id, now_ms),
            ).fetchone()
            return _row_to_session(row) if row is not None else None

    def record_token_mint(self, *, session_id: str, limit: int) -> None:
        now_ms = _to_ms(datetime.now(UTC))
        with self._connect() as connection:
            value = self._increment_counter(
                connection,
                bucket="token_mint_per_session",
                key=session_id,
                now_ms=now_ms,
            )
            if value > limit:
                raise RateLimitExceeded("token minting limit reached")

    def end_session(self, *, session_id: str, device_id: str) -> bool:
        with self._connect() as connection:
            cursor = connection.execute(
                """
                UPDATE sessions
                SET status = 'ended', recent_context_json = '{"recent_turns":[],"memory_blocks":[]}'
                WHERE session_id = ? AND device_id = ? AND status = 'active'
                """,
                (session_id, device_id),
            )
            return cursor.rowcount > 0

    def clear_session_context(self, *, session_id: str) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                UPDATE sessions
                SET recent_context_json = '{"recent_turns":[],"memory_blocks":[]}'
                WHERE session_id = ?
                """,
                (session_id,),
            )

    def _expire_old_sessions(self, connection: sqlite3.Connection, now_ms: int) -> None:
        connection.execute(
            """
            UPDATE sessions
            SET status = 'expired', recent_context_json = '{"recent_turns":[],"memory_blocks":[]}'
            WHERE status = 'active' AND expires_at_ms <= ?
            """,
            (now_ms,),
        )

    def _increment_counter(
        self,
        connection: sqlite3.Connection,
        *,
        bucket: str,
        key: str,
        now_ms: int,
    ) -> int:
        connection.execute(
            """
            INSERT INTO counters(bucket, key, value, updated_at_ms)
            VALUES (?, ?, 1, ?)
            ON CONFLICT(bucket, key) DO UPDATE
            SET value = value + 1, updated_at_ms = excluded.updated_at_ms
            """,
            (bucket, key, now_ms),
        )
        row = connection.execute(
            "SELECT value FROM counters WHERE bucket = ? AND key = ?",
            (bucket, key),
        ).fetchone()
        return int(row["value"])


class ActiveSessionExists(Exception):
    def __init__(self, session: SessionRecord) -> None:
        super().__init__("device already has an active session")
        self.session = session


class RateLimitExceeded(Exception):
    pass


def _row_to_session(row: sqlite3.Row) -> SessionRecord:
    return SessionRecord(
        session_id=str(row["session_id"]),
        device_id=str(row["device_id"]),
        room_name=str(row["room_name"]),
        created_at_ms=int(row["created_at_ms"]),
        expires_at_ms=int(row["expires_at_ms"]),
        status=str(row["status"]),
        recent_context_json=str(row["recent_context_json"]),
    )


def _to_ms(value: datetime) -> int:
    return int(value.timestamp() * 1000)
