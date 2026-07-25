#!/usr/bin/env python3
"""Verify that every artifact in a Memory V3 compiler freeze is unchanged."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker


REPO_ROOT = Path(__file__).resolve().parents[2]
EVAL_ROOT = REPO_ROOT / "evaluation" / "memory_v3"
FREEZE_SCHEMA = EVAL_ROOT / "schemas" / "compiler_freeze.schema.json"
DEFAULT_FREEZE = EVAL_ROOT / "freezes" / "task3_1_candidate_clean_20260720.json"


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be a JSON object")
    return value


def schema_errors(instance: dict[str, Any], schema_path: Path = FREEZE_SCHEMA) -> list[str]:
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors: list[str] = []
    for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
        location = "/".join(str(part) for part in error.absolute_path) or "<root>"
        errors.append(f"{schema_path.name} at {location}: {error.message}")
    return errors


def verify_freeze(
    manifest_path: Path,
    *,
    repo_root: Path = REPO_ROOT,
) -> tuple[dict[str, Any], list[str]]:
    manifest = load_json(manifest_path)
    errors = schema_errors(manifest)
    if errors:
        return manifest, errors

    root = repo_root.resolve()
    seen: set[str] = set()
    for artifact in manifest["artifacts"]:
        relative = artifact["path"]
        if relative in seen:
            errors.append(f"duplicate frozen artifact: {relative}")
            continue
        seen.add(relative)
        candidate = (root / relative).resolve()
        if candidate == root or root not in candidate.parents:
            errors.append(f"frozen artifact escapes repository: {relative}")
            continue
        if not candidate.is_file():
            errors.append(f"frozen artifact is missing: {relative}")
            continue
        actual = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if actual != artifact["sha256"]:
            errors.append(
                f"frozen artifact changed: {relative} "
                f"(expected {artifact['sha256']}, got {actual})"
            )
    return manifest, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_FREEZE)
    args = parser.parse_args()
    try:
        manifest, errors = verify_freeze(args.manifest.resolve())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if errors:
        print("Memory V3 compiler freeze verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        f"Memory V3 compiler freeze verified: {manifest['freeze_id']} "
        f"({len(manifest['artifacts'])} artifacts, status={manifest['status']})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
