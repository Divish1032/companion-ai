#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "apps/mobile/pubspec.yaml"
  "apps/mobile/lib/main.dart"
  "apps/mobile/.env.example"
  "services/api/pyproject.toml"
  "services/api/app/main.py"
  "services/api/.env.example"
  "services/realtime-agent/pyproject.toml"
  "services/realtime-agent/app/main.py"
  "services/realtime-agent/app/providers/interfaces.py"
  "services/realtime-agent/app/providers/routing.py"
  "services/realtime-agent/.env.example"
  "infra/docker-compose.yml"
  "config/personas/hindi_companion_v1.toml"
  "config/safety/crisis_placeholder.toml"
  ".env.example"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "missing Sprint 0 file: $file" >&2
    exit 1
  fi
done

echo "Sprint 0 scaffold verification passed"
