#!/usr/bin/env python3
"""Validate the offline Memory V3 Task 4 transition catalog and reference output."""

from __future__ import annotations

import argparse
import json
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker

from consolidation_reference import POLICY_VERSION, build_projections


REPO_ROOT = Path(__file__).resolve().parents[2]
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
DEFAULT_CATALOG = EVAL_ROOT / "fixtures" / "consolidation_transition_cases.json"
CATALOG_SCHEMA = EVAL_ROOT / "schemas" / "consolidation_transition_catalog.schema.json"
RELATION_PREDICATES = {
    "has_relationship",
    "profile_association",
    "relationship_association",
    "episode_association",
}
EPISODE_PREDICATES = {"experienced_event", "event_outcome", "causes_stress"}
THREAD_PREDICATES = {"open_thread", "assistant_commitment"}


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be a JSON object")
    return value


def schema_errors(catalog: dict[str, Any]) -> list[str]:
    schema = load_json(CATALOG_SCHEMA)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors: list[str] = []
    for error in sorted(validator.iter_errors(catalog), key=lambda item: list(item.path)):
        location = "/".join(str(part) for part in error.absolute_path) or "<root>"
        errors.append(f"{CATALOG_SCHEMA.name} at {location}: {error.message}")
    return errors


def semantic_errors(catalog: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    case_ids: set[str] = set()
    global_observation_ids: set[str] = set()
    for case in catalog.get("cases", []):
        case_id = str(case.get("id", "<missing>"))
        prefix = f"case {case_id}"
        if case_id in case_ids:
            errors.append(f"{prefix}: duplicate case ID")
        case_ids.add(case_id)
        observations = case.get("observations", [])
        by_id: dict[str, dict[str, Any]] = {}
        for observation in observations:
            observation_id = observation["observation_id"]
            if observation_id in by_id:
                errors.append(f"{prefix}: duplicate observation ID {observation_id}")
            if observation_id in global_observation_ids:
                errors.append(f"{prefix}: observation ID is not globally unique {observation_id}")
            global_observation_ids.add(observation_id)
            by_id[observation_id] = observation
            predicate = observation["predicate"]
            has_target = observation["target_entity"] is not None
            if (predicate in RELATION_PREDICATES) != has_target:
                errors.append(f"{prefix}: {observation_id} target entity does not match predicate")
            if predicate == "assistant_commitment" and observation["kind"] != "assistant_commitment":
                errors.append(f"{prefix}: {observation_id} assistant commitment has wrong kind")
            if observation["observed_at_ms"] > case["now_ms"]:
                errors.append(f"{prefix}: {observation_id} occurs after now_ms")

        link_ids: set[str] = set()
        linked_sources: set[tuple[str, str]] = set()
        for link in case.get("accepted_links", []):
            link_id = link["link_id"]
            if link_id in link_ids:
                errors.append(f"{prefix}: duplicate link ID {link_id}")
            link_ids.add(link_id)
            source = by_id.get(link["source_observation_id"])
            target = by_id.get(link["target_observation_id"])
            if source is None or target is None:
                errors.append(f"{prefix}: {link_id} cites an unknown observation")
                continue
            source_key = (link["link_type"], source["observation_id"])
            if source_key in linked_sources:
                errors.append(f"{prefix}: {link_id} gives one source multiple {link['link_type']} targets")
            linked_sources.add(source_key)
            if source["observation_id"] == target["observation_id"]:
                errors.append(f"{prefix}: {link_id} cannot self-link")
            if target["observed_at_ms"] > source["observed_at_ms"]:
                errors.append(f"{prefix}: {link_id} target must precede its source")
            if source["admission"] not in {"auto_admit", "confirmed"} or target["admission"] not in {"auto_admit", "confirmed"}:
                errors.append(f"{prefix}: {link_id} cannot use unprojectable observations")
            if link["link_type"] == "entity_equivalent":
                if source["target_entity"] is None or target["target_entity"] is None:
                    errors.append(f"{prefix}: {link_id} entity link lacks target entities")
                elif source["target_entity"]["entity_type"] != target["target_entity"]["entity_type"]:
                    errors.append(f"{prefix}: {link_id} crosses entity types")
                if link["signal"] not in {"exact_normalized_value", "explicit_alias", "explicit_relationship"}:
                    errors.append(f"{prefix}: {link_id} uses an unsafe entity signal")
            elif link["link_type"] == "episode_equivalent":
                if source["predicate"] not in EPISODE_PREDICATES or target["predicate"] not in EPISODE_PREDICATES:
                    errors.append(f"{prefix}: {link_id} must connect episode observations")
                if link["signal"] not in {"exact_normalized_value", "shared_event_time", "shared_participant"}:
                    errors.append(f"{prefix}: {link_id} uses an unsafe episode signal")
            elif link["link_type"] == "thread_outcome":
                if source["predicate"] != "event_outcome" or target["predicate"] not in THREAD_PREDICATES:
                    errors.append(f"{prefix}: {link_id} must connect an outcome to a thread")
                if link["signal"] != "explicit_outcome_reference":
                    errors.append(f"{prefix}: {link_id} lacks explicit outcome evidence")

        expected_ids = set(case.get("expected", {}).get("ignored_observation_ids", []))
        if not expected_ids.issubset(by_id):
            errors.append(f"{prefix}: ignored observations cite unknown IDs")
    return errors


def _assertion_error(
    assertion: dict[str, Any],
    snapshot: dict[str, Any],
) -> str | None:
    assertion_type = assertion["type"]
    if assertion_type == "claim":
        matches = [
            row
            for row in snapshot["claims"]
            if row["predicate"] == assertion["predicate"]
            and row["value"] == assertion["value"]
            and row["status"] == assertion["status"]
            and row["supporting_observation_ids"] == sorted(assertion["supporting_observation_ids"])
            and row["contradicting_observation_ids"] == sorted(assertion["contradicting_observation_ids"])
        ]
    elif assertion_type == "episode":
        matches = [
            row
            for row in snapshot["episodes"]
            if row["primary_observation_id"] == assertion["primary_observation_id"]
            and row["resolution_state"] == assertion["resolution_state"]
            and row["outcome"] == assertion["outcome"]
            and row["supporting_observation_ids"] == sorted(assertion["supporting_observation_ids"])
        ]
    elif assertion_type == "thread":
        matches = [
            row
            for row in snapshot["threads"]
            if row["primary_observation_id"] == assertion["primary_observation_id"]
            and row["status"] == assertion["status"]
            and row["supporting_observation_ids"] == sorted(assertion["supporting_observation_ids"])
        ]
    elif assertion_type == "entity_count":
        count = sum(
            assertion["normalized_alias"] in row["aliases"]
            for row in snapshot["entities"]
        )
        matches = [count] if count == assertion["count"] else []
    elif assertion_type in {"entity_same", "entity_distinct"}:
        entity_ids = {
            snapshot["entity_by_observation"].get(observation_id)
            for observation_id in assertion["observation_ids"]
        }
        matches = [entity_ids] if (
            None not in entity_ids
            and (
                len(entity_ids) == 1
                if assertion_type == "entity_same"
                else len(entity_ids) == len(assertion["observation_ids"])
            )
        ) else []
    elif assertion_type == "relation":
        matches = [
            row
            for row in snapshot["relations"]
            if row["family"] == assertion["family"]
            and row["target_alias"] == assertion["target_alias"]
            and row["supporting_observation_ids"] == sorted(assertion["supporting_observation_ids"])
        ]
    elif assertion_type == "reflection":
        matches = [
            row
            for row in snapshot["reflections"]
            if row["pattern_value"] == assertion["pattern_value"]
            and row["status"] == assertion["status"]
            and row["supporting_observation_ids"] == sorted(assertion["supporting_observation_ids"])
        ]
    elif assertion_type == "reflection_absent":
        matches = [True] if all(
            row["pattern_value"] != assertion["pattern_value"]
            for row in snapshot["reflections"]
        ) else []
    else:
        return f"unknown assertion type {assertion_type}"
    return None if matches else f"assertion failed: {json.dumps(assertion, sort_keys=True)}"


def transition_errors(catalog: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for case in catalog.get("cases", []):
        prefix = f"case {case['id']}"
        try:
            snapshot = build_projections(case)
            reversed_case = deepcopy(case)
            reversed_case["observations"].reverse()
            reversed_case["accepted_links"].reverse()
            replay = build_projections(reversed_case)
        except (KeyError, TypeError, ValueError) as exc:
            errors.append(f"{prefix}: reference build failed: {exc}")
            continue
        if snapshot != replay:
            errors.append(f"{prefix}: output changes when input order changes")
        expected = case["expected"]
        actual_counts = {
            key: len(snapshot[key])
            for key in ("claims", "episodes", "threads", "entities", "relations", "reflections")
        }
        if actual_counts != expected["counts"]:
            errors.append(f"{prefix}: counts {actual_counts} != {expected['counts']}")
        if snapshot["ignored_observation_ids"] != sorted(expected["ignored_observation_ids"]):
            errors.append(f"{prefix}: ignored observation set differs")
        for assertion in expected["assertions"]:
            error = _assertion_error(assertion, snapshot)
            if error:
                errors.append(f"{prefix}: {error}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    args = parser.parse_args()
    try:
        catalog = load_json(args.catalog.resolve())
        errors = schema_errors(catalog)
        if not errors:
            errors.extend(semantic_errors(catalog))
        if not errors:
            errors.extend(transition_errors(catalog))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if catalog.get("policy_version") != POLICY_VERSION:
        errors.append("catalog policy_version does not match the reference engine")
    if errors:
        print("Memory V3 consolidation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        f"Memory V3 consolidation reference passed: {len(catalog['cases'])} "
        f"development cases, policy={POLICY_VERSION}, runtime_writes=0."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
