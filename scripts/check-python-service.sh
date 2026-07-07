#!/usr/bin/env bash
set -euo pipefail

service_dir="$1"

cd "$service_dir"
uv run ruff check .
uv run pytest
