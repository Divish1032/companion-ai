#!/usr/bin/env bash
set -euo pipefail

compose=(docker compose --env-file .env -f infra/docker-compose.yml)
"${compose[@]}" up -d kokoro-tts

for _ in $(seq 1 30); do
  if curl --fail --silent --show-error http://127.0.0.1:8880/health >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent --show-error http://127.0.0.1:8880/health >/dev/null

for voice in hf_alpha hf_beta hm_omega hm_psi; do
  audio_file=$(mktemp)
  trap 'rm -f "$audio_file"' EXIT
  curl --fail --silent --show-error \
    --header 'content-type: application/json' \
    --output "$audio_file" \
    --data "{\"model\":\"kokoro\",\"input\":\"नमस्ते, आज आपका दिन कैसा रहा?\",\"voice\":\"${voice}\",\"response_format\":\"pcm\",\"stream\":true,\"lang_code\":\"h\"}" \
    http://127.0.0.1:8880/v1/audio/speech
  bytes=$(wc -c <"$audio_file" | tr -d ' ')
  if (( bytes < 960 || bytes % 2 != 0 )); then
    echo "Kokoro voice ${voice} produced invalid PCM (${bytes} bytes)" >&2
    exit 1
  fi
  rm -f "$audio_file"
  trap - EXIT
done

echo "Kokoro Hindi smoke passed for hf_alpha, hf_beta, hm_omega, and hm_psi."
