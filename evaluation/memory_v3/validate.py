#!/usr/bin/env python3
"""Validate Memory V3 Task 1 schemas, fixtures, and optional reports."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker


REPO_ROOT = Path(__file__).resolve().parents[2]
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
DEFAULT_CATALOG = EVAL_ROOT / "fixtures" / "task1_core_scenarios.json"
FIXTURE_SCHEMA = EVAL_ROOT / "schemas" / "fixture_catalog.schema.json"
REPORT_SCHEMA = EVAL_ROOT / "schemas" / "baseline_report.schema.json"
COMPILER_REPORT_SCHEMA = EVAL_ROOT / "schemas" / "compiler_report.schema.json"
DEVELOPMENT_REVIEW_SCHEMA = EVAL_ROOT / "schemas" / "development_review.schema.json"
DEFAULT_DEVELOPMENT_REVIEW = EVAL_ROOT / "reviews" / "task1_ai_development_review.json"
LIVE_RESPONSE_REVIEW_SCHEMA = EVAL_ROOT / "schemas" / "live_response_review.schema.json"
DEFAULT_LIVE_RESPONSE_REVIEW = EVAL_ROOT / "reviews" / "task1_live_pre_task2_review.json"

DEVA_RE = re.compile(r"[\u0900-\u097f]")
LATIN_RE = re.compile(r"[A-Za-z]")


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be a JSON object")
    return value


def schema_errors(instance: dict[str, Any], schema_path: Path) -> list[str]:
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = []
    for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
        location = "/".join(str(part) for part in error.absolute_path) or "<root>"
        errors.append(f"{schema_path.name} at {location}: {error.message}")
    return errors


def inferred_script(text: str) -> str:
    has_devanagari = DEVA_RE.search(text) is not None
    has_latin = LATIN_RE.search(text) is not None
    if has_devanagari and has_latin:
        return "mixed"
    if has_devanagari:
        return "devanagari"
    return "latin"


def semantic_catalog_errors(catalog: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    scenario_ids: set[str] = set()

    for scenario in catalog.get("scenarios", []):
        scenario_id = str(scenario.get("id", "<missing>"))
        prefix = f"scenario {scenario_id}"
        if scenario_id in scenario_ids:
            errors.append(f"{prefix}: duplicate scenario ID")
        scenario_ids.add(scenario_id)

        language_review = scenario.get("language_review", {})
        if scenario.get("protection") == "protected" and language_review.get("status") != "approved":
            errors.append(f"{prefix}: protected scenario lacks approved language review")
        if language_review.get("status") == "approved":
            if not language_review.get("reviewer_id") or not language_review.get("reviewed_at"):
                errors.append(f"{prefix}: approved language review lacks reviewer or timestamp")

        sessions = scenario.get("sessions", [])
        session_ids: set[str] = set()
        turns: dict[str, dict[str, Any]] = {}
        previous_session_start = -1
        for session in sessions:
            session_id = str(session.get("session_id", "<missing>"))
            if session_id in session_ids:
                errors.append(f"{prefix}: duplicate session ID {session_id}")
            session_ids.add(session_id)

            session_turns = session.get("turns", [])
            if session_turns:
                start = int(session_turns[0].get("created_at_ms", 0))
                if start <= previous_session_start:
                    errors.append(f"{prefix}: sessions are not chronologically ordered")
                previous_session_start = start
            previous_turn_time = -1
            for turn in session_turns:
                turn_id = str(turn.get("turn_id", "<missing>"))
                if turn_id in turns:
                    errors.append(f"{prefix}: duplicate turn ID {turn_id}")
                turns[turn_id] = turn
                created_at = int(turn.get("created_at_ms", 0))
                if created_at <= previous_turn_time:
                    errors.append(f"{prefix}: turn times are not increasing in {session_id}")
                previous_turn_time = created_at
                declared_script = turn.get("script")
                actual_script = inferred_script(str(turn.get("text", "")))
                if declared_script != actual_script:
                    errors.append(
                        f"{prefix}: {turn_id} declares script {declared_script}, "
                        f"but text is {actual_script}"
                    )
                if turn.get("role") == "assistant" and turn.get("stt_confidence") is not None:
                    errors.append(f"{prefix}: assistant turn {turn_id} must not have STT confidence")

        formation = scenario.get("formation_expect", {})
        observations = formation.get("expected_observations", [])
        if formation.get("expect_noop") and observations:
            errors.append(f"{prefix}: NOOP expectation cannot include observations")
        if not formation.get("expect_noop") and not observations:
            errors.append(f"{prefix}: non-NOOP formation requires an expected observation")

        expectation_ids: set[str] = set()
        for observation in observations:
            expectation_id = str(observation.get("expectation_id", "<missing>"))
            if expectation_id in expectation_ids:
                errors.append(f"{prefix}: duplicate observation expectation {expectation_id}")
            expectation_ids.add(expectation_id)
            after_turn = observation.get("after_turn_id")
            if after_turn not in turns:
                errors.append(f"{prefix}: unknown after_turn_id {after_turn}")
            evidence_ids = observation.get("evidence_turn_ids", [])
            for evidence_id in evidence_ids:
                evidence = turns.get(evidence_id)
                if evidence is None:
                    errors.append(f"{prefix}: unknown evidence turn {evidence_id}")
                    continue
                if evidence.get("role") != observation.get("source_role"):
                    errors.append(
                        f"{prefix}: {expectation_id} source role does not match {evidence_id}"
                    )
            if observation.get("kind") == "assistant_commitment" and observation.get("source_role") != "assistant":
                errors.append(f"{prefix}: assistant commitment must cite assistant evidence")
            if observation.get("kind") != "assistant_commitment" and observation.get("source_role") != "user":
                errors.append(f"{prefix}: user observation must cite user evidence")

        consolidation = scenario.get("consolidation_expect", {})
        for group in ("current", "historical", "episodes", "threads", "reflections", "forbidden"):
            for item in consolidation.get(group, []):
                for turn_id in item.get("supporting_turn_ids", []):
                    if turn_id not in turns:
                        errors.append(f"{prefix}: {group} expectation cites unknown turn {turn_id}")

        query_ids: set[str] = set()
        for query in scenario.get("queries", []):
            query_id = str(query.get("query_id", "<missing>"))
            query_prefix = f"{prefix} query {query_id}"
            if query_id in query_ids:
                errors.append(f"{query_prefix}: duplicate query ID")
            query_ids.add(query_id)
            after_session_id = query.get("after_session_id")
            if after_session_id not in session_ids:
                errors.append(f"{query_prefix}: unknown after_session_id {after_session_id}")
            if query.get("script") != inferred_script(str(query.get("text", ""))):
                errors.append(f"{query_prefix}: declared script does not match text")
            for turn_id in query.get("recent_turn_ids", []):
                if turn_id not in turns:
                    errors.append(f"{query_prefix}: recent context cites unknown turn {turn_id}")

            oracle = query.get("oracle_brief", {})
            expect = query.get("expect", {})
            oracle_items = oracle.get("items", [])
            if oracle.get("memory_needed") != expect.get("memory_needed"):
                errors.append(f"{query_prefix}: oracle and query memory-needed decisions differ")
            if oracle.get("memory_needed") and not oracle_items:
                errors.append(f"{query_prefix}: memory-needed oracle has no items")
            if not oracle.get("memory_needed") and oracle_items:
                errors.append(f"{query_prefix}: abstaining oracle contains memory items")
            if len(oracle_items) > int(expect.get("max_selected", 0)):
                errors.append(f"{query_prefix}: oracle exceeds max_selected")
            allowed_modes = set(expect.get("allowed_use_modes", []))
            must_include = set(expect.get("must_include_predicates", []))
            oracle_predicates = {item.get("predicate") for item in oracle_items}
            for item in oracle_items:
                if item.get("use_mode") not in allowed_modes:
                    errors.append(f"{query_prefix}: oracle use mode is not allowed")
                for turn_id in item.get("source_turn_ids", []):
                    if turn_id not in turns:
                        errors.append(f"{query_prefix}: oracle cites unknown turn {turn_id}")
            if not must_include.issubset(oracle_predicates):
                missing = sorted(must_include - oracle_predicates)
                errors.append(f"{query_prefix}: oracle misses required predicates {missing}")
            if query.get("response_evaluation"):
                rubric = query.get("response_rubric", {})
                if not rubric.get("rating_dimensions"):
                    errors.append(f"{query_prefix}: response evaluation lacks rating dimensions")

        if scenario.get("priority") == "P0" and not scenario.get("hard_gates"):
            errors.append(f"{prefix}: P0 scenario must name at least one hard gate")

    return errors


def validate_catalog(path: Path) -> tuple[dict[str, Any], list[str]]:
    catalog = load_json(path)
    errors = schema_errors(catalog, FIXTURE_SCHEMA)
    if not errors:
        errors.extend(semantic_catalog_errors(catalog))
    return catalog, errors


def validate_report(path: Path) -> list[str]:
    return schema_errors(load_json(path), REPORT_SCHEMA)


def validate_development_review(
    path: Path,
    catalog_path: Path,
    catalog: dict[str, Any],
) -> list[str]:
    review = load_json(path)
    errors = schema_errors(review, DEVELOPMENT_REVIEW_SCHEMA)
    if errors:
        return errors

    actual_hash = hashlib.sha256(catalog_path.read_bytes()).hexdigest()
    if review["catalog_sha256"] != actual_hash:
        errors.append(
            "development review: catalog hash does not match the reviewed fixture"
        )

    catalog_ids = [scenario["id"] for scenario in catalog["scenarios"]]
    reviewed_ids = [item["scenario_id"] for item in review["scenario_reviews"]]
    if len(reviewed_ids) != len(set(reviewed_ids)):
        errors.append("development review: duplicate scenario review")
    if set(reviewed_ids) != set(catalog_ids):
        missing = sorted(set(catalog_ids) - set(reviewed_ids))
        extra = sorted(set(reviewed_ids) - set(catalog_ids))
        errors.append(
            f"development review: scenario coverage mismatch; missing={missing}, extra={extra}"
        )

    changed = sum(
        item["result"] == "wording_changed" for item in review["scenario_reviews"]
    )
    passed = sum(item["result"] == "pass" for item in review["scenario_reviews"])
    summary = review["summary"]
    if summary["scenario_count"] != len(reviewed_ids):
        errors.append("development review: summary scenario count is incorrect")
    if summary["wording_changed"] != changed:
        errors.append("development review: summary wording-changed count is incorrect")
    if summary["passed_without_change"] != passed:
        errors.append("development review: summary pass count is incorrect")
    return errors


def validate_live_response_review(
    path: Path,
    catalog: dict[str, Any],
) -> list[str]:
    review = load_json(path)
    errors = schema_errors(review, LIVE_RESPONSE_REVIEW_SCHEMA)
    if errors:
        return errors

    expected_pairs = {
        (scenario["id"], query["query_id"])
        for scenario in catalog["scenarios"]
        for query in scenario["queries"]
        if query["response_evaluation"]
    }
    reviewed_pairs = [
        (item["scenario_id"], item["query_id"])
        for item in review["query_reviews"]
    ]
    if len(reviewed_pairs) != len(set(reviewed_pairs)):
        errors.append("live response review: duplicate scenario/query review")
    if set(reviewed_pairs) != expected_pairs:
        missing = sorted(expected_pairs - set(reviewed_pairs))
        extra = sorted(set(reviewed_pairs) - expected_pairs)
        errors.append(
            f"live response review: query coverage mismatch; missing={missing}, extra={extra}"
        )

    for arm_id in ("no_memory", "v2", "oracle"):
        arm_reviews = [item["arms"][arm_id] for item in review["query_reviews"]]
        passed = sum(item["result"] == "pass" for item in arm_reviews)
        failed = len(arm_reviews) - passed
        summary = review["summary"][arm_id]
        if (summary["passed"], summary["failed"], summary["total"]) != (
            passed,
            failed,
            len(arm_reviews),
        ):
            errors.append(f"live response review: incorrect {arm_id} summary")
        expected_rate = round(passed / len(arm_reviews), 4)
        if summary["pass_rate"] != expected_rate:
            errors.append(f"live response review: incorrect {arm_id} pass rate")
        for arm_review in arm_reviews:
            if arm_review["result"] == "pass" and arm_review["failure_modes"]:
                errors.append(
                    f"live response review: passing {arm_id} arm has failure modes"
                )
            if arm_review["result"] == "fail" and not arm_review["failure_modes"]:
                errors.append(
                    f"live response review: failing {arm_id} arm lacks failure mode"
                )

    source_path = REPO_ROOT / review["source"]["local_artifact"]
    if source_path.is_file():
        actual_hash = hashlib.sha256(source_path.read_bytes()).hexdigest()
        if review["source"]["sha256"] != actual_hash:
            errors.append("live response review: local baseline hash mismatch")
        report = load_json(source_path)
        errors.extend(schema_errors(report, REPORT_SCHEMA))
        run = report.get("run", {})
        for field in ("run_id", "fixture_sha256", "provider", "model"):
            if review["source"][field] != run.get(field):
                errors.append(
                    f"live response review: source {field} does not match local baseline"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--compiler-report", type=Path)
    parser.add_argument(
        "--development-review",
        type=Path,
        default=DEFAULT_DEVELOPMENT_REVIEW,
    )
    parser.add_argument(
        "--live-response-review",
        type=Path,
        default=DEFAULT_LIVE_RESPONSE_REVIEW,
    )
    args = parser.parse_args()

    for schema_path in (
        FIXTURE_SCHEMA,
        REPORT_SCHEMA,
        COMPILER_REPORT_SCHEMA,
        DEVELOPMENT_REVIEW_SCHEMA,
        LIVE_RESPONSE_REVIEW_SCHEMA,
    ):
        try:
            Draft202012Validator.check_schema(load_json(schema_path))
        except Exception as exc:
            print(f"ERROR: invalid schema {schema_path}: {exc}", file=sys.stderr)
            return 1

    try:
        catalog, errors = validate_catalog(args.catalog)
        errors.extend(
            validate_development_review(
                args.development_review,
                args.catalog,
                catalog,
            )
        )
        errors.extend(validate_live_response_review(args.live_response_review, catalog))
        if args.report is not None:
            errors.extend(validate_report(args.report))
        if args.compiler_report is not None:
            errors.extend(
                schema_errors(load_json(args.compiler_report), COMPILER_REPORT_SCHEMA)
            )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if errors:
        print("Memory V3 Task 1 validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    scenarios = catalog["scenarios"]
    queries = sum(len(scenario["queries"]) for scenario in scenarios)
    pending = sum(
        scenario["language_review"]["status"] != "approved" for scenario in scenarios
    )
    print(
        f"Memory V3 Task 1 validation passed: {len(scenarios)} scenarios, "
        f"{queries} queries, {pending} pending language reviews."
    )
    if args.report is not None:
        print(f"Baseline report valid: {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
