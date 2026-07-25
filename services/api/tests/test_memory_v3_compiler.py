from __future__ import annotations

import asyncio
import json

from fastapi.testclient import TestClient
import httpx
import pytest

from app.main import app, get_memory_v3_compiler, settings
from app.memory_v3_compiler import (
    MemoryCompileRequestV3,
    MemoryCompileResultV3,
    MemoryObservationV3,
    MemorySemanticAtomV3,
    MemoryV3CompilerUnavailable,
    OpenAICompatibleMemoryV3Compiler,
    construct_memory_observations,
    filter_grounded_observations,
)


class FakeCompiler:
    def __init__(self, candidates: list[MemoryObservationV3] | None = None) -> None:
        self.candidates = candidates if candidates is not None else [_observation()]

    async def compile(self, request: MemoryCompileRequestV3) -> MemoryCompileResultV3:
        return MemoryCompileResultV3(
            candidates=self.candidates,
            no_memory_reason=None if self.candidates else "no durable detail",
            provider="fake",
            model="compiler-test",
            prompt_version="memory_semantic_atoms_v3_1",
            usage_input_tokens=120,
            usage_output_tokens=40,
        )


class FailingCompiler:
    async def compile(self, request: MemoryCompileRequestV3) -> MemoryCompileResultV3:
        raise MemoryV3CompilerUnavailable("offline")


def _request_body() -> dict[str, object]:
    return {
        "schema_version": 3,
        "job_id": "memory_compile_testjob01",
        "language": "hi-IN",
        "timezone": "Asia/Kolkata",
        "now_ms": 100,
        "turns": [
            {
                "turn_id": "turn_name",
                "role": "user",
                "text": "Mera naam Aditi hai.",
                "status": "final",
                "language": "hi-IN",
                "script": "latin",
                "stt_confidence": 0.99,
                "stt_provider": "synthetic",
                "stt_model": "fixture",
                "created_at_ms": 10,
            },
            {
                "turn_id": "turn_name_reply",
                "role": "assistant",
                "text": "Aditi, aapse milkar achha laga.",
                "status": "final",
                "language": "hi-IN",
                "script": "latin",
                "created_at_ms": 11,
            },
        ],
    }


def _observation(**updates: object) -> MemoryObservationV3:
    payload: dict[str, object] = {
        "schema_version": 3,
        "candidate_id": "candidate_name_12345678",
        "kind": "profile",
        "subject": {"entity_type": "user", "mention": "user"},
        "predicate": "preferred_name",
        "object": {"text": "Aditi", "normalized_value": "Aditi"},
        "evidence": [
            {
                "turn_id": "turn_name",
                "role": "user",
                "fragment": "Aditi",
                "start_char": 10,
                "end_char": 15,
            }
        ],
        "temporal": {
            "status": "current",
            "resolution_confidence": 1.0,
        },
        "epistemic": {
            "explicitness": "explicit",
            "confidence": 0.99,
            "negated": False,
            "hypothetical": False,
            "quoted": False,
        },
        "utility": {
            "salience": 0.9,
            "future_utility": 0.95,
            "proactive_allowed": False,
            "confirmation_required": False,
        },
        "privacy": {
            "sensitivity": "normal",
            "durable_eligibility": "automatic",
        },
        "proposed_operation": "ADD",
    }
    payload.update(updates)
    return MemoryObservationV3.model_validate(payload)


def _atom(**updates: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "predicate": "preferred_name",
        "subject": {"entity_type": "user", "mention": "user"},
        "object_quote": "Aditi",
        "evidence": [{"turn_id": "turn_name", "quote": "Mera naam Aditi hai."}],
        "modality": "asserted",
        "explicitness": "explicit",
        "temporal_class": "current",
        "normalized_value": "Aditi",
        "sensitivity_hint": "normal",
    }
    payload.update(updates)
    return payload


