#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <production.env> <runtime-root>" >&2
  exit 64
fi

environment_file=$1
runtime_root=$2
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)

set -a
# shellcheck disable=SC1090
source "$environment_file"
set +a

for required in DEPLOY_DOMAIN LIVEKIT_INTERFACE LIVEKIT_API_KEY LIVEKIT_API_SECRET; do
  if [[ -z ${!required:-} ]]; then
    echo "missing required value: $required" >&2
    exit 65
  fi
done

install -d -m 0750 "$runtime_root/config"
envsubst '${DEPLOY_DOMAIN} ${LIVEKIT_INTERFACE} ${LIVEKIT_API_KEY} ${LIVEKIT_API_SECRET}' \
  < "$repo_root/infra/production/livekit.yaml.template" \
  > "$runtime_root/config/livekit.yaml"
chmod 0640 "$runtime_root/config/livekit.yaml"
