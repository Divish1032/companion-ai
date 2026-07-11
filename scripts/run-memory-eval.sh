#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root/apps/mobile"
flutter test \
  test/app_database_memory_test.dart \
  test/memory_embedding_service_test.dart

cd "$repo_root/services/realtime-agent"
uv run --no-sync pytest -q \
  tests/test_context.py \
  tests/test_lifecycle.py \
  tests/test_provider_routing.py

echo "Hindi/Hinglish deterministic memory evaluation passed"
