from __future__ import annotations

import asyncio
import json

from fastapi.testclient import TestClient
import httpx
import pytest

from app.main import app, get_memory_candidate_extractor, settings
from app.memory_extraction import (
    MemoryCandidate,
    MemoryExtractionRequest,
    MemoryExtractionResult,
    MemoryExtractionUnavailable,
    OpenAICompatibleMemoryCandidateExtractor,
    build_judge_decision,
    filter_source_safe_candidates,
)


class FakeExtractor:
    def __init__(
        self,
        *,
        suggested_action: str = "ADD",
        usage_input_tokens: int | None = None,
        usage_output_tokens: int | None = None,
    ) -> None:
        self.suggested_action = suggested_action
        self.usage_input_tokens = usage_input_tokens
        self.usage_output_tokens = usage_output_tokens

    async def extract(self, request: MemoryExtractionRequest) -> MemoryExtractionResult:
        return MemoryExtractionResult(
            candidates=[
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
                    suggested_action=self.suggested_action,
                    follow_up_allowed=True,
                    proactive_allowed=False,
                )
            ],
            usage_input_tokens=self.usage_input_tokens,
            usage_output_tokens=self.usage_output_tokens,
        )


def _judge_request_body() -> dict[str, object]:
    return {
        "job_id": "job-1",
        "extraction_version": "v1",
        "judge_contract_version": "memory_judge_v1",
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
    }


def _post_judge(body: dict[str, object], extractor: FakeExtractor | None = None):
    if extractor is not None:
        app.dependency_overrides[get_memory_candidate_extractor] = lambda: extractor
    try:
        return TestClient(app).post("/v1/memory-judge", json=body)
    finally:
        app.dependency_overrides.clear()