def _post_compile(
    body: dict[str, object],
    compiler: FakeCompiler | FailingCompiler,
):
    app.dependency_overrides[get_memory_v3_compiler] = lambda: compiler
    try:
        return TestClient(app).post("/v1/memory/compile", json=body)
    finally:
        app.dependency_overrides.clear()


def test_compile_endpoint_returns_the_versioned_untrusted_envelope(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_v3_compiler", True)

    response = _post_compile(_request_body(), FakeCompiler())

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 3
    assert body["job_id"] == "memory_compile_testjob01"
    assert body["contract_version"] == "memory_compile_v3_1"
    assert body["candidates"][0]["predicate"] == "preferred_name"
    assert body["candidates"][0]["evidence"][0]["fragment"] == "Aditi"
    assert body["model"] == {
        "provider": "fake",
        "model": "compiler-test",
        "prompt_version": "memory_semantic_atoms_v3_1",
        "usage_source": "provider_reported",
        "input_tokens": 120,
        "output_tokens": 40,
    }
    assert "target_id" not in json.dumps(body)


def test_compile_endpoint_accepts_an_empty_successful_result(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_v3_compiler", True)

    response = _post_compile(_request_body(), FakeCompiler([]))

    assert response.status_code == 200
    assert response.json()["candidates"] == []
    assert response.json()["no_memory_reason"] == "no durable detail"


def test_compile_endpoint_is_disabled_and_fails_closed(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_v3_compiler", False)
    disabled = _post_compile(_request_body(), FakeCompiler())
    assert disabled.status_code == 503
    assert disabled.json()["detail"]["code"] == "memory_v3_compiler_disabled"

    monkeypatch.setattr(settings, "enable_memory_v3_compiler", True)
    unavailable = _post_compile(_request_body(), FailingCompiler())
    assert unavailable.status_code == 503
    assert unavailable.json()["detail"]["code"] == "memory_v3_compiler_unavailable"
    assert unavailable.json()["detail"]["stage"] == "offline"


def test_compile_request_is_strict_bounded_and_role_aware(monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr(settings, "enable_memory_v3_compiler", True)
    unknown = _request_body()
    unknown["raw_transcript"] = "must not be accepted"
    assert _post_compile(unknown, FakeCompiler()).status_code == 422

    duplicate = _request_body()
    duplicate["turns"] = [
        duplicate["turns"][0],  # type: ignore[index]
        duplicate["turns"][0],  # type: ignore[index]
    ]
    assert _post_compile(duplicate, FakeCompiler()).status_code == 422

    too_many = _request_body()
    too_many["turns"] = [
        {
            "turn_id": f"turn_{index}",
            "role": "user",
            "text": "bounded",
            "status": "final",
            "created_at_ms": index,
        }
        for index in range(13)
    ]
    assert _post_compile(too_many, FakeCompiler()).status_code == 422

    explicit_null = _request_body()
    explicit_null["turns"][0]["script"] = None  # type: ignore[index]
    assert _post_compile(explicit_null, FakeCompiler()).status_code == 422


def test_server_grounding_rejects_wrong_fragment_and_object() -> None:
    request = MemoryCompileRequestV3.model_validate(_request_body())
    valid = _observation()
    wrong_fragment = _observation(
        candidate_id="candidate_wrong_fragment",
        evidence=[
            {
                "turn_id": "turn_name",
                "role": "user",
                "fragment": "Rahul",
            }
        ],
    )
    ungrounded_object = _observation(
        candidate_id="candidate_ungrounded_object",
        object={"text": "Aditi Sharma", "normalized_value": "Aditi Sharma"},
    )
    mismatched_ontology = _observation(
        candidate_id="candidate_bad_ontology",
        kind="open_thread",
    )

    assert filter_grounded_observations(
        request,
        [wrong_fragment, valid, ungrounded_object, mismatched_ontology],
    ) == [valid]


def test_semantic_atoms_are_constructed_with_local_authority() -> None:
    request = MemoryCompileRequestV3.model_validate(_request_body())
    atom = MemorySemanticAtomV3.model_validate(_atom())

    first, first_outcomes = construct_memory_observations(request, [atom])
    second, _ = construct_memory_observations(request, [atom])

    assert first == second
    assert first_outcomes[0].disposition == "constructed"
    candidate = first[0]
    assert candidate.kind == "profile"
    assert candidate.proposed_operation == "ADD"
    assert candidate.evidence[0].start_char == 0
    assert candidate.evidence[0].end_char == len("Mera naam Aditi hai.")
    assert candidate.epistemic.confidence == 0.95
    assert candidate.object.normalized_value == "Aditi"
    assert candidate.utility.proactive_allowed is False
    assert candidate.privacy.durable_eligibility == "automatic"


def test_semantic_constructor_records_modality_and_privacy_rejections() -> None:
    request = MemoryCompileRequestV3.model_validate(_request_body())
    hypothetical = MemorySemanticAtomV3.model_validate(_atom(modality="hypothetical"))
    secret = MemorySemanticAtomV3.model_validate(_atom(sensitivity_hint="forbidden"))

    candidates, outcomes = construct_memory_observations(
        request,
        [hypothetical, secret],
    )

    assert candidates == []
    assert [item.reason for item in outcomes] == [
        "unsupported_modality_hypothetical",
        "local_forbidden_content",
    ]


def test_constructor_does_not_store_arbitrary_model_normalization() -> None:
    request = MemoryCompileRequestV3.model_validate(_request_body())
    atom = MemorySemanticAtomV3.model_validate(_atom(normalized_value="Aditi is a doctor"))

    candidates, _ = construct_memory_observations(request, [atom])

    assert candidates[0].object.normalized_value == "Aditi"


def test_constructor_canonicalizes_support_style_deterministically() -> None:
    body = _request_body()
    body["turns"] = [
        {
            "turn_id": "turn_support",
            "role": "user",
            "text": "Solutions mat do; pehle bas validate karna.",
            "status": "final",
            "language": "hi-IN",
            "script": "latin",
            "stt_confidence": 0.99,
            "created_at_ms": 10,
        }
    ]
    atom = MemorySemanticAtomV3.model_validate(
        {
            "predicate": "support_style",
            "subject": {"entity_type": "user", "mention": "user"},
            "object_quote": "Solutions mat do; pehle bas validate karna.",
            "evidence": [
                {
                    "turn_id": "turn_support",
                    "quote": "Solutions mat do; pehle bas validate karna.",
                }
            ],
            "modality": "asserted",
            "explicitness": "explicit",
            "temporal_class": "current",
            "normalized_value": "invented model prose is ignored",
            "sensitivity_hint": "normal",
        }
    )

    candidates, _ = construct_memory_observations(
        MemoryCompileRequestV3.model_validate(body),
        [atom],
    )

    assert candidates[0].object.normalized_value == "validate first; no solutions"


def test_observation_model_allows_only_atomic_add() -> None:
    payload = _observation().model_dump()
    payload["proposed_operation"] = "SUPERSEDE"

    with pytest.raises(ValueError):
        MemoryObservationV3.model_validate(payload)


def test_observation_model_blocks_assistant_to_user_contamination() -> None:
    with pytest.raises(ValueError):
        _observation(
            evidence=[
                {
                    "turn_id": "turn_name",
                    "role": "assistant",
                    "fragment": "Aditi",
                }
            ]
        )


def test_openai_compatible_compiler_uses_strict_stateless_schema() -> None:
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured.update(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "usage": {"prompt_tokens": 321, "completion_tokens": 123},
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "atoms": [_atom()],
                                    "no_atom_reason": None,
                                }
                            )
                        }
                    }
                ],
            },
        )

    compiler = OpenAICompatibleMemoryV3Compiler(
        base_url="https://compiler.test/v1",
        api_key="secret",
        model="compiler-test",
        timeout_seconds=1,
        transport=httpx.MockTransport(handler),
    )

    result = asyncio.run(compiler.compile(MemoryCompileRequestV3.model_validate(_request_body())))

    assert len(result.candidates) == 1
    assert result.usage_input_tokens == 321
    assert result.usage_output_tokens == 123
    assert captured["temperature"] == 0
    assert captured["reasoning_effort"] is None
    assert captured["max_tokens"] == 4096
    assert captured["n"] == 1
    assert captured["seed"] == 7
    assert "store" not in captured
    assert captured["response_format"]["json_schema"]["strict"] is True  # type: ignore[index]
    schema = captured["response_format"]["json_schema"]["schema"]  # type: ignore[index]
    assert set(schema["required"]) == set(schema["properties"])
    atom_schema = schema["$defs"]["MemorySemanticAtomV3"]
    assert set(atom_schema["required"]) == set(atom_schema["properties"])
    assert "default" not in json.dumps(schema)
    prompt = captured["messages"][0]["content"]  # type: ignore[index]
    assert "phone" in prompt
    assert "owns durable truth" in prompt
    assert "Copy object_quote" in prompt
    assert "negated, hypothetical" in prompt
    assert "profile_association" in prompt
    assert "Do not generate candidate IDs" in prompt
    assert "candidate_example" not in prompt
    assert result.semantic_atoms[0].predicate == "preferred_name"
    assert result.construction_outcomes[0].disposition == "constructed"


