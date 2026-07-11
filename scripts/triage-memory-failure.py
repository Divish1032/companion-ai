#!/usr/bin/env python3
"""Generate triage proposal skeletons from a failed quality-lab report.

Usage:
  python3 scripts/triage-memory-failure.py <report.json> [--fixture <id>]

Reads a redacted quality-lab report JSON and generates one triage proposal
skeleton per failing fixture. Each skeleton includes:
  - Failure category, severity, assertion
  - Actual vs expected labels/IDs (from report)
  - Placeholder fields for the agent to fill: hypothesis, fix area, risk
  - Allowed code areas from the agent constraints schema

The agent fills in the proposal fields and writes the completed triage back
as evaluation/memory/reports/triage_<triage_id>.json .

Never writes transcript or memory content text.
"""

from __future__ import annotations

import json
import sys
from datetime import UTC, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIR = REPO_ROOT / "evaluation" / "memory" / "schemas"
REPORT_DIR = REPO_ROOT / "evaluation" / "memory" / "reports"

FAILURE_CATEGORIES = {
    "ADMISSION": "Wrong durable record was created, rejected, or replaced.",
    "CONSOLIDATION": "Receipt, decay, summary, graph, or supersession state is wrong.",
    "ROUTING": "Incorrect memory-needed route or lookup bypass.",
    "RETRIEVAL": "Wrong, missing, duplicate, or forbidden packet selection.",
    "PROTOCOL": "Stale/invalid packet or sequence-correlation problem.",
    "PROMPT": "Wrong role, budget, grouping, or latest-user priority.",
    "FALLBACK": "Timeout/model/vector/reranker failure does not fail safely.",
    "SAFETY_PRIVACY": "Sensitive content or safety ordering rule is violated.",
}

RELEVANT_CODE_MAP: dict[str, list[str]] = {
    "ADMISSION": [
        "apps/mobile/lib/features/chat_history/data/app_database.dart",
        "apps/mobile/test/app_database_memory_test.dart",
    ],
    "CONSOLIDATION": [
        "apps/mobile/lib/features/chat_history/data/app_database.dart",
    ],
    "ROUTING": [
        "services/realtime-agent/app/memory_router.py",
        "services/realtime-agent/app/memory_planner.py",
        "services/realtime-agent/app/lifecycle.py",
    ],
    "RETRIEVAL": [
        "apps/mobile/lib/features/chat_history/data/app_database.dart",
        "apps/mobile/lib/features/chat_history/data/memory_embedding_service.dart",
        "services/realtime-agent/app/context.py",
    ],
    "PROTOCOL": [
        "services/realtime-agent/app/lifecycle.py",
        "apps/mobile/lib/features/voice_chat/presentation/voice_chat_controller.dart",
    ],
    "PROMPT": [
        "services/realtime-agent/app/context.py",
    ],
    "FALLBACK": [
        "apps/mobile/lib/features/chat_history/data/memory_embedding_service.dart",
        "services/realtime-agent/app/lifecycle.py",
    ],
    "SAFETY_PRIVACY": [
        "services/realtime-agent/app/safety.py",
        "services/realtime-agent/app/context.py",
    ],
}


def load_report(report_path: str) -> dict:
    with open(report_path, encoding="utf-8") as fh:
        return json.load(fh)