def test_memory_judge_returns_typed_untrusted_decisions(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", True)
    response = _post_judge(_judge_request_body(), FakeExtractor())
    assert response.status_code == 200
    body = response.json()
    assert body["job_id"] == "job-1"
    assert body["contract_version"] == "memory_judge_v1"
    assert body["cost"] == {
        "source": "unknown",
        "input_tokens": 0,
        "output_tokens": 0,
        "estimated_micro_inr": 0,
    }
    decision = body["decisions"][0]
    assert decision["action"] == "accept"
    assert decision["decision_id"].startswith("mjd_")
    assert len(decision["decision_id"]) >= 16
    assert decision["proposal"]["kind"] == "open_thread"
    assert decision["proposal"]["source_turn_ids"] == ["turn-1"]
    # No local/remote claim ID travels on the wire; targets resolve on-device.
    assert "target_id" not in decision["proposal"]
    assert "memory_id" not in decision["proposal"]


def test_memory_judge_decision_ids_are_deterministic_for_replay(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", True)
    first = _post_judge(_judge_request_body(), FakeExtractor()).json()
    second = _post_judge(_judge_request_body(), FakeExtractor()).json()
    assert first["decisions"][0]["decision_id"] == second["decisions"][0]["decision_id"]


def test_memory_judge_maps_noop_to_reject_decision(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", True)
    response = _post_judge(
        _judge_request_body(), FakeExtractor(suggested_action="NOOP")
    )
    assert response.status_code == 200
    assert response.json()["decisions"][0]["action"] == "reject"


def test_memory_judge_reports_provider_usage_when_rates_are_reviewed(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", True)
    monkeypatch.setattr(settings, "memory_judge_input_micro_inr_per_million_tokens", 2_500_000)
    monkeypatch.setattr(settings, "memory_judge_output_micro_inr_per_million_tokens", 10_000_000)
    response = _post_judge(
        _judge_request_body(),
        FakeExtractor(usage_input_tokens=1_000, usage_output_tokens=200),
    )
    assert response.json()["cost"] == {
        "source": "provider_reported",
        "input_tokens": 1_000,
        "output_tokens": 200,
        "estimated_micro_inr": 4_500,
    }


def test_memory_judge_usage_without_reviewed_rate_stays_unknown(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", True)
    response = _post_judge(
        _judge_request_body(),
        FakeExtractor(usage_input_tokens=1_000, usage_output_tokens=200),
    )
    cost = response.json()["cost"]
    assert cost["source"] == "unknown"
    assert cost["input_tokens"] == 1_000
    assert cost["output_tokens"] == 200
    assert cost["estimated_micro_inr"] == 0


def test_memory_judge_is_disabled_by_default(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_extraction", False)
    response = TestClient(app).post("/v1/memory-judge", json=_judge_request_body())
    assert response.status_code == 503


def test_legacy_memory_candidates_route_is_gone() -> None:
    response = TestClient(app).post("/v1/memory-candidates", json=_judge_request_body())
    assert response.status_code == 404


def test_duplicate_turn_role_pair_is_rejected() -> None:
    response = TestClient(app).post(
        "/v1/memory-judge",
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


def test_judge_window_is_bounded_to_eight_messages() -> None:
    response = TestClient(app).post(
        "/v1/memory-judge",
        json={
            "job_id": "job-1",
            "extraction_version": "v1",
            "turns": [
                {
                    "turn_id": f"t{index}",
                    "role": "user",
                    "text": f"turn number {index}",
                    "created_at_ms": index,
                }
                for index in range(9)
            ],
        },
    )
    assert response.status_code == 422


def test_extraction_request_rejects_unknown_fields() -> None:
    response = TestClient(app).post(
        "/v1/memory-judge",
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


def test_validation_failure_logs_field_paths_only(capsys) -> None:  # noqa: ANN001
    body = _judge_request_body()
    body["unexpected"] = "mera naam Rahul hai"
    response = TestClient(app).post("/v1/memory-judge", json=body)
    assert response.status_code == 422
    captured = capsys.readouterr().out
    assert "mera naam Rahul hai" not in captured
    assert "api_request_validation_error" in captured


def test_build_judge_decision_maps_actions_and_hashes_content() -> None:
    candidate = _candidate(kind="episode", source_turn_ids=["t1"], evidence_role="user")
    supersede = candidate.model_copy(update={"suggested_action": "SUPERSEDE"})
    expire = candidate.model_copy(update={"suggested_action": "EXPIRE"})
    assert build_judge_decision("job", candidate).action == "accept"
    assert build_judge_decision("job", supersede).action == "supersede"
    assert build_judge_decision("job", expire).action == "update"
    assert (
        build_judge_decision("job", candidate).decision_id
        != build_judge_decision("job-other", candidate).decision_id
    )


def test_openai_compatible_extractor_uses_strict_schema_and_parses_candidate() -> None:
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured.update(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "usage": {"prompt_tokens": 812, "completion_tokens": 96},
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
                ],
            },
        )

    extractor = OpenAICompatibleMemoryCandidateExtractor(
        base_url="https://model.test/v1",
        api_key="secret",
        model="extractor-test",
        timeout_seconds=1,
        transport=httpx.MockTransport(handler),
    )
    result = asyncio.run(extractor.extract(_request()))

    assert result.candidates[0].candidate_kind == "episode"
    assert result.usage_input_tokens == 812
    assert result.usage_output_tokens == 96
    assert captured["temperature"] == 0
    assert captured["store"] is False
    system_prompt = captured["messages"][0]["content"]
    assert "Be conservative" in system_prompt
    assert "reject by omitting the candidate" in system_prompt
    assert "Never propose\nsensitive or high-risk facts" in system_prompt.replace("\r\n", "\n")
    assert "never prove a user fact" in system_prompt
    assert "completed personal milestone or recent experience" in system_prompt
    assert "Do not invent an exact date" in system_prompt
    assert "never cite an assistant question" in system_prompt
    assert "suggested_action must be ADD" in system_prompt
    assert captured["response_format"]["json_schema"]["strict"] is True
    schema = captured["response_format"]["json_schema"]["schema"]
    assert schema["additionalProperties"] is False
    candidate_schema = schema["$defs"]["MemoryCandidate"]
    assert candidate_schema["additionalProperties"] is False
    assert set(candidate_schema["required"]) == set(candidate_schema["properties"])


def test_openai_compatible_extractor_reports_missing_usage_as_none() -> None:
    extractor = OpenAICompatibleMemoryCandidateExtractor(
        base_url="https://model.test/v1",
        api_key="secret",
        model="extractor-test",
        timeout_seconds=1,
        transport=httpx.MockTransport(
            lambda _: httpx.Response(
                200,
                json={"choices": [{"message": {"content": json.dumps({"candidates": []})}}]},
            )
        ),
    )
    result = asyncio.run(extractor.extract(_request()))
    assert result.candidates == []
    assert result.usage_input_tokens is None
    assert result.usage_output_tokens is None


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


def test_extraction_request_accepts_user_assistant_pair_for_one_turn() -> None:
    request = MemoryExtractionRequest.model_validate(
        {
            "job_id": "paired-turn",
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

    assert len(request.turns) == 2


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


def test_server_filter_keeps_user_evidence_when_turn_id_is_shared_with_assistant() -> None:
    # Regression: a voice turn's user message and assistant reply share one
    # turn ID. The filter must not collapse the pair into the assistant
    # message and silently drop legitimate user-evidence candidates.
    request = MemoryExtractionRequest.model_validate(
        {
            "job_id": "filter-paired-turn",
            "extraction_version": "v1",
            "turns": [
                {
                    "turn_id": "turn-11",
                    "role": "user",
                    "text": "नहीं मेरा नाम अमित है",
                    "created_at_ms": 1,
                },
                {
                    "turn_id": "turn-11",
                    "role": "assistant",
                    "text": "ओह, तो आपका नाम अमित है!",
                    "created_at_ms": 2,
                },
            ],
        }
    )
    candidate = MemoryCandidate.model_validate(
        {
            "candidate_kind": "profile",
            "subject": "user",
            "predicate": "preferred_name",
            "object_text": "अमित",
            "event_start_at_ms": None,
            "event_end_at_ms": None,
            "temporal_status": "current",
            "explicitness": "explicit",
            "confidence": 0.92,
            "future_utility": 0.8,
            "sensitivity": "normal",
            "source_turn_ids": ["turn-11"],
            "evidence_role": "user",
            "suggested_action": "ADD",
            "follow_up_allowed": False,
            "proactive_allowed": False,
        }
    )

    assert filter_source_safe_candidates(request, [candidate]) == [candidate]


def test_server_filter_rejects_assistant_citation_claimed_as_user_evidence() -> None:
    request = MemoryExtractionRequest.model_validate(
        {
            "job_id": "filter-provenance",
            "extraction_version": "v1",
            "turns": [
                {
                    "turn_id": "u1",
                    "role": "user",
                    "text": "Mera design interview hua tha.",
                    "created_at_ms": 1,
                },
                {
                    "turn_id": "a1",
                    "role": "assistant",
                    "text": "Interview kaisa gaya?",
                    "created_at_ms": 2,
                },
            ],
        }
    )
    invalid = _candidate(
        kind="episode",
        source_turn_ids=["u1", "a1"],
        evidence_role="user",
    ).model_copy(update={"explicitness": "explicit"})

    assert filter_source_safe_candidates(request, [invalid]) == []


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
