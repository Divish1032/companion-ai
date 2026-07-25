from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
CATALOG = EVAL_ROOT / "fixtures" / "task1_core_scenarios.json"
HOLDOUT_TEMPLATE = EVAL_ROOT / "fixtures" / "compiler_holdout_catalog.template.json"


def test_task1_catalog_is_valid_and_honest_about_pending_review() -> None:
    result = subprocess.run(
        [sys.executable, str(EVAL_ROOT / "validate.py")],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    scenarios = catalog["scenarios"]
    assert 20 <= len(scenarios) <= 30
    assert all(item["source"] == "synthetic" for item in scenarios)
    assert all(item["protection"] == "review_candidate" for item in scenarios)
    assert all(item["language_review"]["status"] == "pending" for item in scenarios)


def test_prompts_only_runner_builds_three_matched_arms(tmp_path: Path) -> None:
    output = tmp_path / "baseline.json"
    result = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "run-memory-v3-baselines.py"),
            "--provider",
            "none",
            "--skip-v2-probe",
            "--output",
            str(output),
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    report = json.loads(output.read_text(encoding="utf-8"))
    assert report["run"]["provider"] == "none"
    assert report["run"]["v2_probe_status"] == "skipped"
    assert report["summary"]["quality_claim_allowed"] is False
    assert report["summary"]["language_review_pending"] == 25

    query_results = [
        query
        for scenario in report["scenarios"]
        for query in scenario["queries"]
    ]
    for query in query_results:
        assert [arm["arm_id"] for arm in query["arms"]] == [
            "no_memory",
            "v2",
            "oracle",
        ]

    crisis = next(
        query
        for scenario in report["scenarios"]
        if scenario["scenario_id"] == "crisis_bypass_with_memory_v3"
        for query in scenario["queries"]
    )
    assert all(arm["response_status"] == "safety_override" for arm in crisis["arms"])
    assert all(not arm["messages"] for arm in crisis["arms"])
    assert all("112" in arm["response"] for arm in crisis["arms"])

    paraphrase = next(
        query
        for scenario in report["scenarios"]
        if scenario["scenario_id"] == "paraphrased_episode_recall_v3"
        for query in scenario["queries"]
    )
    no_memory, _, oracle = paraphrase["arms"]
    assert no_memory["intended_memory"] == []
    assert oracle["intended_memory"][0]["predicate"] == "experienced_event"
    assert all("Goa road trip" not in item["content"] for item in no_memory["messages"])
    assert any("Goa road trip" in item["content"] for item in oracle["messages"])


def test_paid_provider_requires_explicit_confirmation() -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "run-memory-v3-baselines.py"),
            "--provider",
            "sarvam",
            "--skip-v2-probe",
            "--allow-unreviewed-fixtures",
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        env={},
    )

    assert result.returncode != 0
    assert "--confirm-paid-synthetic-run" in result.stderr


def test_paid_provider_refuses_pending_language_reviews() -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "run-memory-v3-baselines.py"),
            "--provider",
            "sarvam",
            "--skip-v2-probe",
            "--confirm-paid-synthetic-run",
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        env={},
    )

    assert result.returncode != 0
    assert "language reviews are pending" in result.stderr


def test_task3_1_compiler_freeze_is_intact() -> None:
    result = subprocess.run(
        [sys.executable, str(EVAL_ROOT / "verify_compiler_freeze.py")],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "task3_1_freeze_candidate_clean_20260720" in result.stdout


def test_holdout_template_is_structurally_valid_but_not_release_qualified() -> None:
    structural = subprocess.run(
        [
            sys.executable,
            str(EVAL_ROOT / "validate_compiler_holdout.py"),
            "--catalog",
            str(HOLDOUT_TEMPLATE),
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    release = subprocess.run(
        [
            sys.executable,
            str(EVAL_ROOT / "validate_compiler_holdout.py"),
            "--catalog",
            str(HOLDOUT_TEMPLATE),
            "--release-gate",
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert structural.returncode == 0, structural.stdout + structural.stderr
    assert release.returncode != 0
    assert "release gate refuses template_only=true" in release.stderr
    assert "20-30 protected scenarios" in release.stderr


def test_holdout_cannot_be_selected_as_development_data() -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "run-memory-v3-compiler-eval.py"),
            "--catalog",
            str(HOLDOUT_TEMPLATE),
            "--provider",
            "none",
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode != 0
    assert "has no development split" in result.stderr
