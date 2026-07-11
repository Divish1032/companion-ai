#!/usr/bin/env python3
"""Validate fixture YAML and report JSON against their schemas."""

import json
import sys
from pathlib import Path

import jsonschema
import yaml


REPO_ROOT = Path(__file__).resolve().parents[3]
SCHEMA_DIR = REPO_ROOT / "evaluation" / "memory" / "schemas"

FIXTURE_SCHEMA_PATH = SCHEMA_DIR / "fixture_schema.json"
REPORT_SCHEMA_PATH = SCHEMA_DIR / "report_schema.json"


def load_json_schema(path: Path) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def validate_fixture_yaml(fixture_path: Path) -> list[str]:
    schema = load_json_schema(FIXTURE_SCHEMA_PATH)
    with open(fixture_path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    errors = []
    try:
        jsonschema.validate(data, schema)
    except jsonschema.ValidationError as exc:
        errors.append(str(exc.message))
    return errors


def validate_report_json(report_path: Path) -> list[str]:
    schema = load_json_schema(REPORT_SCHEMA_PATH)
    with open(report_path, encoding="utf-8") as fh:
        data = json.load(fh)
    errors = []
    try:
        jsonschema.validate(data, schema)
    except jsonschema.ValidationError as exc:
        errors.append(str(exc.message))
    return errors


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: validate_schemas.py [--fixture <path> | --report <path>]")
        sys.exit(1)

    mode = sys.argv[1]
    if mode == "--fixture":
        path = Path(sys.argv[2])
        errors = validate_fixture_yaml(path)
    elif mode == "--report":
        path = Path(sys.argv[2])
        errors = validate_report_json(path)
    else:
        print(f"Unknown mode: {mode}")
        sys.exit(1)

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        sys.exit(1)

    print(f"OK: {path}")
