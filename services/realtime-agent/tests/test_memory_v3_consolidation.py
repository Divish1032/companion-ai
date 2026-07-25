from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
CATALOG = EVAL_ROOT / "fixtures" / "consolidation_transition_cases.json"


def test_offline_consolidation_transition_catalog_passes() -> None:
    result = subprocess.run(
        [sys.executable, str(EVAL_ROOT / "validate_consolidation.py")],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "9 development cases" in result.stdout
    assert "runtime_writes=0" in result.stdout


def test_entity_link_with_unsafe_signal_fails_closed(tmp_path: Path) -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    case = next(item for item in catalog["cases"] if item["id"] == "explicit_sister_alias_links_v3")
    case["accepted_links"][0]["signal"] = "shared_participant"
    fixture = tmp_path / "unsafe-consolidation.json"
    fixture.write_text(json.dumps(catalog), encoding="utf-8")

    result = subprocess.run(
        [
            sys.executable,
            str(EVAL_ROOT / "validate_consolidation.py"),
            "--catalog",
            str(fixture),
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode != 0
    assert "uses an unsafe entity signal" in result.stderr


def test_thread_cannot_close_from_similarity_without_explicit_link() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    case = next(
        item for item in catalog["cases"]
        if item["id"] == "similar_outcome_without_link_stays_open_v3"
    )

    sys.path.insert(0, str(EVAL_ROOT))
    from consolidation_reference import build_projections

    snapshot = build_projections(case)
    assert snapshot["threads"][0]["status"] == "due"
    assert snapshot["threads"][0]["supporting_observation_ids"] == [
        "observation_exam_thread"
    ]
