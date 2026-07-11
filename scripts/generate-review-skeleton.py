#!/usr/bin/env python3
"""Generate human review skeletons for all fixtures.

Usage:
  python3 scripts/generate-review-skeleton.py [--round 1]

Creates one review JSON per fixture under evaluation/memory/reports/reviews/ .
Each skeleton pre-fills fixture metadata and leaves boolean review checks
as null (unreviewed). The human reviewer fills in the verdict, checks, and
signs off.

Per Section 7.3:
  - Reviewers: product owner assigns Hindi/Hinglish reviewer.
  - Review pilot: begin with the first 10 fixtures; expand to 15 after.
  - Fixture text must be native or professionally fluent Hindi/Hinglish.
  - Reviewer validates expected behaviour, not preferred assistant wording.
"""

from __future__ import annotations

import json
from datetime import date, datetime, timezone
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
FIXTURE_DIR = REPO_ROOT / "evaluation" / "memory" / "fixtures"
REVIEW_DIR = REPO_ROOT / "evaluation" / "memory" / "reports" / "reviews"


def load_fixture_yaml(path: Path) -> dict | None:
    try:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except Exception:
        return None


def _extract_route(fixture: dict) -> str:
    query = fixture.get("query", {})
    expect = query.get("expect", {})
    return expect.get("route", "unspecified")


def _extract_safety(fixture: dict) -> str:
    tags = fixture.get("tags", [])
    if "safety" in tags or "crisis" in tags or "P0" in tags:
        return "safety_relevant"
    if any(t in tags for t in ("corruption", "protocol")):
        return "safety_relevant"
    return "normal"


def generate_review_skeleton(fixture_path: Path, round_number: int = 1) -> dict | None:
    fixture = load_fixture_yaml(fixture_path)
    if fixture is None:
        return None

    fixture_id = fixture.get("id", fixture_path.stem)
    tags = fixture.get("tags", [])
    protected = fixture.get("protected", False)
    has_agent = fixture.get("agent_context_expect") is not None
    has_query = fixture.get("query") is not None

    storage_expect = fixture.get("storage_expect", {})
    query_expect = fixture.get("query", {}).get("expect", {})
    agent_expect = fixture.get("agent_context_expect", {})

    turn_count = sum(
        len(session.get("turns", [])) for session in fixture.get("sessions", [])
    )
    session_count = len(fixture.get("sessions", []))

    return {
        "fixture_id": fixture_id,
        "fixture_file": f"{fixture_path.name}",
        "reviewer": "<ASSIGN>",
        "reviewer_role": "<product_owner | hindi_reviewer | maintainer>",
        "review_date": None,
        "verdict": "needs_language_review",
        "effort_minutes": 0,
        "checks": {
            "natural_language_quality": None,
            "memory_semantics_correct": None,
            "route_classification_correct": None,
            "safety_classification_correct": None,
            "expected_memory_ids_correct": None,
            "no_overlap_with_existing_tests": None,
            "deterministic_expectations_valid": None,
        },
        "ambiguity_findings": "",
        "changes_requested": "",
        "review_pilot_round": round_number,
        "fixture_summary": {
            "protected": protected,
            "tags": tags,
            "sessions": session_count,
            "turns": turn_count,
            "has_storage_expect": bool(storage_expect),
            "storage_labels_expected": storage_expect.get("must_exist_labels", []),
            "has_query_expect": has_query,
            "query_route_expected": _extract_route(fixture),
            "has_agent_expect": has_agent,
            "safety_relevance": _extract_safety(fixture),
        },
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Generate fixture review skeletons.")
    parser.add_argument("--round", type=int, default=1, help="Review pilot round number.")
    args = parser.parse_args()

    REVIEW_DIR.mkdir(parents=True, exist_ok=True)

    fixture_files = sorted(FIXTURE_DIR.glob("*.yaml"))
    if not fixture_files:
        print("No fixture files found.")
        return

    generated = []
    for fixture_path in fixture_files:
        skeleton = generate_review_skeleton(fixture_path, args.round)
        if skeleton is None:
            print(f"  SKIP: {fixture_path.name} (could not parse)")
            continue

        out_path = REVIEW_DIR / f"review_{skeleton['fixture_id']}.json"
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(skeleton, fh, indent=2, ensure_ascii=False)
        generated.append(skeleton)
        print(f"  {skeleton['fixture_id']} ({skeleton['fixture_summary']['turns']} turns, "
              f"{'protected' if skeleton['fixture_summary']['protected'] else 'unprotected'}) "
              f"-> {out_path.name}")

    print(f"\nGenerated {len(generated)} review skeletons in {REVIEW_DIR}")
    print(f"Review pilot round: {args.round}")
    print("\nNext steps:")
    print("  1. Assign Hindi/Hinglish reviewer(s)")
    print("  2. Reviewer fills in each review_*.json (verdict, checks, effort)")
    print("  3. Re-run: python3 scripts/generate-review-skeleton.py --round <N>")
    print("     Existing completed reviews are not overwritten if verdict is set.")


if __name__ == "__main__":
    main()
