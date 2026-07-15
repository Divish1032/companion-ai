from __future__ import annotations

import asyncio
import json

from fastapi.testclient import TestClient
import httpx
import pytest
from pydantic import ValidationError

from app.main import app, get_memory_candidate_extractor, settings
from app.memory_extraction import (
    MemoryCandidate,
    MemoryExtractionRequest,
    MemoryExtractionUnavailable,
    OpenAICompatibleMemoryCandidateExtractor,
    filter_source_safe_candidates,
)


class FakeExtractor:
    async def extract(self, request: MemoryExtractionRequest) -> list[MemoryCandidate]:
        return [
            MemoryCandidate(
                candidate_kind="open_thread",
                subject="user",
                predicate="has_interview",
                object_text="Interview on Friday",
                event_start_at_ms=None,
                event_end_at_ms=None,
                temporal_status="future",
                explicitness="explicit",
                confidence=0.93,
                future_utility=0.9,
                sensitivity="normal",
                source_turn_ids=[request.turns[0].turn_id],
                evidence_role="user",
                suggested_action="ADD",
                follow_up_allowed=True,
                proactive_allowed=False,
            )
        ]


def test_memory_candidates_are_strict_and_source_bounded(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", True)
    app.dependency_overrides[get_memory_candidate_extractor] = lambda: FakeExtractor()
    try:
        response = TestClient(app).post(
            "/v1/memory-candidates",
            json={
                "job_id": "job-1",
                "extraction_version": "v1",
                "language": "hi-IN",
                "turns": [
                    {
                        "turn_id": "turn-1",
                        "role": "user",
                        "text": "Friday ko mera interview hai, baad mein poochna.",
                        "created_at_ms": 1,
                        "status": "final",
                        "confidence": 0.96,
                    }
                ],
            },
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    body = response.json()
    assert body["job_id"] == "job-1"
    assert body["candidates"][0]["candidate_kind"] == "open_thread"
    assert body["candidates"][0]["source_turn_ids"] == ["turn-1"]


def test_memory_candidates_endpoint_is_disabled_by_default(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", False)
    response = TestClient(app).post(
        "/v1/memory-candidates",
        json={
            "job_id": "job-1",
            "extraction_version": "v1",
            "turns": [
                {
                    "turn_id": "turn-1",
                    "role": "user",
                    "text": "A complete user utterance",
                    "created_at_ms": 1,
                }
            ],
        },
    )
    assert response.status_code == 503


def test_duplicate_turn_role_pair_is_rejected() -> None:
    response = TestClient(app).post(
        "/v1/memory-candidates",
        json={
            "job_id": "job-1",
            "extraction_version": "v1",
            "turns": [
                {"turn_id": "t1", "role": "user", "text": "first turn", "created_at_ms": 1},
                {"turn_id": "t1", "role": "user", "text": "duplicate", "created_at_ms": 2},
            ],
        },
    )
    assert response.status_code == 422


def test_extraction_request_rejects_unknown_fields() -> None:
    response = TestClient(app).post(
        "/v1/memory-candidates",
        json={
            "job_id": "job-1",
            "extraction_version": "v1",
            "unexpected": "not allowed",
            "turns": [
                {
                    "turn_id": "t1",
                    "role": "user",
                    "text": "complete turn",
                    "created_at_ms": 1,
                }
            ],
        },
    )
    assert response.status_code == 422


def test_openai_compatible_extractor_uses_strict_schema_and_parses_candidate() -> None:
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured.update(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "candidates": [
                                        {
                                            "candidate_kind": "episode",
                                            "subject": "user",
                                            "predicate": "attended_interview",
                                            "object_text": "design interview",
                                            "event_start_at_ms": None,
                                            "event_end_at_ms": None,
                                            "temporal_status": "past",
                                            "explicitness": "explicit",
                                            "confidence": 0.9,
                                            "future_utility": 0.8,
                                            "sensitivity": "normal",
                                            "source_turn_ids": ["t1"],
                                            "evidence_role": "user",
                                            "suggested_action": "ADD",
                                            "follow_up_allowed": False,
                                            "proactive_allowed": False,
                                        }
                                    ]
                                }
                            )
                        }
                    }
                ]
            },
        )

    extractor = OpenAICompatibleMemoryCandidateExtractor(
        base_url="https://model.test/v1",
        api_key="secret",
        model="extractor-test",
        timeout_seconds=1,
        transport=httpx.MockTransport(handler),
    )
    candidates = asyncio.run(extractor.extract(_request()))

    assert candidates[0].candidate_kind == "episode"
    assert captured["temperature"] == 0
    assert captured["store"] is False
    assert captured["response_format"]["json_schema"]["strict"] is True
    schema = captured["response_format"]["json_schema"]["schema"]
    assert schema["additionalProperties"] is False
    candidate_schema = schema["$defs"]["MemoryCandidate"]
    assert candidate_schema["additionalProperties"] is False
    assert set(candidate_schema["required"]) == set(candidate_schema["properties"])