def load_fixture(fixture_id: str) -> dict | None:
    fixture_path = REPO_ROOT / "evaluation" / "memory" / "fixtures" / f"{fixture_id}.yaml"
    if not fixture_path.exists():
        return None
    import yaml
    with open(fixture_path, encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def infer_category(result: dict, fixture: dict | None) -> str:
    category = result.get("failure_category")
    if category and category in FAILURE_CATEGORIES:
        return category
    assertion = result.get("assertion", "")
    if "schema" in assertion.lower():
        return "PROTOCOL"
    if any(term in assertion.lower() for term in ("label", "id", "memory_id")):
        return "RETRIEVAL"
    if any(term in assertion.lower() for term in ("dart", "fallback", "output")):
        return "FALLBACK"
    return "RETRIEVAL"


def map_severity(fixture: dict | None, result: dict) -> str:
    if result.get("severity"):
        return result["severity"]
    if fixture and fixture.get("protected"):
        return "P1"
    return "P2"


def generate_proposals(report: dict, target_fixture: str | None = None) -> list[dict]:
    proposals = []
    run_id = report.get("run_id", "unknown")
    results = report.get("results", [])

    for result in results:
        fixture_id = result.get("fixture_id", "")
        if target_fixture and fixture_id != target_fixture:
            continue
        if result.get("passed"):
            continue

        fixture = load_fixture(fixture_id)
        category = infer_category(result, fixture)
        severity = map_severity(fixture, result)

        triage_id = f"triage_{fixture_id}_{datetime.now(UTC).strftime('%Y%m%d_%H%M%S')}"

        proposal: dict = {
            "triage_id": triage_id,
            "run_id": run_id,
            "fixture_id": fixture_id,
            "created_at": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "failure": {
                "category": category,
                "severity": severity,
                "assertion": result.get("assertion", "unknown"),
                "actual_vs_expected": {
                    "expected_labels": result.get("expected_labels", []),
                    "actual_labels": result.get("actual_labels", []),
                    "expected_memory_ids": result.get("expected_memory_ids", []),
                    "actual_memory_ids": result.get("actual_memory_ids", []),
                    "route": result.get("route", ""),
                    "packet_count": result.get("packet_count", 0),
                    "fallback": result.get("fallback", False),
                },
            },
            "proposal": {
                "hypothesis": "<AGENT: describe root cause hypothesis>",
                "suggested_fix_area": _format_code_areas(category) + " <AGENT: narrow to specific line>",
                "minimal_reproducer_fixture": {
                    "id": f"<AGENT: propose fixture ID e.g. {fixture_id}_repro>",
                    "tags": fixture.get("tags", []) if fixture else [],
                    "description": "<AGENT: describe what minimal turns reproduce this>",
                    "expected_behavior": "<AGENT: what should happen>",
                },
                "patch_description": "<AGENT: describe the proposed code change>",
                "files_to_change": RELEVANT_CODE_MAP.get(category, []),
                "risk": "<AGENT: Low | Medium | High>",
            },
            "verification": {},
            "status": "proposed",
            "human_review": {
                "required": True,
                "reviewer": "<ASSIGN>",
                "review_date": None,
                "review_notes": "",
            },
        }
        proposals.append(proposal)

    return proposals


def _format_code_areas(category: str) -> str:
    areas = RELEVANT_CODE_MAP.get(category, [])
    return ", ".join(areas) if areas else "<AGENT: identify relevant source file>"


def write_proposal(proposal: dict) -> str:
    path = REPORT_DIR / f"{proposal['triage_id']}.json"
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(proposal, fh, indent=2, ensure_ascii=False)
    return str(path)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: triage-memory-failure.py <report.json> [--fixture <id>]")
        sys.exit(1)

    report_path = sys.argv[1]
    target_fixture = None
    if len(sys.argv) >= 4 and sys.argv[2] == "--fixture":
        target_fixture = sys.argv[3]

    report = load_report(report_path)
    proposals = generate_proposals(report, target_fixture)

    if not proposals:
        print("No failing fixtures found in report.")
        sys.exit(0)

    written = []
    for proposal in proposals:
        path = write_proposal(proposal)
        written.append(path)
        print(f"  {proposal['fixture_id']} [{proposal['failure']['severity']}] "
              f"{proposal['failure']['category']} -> {path}")

    print(f"\nGenerated {len(written)} triage proposal(s).")
    print("Agent: fill in <AGENT: ...> placeholders in each proposal file.")
    print("Then run: scripts/check-improvement-gate.py <triage.json> after the fix.")


if __name__ == "__main__":
    main()
