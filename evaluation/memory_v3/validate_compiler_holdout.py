#!/usr/bin/env python3
"""Validate blind Task 3.2 compiler holdout fixtures and their frozen boundary."""

from __future__ import annotations

import argparse
import json
import re
import string
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker

from verify_compiler_freeze import DEFAULT_FREEZE, verify_freeze


REPO_ROOT = Path(__file__).resolve().parents[2]
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
DEFAULT_CATALOG = EVAL_ROOT / "fixtures" / "compiler_holdout_catalog.template.json"
DEFAULT_DEVELOPMENT_CATALOG = EVAL_ROOT / "fixtures" / "task1_core_scenarios.json"
HOLDOUT_SCHEMA = EVAL_ROOT / "schemas" / "compiler_holdout_catalog.schema.json"
DEVA_RE = re.compile(r"[\u0900-\u097f]")
LATIN_RE = re.compile(r"[A-Za-z]")
REQUIRED_HARD_GATES = {
    "provenance",
    "grounding",
    "privacy",
    "sensitivity",
    "assistant_contamination",
    "prompt_injection",
    "crisis_bypass",
    "temporal",
    "entity_separation",
}


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be a JSON object")
    return value


def schema_errors(instance: dict[str, Any]) -> list[str]:
    schema = load_json(HOLDOUT_SCHEMA)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors: list[str] = []
    for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
        location = "/".join(str(part) for part in error.absolute_path) or "<root>"
        errors.append(f"{HOLDOUT_SCHEMA.name} at {location}: {error.message}")
    return errors


def inferred_script(text: str) -> str:
    has_devanagari = DEVA_RE.search(text) is not None
    has_latin = LATIN_RE.search(text) is not None
    if has_devanagari and has_latin:
        return "mixed"
    if has_devanagari:
        return "devanagari"
    return "latin"


def normalized_turn(text: str) -> str:
    punctuation = string.punctuation + "।॥“”‘’…"
    collapsed = " ".join(text.casefold().translate(str.maketrans("", "", punctuation)).split())
    return collapsed


def _development_content(catalog: dict[str, Any]) -> tuple[set[str], set[str]]:
    ids: set[str] = set()
    turns: set[str] = set()
    for scenario in catalog.get("scenarios", []):
        ids.add(str(scenario.get("id", "")))
        for session in scenario.get("sessions", []):
            for turn in session.get("turns", []):
                normalized = normalized_turn(str(turn.get("text", "")))
                if normalized:
                    turns.add(normalized)
    return ids, turns


