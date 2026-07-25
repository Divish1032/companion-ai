#!/usr/bin/env python3
"""Stage-aware, transcript-redacted Memory V3 formation evaluation."""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import math
import os
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, TypeVar

from dotenv import load_dotenv
from jsonschema import Draft202012Validator, FormatChecker


REPO_ROOT = Path(__file__).resolve().parents[1]
API_ROOT = REPO_ROOT / "services" / "api"
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
DEFAULT_CATALOG = EVAL_ROOT / "fixtures" / "task1_core_scenarios.json"
DEFAULT_SPLITS = EVAL_ROOT / "fixtures" / "compiler_splits.json"
FIXTURE_SCHEMA = EVAL_ROOT / "schemas" / "fixture_catalog.schema.json"
HOLDOUT_SCHEMA = EVAL_ROOT / "schemas" / "compiler_holdout_catalog.schema.json"
COMPILER_REPORT_SCHEMA = EVAL_ROOT / "schemas" / "compiler_report.schema.json"
DEFAULT_FREEZE = EVAL_ROOT / "freezes" / "task3_1_candidate_clean_20260720.json"
PHONE_ROOT = REPO_ROOT / "apps" / "mobile"
PHONE_BRIDGE = PHONE_ROOT / "tool" / "memory_v3_admission_bridge.dart"

if str(API_ROOT) not in sys.path:
    sys.path.insert(0, str(API_ROOT))
if str(EVAL_ROOT) not in sys.path:
    sys.path.insert(0, str(EVAL_ROOT))

from app.memory_v3_compiler import (  # noqa: E402
    MemoryCompileRequestV3,
    MemoryCompileResultV3,
    MemoryObservationV3,
    MemorySemanticAtomV3,
    MemoryV3CompilerUnavailable,
    OpenAICompatibleMemoryV3Compiler,
    construct_memory_observations,
)
from validate_compiler_holdout import validate_holdout  # noqa: E402


T = TypeVar("T")


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def _fixture_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _percentile(values: list[int], percentile: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, math.ceil(percentile * len(ordered)) - 1)
    return ordered[index]


def _semantic_text(atom: MemorySemanticAtomV3) -> str:
    return " ".join(
        str(value)
        for value in (
            atom.object_quote,
            atom.normalized_value,
            atom.assessment,
        )
        if value is not None
    ).casefold()


def _candidate_text(candidate: MemoryObservationV3) -> str:
    # Evidence is deliberately excluded: copying expected words somewhere in a
    # broad evidence span must not count as a correct object extraction.
    return " ".join(
        str(value)
        for value in (
            candidate.object.text,
            candidate.object.normalized_value,
            candidate.object.user_assessment,
        )
        if value is not None
    ).casefold()


def _expected_explicitness(expected: dict[str, Any]) -> str:
    return expected.get(
        "explicitness",
        "assistant_only" if expected["kind"] == "assistant_commitment" else "explicit",
    )


def _semantic_edge(atom: MemorySemanticAtomV3, expected: dict[str, Any]) -> bool:
    expected_atom_explicitness = (
        "explicit"
        if _expected_explicitness(expected) == "assistant_only"
        else _expected_explicitness(expected)
    )
    subject_type = expected.get("subject_entity_type", "user")
    subject_tokens = expected.get("subject_contains", [])
    target_tokens = expected.get("target_contains", [])
    target_text = atom.target_entity.mention.casefold() if atom.target_entity else ""
    return bool(
        atom.predicate == expected["predicate"]
        and atom.modality == expected.get("modality", "asserted")
        and atom.explicitness == expected_atom_explicitness
        and atom.temporal_class
        == expected.get("semantic_temporal_class", expected["temporal_status"])
        and atom.subject.entity_type == subject_type
        and all(token.casefold() in atom.subject.mention.casefold() for token in subject_tokens)
        and all(token.casefold() in target_text for token in target_tokens)
        and all(token.casefold() in _semantic_text(atom) for token in expected["object_contains"])
        and set(expected["evidence_turn_ids"]) == {item.turn_id for item in atom.evidence}
    )


