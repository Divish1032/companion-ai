#!/usr/bin/env python3
"""Capture matched no-memory, unchanged-V2, and oracle Task 1 baselines."""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import tomllib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
AGENT_ROOT = REPO_ROOT / "services" / "realtime-agent"
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
DEFAULT_CATALOG = EVAL_ROOT / "fixtures" / "task1_core_scenarios.json"
DEFAULT_PERSONA = REPO_ROOT / "config" / "personas" / "hindi_companion_v1.toml"

if str(AGENT_ROOT) not in sys.path:
    sys.path.insert(0, str(AGENT_ROOT))

from app.context import PromptContextBuilder  # noqa: E402
from app.lifecycle import (  # noqa: E402
    _clip_response_text,
    _is_question_turn,
    _looks_like_question_echo,
    _memory_admission_hint,
    _render_memory_directive,
    _sanitize_llm_output,
)
from app.providers.interfaces import LLMMessage  # noqa: E402
from app.providers.llm import SarvamChatLLMProvider  # noqa: E402
from app.safety import SafetyClassifier  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: JSON root must be an object")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_value(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() or "unknown"


def git_dirty() -> bool:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
        check=False,
        capture_output=True,
        text=True,
    )
    return bool(result.stdout.strip())


def validate_catalog(catalog: Path) -> None:
    result = subprocess.run(
        [sys.executable, str(EVAL_ROOT / "validate.py"), "--catalog", str(catalog)],
        cwd=REPO_ROOT,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError("fixture catalog validation failed")


def run_v2_probe(catalog: Path, output: Path) -> dict[str, Any]:
    environment = os.environ.copy()
    environment["MEMORY_V3_FIXTURE_CATALOG"] = str(catalog.resolve())
    environment["MEMORY_V3_V2_PROBE_OUTPUT"] = str(output.resolve())
    result = subprocess.run(
        [
            "flutter",
            "test",
            "test/memory_v3_baseline_probe_test.dart",
            "--reporter",
            "compact",
        ],
        cwd=REPO_ROOT / "apps" / "mobile",
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not output.is_file():
        tail = "\n".join((result.stdout + result.stderr).splitlines()[-20:])
        raise RuntimeError(f"V2 Flutter probe failed:\n{tail}")
    return load_json(output)


def skipped_probe(catalog: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "source": "skipped",
        "scenario_count": len(catalog["scenarios"]),
        "scenarios": [
            {
                "scenario_id": scenario["id"],
                "error": "V2 probe skipped by operator",
                "queries": [
                    {
                        "query_id": query["query_id"],
                        "status": "skipped",
                        "latency_ms": 0,
                        "memory_blocks": [],
                        "stored_memory_blocks": [],
                        "state_snapshot": [],
                        "response_directive": None,
                        "state_facts": [],
                        "policy_card": {},
                        "semantic_resolved": False,
                        "error": "V2 probe skipped by operator",
                    }
                    for query in scenario["queries"]
                ],
            }
            for scenario in catalog["scenarios"]
        ],
    }


def probe_index(probe: dict[str, Any]) -> dict[tuple[str, str], dict[str, Any]]:
    indexed: dict[tuple[str, str], dict[str, Any]] = {}
    for scenario in probe.get("scenarios", []):
        for query in scenario.get("queries", []):
            indexed[(scenario["scenario_id"], query["query_id"])] = query
    return indexed


def scenario_error_index(probe: dict[str, Any]) -> dict[str, str | None]:
    return {
        str(scenario.get("scenario_id")): scenario.get("error")
        for scenario in probe.get("scenarios", [])
    }


def state_key_matches(predicate: str, state_key: str) -> bool:
    exact = {
        "preferred_name": "user.profile.preferred_name",
        "response_language": "user.preference.response_language",
        "response_length": "user.preference.response_length",
        "support_style": "user.preference.comfort_style",
    }
    if predicate in exact:
        return state_key == exact[predicate]
    prefixes = {
        "has_relationship": "user.relationship.",
        "follows_routine": "user.routine.",
        "pursues_goal": "user.goal.",
        "avoids_topic": "user.boundary.",
    }
    prefix = prefixes.get(predicate)
    return prefix is not None and state_key.startswith(prefix)


def expected_source_turns(
    scenario: dict[str, Any], predicates: set[str]
) -> set[str]:
    source_turns: set[str] = set()
    for observation in scenario["formation_expect"]["expected_observations"]:
        if observation["predicate"] in predicates:
            source_turns.update(observation["evidence_turn_ids"])
    for group in ("current", "historical", "episodes", "threads", "reflections"):
        for item in scenario["consolidation_expect"][group]:
            if item["predicate"] in predicates:
                source_turns.update(item["supporting_turn_ids"])
    return source_turns


def diagnose_v2(
    scenario: dict[str, Any],
    query: dict[str, Any],
    probe_result: dict[str, Any],
    *,
    safety_bypass: bool,
) -> dict[str, Any]:
    expected_needed = bool(query["expect"]["memory_needed"])
    if probe_result.get("status") != "completed":
        return {
            "expected_memory_needed": expected_needed,
            "evidence_present_in_v2_storage": False,
            "memory_reached_response_boundary": False,
            "decision_correct": False,
            "first_causal_stage": "probe_failed",
        }

    predicates = set(query["expect"]["must_include_predicates"])
    sources = expected_source_turns(scenario, predicates)
    state_present = any(
        any(state_key_matches(predicate, str(item.get("state_key", ""))) for predicate in predicates)
        for item in probe_result.get("state_snapshot", [])
    )
    stored_present = any(
        sources.intersection(block.get("source_turn_ids", []))
        for block in probe_result.get("stored_memory_blocks", [])
    )
    evidence_present = state_present or stored_present
    reached = bool(
        probe_result.get("response_directive") == "fact_answer"
        or probe_result.get("memory_blocks")
        or probe_result.get("policy_card")
    )

    if safety_bypass:
        stage = "safety_bypass"
        correct = not expected_needed
        reached = False
    elif expected_needed and reached:
        stage = "reached_response_boundary"
        correct = True
    elif expected_needed and evidence_present:
        stage = "retrieval"
        correct = False
    elif expected_needed:
        stage = "formation_or_admission"
        correct = False
    elif reached:
        stage = "false_positive"
        correct = False
    else:
        stage = "correct_abstention"
        correct = True

    return {
        "expected_memory_needed": expected_needed,
        "evidence_present_in_v2_storage": evidence_present,
        "memory_reached_response_boundary": reached,
        "decision_correct": correct,
        "first_causal_stage": stage,
    }


def turn_index(scenario: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        turn["turn_id"]: turn
        for session in scenario["sessions"]
        for turn in session["turns"]
    }


def recent_turns(scenario: dict[str, Any], query: dict[str, Any]) -> list[dict[str, Any]]:
    turns = turn_index(scenario)
    return [
        {
            "turn_id": turn_id,
            "role": turns[turn_id]["role"],
            "text": turns[turn_id]["text"],
            "status": turns[turn_id]["status"],
            "confidence": turns[turn_id]["stt_confidence"],
            "created_at_ms": turns[turn_id]["created_at_ms"],
            "source": "task1_fixture_recent_turn",
        }
        for turn_id in query.get("recent_turn_ids", [])
    ]


def oracle_blocks(
    scenario: dict[str, Any], query: dict[str, Any]
) -> list[dict[str, Any]]:
    turns = turn_index(scenario)
    blocks = []
    for index, item in enumerate(query["oracle_brief"]["items"]):
        if item["use_mode"] == "DO_NOT_USE":
            continue
        predicate = item["predicate"]
        kind = item["kind"]
        if predicate == "preferred_name":
            v2_kind = "stable_fact"
        elif predicate in {"support_style", "response_language", "response_length"}:
            v2_kind = "procedural"
        elif kind == "episode":
            v2_kind = "episodic"
        elif kind in {"open_thread", "reflection"}:
            v2_kind = "session_summary"
        else:
            v2_kind = "semantic"
        source_times = [
            turns[turn_id]["created_at_ms"]
            for turn_id in item["source_turn_ids"]
            if turn_id in turns
        ]
        source_roles = {
            turns[turn_id]["role"]
            for turn_id in item["source_turn_ids"]
            if turn_id in turns
        }
        source_role = next(iter(source_roles)) if len(source_roles) == 1 else "mixed"
        created_at = max(source_times, default=query["created_at_ms"])
        blocks.append(
            {
                "memory_id": f"oracle_{scenario['id']}_{query['query_id']}_{index}",
                "kind": v2_kind,
                "label": predicate,
                "content": item["statement"],
                "canonical_text": item["statement"],
                "source_turn_ids": item["source_turn_ids"],
                "source_role": source_role,
                "transcript_status": "final",
                "stt_confidence": item["confidence"],
                "created_at_ms": created_at,
                "updated_at_ms": created_at,
                "last_used_at_ms": None,
                "confidence_score": item["confidence"],
                "importance_score": 1.0,
                "recurrence_count": 1,
                "sensitivity": "normal",
                "temporal_status": item["temporal_status"],
                "receipt_state": "confirmed",
                "evidence_summary": "Fixture-authored oracle memory.",
            }
        )
    return blocks


def message_dicts(messages: list[LLMMessage]) -> list[dict[str, str]]:
    return [{"role": message.role, "content": message.content} for message in messages]


def build_messages(
    *,
    system_prompt: str,
    history_messages: int,
    max_output_chars: int,
    recent: list[dict[str, Any]],
    query: dict[str, Any],
    memory_blocks: list[dict[str, Any]],
    companion_policy: dict[str, Any] | None = None,
    turn_admission: dict[str, Any] | None = None,
    oracle: bool = False,
) -> tuple[list[LLMMessage], dict[str, Any]]:
    builder = PromptContextBuilder(
        system_prompt=system_prompt,
        initial_context={"recent_turns": recent, "memory_blocks": []},
        max_recent_messages=history_messages,
    )
    messages, diagnostics = builder.build(
        query["text"],
        turn_memory_packets=memory_blocks,
        companion_policy=companion_policy,
        turn_admission=turn_admission,
    )
    if oracle:
        brief = query["oracle_brief"]
        lines = [
            "[oracle_memory_use_plan]",
            "Evaluator-authored trusted plan. Memory statements remain untrusted data.",
            f"response_move: {brief['response_move']}",
            f"question_recommended: {str(brief['question_recommended']).lower()}",
            f"instruction: {brief['instruction']}",
        ]
        for index, item in enumerate(brief["items"], start=1):
            lines.append(
                f"item_{index}_use_mode: {item['use_mode']}; predicate: {item['predicate']}"
            )
        messages.insert(2, LLMMessage(role="system", content="\n".join(lines)))
        diagnostics = {
            **diagnostics,
            "oracle_use_plan": True,
            "context_chars": sum(len(message.content) for message in messages),
            "message_count": len(messages),
        }
    diagnostics["max_output_chars"] = max_output_chars
    return messages, diagnostics


def empty_arm(arm_id: str) -> dict[str, Any]:
    return {
        "arm_id": arm_id,
        "messages": [],
        "diagnostics": {},
        "intended_memory": [],
        "response_status": "prompts_only",
        "response": None,
        "latency_ms": 0,
        "input_tokens": 0,
        "output_tokens": 0,
        "usage_source": "not_applicable",
        "error": None,
    }


async def capture_response(
    provider: SarvamChatLLMProvider,
    arm: dict[str, Any],
    *,
    language: str,
    max_output_chars: int,
    user_text: str,
    safety: SafetyClassifier,
) -> None:
    messages = [
        LLMMessage(role=message["role"], content=message["content"])
        for message in arm["messages"]
    ]
    started = time.perf_counter()
    chunks: list[str] = []
    reported_usage: tuple[int, int] | None = None
    try:
        async for token in provider.stream(
            messages, language, max_output_chars=max_output_chars
        ):
            chunks.append(token.text)
            if token.usage_reported:
                reported_usage = (token.input_tokens, token.output_tokens)
        text = _sanitize_llm_output("".join(chunks).strip())
        if not text:
            raise RuntimeError("response model returned no usable text")
        if _is_question_turn(user_text) and _looks_like_question_echo(user_text, text):
            text = "Mujhe is baat ka abhi pakka jawab nahi pata."
        text, clipped = _clip_response_text(text, max_chars=max_output_chars)
        output_decision = safety.classify_output(text)
        if output_decision.response_override is not None:
            text = output_decision.response_override
        arm["response_status"] = "completed"
        arm["response"] = text
        arm["diagnostics"]["clipped"] = clipped
        arm["diagnostics"]["output_safety_reason"] = output_decision.reason
        if reported_usage is not None:
            arm["input_tokens"], arm["output_tokens"] = reported_usage
            arm["usage_source"] = "provider_reported"
        else:
            arm["usage_source"] = "unknown"
    except Exception as exc:
        arm["response_status"] = "failed"
        arm["error"] = str(exc)[:500]
        arm["usage_source"] = "unknown"
    finally:
        arm["latency_ms"] = round((time.perf_counter() - started) * 1000)


def provider_from_args(args: argparse.Namespace) -> SarvamChatLLMProvider | None:
    if args.provider == "none":
        return None
    if not args.confirm_paid_synthetic_run:
        raise ValueError(
            "--provider sarvam requires --confirm-paid-synthetic-run because it makes paid calls"
        )
    api_key = os.environ.get("AGENT_SARVAM_API_KEY") or os.environ.get("SARVAM_API_KEY")
    if not api_key:
        raise ValueError("AGENT_SARVAM_API_KEY or SARVAM_API_KEY is required")
    return SarvamChatLLMProvider(
        api_key=api_key,
        model=args.model,
        base_url=os.environ.get("AGENT_SARVAM_BASE_URL", "https://api.sarvam.ai/v1"),
        timeout_seconds=args.timeout_seconds,
    )


async def assemble_report(args: argparse.Namespace) -> tuple[dict[str, Any], Path]:
    catalog_path = args.catalog.resolve()
    persona_path = args.persona.resolve()
    validate_catalog(catalog_path)
    catalog = load_json(catalog_path)
    with persona_path.open("rb") as handle:
        persona = tomllib.load(handle)
    system_prompt = str(persona["prompt"]["system"]).strip()
    max_output_chars = int(persona["response"]["max_chars"])
    history_messages = int(persona["history"]["messages"])
    pending_reviews = sum(
        item["language_review"]["status"] != "approved"
        for item in catalog["scenarios"]
    )
    if (
        args.provider != "none"
        and pending_reviews
        and not args.allow_unreviewed_fixtures
    ):
        raise ValueError(
            f"{pending_reviews} language reviews are pending; approve them first or "
            "explicitly pass --allow-unreviewed-fixtures for a non-baseline exploratory run"
        )
    provider = provider_from_args(args)

    with tempfile.TemporaryDirectory(prefix="memory_v3_probe_") as temp_dir:
        probe_output = Path(temp_dir) / "v2_probe.json"
        if args.v2_probe_file is not None:
            probe = load_json(args.v2_probe_file)
        elif args.skip_v2_probe:
            probe = skipped_probe(catalog)
        else:
            probe = run_v2_probe(catalog_path, probe_output)

    probes = probe_index(probe)
    scenario_errors = scenario_error_index(probe)
    v2_probe_status = "completed"
    if args.skip_v2_probe:
        v2_probe_status = "skipped"
    elif any(item.get("status") != "completed" for item in probes.values()):
        v2_probe_status = "failed"

    safety = SafetyClassifier()
    scenario_results = []
    prompt_arm_count = 0
    response_arm_count = 0
    v2_stage_counts = {
        "memory_required_queries": 0,
        "reached_response_boundary": 0,
        "formation_or_admission_gaps": 0,
        "retrieval_gaps": 0,
        "correct_abstentions": 0,
        "false_positives": 0,
        "safety_bypasses": 0,
        "probe_failures": 0,
    }

    for scenario in catalog["scenarios"]:
        query_results = []
        for query in scenario["queries"]:
            probe_result = probes.get((scenario["id"], query["query_id"])) or {
                "status": "failed",
                "latency_ms": 0,
                "memory_blocks": [],
                "stored_memory_blocks": [],
                "state_snapshot": [],
                "response_directive": None,
                "state_facts": [],
                "policy_card": {},
                "semantic_resolved": False,
                "error": "missing V2 probe result",
            }
            recent = recent_turns(scenario, query)
            oracle_memory = oracle_blocks(scenario, query)
            arms = [empty_arm("no_memory"), empty_arm("v2"), empty_arm("oracle")]

            input_decision = safety.classify_input(query["text"])
            diagnosis = diagnose_v2(
                scenario,
                query,
                probe_result,
                safety_bypass=input_decision.response_override is not None,
            )
            if diagnosis["expected_memory_needed"]:
                v2_stage_counts["memory_required_queries"] += 1
            stage_count_keys = {
                "reached_response_boundary": "reached_response_boundary",
                "formation_or_admission": "formation_or_admission_gaps",
                "retrieval": "retrieval_gaps",
                "correct_abstention": "correct_abstentions",
                "false_positive": "false_positives",
                "safety_bypass": "safety_bypasses",
                "probe_failed": "probe_failures",
            }
            count_key = stage_count_keys.get(diagnosis["first_causal_stage"])
            if count_key is not None:
                v2_stage_counts[count_key] += 1
            if input_decision.response_override is not None:
                for arm in arms:
                    arm["response_status"] = "safety_override"
                    arm["response"] = input_decision.response_override
                    arm["usage_source"] = "not_applicable"
                    arm["diagnostics"] = {"safety_reason": input_decision.reason}
                    response_arm_count += 1
            else:
                no_messages, no_diagnostics = build_messages(
                    system_prompt=system_prompt,
                    history_messages=history_messages,
                    max_output_chars=max_output_chars,
                    recent=recent,
                    query=query,
                    memory_blocks=[],
                )
                arms[0]["messages"] = message_dicts(no_messages)
                arms[0]["diagnostics"] = no_diagnostics
                prompt_arm_count += 1

                v2_context = {
                    "response_directive": probe_result.get("response_directive"),
                    "state_facts": probe_result.get("state_facts", []),
                    "policy_card": probe_result.get("policy_card", {}),
                    "memory_packets": probe_result.get("memory_blocks", []),
                    "semantic_resolved": probe_result.get("semantic_resolved", False),
                }
                direct_response = _render_memory_directive(v2_context)
                arms[1]["intended_memory"] = probe_result.get("memory_blocks", [])
                if direct_response is not None:
                    arms[1]["response_status"] = "direct_response"
                    arms[1]["response"] = direct_response
                    arms[1]["usage_source"] = "not_applicable"
                    arms[1]["diagnostics"] = {
                        "response_directive": probe_result.get("response_directive"),
                        "state_fact_count": len(probe_result.get("state_facts", [])),
                    }
                    response_arm_count += 1
                else:
                    v2_messages, v2_diagnostics = build_messages(
                        system_prompt=system_prompt,
                        history_messages=history_messages,
                        max_output_chars=max_output_chars,
                        recent=recent,
                        query=query,
                        memory_blocks=probe_result.get("memory_blocks", []),
                        companion_policy=probe_result.get("policy_card", {}),
                        turn_admission=_memory_admission_hint(v2_context),
                    )
                    arms[1]["messages"] = message_dicts(v2_messages)
                    arms[1]["diagnostics"] = v2_diagnostics
                    prompt_arm_count += 1

                oracle_messages, oracle_diagnostics = build_messages(
                    system_prompt=system_prompt,
                    history_messages=history_messages,
                    max_output_chars=max_output_chars,
                    recent=recent,
                    query=query,
                    memory_blocks=oracle_memory,
                    oracle=True,
                )
                arms[2]["messages"] = message_dicts(oracle_messages)
                arms[2]["diagnostics"] = oracle_diagnostics
                arms[2]["intended_memory"] = query["oracle_brief"]["items"]
                prompt_arm_count += 1

                if provider is not None:
                    for arm in arms:
                        if arm["response_status"] == "direct_response":
                            continue
                        if not query["response_evaluation"]:
                            arm["response_status"] = "not_selected"
                            continue
                        await capture_response(
                            provider,
                            arm,
                            language=query["language"],
                            max_output_chars=max_output_chars,
                            user_text=query["text"],
                            safety=safety,
                        )
                        if arm["response"] is not None:
                            response_arm_count += 1

            query_results.append(
                {
                    "query_id": query["query_id"],
                    "response_evaluation": query["response_evaluation"],
                    "v2_retrieval": {
                        "status": probe_result.get("status", "failed"),
                        "latency_ms": max(0, int(probe_result.get("latency_ms", 0))),
                        "memory_blocks": probe_result.get("memory_blocks", []),
                        "stored_memory_blocks": probe_result.get(
                            "stored_memory_blocks", []
                        ),
                        "state_snapshot": probe_result.get("state_snapshot", []),
                        "response_directive": probe_result.get("response_directive"),
                        "state_facts": probe_result.get("state_facts", []),
                        "policy_card": probe_result.get("policy_card", {}),
                        "semantic_resolved": bool(probe_result.get("semantic_resolved", False)),
                        "error": probe_result.get("error"),
                    },
                    "v2_diagnosis": diagnosis,
                    "arms": arms,
                }
            )

        scenario_results.append(
            {
                "scenario_id": scenario["id"],
                "protection": scenario["protection"],
                "priority": scenario["priority"],
                "v2_probe_error": scenario_errors.get(scenario["id"]),
                "queries": query_results,
            }
        )

    now = datetime.now(timezone.utc).replace(microsecond=0)
    run_id = f"memory_v3_baseline_{now.strftime('%Y%m%dT%H%M%SZ')}"
    output = args.output or (
        REPO_ROOT / "tmp" / "memory_v3_baselines" / f"{run_id}.json"
    )
    report = {
        "schema_version": 3,
        "contract_version": "memory_v3_baseline_report_v1",
        "run": {
            "run_id": run_id,
            "generated_at": now.isoformat().replace("+00:00", "Z"),
            "git_revision": git_value("rev-parse", "HEAD"),
            "git_dirty": git_dirty(),
            "fixture_catalog": str(catalog_path.relative_to(REPO_ROOT)),
            "fixture_sha256": sha256(catalog_path),
            "persona_file": str(persona_path.relative_to(REPO_ROOT)),
            "persona_sha256": sha256(persona_path),
            "provider": args.provider,
            "model": args.model if args.provider != "none" else None,
            "temperature": "provider_default" if args.provider != "none" else None,
            "max_output_chars": max_output_chars,
            "v2_probe_status": v2_probe_status,
        },
        "summary": {
            "scenario_count": len(catalog["scenarios"]),
            "query_count": sum(len(item["queries"]) for item in catalog["scenarios"]),
            "response_evaluation_query_count": sum(
                query["response_evaluation"]
                for item in catalog["scenarios"]
                for query in item["queries"]
            ),
            "prompt_arm_count": prompt_arm_count,
            "response_arm_count": response_arm_count,
            "language_review_pending": sum(
                item["language_review"]["status"] != "approved"
                for item in catalog["scenarios"]
            ),
            "protected_scenarios": sum(
                item["protection"] == "protected" for item in catalog["scenarios"]
            ),
            "quality_claim_allowed": False,
            "v2_baseline": v2_stage_counts,
        },
        "scenarios": scenario_results,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report, output


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--persona", type=Path, default=DEFAULT_PERSONA)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--provider", choices=("none", "sarvam"), default="none")
    parser.add_argument("--model", default=os.environ.get("AGENT_LLM_MODEL", "sarvam-30b"))
    parser.add_argument("--timeout-seconds", type=float, default=20.0)
    parser.add_argument("--confirm-paid-synthetic-run", action="store_true")
    parser.add_argument("--allow-unreviewed-fixtures", action="store_true")
    parser.add_argument("--skip-v2-probe", action="store_true")
    parser.add_argument("--v2-probe-file", type=Path)
    args = parser.parse_args()
    if args.skip_v2_probe and args.v2_probe_file is not None:
        parser.error("--skip-v2-probe and --v2-probe-file are mutually exclusive")
    return args


def main() -> int:
    args = parse_args()
    try:
        report, output = asyncio.run(assemble_report(args))
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    result = subprocess.run(
        [
            sys.executable,
            str(EVAL_ROOT / "validate.py"),
            "--catalog",
            str(args.catalog),
            "--report",
            str(output),
        ],
        cwd=REPO_ROOT,
        check=False,
    )
    if result.returncode != 0:
        return result.returncode
    summary = report["summary"]
    print(f"Baseline report: {output}")
    print(
        f"Captured {summary['scenario_count']} scenarios, "
        f"{summary['prompt_arm_count']} prompt arms, "
        f"{summary['response_arm_count']} response arms."
    )
    if args.provider == "none":
        print("No response-quality claim: provider mode was prompts-only.")
    if summary["language_review_pending"]:
        print(
            "No protected-fixture claim: "
            f"{summary['language_review_pending']} language reviews remain pending."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