def test_openai_compatible_extractor_fails_closed_on_non_json_output() -> None:
    extractor = OpenAICompatibleMemoryCandidateExtractor(
        base_url="https://model.test/v1",
        api_key="secret",
        model="extractor-test",
        timeout_seconds=1,
        transport=httpx.MockTransport(
            lambda _: httpx.Response(
                200,
                json={"choices": [{"message": {"content": "not-json"}}]},
            )
        ),
    )

    with pytest.raises(MemoryExtractionUnavailable):
        asyncio.run(extractor.extract(_request()))


def test_extraction_request_rejects_duplicate_turn_id_across_roles() -> None:
    with pytest.raises(ValidationError):
        MemoryExtractionRequest.model_validate(
            {
                "job_id": "duplicate-turn",
                "extraction_version": "v1",
                "turns": [
                    {
                        "turn_id": "same-id",
                        "role": "user",
                        "text": "Mera interview hua.",
                        "created_at_ms": 1,
                    },
                    {
                        "turn_id": "same-id",
                        "role": "assistant",
                        "text": "Interview ke baare mein batao.",
                        "created_at_ms": 2,
                    },
                ],
            }
        )


def test_server_filter_rejects_sensitive_and_role_inconsistent_candidates() -> None:
    request = MemoryExtractionRequest.model_validate(
        {
            "job_id": "filter-1",
            "extraction_version": "v1",
            "turns": [
                {
                    "turn_id": "u1",
                    "role": "user",
                    "text": "Scripted test OTP 000000 hai.",
                    "created_at_ms": 1,
                },
                {
                    "turn_id": "a1",
                    "role": "assistant",
                    "text": "I will ask about your walk next week.",
                    "created_at_ms": 2,
                },
            ],
        }
    )
    invalid_commitment = _candidate(
        kind="assistant_commitment",
        source_turn_ids=["u1"],
        evidence_role="mixed",
    )
    sensitive_episode = _candidate(
        kind="episode",
        source_turn_ids=["u1"],
        evidence_role="user",
    )
    valid_commitment = _candidate(
        kind="assistant_commitment",
        source_turn_ids=["a1"],
        evidence_role="assistant",
    )

    safe = filter_source_safe_candidates(
        request,
        [invalid_commitment, sensitive_episode, valid_commitment],
    )

    assert safe == [valid_commitment]


def _request() -> MemoryExtractionRequest:
    return MemoryExtractionRequest.model_validate(
        {
            "job_id": "job-1",
            "extraction_version": "v1",
            "turns": [
                {
                    "turn_id": "t1",
                    "role": "user",
                    "text": "design interview hua",
                    "created_at_ms": 1,
                }
            ],
        }
    )


def _candidate(
    *,
    kind: str,
    source_turn_ids: list[str],
    evidence_role: str,
) -> MemoryCandidate:
    return MemoryCandidate.model_validate(
        {
            "candidate_kind": kind,
            "subject": "assistant",
            "predicate": "will_follow_up",
            "object_text": "Ask about the walk next week",
            "event_start_at_ms": None,
            "event_end_at_ms": None,
            "temporal_status": "future",
            "explicitness": "assistant_only",
            "confidence": 0.9,
            "future_utility": 0.8,
            "sensitivity": "normal",
            "source_turn_ids": source_turn_ids,
            "evidence_role": evidence_role,
            "suggested_action": "ADD",
            "follow_up_allowed": True,
            "proactive_allowed": False,
        }
    )