def _candidate_edge(
    candidate: MemoryObservationV3,
    expected: dict[str, Any],
    *,
    structural_only: bool,
) -> bool:
    subject_type = expected.get("subject_entity_type", "user")
    subject_tokens = expected.get("subject_contains", [])
    target_tokens = expected.get("target_contains", [])
    target_text = (
        candidate.object.target_entity.mention.casefold() if candidate.object.target_entity else ""
    )
    return bool(
        candidate.kind == expected["kind"]
        and candidate.predicate == expected["predicate"]
        and candidate.proposed_operation == expected["operation"]
        and candidate.temporal.status == expected["temporal_status"]
        and candidate.epistemic.explicitness == _expected_explicitness(expected)
        and not candidate.epistemic.negated
        and not candidate.epistemic.hypothetical
        and not candidate.epistemic.quoted
        and candidate.subject.entity_type == subject_type
        and all(
            token.casefold() in candidate.subject.mention.casefold() for token in subject_tokens
        )
        and all(token.casefold() in target_text for token in target_tokens)
        and (
            structural_only
            or all(
                token.casefold() in _candidate_text(candidate)
                for token in expected["object_contains"]
            )
        )
        and set(expected["evidence_turn_ids"]) == {item.turn_id for item in candidate.evidence}
        and {item.role for item in candidate.evidence} == {expected["source_role"]}
    )


def _maximum_matching(
    actual: list[T],
    expected: list[dict[str, Any]],
    edge: Callable[[T, dict[str, Any]], bool],
) -> tuple[dict[int, int], set[int], set[int]]:
    """Maximum-cardinality bipartite matching, independent of fixture order."""

    expected_to_actual: dict[int, int] = {}

    def augment(actual_index: int, visited: set[int]) -> bool:
        for expected_index, expectation in enumerate(expected):
            if expected_index in visited or not edge(actual[actual_index], expectation):
                continue
            visited.add(expected_index)
            prior = expected_to_actual.get(expected_index)
            if prior is None or augment(prior, visited):
                expected_to_actual[expected_index] = actual_index
                return True
        return False

    for actual_index in range(len(actual)):
        augment(actual_index, set())
    actual_to_expected = {
        actual_index: expected_index for expected_index, actual_index in expected_to_actual.items()
    }
    return (
        actual_to_expected,
        set(range(len(actual))) - set(actual_to_expected),
        set(range(len(expected))) - set(expected_to_actual),
    )


def _signature(candidate: MemoryObservationV3) -> dict[str, Any]:
    return {
        "candidate_id_hash": hashlib.sha256(candidate.candidate_id.encode()).hexdigest()[:24],
        "kind": candidate.kind,
        "predicate": candidate.predicate,
        "operation": candidate.proposed_operation,
        "temporal_status": candidate.temporal.status,
        "explicitness": candidate.epistemic.explicitness,
        "sensitivity": candidate.privacy.sensitivity,
        "durable_eligibility": candidate.privacy.durable_eligibility,
        "evidence_turn_ids": sorted({item.turn_id for item in candidate.evidence}),
        "evidence_roles": sorted({item.role for item in candidate.evidence}),
    }


def _split_scenarios(
    catalog: dict[str, Any],
    split_manifest: dict[str, Any],
    requested_split: str,
) -> list[dict[str, Any]]:
    if catalog.get("contract_version") == "memory_v3_compiler_holdout_v1":
        if requested_split == "development":
            raise SystemExit(
                "A blind holdout catalog has no development split; choose protected, "
                "robustness, or all."
            )
        scenarios = catalog["scenarios"]
        selected = (
            scenarios
            if requested_split == "all"
            else [item for item in scenarios if item["split"] == requested_split]
        )
        if not selected:
            raise SystemExit(f"Blind holdout split '{requested_split}' is empty.")
        return selected

    catalog_id = catalog["catalog_id"]
    split_map = split_manifest.get("catalogs", {}).get(catalog_id)
    if not isinstance(split_map, dict):
        raise SystemExit(f"No compiler split definition for catalog {catalog_id}.")
    all_ids = [item["id"] for item in catalog["scenarios"]]
    assigned = [
        scenario_id
        for name in ("development", "protected", "robustness")
        for scenario_id in split_map.get(name, [])
    ]
    if len(assigned) != len(set(assigned)) or set(assigned) != set(all_ids):
        raise SystemExit("Compiler split manifest must assign every scenario exactly once.")
    selected = set(all_ids if requested_split == "all" else split_map[requested_split])
    if not selected:
        raise SystemExit(
            f"Compiler split '{requested_split}' is empty for {catalog_id}; "
            "no protected claim can be made yet."
        )
    return [item for item in catalog["scenarios"] if item["id"] in selected]