def test_openai_compatible_compiler_fails_closed_on_invalid_output() -> None:
    compiler = OpenAICompatibleMemoryV3Compiler(
        base_url="https://compiler.test/v1",
        api_key="secret",
        model="compiler-test",
        timeout_seconds=1,
        transport=httpx.MockTransport(
            lambda _: httpx.Response(
                200,
                json={"choices": [{"message": {"content": "not-json"}}]},
            )
        ),
    )

    with pytest.raises(MemoryV3CompilerUnavailable):
        asyncio.run(compiler.compile(MemoryCompileRequestV3.model_validate(_request_body())))


def test_deepseek_compiler_uses_non_thinking_json_object_profile() -> None:
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured.update(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "usage": {"prompt_tokens": 321, "completion_tokens": 123},
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "atoms": [_atom()],
                                    "no_atom_reason": None,
                                }
                            )
                        }
                    }
                ],
            },
        )

    compiler = OpenAICompatibleMemoryV3Compiler(
        base_url="https://api.deepseek.com",
        api_key="secret",
        model="deepseek-v4-flash",
        timeout_seconds=1,
        provider="deepseek",
        request_profile="deepseek_json_object",
        transport=httpx.MockTransport(handler),
    )

    result = asyncio.run(compiler.compile(MemoryCompileRequestV3.model_validate(_request_body())))

    assert len(result.candidates) == 1
    assert captured["thinking"] == {"type": "disabled"}
    assert captured["response_format"] == {"type": "json_object"}
    assert "reasoning_effort" not in captured
    assert "n" not in captured
    assert "seed" not in captured
    prompt = captured["messages"][0]["content"]  # type: ignore[index]
    assert "json" in prompt.casefold()
    assert "semantic memory atoms" in prompt
    assert "Exact output JSON Schema" in prompt
    assert '"temporal_class"' in prompt


def test_deepseek_compiler_thinking_profile_omits_sampling_parameters() -> None:
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
                                    "atoms": [],
                                    "no_atom_reason": "ordinary conversation",
                                }
                            )
                        }
                    }
                ]
            },
        )

    compiler = OpenAICompatibleMemoryV3Compiler(
        base_url="https://api.deepseek.com",
        api_key="secret",
        model="deepseek-v4-flash",
        timeout_seconds=1,
        request_profile="deepseek_json_object_thinking",
        transport=httpx.MockTransport(handler),
    )

    result = asyncio.run(compiler.compile(MemoryCompileRequestV3.model_validate(_request_body())))

    assert result.candidates == []
    assert captured["thinking"] == {"type": "enabled"}
    assert captured["reasoning_effort"] == "high"
    assert captured["response_format"] == {"type": "json_object"}
    assert "temperature" not in captured
    assert "n" not in captured
    assert "seed" not in captured
