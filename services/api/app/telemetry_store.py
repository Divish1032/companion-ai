"""Content-free telemetry persistence and percentile summaries.

SQLite is deliberately the local-development backend.  The schema and ingest
contract are Postgres-compatible so production Compose can point this service at
its managed telemetry database without changing clients.
"""

from __future__ import annotations

import json
import sqlite3
import time
from pathlib import Path


FORBIDDEN_CONTENT_KEYS = {
    "text", "content", "message", "query", "prompt", "transcript", "memory", "vector", "audio",
    "device_id", "authorization", "api_key",
}


class TelemetryValidationError(ValueError):
    pass


def validate_redacted(value: object, *, key: str = "") -> None:
    if key.casefold() in FORBIDDEN_CONTENT_KEYS:
        raise TelemetryValidationError(f"forbidden telemetry key: {key}")
    if isinstance(value, dict):
        for child_key, child_value in value.items():
            if not isinstance(child_key, str):
                raise TelemetryValidationError("telemetry keys must be strings")
            validate_redacted(child_value, key=child_key)
    elif isinstance(value, list):
        for item in value:
            validate_redacted(item)
    elif not isinstance(value, str | int | float | bool | type(None)):
        raise TelemetryValidationError("unsupported telemetry value")


class TelemetryStore:
    def __init__(self, path: str) -> None:
        self.path = path
        self.is_postgres = path.startswith("postgresql://") or path.startswith("postgres://")
        if not self.is_postgres:
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        if self.is_postgres:
            import psycopg
            return psycopg.connect(self.path)  # type: ignore[return-value]
        return sqlite3.connect(self.path)

    def _initialize(self) -> None:
        with self._connect() as connection:
            statement = (
                """
                CREATE TABLE IF NOT EXISTS telemetry_turns (
                  session_id TEXT NOT NULL,
                  turn_id TEXT NOT NULL,
                  received_at_ms INTEGER NOT NULL,
                  terminal_outcome TEXT NOT NULL,
                  total_cost_micro_inr INTEGER NOT NULL,
                  cost_complete INTEGER NOT NULL,
                  payload_json TEXT NOT NULL,
                  PRIMARY KEY (session_id, turn_id)
                )
                """
            )
            connection.execute(statement)
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS telemetry_operation_records (
                  record_id TEXT PRIMARY KEY, session_id TEXT NOT NULL,
                  turn_id TEXT NOT NULL, received_at_ms INTEGER NOT NULL,
                  terminal_outcome TEXT NOT NULL, total_cost_micro_inr INTEGER NOT NULL,
                  cost_complete INTEGER NOT NULL, payload_json TEXT NOT NULL
                )
                """
            )

    def ingest(self, envelope: dict[str, object]) -> None:
        validate_redacted(envelope)
        if envelope.get("schema") != "telemetry_envelope_v1":
            raise TelemetryValidationError("unsupported telemetry schema")
        session_id, turn_id = envelope.get("session_id"), envelope.get("turn_id")
        terminal_outcome = envelope.get("terminal_outcome")
        total = envelope.get("total_cost_micro_inr")
        complete = envelope.get("cost_complete")
        if not isinstance(session_id, str) or not isinstance(turn_id, str):
            raise TelemetryValidationError("session_id and turn_id are required")
        if not isinstance(terminal_outcome, str) or not isinstance(total, int) or not isinstance(complete, bool):
            raise TelemetryValidationError("terminal telemetry fields are invalid")
        with self._connect() as connection:
            # Operation records are append-only. A delayed memory judgement is
            # a second immutable observation, never an overwrite of a voice turn.
            record_id = str(envelope.get("record_id") or f"{session_id}:{turn_id}:{envelope.get('timestamps_ms', {}).get('terminal', 0)}")
            statement = """INSERT INTO telemetry_operation_records
              (record_id, session_id, turn_id, received_at_ms, terminal_outcome, total_cost_micro_inr,
               cost_complete, payload_json) VALUES ({params}) ON CONFLICT (record_id) DO NOTHING"""
            values = (record_id, session_id, turn_id, int(time.time() * 1000), terminal_outcome, total, int(complete),
                      json.dumps(envelope, sort_keys=True, separators=(",", ":")))
            if self.is_postgres:
                statement = statement.format(params="%s, %s, %s, %s, %s, %s, %s, %s")
            else:
                statement = statement.format(params="?, ?, ?, ?, ?, ?, ?, ?")
            connection.execute(statement, values)

    def session_summary(self, session_id: str) -> dict[str, object]:
        with self._connect() as connection:
            placeholder = "%s" if self.is_postgres else "?"
            rows = connection.execute(
                f"SELECT total_cost_micro_inr, cost_complete, payload_json FROM telemetry_operation_records WHERE session_id = {placeholder}",
                (session_id,),
            ).fetchall()
        server_values = []
        playback_reports = 0
        duration_samples: dict[str, list[int]] = {}
        for _, _, payload in rows:
            decoded = json.loads(payload)
            timestamps = decoded.get("timestamps_ms", {})
            durations = decoded.get("durations_ms", {})
            if isinstance(durations, dict):
                for name, value in durations.items():
                    if isinstance(name, str) and isinstance(value, int) and value >= 0:
                        duration_samples.setdefault(name, []).append(value)
            if isinstance(timestamps, dict):
                start, end = timestamps.get("server_endpoint_commit"), timestamps.get("tts_first_published")
                if isinstance(start, int) and isinstance(end, int) and end >= start:
                    server_values.append(end - start)
                if isinstance(timestamps.get("client_first_playback_timestamp_ms"), int):
                    playback_reports += 1
        return {
            "session_id": session_id,
            "turn_count": len(rows),
            "total_cost_micro_inr": sum(int(row[0]) for row in rows),
            "cost_complete": all(bool(row[1]) for row in rows),
            "endpoint_to_first_published_ms": percentile_summary(server_values),
            "client_playback_report_coverage": playback_reports / len(rows) if rows else 0.0,
            "operation_latency_ms": {
                name: percentile_summary(values) for name, values in sorted(duration_samples.items())
            },
        }

    def purge_before(self, cutoff_ms: int) -> int:
        with self._connect() as connection:
            placeholder = "%s" if self.is_postgres else "?"
            cursor = connection.execute(f"DELETE FROM telemetry_operation_records WHERE received_at_ms < {placeholder}", (cutoff_ms,))
            return cursor.rowcount


def percentile_summary(values: list[int]) -> dict[str, object]:
    ordered = sorted(values)
    if not ordered:
        return {"sample_count": 0, "p50_ms": None, "p95_ms": None, "p95_sufficient": False}
    def percentile(percent: int) -> int:
        index = max((len(ordered) * percent + 99) // 100 - 1, 0)
        return ordered[index]
    return {
        "sample_count": len(ordered),
        "p50_ms": percentile(50),
        "p95_ms": percentile(95),
        "p95_sufficient": len(ordered) >= 20,
    }