async def _phone_admission(
    case_id: str,
    request: MemoryCompileRequestV3,
    candidates: list[MemoryObservationV3],
) -> list[dict[str, Any]]:
    payload = {
        "cases": [
            {
                "case_id": case_id,
                "sources": [
                    {
                        "id": f"fixture_{turn.turn_id}_{turn.role}",
                        "turn_id": turn.turn_id,
                        "role": turn.role,
                        "text": turn.text,
                        "status": turn.status,
                        "created_at_ms": turn.created_at_ms,
                        "stt_confidence": turn.stt_confidence,
                    }
                    for turn in request.turns
                ],
                "candidates": [
                    item.model_dump(mode="json", exclude_none=True) for item in candidates
                ],
            }
        ]
    }
    dart_wrapper = shutil.which("dart")
    if dart_wrapper is None:
        raise RuntimeError("phone_admission_dart_not_found")
    wrapper_path = Path(dart_wrapper).resolve()
    sdk_binary = wrapper_path.parent / "cache" / "dart-sdk" / "bin" / "dart"
    dart_binary = sdk_binary if sdk_binary.is_file() else wrapper_path
    process = await asyncio.create_subprocess_exec(
        str(dart_binary),
        "--disable-analytics",
        "run",
        str(PHONE_BRIDGE),
        cwd=PHONE_ROOT,
        env={**os.environ, "DART_DISABLE_ANALYTICS": "true", "CI": "true"},
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate(
        json.dumps(payload, ensure_ascii=False).encode("utf-8")
    )
    if process.returncode != 0:
        error_type = stderr.decode("utf-8", errors="replace").strip().splitlines()[-1:]
        raise RuntimeError(
            "phone_admission_bridge_failed" + (f":{error_type[0]}" if error_type else "")
        )
    decoded = json.loads(stdout)
    return decoded["results"][0]["outcomes"]


def _deterministic_baseline(request: MemoryCompileRequestV3) -> MemoryCompileResultV3:
    """Intentionally small eval-only baseline; never a production extractor."""

    atoms: list[MemorySemanticAtomV3] = []
    for turn in request.turns:
        if turn.role != "user" or turn.status == "safety_override":
            continue
        name = re.search(
            r"(?:mera naam|मेरा नाम)\s+([A-Za-z\u0900-\u097f]{2,40})",
            turn.text,
            re.IGNORECASE,
        )
        if name:
            value = name.group(1)
            atoms.append(
                MemorySemanticAtomV3.model_validate(
                    {
                        "predicate": "preferred_name",
                        "subject": {"entity_type": "user", "mention": "user"},
                        "object_quote": value,
                        "evidence": [{"turn_id": turn.turn_id, "quote": turn.text}],
                        "modality": "asserted",
                        "explicitness": "explicit",
                        "temporal_class": "current",
                        "normalized_value": value,
                        "sensitivity_hint": "normal",
                    }
                )
            )
        if re.search(r"\b(advice|solution|suno|listen)\b|सलाह|सुनो", turn.text, re.I):
            atoms.append(
                MemorySemanticAtomV3.model_validate(
                    {
                        "predicate": "support_style",
                        "subject": {"entity_type": "user", "mention": "user"},
                        "object_quote": turn.text,
                        "evidence": [{"turn_id": turn.turn_id, "quote": turn.text}],
                        "modality": "asserted",
                        "explicitness": "explicit",
                        "temporal_class": "current",
                        "sensitivity_hint": "normal",
                    }
                )
            )
    candidates, outcomes = construct_memory_observations(request, atoms)
    return MemoryCompileResultV3(
        candidates=candidates,
        no_memory_reason=None if atoms else "deterministic_baseline_no_match",
        provider="deterministic_local",
        model="formation_rules_v1",
        prompt_version="memory_semantic_atoms_v3_1",
        semantic_atoms=atoms,
        construction_outcomes=outcomes,
        provider_model="formation_rules_v1",
    )


def _checkpoint(path: Path, metadata: dict[str, Any], runs: list[dict[str, Any]]) -> None:
    checkpoint_path = path.with_suffix(path.suffix + ".checkpoint.json")
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    checkpoint_path.write_text(
        json.dumps({**metadata, "complete": False, "runs": runs}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _write_debug(
    path: Path,
    debug_runs: list[dict[str, Any]],
) -> None:
    resolved = path.resolve()
    allowed_root = (REPO_ROOT / "tmp").resolve()
    if allowed_root not in resolved.parents:
        raise SystemExit("--debug-artifact must be inside the repository tmp/ directory.")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    resolved.write_text(
        json.dumps({"synthetic_only": True, "runs": debug_runs}, indent=2, ensure_ascii=False)
        + "\n",
        encoding="utf-8",
    )


async def _run(args: argparse.Namespace) -> int:
    catalog_path = args.catalog.resolve()
    catalog = _load_json(catalog_path)
    is_holdout = catalog.get("contract_version") == "memory_v3_compiler_holdout_v1"
    if is_holdout:
        _, freeze_manifest, holdout_errors = validate_holdout(
            catalog_path,
            args.freeze_manifest.resolve(),
            DEFAULT_CATALOG,
            release_gate=args.pipeline == "hybrid" and args.provider != "none",
        )
        if holdout_errors:
            raise SystemExit(
                "Blind holdout validation failed:\n- " + "\n- ".join(holdout_errors)
            )
    else:
        fixture_schema = _load_json(FIXTURE_SCHEMA)
        Draft202012Validator.check_schema(fixture_schema)
        fixture_errors = sorted(
            Draft202012Validator(
                fixture_schema,
                format_checker=FormatChecker(),
            ).iter_errors(catalog),
            key=lambda item: list(item.path),
        )
        if fixture_errors:
            raise SystemExit(f"Development catalog schema failed: {fixture_errors[0].message}")
        freeze_manifest = None
    scenarios = _split_scenarios(catalog, _load_json(args.splits.resolve()), args.split)
    scenario_filter = set(args.scenario)
    if scenario_filter:
        scenarios = [item for item in scenarios if item["id"] in scenario_filter]
    if not scenarios:
        raise SystemExit("No scenarios selected.")
    pending = [item["id"] for item in scenarios if item["language_review"]["status"] != "approved"]
    if args.provider == "none" and args.pipeline == "hybrid":
        print(
            "Memory V3 compiler evaluation ready: "
            f"{len(scenarios)} {args.split} scenarios; no remote calls made."
        )
        return 0
    if args.pipeline == "hybrid":
        if not args.allow_remote:
            raise SystemExit("Remote compiler evaluation requires --allow-remote.")
        if pending and is_holdout:
            raise SystemExit(
                "Blind holdout runs require approved natural/aligned language review; "
                "--allow-unreviewed never overrides this gate."
            )
        if pending and not args.allow_unreviewed:
            raise SystemExit(
                "Language review remains pending; pass --allow-unreviewed only for an "
                "explicit development comparison."
            )
        load_dotenv(REPO_ROOT / ".env", override=False)
        api_key = os.environ.get(args.api_key_env, "")
        if not args.base_url or not args.model or not api_key:
            raise SystemExit("Compiler base URL, model, and API-key environment are required.")
        compiler = OpenAICompatibleMemoryV3Compiler(
            base_url=args.base_url,
            api_key=api_key,
            model=args.model,
            timeout_seconds=args.timeout_seconds,
            provider=args.provider,
            request_profile=args.request_profile,
        )
    else:
        compiler = None

    output = args.output.resolve()
    metadata = {
        "schema_version": 2,
        "report_type": "memory_v3_compiler_formation_eval",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "catalog_hash": _fixture_hash(catalog_path),
        "catalog_id": catalog["catalog_id"],
        "split": args.split,
        "pipeline": args.pipeline,
        "provider": args.provider if compiler else "deterministic_local",
        "requested_model": args.model if compiler else "formation_rules_v1",
        "prompt_version": "memory_semantic_atoms_v3_1",
        "request_profile": args.request_profile if compiler else "local",
        "repetitions": args.repetitions,
        "language_review_override": bool(pending),
    }
    if freeze_manifest is not None:
        metadata["compiler_freeze_id"] = freeze_manifest["freeze_id"]
    runs: list[dict[str, Any]] = []
    debug_runs: list[dict[str, Any]] = []
    latencies: list[int] = []
    costs: list[int] = []
    for repetition in range(1, args.repetitions + 1):
        for scenario in scenarios:
            for session_index, session in enumerate(scenario["sessions"]):
                turns = session["turns"][-12:]
                turn_ids = {item["turn_id"] for item in turns}
                expected = [
                    item
                    for item in scenario["formation_expect"]["expected_observations"]
                    if item["after_turn_id"] in turn_ids
                ]
                run_id = f"{scenario['id']}:{session['session_id']}:r{repetition}"
                request = MemoryCompileRequestV3.model_validate(
                    {
                        "schema_version": 3,
                        "job_id": "memory_compile_"
                        + hashlib.sha256(run_id.encode()).hexdigest()[:24],
                        "language": turns[-1]["language"],
                        "timezone": scenario["timezone"],
                        "now_ms": turns[-1]["created_at_ms"],
                        "turns": turns,
                    }
                )
                started = time.perf_counter()
                try:
                    result = (
                        await compiler.compile(request)
                        if compiler
                        else _deterministic_baseline(request)
                    )
                    latency_ms = round((time.perf_counter() - started) * 1000)
                    latencies.append(latency_ms)
                    admissions = await _phone_admission(run_id, request, result.candidates)
                    admission_by_id = {item["candidate_id"]: item for item in admissions}
                    semantic_matches, semantic_unexpected, semantic_missing = _maximum_matching(
                        result.semantic_atoms,
                        expected,
                        _semantic_edge,
                    )
                    construction_matches, construction_unexpected, construction_missing = (
                        _maximum_matching(
                            result.candidates,
                            expected,
                            lambda candidate, expectation: _candidate_edge(
                                candidate, expectation, structural_only=False
                            ),
                        )
                    )
                    structural_matches, _, structural_missing = _maximum_matching(
                        result.candidates,
                        expected,
                        lambda candidate, expectation: _candidate_edge(
                            candidate, expectation, structural_only=True
                        ),
                    )

                    def admission_edge(
                        candidate: MemoryObservationV3,
                        expectation: dict[str, Any],
                    ) -> bool:
                        if not _candidate_edge(candidate, expectation, structural_only=False):
                            return False
                        disposition = admission_by_id[candidate.candidate_id]["disposition"]
                        mapped = {
                            "admitted": "auto_admit",
                            "deferred": "defer",
                            "confirmation_required": "confirmation_required",
                            "rejected": "reject",
                        }[disposition]
                        return mapped == expectation["admission"]

                    admission_matches, admission_unexpected, admission_missing = _maximum_matching(
                        result.candidates,
                        expected,
                        admission_edge,
                    )
                    forbidden = sorted(
                        {
                            item.predicate
                            for item in result.candidates
                            if item.predicate
                            in scenario["formation_expect"]["forbidden_predicates"]
                        }
                    )
                    phone_rejections = sorted(
                        {item["reason"] for item in admissions if item["disposition"] == "rejected"}
                    )
                    noop_failed = bool(
                        scenario["formation_expect"]["expect_noop"] and result.candidates
                    )
                    estimated_micro_inr = None
                    if (
                        result.usage_input_tokens is not None
                        and result.usage_output_tokens is not None
                        and args.input_micro_inr_per_million > 0
                        and args.output_micro_inr_per_million > 0
                    ):
                        estimated_micro_inr = math.ceil(
                            (
                                result.usage_input_tokens * args.input_micro_inr_per_million
                                + result.usage_output_tokens * args.output_micro_inr_per_million
                            )
                            / 1_000_000
                        )
                        costs.append(estimated_micro_inr)
                    run = {
                        "run_id": run_id,
                        "scenario_id": scenario["id"],
                        "session_id": session["session_id"],
                        "repetition": repetition,
                        "status": "completed",
                        "error_stage": None,
                        "error_code": None,
                        "latency_ms": latency_ms,
                        "input_tokens": result.usage_input_tokens,
                        "output_tokens": result.usage_output_tokens,
                        "estimated_micro_inr": estimated_micro_inr,
                        "actual_model": result.provider_model,
                        "system_fingerprint_hash": (
                            hashlib.sha256(result.system_fingerprint.encode()).hexdigest()[:24]
                            if result.system_fingerprint
                            else None
                        ),
                        "expected_count": len(expected),
                        "semantic_atom_count": len(result.semantic_atoms),
                        "constructed_count": len(result.candidates),
                        "semantic_matched": len(semantic_matches),
                        "construction_matched": len(construction_matches),
                        "structural_matched": len(structural_matches),
                        "admission_matched": len(admission_matches),
                        "semantic_missing_ids": [
                            expected[index]["expectation_id"] for index in sorted(semantic_missing)
                        ],
                        "construction_missing_ids": [
                            expected[index]["expectation_id"]
                            for index in sorted(construction_missing)
                        ],
                        "structural_missing_ids": [
                            expected[index]["expectation_id"]
                            for index in sorted(structural_missing)
                        ],
                        "admission_missing_ids": [
                            expected[index]["expectation_id"] for index in sorted(admission_missing)
                        ],
                        "semantic_unexpected_count": len(semantic_unexpected),
                        "construction_unexpected_count": len(construction_unexpected),
                        "admission_unexpected_count": len(admission_unexpected),
                        "construction_rejection_reasons": sorted(
                            {
                                item.reason
                                for item in result.construction_outcomes
                                if item.disposition == "rejected"
                            }
                        ),
                        "phone_dispositions": sorted({item["disposition"] for item in admissions}),
                        "phone_rejection_reasons": phone_rejections,
                        "forbidden_predicates": forbidden,
                        "noop_failed": noop_failed,
                        "candidate_signatures": [_signature(item) for item in result.candidates],
                    }
                    runs.append(run)
                    if args.debug_artifact:
                        debug_runs.append(
                            {
                                "run_id": run_id,
                                "request": request.model_dump(mode="json"),
                                "semantic_atoms": [
                                    item.model_dump(mode="json") for item in result.semantic_atoms
                                ],
                                "construction_outcomes": [
                                    {
                                        "atom_index": item.atom_index,
                                        "disposition": item.disposition,
                                        "reason": item.reason,
                                    }
                                    for item in result.construction_outcomes
                                ],
                                "candidates": [
                                    item.model_dump(mode="json", exclude_none=True)
                                    for item in result.candidates
                                ],
                                "phone_admission": admissions,
                            }
                        )
                except MemoryV3CompilerUnavailable as error:
                    latency_ms = error.latency_ms or round((time.perf_counter() - started) * 1000)
                    latencies.append(latency_ms)
                    code = error.error_code
                    stage = (
                        "transport"
                        if code == "network_error" or code.startswith("provider_http_")
                        else "provider_envelope"
                        if code in {"invalid_provider_json", "missing_provider_content"}
                        else "semantic_syntax"
                        if code == "invalid_semantic_json"
                        else "semantic_schema"
                    )
                    error_cost = None
                    if (
                        error.usage_input_tokens is not None
                        and error.usage_output_tokens is not None
                        and args.input_micro_inr_per_million > 0
                        and args.output_micro_inr_per_million > 0
                    ):
                        error_cost = math.ceil(
                            (
                                error.usage_input_tokens * args.input_micro_inr_per_million
                                + error.usage_output_tokens * args.output_micro_inr_per_million
                            )
                            / 1_000_000
                        )
                        costs.append(error_cost)
                    runs.append(
                        {
                            "run_id": run_id,
                            "scenario_id": scenario["id"],
                            "session_id": session["session_id"],
                            "repetition": repetition,
                            "status": "error",
                            "error_stage": stage,
                            "error_code": code,
                            "error_diagnostics": list(error.diagnostics),
                            "latency_ms": latency_ms,
                            "expected_count": len(expected),
                            "input_tokens": error.usage_input_tokens,
                            "output_tokens": error.usage_output_tokens,
                            "estimated_micro_inr": error_cost,
                            "actual_model": error.provider_model,
                            "system_fingerprint_hash": (
                                hashlib.sha256(error.system_fingerprint.encode()).hexdigest()[:24]
                                if error.system_fingerprint
                                else None
                            ),
                        }
                    )
                except RuntimeError as error:
                    latency_ms = round((time.perf_counter() - started) * 1000)
                    latencies.append(latency_ms)
                    runs.append(
                        {
                            "run_id": run_id,
                            "scenario_id": scenario["id"],
                            "session_id": session["session_id"],
                            "repetition": repetition,
                            "status": "error",
                            "error_stage": "admission_runtime",
                            "error_code": str(error).split(":", 1)[0][:120],
                            "latency_ms": latency_ms,
                            "expected_count": len(expected),
                        }
                    )
                _checkpoint(output, metadata, runs)

    completed = [item for item in runs if item["status"] == "completed"]
    expected_total = sum(item["expected_count"] for item in runs)
    candidate_total = sum(item["constructed_count"] for item in completed)
    semantic_total = sum(item["semantic_atom_count"] for item in completed)
    metrics = {
        "run_count": len(runs),
        "completed_runs": len(completed),
        "error_runs": len(runs) - len(completed),
        "error_counts_by_stage": {
            stage: sum(1 for item in runs if item.get("error_stage") == stage)
            for stage in (
                "transport",
                "provider_envelope",
                "semantic_schema",
                "semantic_syntax",
                "admission_runtime",
            )
        },
        "expected_observations": expected_total,
        "semantic_atoms": semantic_total,
        "constructed_candidates": candidate_total,
        "semantic_matched": sum(item["semantic_matched"] for item in completed),
        "construction_matched": sum(item["construction_matched"] for item in completed),
        "structural_matched": sum(item["structural_matched"] for item in completed),
        "admission_matched": sum(item["admission_matched"] for item in completed),
        "semantic_recall": (
            sum(item["semantic_matched"] for item in completed) / expected_total
            if expected_total
            else 1.0
        ),
        "construction_recall": (
            sum(item["construction_matched"] for item in completed) / expected_total
            if expected_total
            else 1.0
        ),
        "structural_recall": (
            sum(item["structural_matched"] for item in completed) / expected_total
            if expected_total
            else 1.0
        ),
        "admission_recall": (
            sum(item["admission_matched"] for item in completed) / expected_total
            if expected_total
            else 1.0
        ),
        "construction_precision": (
            sum(item["construction_matched"] for item in completed) / candidate_total
            if candidate_total
            else 1.0
        ),
        "admission_precision": (
            sum(item["admission_matched"] for item in completed) / candidate_total
            if candidate_total
            else 1.0
        ),
        "hard_gate_failures": sum(
            1
            for item in completed
            if item["forbidden_predicates"]
            or item["phone_rejection_reasons"]
            or item["noop_failed"]
        ),
        "latency_ms": {
            "p50": _percentile(latencies, 0.50),
            "p95": _percentile(latencies, 0.95),
            "max": max(latencies) if latencies else None,
        },
        "cost_source": "reviewed_operator_rate" if costs else "unknown",
        "total_estimated_micro_inr": sum(costs) if costs else None,
    }
    report = {**metadata, "metrics": metrics, "runs": runs}
    report_schema = _load_json(COMPILER_REPORT_SCHEMA)
    Draft202012Validator.check_schema(report_schema)
    Draft202012Validator(report_schema).validate(report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    output.with_suffix(output.suffix + ".checkpoint.json").unlink(missing_ok=True)
    if args.debug_artifact:
        _write_debug(args.debug_artifact, debug_runs)
    print(json.dumps(metrics, sort_keys=True))
    print(f"Redacted report: {output}")
    failed = bool(
        metrics["error_runs"]
        or metrics["hard_gate_failures"]
        or metrics["admission_matched"] != expected_total
        or sum(item["admission_unexpected_count"] for item in completed)
    )
    return 1 if failed else 0


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--splits", type=Path, default=DEFAULT_SPLITS)
    parser.add_argument("--freeze-manifest", type=Path, default=DEFAULT_FREEZE)
    parser.add_argument(
        "--split",
        choices=("development", "protected", "robustness", "all"),
        default="development",
    )
    parser.add_argument(
        "--pipeline",
        choices=("hybrid", "deterministic_only"),
        default="hybrid",
    )
    parser.add_argument("--provider", default="none")
    parser.add_argument("--base-url", default=os.environ.get("MEMORY_V3_COMPILER_BASE_URL", ""))
    parser.add_argument("--model", default=os.environ.get("MEMORY_V3_COMPILER_MODEL", ""))
    parser.add_argument("--api-key-env", default="MEMORY_V3_COMPILER_API_KEY")
    parser.add_argument(
        "--request-profile",
        choices=(
            "openai_json_schema",
            "deepseek_json_object",
            "deepseek_json_object_thinking",
        ),
        default=os.environ.get("MEMORY_V3_COMPILER_REQUEST_PROFILE", "openai_json_schema"),
    )
    parser.add_argument("--repetitions", type=int, choices=range(1, 11), default=1)
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    parser.add_argument("--input-micro-inr-per-million", type=int, default=0)
    parser.add_argument("--output-micro-inr-per-million", type=int, default=0)
    parser.add_argument("--allow-remote", action="store_true")
    parser.add_argument("--allow-unreviewed", action="store_true")
    parser.add_argument("--scenario", action="append", default=[])
    parser.add_argument(
        "--output",
        type=Path,
        default=EVAL_ROOT / "compiler_runs" / "latest.json",
    )
    parser.add_argument("--debug-artifact", type=Path)
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run(_arguments())))
