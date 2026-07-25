#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root/apps/mobile"
flutter test \
  test/app_database_memory_test.dart \
  test/companion_memory_test.dart \
  test/companion_state_database_test.dart \
  test/memory_embedding_service_test.dart \
  test/memory_vector_index_test.dart \
  test/long_term_memory_service_test.dart \
  test/app_database_migration_test.dart \
  test/memory_v3_schema_test.dart \
  test/memory_v3_compiler_test.dart \
  test/database_encryption_test.dart \
  test/widget_test.dart

cd "$repo_root/services/api"
uv run --no-sync pytest -q \
  tests/test_memory_extraction.py \
  tests/test_memory_v3_compiler.py \
  tests/test_health.py \
  tests/test_model_readiness.py

cd "$repo_root/services/realtime-agent"
uv run --no-sync pytest -q \
  tests/test_context.py \
  tests/test_lifecycle.py \
  tests/test_provider_routing.py

echo "Hindi/Hinglish deterministic + asynchronous memory evaluation passed"
