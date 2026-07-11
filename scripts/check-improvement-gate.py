#!/usr/bin/env python3
"""Verify that a candidate fix meets all improvement gate conditions.

Usage:
  1. Before fix:    scripts/run-memory-quality-lab.sh --baseline
  2. Apply fix
  3. After fix:     scripts/run-memory-quality-lab.sh  (produces report)
  4. Verify gates:  scripts/check-improvement-gate.py <triage.json> \
                       --baseline <baseline.json> \
                       --candidate <candidate.json>

A candidate is an improvement only when ALL of these pass:
  - Target failing fixture passes in the candidate run.
  - scripts/run-memory-eval.sh passes.
  - All protected fixtures pass in the candidate run.
  - No P0 or P1 regression appears in comparison.
  - Human approval recorded.
"""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def load_json(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save_json(data: dict, path: str) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)


def run_existing_gate() -> tuple[bool, str]:
    result = subprocess.run(
        ["bash", str(REPO_ROOT / "scripts" / "run-memory-eval.sh")],
        capture_output=True, text=True, timeout=120,
        cwd=str(REPO_ROOT),
    )
    return result.returncode == 0, result.stdout + result.stderr


def check_improvement_gate(
    triage: dict,
    baseline_report: dict,
    candidate_report: dict,
    *,
    skip_gate: bool = False,
) -> dict:
    fixture_id = triage["fixture_id"]
    results = {"passed": True, "checks": {}, "diagnostics": {}}

    baseline_results = {r["fixture_id"]: r for r in baseline_report.get("results", [])}
    candidate_results = {r["fixture_id"]: r for r in candidate_report.get("results", [])}

    # 1. Target fixture passes
    cd_result = candidate_results.get(fixture_id, {})
    target_passes = cd_result.get("passed", False)
    results["checks"]["target_fixture_passes"] = target_passes
    if not target_passes:
        results["passed"] = False
        results["diagnostics"]["target_fixture"] = f"{fixture_id} still fails in candidate"

    # 2. Existing gate passes
    if not skip_gate:
        gate_ok, gate_output = run_existing_gate()
        results["checks"]["existing_gate_passes"] = gate_ok
        if not gate_ok:
            results["passed"] = False
            results["diagnostics"]["existing_gate"] = gate_output[:500]
    else:
        results["checks"]["existing_gate_passes"] = "skipped"

    # 3. All protected fixtures pass
    protected_failures = []
    for fid, result in candidate_results.items():
        if not result.get("passed"):
            severity = result.get("severity", "")
            if severity in ("P0", "P1"):
                protected_failures.append(fid)
    results["checks"]["all_protected_pass"] = len(protected_failures) == 0
    if protected_failures:
        results["passed"] = False
        results["diagnostics"]["protected_failures"] = protected_failures

    # 4. No regressions
    regressions = []
    for fid, cd_result in candidate_results.items():
        bl_result = baseline_results.get(fid, {})
        if bl_result.get("passed") and not cd_result.get("passed"):
            regressions.append(fid)
    results["checks"]["no_regressions"] = len(regressions) == 0
    if regressions:
        results["passed"] = False
        results["diagnostics"]["regressions"] = regressions

    # 5. Human approval
    human_review = triage.get("human_review", {})
    has_approval = human_review.get("review_date") is not None and human_review.get("reviewer")
    results["checks"]["human_approved"] = has_approval
    if not has_approval:
        results["passed"] = False
        results["diagnostics"]["human_review"] = "Human approval not recorded in triage"

    # Summary
    passed_count = sum(1 for v in results["checks"].values() if v is True)
    total_count = len(results["checks"])
    results["summary"] = f"{passed_count}/{total_count} gates passed"

    return results


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Verify improvement gates for a candidate memory fix."
    )
    parser.add_argument("triage_json", help="Path to the triage proposal JSON")
    parser.add_argument("--baseline", required=True, help="Path to baseline report JSON")
    parser.add_argument("--candidate", required=True, help="Path to candidate report JSON")
    parser.add_argument("--skip-gate", action="store_true",
                        help="Skip running scripts/run-memory-eval.sh")
    parser.add_argument("--output", help="Write result to a JSON file")
    args = parser.parse_args()

    triage = load_json(args.triage_json)
    baseline = load_json(args.baseline)
    candidate = load_json(args.candidate)

    result = check_improvement_gate(
        triage, baseline, candidate,
        skip_gate=args.skip_gate,
    )

    print(f"Improvement gate: {result['summary']}")
    for check_name, value in result["checks"].items():
        status = "PASS" if value is True else ("FAIL" if value is False else str(value))
        print(f"  [{status}] {check_name}")

    if result.get("diagnostics"):
        print("\nDiagnostics:")
        for key, msg in result["diagnostics"].items():
            if isinstance(msg, list):
                print(f"  {key}: {', '.join(msg)}")
            else:
                print(f"  {key}: {msg}")

    if args.output:
        save_json(result, args.output)
        print(f"\nResult written to {args.output}")

    sys.exit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
