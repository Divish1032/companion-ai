#!/usr/bin/env bash
set -euo pipefail

compose=(docker compose --env-file .env -f infra/docker-compose.yml)
"${compose[@]}" up -d realtime-agent
"${compose[@]}" exec -T realtime-agent python -m app.sarvam_fallback_e2e
