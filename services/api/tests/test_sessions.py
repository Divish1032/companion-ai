from pathlib import Path

from fastapi.testclient import TestClient
from livekit import api

from app import main
from app.agent_assignment import AgentAssignmentFailed
from app.session_store import SessionStore


def test_create_session_accepts_bounded_context_and_token(tmp_path: Path) -> None:
    assigner = _FakeAgentAssigner()
    client, store = _client(tmp_path, assigner=assigner)
    main.settings.livekit_api_key = "devkey"
    main.settings.livekit_api_secret = "secret"
    main.settings.livekit_url = "ws://localhost:7880"
    main.settings.max_recent_context_messages = 2
    main.settings.max_memory_context_blocks = 1

    response = client.post(
        "/v1/session",
        json={
            "device_id": "anon_test_device",
            "recent_transcript_context": [
                _context_item("turn_1", "first"),
                _context_item("turn_2", "second"),
                _context_item("turn_3", "third", role="assistant"),
            ],
            "memory_context": [
                _memory_item("memory_1", "first memory"),
                _memory_item("memory_2", "second memory"),
            ],
        },
    )

    assert response.status_code == 200
    body = response.json()
    session = store.get_active_session(
        session_id=body["session_id"],
        device_id="anon_test_device",
    )
    assert session is not None
    assert session.recent_context() == {"recent_turns": [], "memory_blocks": []}
    assigned_context = assigner.assigned_contexts[0]
    assert isinstance(assigned_context, dict)
    assert len(assigned_context["recent_turns"]) == 2
    assert len(assigned_context["memory_blocks"]) == 1
    assert "second" in str(assigned_context)
    assert "third" in str(assigned_context)
    assert "second memory" in str(assigned_context)
    assert assigner.assigned_session_ids == [body["session_id"]]

    token_response = client.post(
        "/v1/livekit/token",
        json={"device_id": "anon_test_device", "session_id": body["session_id"]},
    )

    assert token_response.status_code == 200
    token_body = token_response.json()
    claims = api.TokenVerifier("devkey", "secret").verify(token_body["token"])
    assert claims.video.room == body["room_name"]
    assert claims.video.room_join is True
    assert claims.video.can_publish is True
    assert claims.video.can_publish_data is True
    assert claims.video.can_subscribe is True


def test_one_active_session_per_device_until_end(tmp_path: Path) -> None:
    client, _store = _client(tmp_path)

    first = client.post("/v1/session", json={"device_id": "anon_test_device"})
    assert first.status_code == 200

    second = client.post("/v1/session", json={"device_id": "anon_test_device"})
    assert second.status_code == 409
    assert second.json()["detail"]["code"] == "active_session_exists"

    ended = client.post(
        "/v1/session/end",
        json={
            "device_id": "anon_test_device",
            "session_id": first.json()["session_id"],
        },
    )
    assert ended.status_code == 200
    assert ended.json()["ended"] is True

    third = client.post("/v1/session", json={"device_id": "anon_test_device"})
    assert third.status_code == 200
    assert third.json()["session_id"] != first.json()["session_id"]


def test_token_requires_active_matching_session(tmp_path: Path) -> None:
    client, _store = _client(tmp_path)
    main.settings.livekit_api_key = "devkey"
    main.settings.livekit_api_secret = "secret"

    session = client.post("/v1/session", json={"device_id": "anon_test_device"}).json()
    response = client.post(
        "/v1/livekit/token",
        json={"device_id": "anon_other_device", "session_id": session["session_id"]},
    )

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "session_not_found"


def test_session_counter_is_durable(tmp_path: Path) -> None:
    store_path = tmp_path / "sessions.sqlite"
    first_store = SessionStore(str(store_path))
    first_store.create_session(
        device_id="anon_test_device",
        max_session_seconds=1200,
        recent_context=[],
        session_create_limit_per_day=50,
    )

    second_store = SessionStore(str(store_path))
    try:
        second_store.create_session(
            device_id="anon_test_device",
            max_session_seconds=1200,
            recent_context=[],
            session_create_limit_per_day=50,
        )
    except Exception as error:
        assert error.__class__.__name__ == "ActiveSessionExists"
    else:
        raise AssertionError("expected persisted active session to block duplicate")


def test_agent_assignment_failure_returns_503_and_ends_session(tmp_path: Path) -> None:
    client, store = _client(tmp_path, assigner=_FailingAgentAssigner())

    response = client.post("/v1/session", json={"device_id": "anon_test_device"})

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "agent_assignment_failed"
    active = store.get_active_session(
        session_id="missing_after_failure",
        device_id="anon_test_device",
    )
    assert active is None

    retry = client.post("/v1/session", json={"device_id": "anon_test_device"})
    assert retry.status_code == 503


def test_stateless_embeddings_and_rerank_do_not_require_session(tmp_path: Path) -> None:
    client, _store = _client(tmp_path)

    embedding_response = client.post(
        "/v1/embeddings",
        json={"texts": ["office manager pressure"], "dimension": 64},
    )
    assert embedding_response.status_code == 200
    embedding_body = embedding_response.json()
    assert embedding_body["dimension"] == 64
    assert len(embedding_body["embeddings"]) == 1
    assert len(embedding_body["embeddings"][0]) == 64

    rerank_response = client.post(
        "/v1/rerank",
        json={
            "query": "bad day at office",
            "candidates": [
                {"id": "work", "text": "office manager pressure stress"},
                {"id": "food", "text": "chai preference"},
            ],
        },
    )
    assert rerank_response.status_code == 200
    assert rerank_response.json()["results"][0]["id"] == "work"


def _client(
    tmp_path: Path,
    *,
    assigner: object | None = None,
) -> tuple[TestClient, SessionStore]:
    store = SessionStore(str(tmp_path / "sessions.sqlite"))
    main.app.dependency_overrides[main.get_store] = lambda: store
    main.app.dependency_overrides[main.get_agent_assigner] = lambda: (
        assigner or _FakeAgentAssigner()
    )
    main.settings.max_recent_context_messages = 12
    main.settings.max_memory_context_blocks = 6
    main.settings.session_create_limit_per_day = 50
    main.settings.token_mint_limit_per_session = 20
    main.settings.max_session_seconds = 1200
    client = TestClient(main.app)
    return client, store


def _context_item(turn_id: str, text: str, *, role: str = "user") -> dict[str, object]:
    return {
        "turn_id": turn_id,
        "role": role,
        "text": text,
        "created_at_ms": 1,
    }


def _memory_item(memory_id: str, content: str) -> dict[str, object]:
    return {
        "memory_id": memory_id,
        "kind": "semantic",
        "label": "safe_preference",
        "content": content,
        "canonical_text": content,
        "sensitivity": "normal",
        "temporal_status": "current",
        "receipt_state": "implicit",
        "source_turn_ids": ["turn_1"],
        "source_role": "user",
        "transcript_status": "final",
        "stt_confidence": 0.99,
        "created_at_ms": 1,
        "updated_at_ms": 2,
        "last_used_at_ms": None,
        "confidence_score": 0.8,
        "importance_score": 0.7,
    }


class _FakeAgentAssigner:
    def __init__(self) -> None:
        self.assigned_session_ids: list[str] = []
        self.assigned_contexts: list[dict[str, object]] = []

    async def assign(self, *, session) -> None:  # noqa: ANN001
        self.assigned_session_ids.append(session.session_id)
        self.assigned_contexts.append(session.recent_context())


class _FailingAgentAssigner:
    async def assign(self, *, session) -> None:  # noqa: ANN001
        raise AgentAssignmentFailed("boom")