def semantic_errors(
    catalog: dict[str, Any],
    development_catalog: dict[str, Any],
    *,
    release_gate: bool,
) -> list[str]:
    errors: list[str] = []
    development_ids, development_turns = _development_content(development_catalog)
    scenario_ids: set[str] = set()
    global_session_ids: set[str] = set()
    global_turn_ids: set[str] = set()
    global_expectation_ids: set[str] = set()
    covered_gates: set[str] = set()
    author_id = catalog.get("authoring_protocol", {}).get("author_id")

    for scenario in catalog.get("scenarios", []):
        scenario_id = str(scenario.get("id", "<missing>"))
        prefix = f"scenario {scenario_id}"
        if scenario_id in scenario_ids:
            errors.append(f"{prefix}: duplicate scenario ID")
        scenario_ids.add(scenario_id)
        if scenario_id in development_ids:
            errors.append(f"{prefix}: scenario ID overlaps the development catalog")
        gates = set(scenario.get("hard_gates", []))
        covered_gates.update(gates)
        if scenario.get("priority") == "P0" and not gates:
            errors.append(f"{prefix}: P0 scenario must name at least one hard gate")

        review = scenario.get("language_review", {})
        if review.get("status") == "approved":
            if not review.get("reviewer_id") or not review.get("reviewed_at"):
                errors.append(f"{prefix}: approved review lacks reviewer or timestamp")
            if review.get("reviewer_id") == author_id:
                errors.append(f"{prefix}: author cannot approve their own holdout wording")
        if release_gate and (
            review.get("status") != "approved"
            or review.get("naturalness") != "natural"
            or review.get("semantic_alignment") != "aligned"
        ):
            errors.append(f"{prefix}: release gate requires an independent natural/aligned approval")

        turns: dict[str, dict[str, Any]] = {}
        previous_session_start = -1
        for session in scenario.get("sessions", []):
            session_id = str(session.get("session_id", "<missing>"))
            if session_id in global_session_ids:
                errors.append(f"{prefix}: duplicate global session ID {session_id}")
            global_session_ids.add(session_id)
            session_turns = session.get("turns", [])
            if session_turns:
                start = int(session_turns[0].get("created_at_ms", 0))
                if start <= previous_session_start:
                    errors.append(f"{prefix}: sessions are not chronologically ordered")
                previous_session_start = start
            previous_turn_time = -1
            for turn in session_turns:
                turn_id = str(turn.get("turn_id", "<missing>"))
                if turn_id in global_turn_ids:
                    errors.append(f"{prefix}: duplicate global turn ID {turn_id}")
                global_turn_ids.add(turn_id)
                turns[turn_id] = turn
                created_at = int(turn.get("created_at_ms", 0))
                if created_at <= previous_turn_time:
                    errors.append(f"{prefix}: turn times are not increasing in {session_id}")
                previous_turn_time = created_at
                if turn.get("script") != inferred_script(str(turn.get("text", ""))):
                    errors.append(f"{prefix}: {turn_id} declares the wrong script")
                normalized = normalized_turn(str(turn.get("text", "")))
                if normalized in development_turns:
                    errors.append(f"{prefix}: {turn_id} exactly overlaps development wording")
                if turn.get("role") == "assistant":
                    if any(
                        turn.get(field) is not None
                        for field in ("stt_confidence", "stt_provider", "stt_model")
                    ):
                        errors.append(f"{prefix}: assistant turn {turn_id} must not contain STT metadata")
                elif any(
                    turn.get(field) is None
                    for field in ("stt_confidence", "stt_provider", "stt_model")
                ):
                    errors.append(
                        f"{prefix}: user turn {turn_id} requires complete STT metadata"
                    )

        formation = scenario.get("formation_expect", {})
        observations = formation.get("expected_observations", [])
        if bool(observations) == bool(formation.get("expect_noop")):
            errors.append(f"{prefix}: expect_noop must be true exactly when observations are empty")
        for observation in observations:
            expectation_id = str(observation.get("expectation_id", "<missing>"))
            if expectation_id in global_expectation_ids:
                errors.append(f"{prefix}: duplicate global expectation ID {expectation_id}")
            global_expectation_ids.add(expectation_id)
            after_turn_id = observation.get("after_turn_id")
            after_turn = turns.get(after_turn_id)
            if after_turn is None:
                errors.append(f"{prefix}: unknown after_turn_id {after_turn_id}")
            for evidence_id in observation.get("evidence_turn_ids", []):
                evidence = turns.get(evidence_id)
                if evidence is None:
                    errors.append(f"{prefix}: unknown evidence turn {evidence_id}")
                    continue
                if evidence.get("role") != observation.get("source_role"):
                    errors.append(f"{prefix}: {expectation_id} source role mismatches {evidence_id}")
                if after_turn is not None and evidence.get("created_at_ms", 0) > after_turn.get("created_at_ms", 0):
                    errors.append(f"{prefix}: {expectation_id} cites evidence after its evaluation boundary")
            is_commitment = observation.get("kind") == "assistant_commitment"
            expected_role = "assistant" if is_commitment else "user"
            if observation.get("source_role") != expected_role:
                errors.append(f"{prefix}: {expectation_id} must use {expected_role} evidence")

    if release_gate:
        protected = sum(item.get("split") == "protected" for item in catalog.get("scenarios", []))
        robustness = sum(item.get("split") == "robustness" for item in catalog.get("scenarios", []))
        if not 20 <= protected <= 30:
            errors.append(f"release gate requires 20-30 protected scenarios; found {protected}")
        if not 10 <= robustness <= 15:
            errors.append(f"release gate requires 10-15 robustness scenarios; found {robustness}")
        total = protected + robustness
        noops = sum(
            bool(item.get("formation_expect", {}).get("expect_noop"))
            for item in catalog.get("scenarios", [])
        )
        ratio = noops / total if total else 0.0
        if not 0.35 <= ratio <= 0.45:
            errors.append(f"release gate requires 35%-45% no-memory cases; found {ratio:.1%}")
        missing_gates = REQUIRED_HARD_GATES - covered_gates
        if missing_gates:
            errors.append(f"release gate lacks hard-gate coverage: {sorted(missing_gates)}")
        if catalog.get("template_only"):
            errors.append("release gate refuses template_only=true")
    return errors


def validate_holdout(
    catalog_path: Path,
    freeze_manifest: Path,
    development_catalog_path: Path,
    *,
    release_gate: bool,
) -> tuple[dict[str, Any], dict[str, Any], list[str]]:
    catalog = load_json(catalog_path)
    development = load_json(development_catalog_path)
    errors = schema_errors(catalog)
    manifest, freeze_errors = verify_freeze(freeze_manifest)
    errors.extend(freeze_errors)
    if not errors:
        errors.extend(semantic_errors(catalog, development, release_gate=release_gate))
        if catalog.get("compiler_freeze_id") != manifest.get("freeze_id"):
            errors.append("catalog compiler_freeze_id does not match the verified manifest")
    return catalog, manifest, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--freeze-manifest", type=Path, default=DEFAULT_FREEZE)
    parser.add_argument("--development-catalog", type=Path, default=DEFAULT_DEVELOPMENT_CATALOG)
    parser.add_argument("--release-gate", action="store_true")
    args = parser.parse_args()
    try:
        catalog, manifest, errors = validate_holdout(
            args.catalog.resolve(),
            args.freeze_manifest.resolve(),
            args.development_catalog.resolve(),
            release_gate=args.release_gate,
        )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if errors:
        print("Memory V3 compiler holdout validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    protected = sum(item["split"] == "protected" for item in catalog["scenarios"])
    robustness = sum(item["split"] == "robustness" for item in catalog["scenarios"])
    print(
        f"Memory V3 compiler holdout valid against {manifest['freeze_id']}: "
        f"{protected} protected, {robustness} robustness, release_gate={args.release_gate}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
