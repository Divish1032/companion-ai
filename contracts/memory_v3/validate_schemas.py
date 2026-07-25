#!/usr/bin/env python3
"""Validate the Memory V3 JSON Schemas and representative envelopes."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from referencing import Registry, Resource


ROOT = Path(__file__).resolve().parent


def walk_refs(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "$ref" and isinstance(child, str):
                yield child
            yield from walk_refs(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_refs(child)


def observation() -> dict[str, Any]:
    return {
        "schema_version": 3,
        "candidate_id": "candidate_example001",
        "kind": "preference",
        "subject": {"entity_type": "user", "mention": "user"},
        "predicate": "support_style",
        "object": {"text": "Prefers listening before advice"},
        "evidence": [
            {
                "turn_id": "turn-001",
                "role": "user",
                "fragment": "Pehle bas meri baat suno, advice baad mein.",
            }
        ],
        "temporal": {"status": "current", "resolution_confidence": 0.95},
        "epistemic": {
            "explicitness": "explicit",
            "confidence": 0.98,
            "negated": False,
            "hypothetical": False,
            "quoted": False,
        },
        "utility": {
            "salience": 0.8,
            "future_utility": 0.9,
            "proactive_allowed": True,
            "confirmation_required": False,
        },
        "privacy": {
            "sensitivity": "normal",
            "durable_eligibility": "automatic",
            "reason": None,
        },
        "proposed_operation": "ADD",
    }


def model() -> dict[str, Any]:
    return {
        "provider": "example",
        "model": "example-model",
        "prompt_version": "memory-v3-test",
        "usage_source": "provider_reported",
        "input_tokens": 100,
        "output_tokens": 40,
    }


def semantic_atom() -> dict[str, Any]:
    return {
        "predicate": "support_style",
        "subject": {"entity_type": "user", "mention": "user"},
        "object_quote": "Pehle bas meri baat suno",
        "evidence": [
            {
                "turn_id": "turn-001",
                "quote": "Pehle bas meri baat suno, advice baad mein.",
            }
        ],
        "modality": "asserted",
        "explicitness": "explicit",
        "temporal_class": "current",
        "normalized_value": "listen before advice",
        "sensitivity_hint": "normal",
    }


def samples() -> dict[str, list[dict[str, Any]]]:
    candidate = observation()
    return {
        "memory_observation.schema.json": [candidate],
        "memory_semantic_atoms.schema.json": [
            {"atoms": [semantic_atom()], "no_atom_reason": None}
        ],
        "memory_compile_request.schema.json": [
            {
                "schema_version": 3,
                "job_id": "memory_compile_example001",
                "language": "hi-IN",
                "timezone": "Asia/Kolkata",
                "now_ms": 1784485800000,
                "turns": [
                    {
                        "turn_id": "turn-001",
                        "role": "user",
                        "text": "Pehle bas meri baat suno, advice baad mein.",
                        "status": "final",
                        "language": "hi-IN",
                        "script": "latin",
                        "stt_confidence": 0.96,
                        "stt_provider": "example",
                        "stt_model": "example-stt",
                        "created_at_ms": 1784485800000,
                    }
                ],
            }
        ],
        "memory_compile_response.schema.json": [
            {
                "schema_version": 3,
                "job_id": "memory_compile_example001",
                "contract_version": "memory_compile_v3_1",
                "candidates": [candidate],
                "no_memory_reason": None,
                "model": model(),
            }
        ],
        "memory_consolidation.schema.json": [
            {
                "schema_version": 3,
                "message_type": "request",
                "job_id": "memory_consolidate_example001",
                "contract_version": "memory_consolidation_adjudication_v3_1",
                "now_ms": 1784485800000,
                "timezone": "Asia/Kolkata",
                "items": [
                    {
                        "item_ref": "item_new_preference",
                        "kind": "observation",
                        "predicate": "support_style",
                        "statement": "Prefers listening before advice",
                        "temporal_status": "current",
                        "entity_type": None,
                        "normalized_alias": None,
                        "source_refs": ["source_new_preference"],
                    },
                    {
                        "item_ref": "item_current_preference",
                        "kind": "claim",
                        "predicate": "support_style",
                        "statement": "Prefers listening before advice",
                        "temporal_status": "current",
                        "entity_type": None,
                        "normalized_alias": None,
                        "source_refs": ["source_prior_preference"],
                    },
                ],
                "questions": [
                    {
                        "question_ref": "question_preference_equivalence",
                        "task": "semantic_equivalence",
                        "source_item_ref": "item_new_preference",
                        "candidate_item_refs": ["item_current_preference"],
                        "allowed_signals": ["exact_normalized_value"],
                    }
                ],
            },
            {
                "schema_version": 3,
                "message_type": "response",
                "job_id": "memory_consolidate_example001",
                "contract_version": "memory_consolidation_adjudication_v3_1",
                "decisions": [
                    {
                        "question_ref": "question_preference_equivalence",
                        "decision": "MATCH",
                        "selected_candidate_ref": "item_current_preference",
                        "signals": ["exact_normalized_value"],
                    }
                ],
                "model": model(),
            },
        ],
        "memory_context_request.schema.json": [
            {
                "schema_version": 3,
                "contract_version": "memory_context_v3",
                "request_sequence": 12,
                "session_id": "session-001",
                "turn_id": "turn-012",
                "query_text": "Maine interview ke baare mein kya bataya tha?",
                "language": "hi-IN",
                "created_at_ms": 1784485800000,
                "transcript_status": "final",
                "stt_confidence": 0.94,
                "stt_provider": "example",
                "stt_model": "example-stt",
                "budget": {
                    "max_memories": 6,
                    "max_chars": 2500,
                    "deadline_ms": 500,
                    "allow_deep_recall": True,
                },
            }
        ],
        "memory_brief.schema.json": [
            {
                "schema_version": 3,
                "contract_version": "memory_brief_v3",
                "request_sequence": 12,
                "turn_id": "turn-012",
                "semantic_resolved": True,
                "fallback_reason": None,
                "query_plan": {
                    "plan_id": "plan_example001",
                    "memory_needed": True,
                    "query_type": "episodic",
                    "explicit_recall": True,
                    "path": "deep",
                    "subjects": ["interview"],
                    "temporal_scope": "historical",
                    "candidate_kinds": ["episode", "open_thread"],
                },
                "response_policy": {
                    "language": "hi-IN",
                    "script": "latin",
                    "length": "brief",
                    "support_style": "validate_first",
                    "follow_up_style": "specific_question",
                    "proactive_memory_allowed": True,
                },
                "current_state": {
                    "topic": "job interview",
                    "affect": {"emotion": "anxiety", "intensity": 0.6, "confidence": 0.8},
                    "support_need": "validation",
                    "unresolved_thread_refs": ["thread-interview-001"],
                },
                "memories": [
                    {
                        "memory_id": "memory-episode-001",
                        "kind": "episode",
                        "statement": "The user had an interview scheduled for Monday.",
                        "temporal_status": "historical",
                        "confidence": 0.93,
                        "relevance_reason": "Direct answer to an explicit recall request.",
                        "use_mode": "EXPLICIT_RECALL",
                        "warnings": [],
                        "event_start_at_ms": 1784053800000,
                        "source_role": "user",
                    }
                ],
                "response_move": {
                    "act": "follow_up",
                    "question_recommended": True,
                    "instruction": "Recall the interview briefly, then ask how it went.",
                },
                "diagnostics": {
                    "candidate_count": 8,
                    "selected_count": 1,
                    "retrieval_ms": 34,
                    "selection_ms": 6,
                    "total_ms": 40,
                    "budget_truncated": False,
                },
            }
        ],
        "memory_usage_event.schema.json": [
            {
                "schema_version": 3,
                "event_id": "memory_usage_example001",
                "response_id": "response-012",
                "turn_id": "turn-012",
                "query_plan_id": "plan_example001",
                "created_at_ms": 1784485800500,
                "selected": [
                    {
                        "memory_id": "memory-episode-001",
                        "use_mode": "EXPLICIT_RECALL",
                        "retrieval_score": 0.94,
                    }
                ],
                "response_move": "follow_up",
                "explicit_feedback": None,
                "implicit_signals": ["topic_continuation"],
                "outcome": "unknown",
            }
        ],
    }


def main() -> int:
    schema_paths = sorted(ROOT.glob("*.schema.json"))
    if not schema_paths:
        print("No Memory V3 schemas found.", file=sys.stderr)
        return 1

    schemas: dict[str, dict[str, Any]] = {}
    ids: set[str] = set()
    errors: list[str] = []

    for path in schema_paths:
        try:
            schema = json.loads(path.read_text(encoding="ascii"))
            Draft202012Validator.check_schema(schema)
        except Exception as exc:  # Validation output must include the filename.
            errors.append(f"{path.name}: invalid schema: {exc}")
            continue

        schema_id = schema.get("$id")
        if not isinstance(schema_id, str) or not schema_id:
            errors.append(f"{path.name}: missing $id")
        elif schema_id in ids:
            errors.append(f"{path.name}: duplicate $id {schema_id}")
        else:
            ids.add(schema_id)

        for ref in walk_refs(schema):
            if ref.startswith("#") or "://" in ref:
                continue
            target = ref.split("#", 1)[0]
            if not (ROOT / target).is_file():
                errors.append(f"{path.name}: missing relative $ref target {target}")

        schemas[path.name] = schema

    registry = Registry()
    for schema in schemas.values():
        if isinstance(schema.get("$id"), str):
            registry = registry.with_resource(
                schema["$id"], Resource.from_contents(schema)
            )

    expected_samples = samples()
    missing_samples = set(schemas) - set(expected_samples)
    if missing_samples:
        errors.append(
            "Missing representative samples for: " + ", ".join(sorted(missing_samples))
        )

    for filename, instances in expected_samples.items():
        schema = schemas.get(filename)
        if schema is None:
            errors.append(f"{filename}: schema expected by validator is missing")
            continue
        validator = Draft202012Validator(schema, registry=registry)
        for index, instance in enumerate(instances, start=1):
            for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
                location = "/".join(str(part) for part in error.absolute_path) or "<root>"
                errors.append(
                    f"{filename} sample {index} at {location}: {error.message}"
                )

    if errors:
        print("Memory V3 contract validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    instance_count = sum(len(items) for items in expected_samples.values())
    print(
        f"Memory V3 contract validation passed: {len(schemas)} schemas, "
        f"{instance_count} representative envelopes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
