#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="$repo_root/services/realtime-agent/.venv/bin/python"

if [[ ! -x "$python_bin" ]]; then
  echo "ERROR: realtime-agent Python environment is unavailable." >&2
  echo "Run 'uv sync' in services/realtime-agent, then retry." >&2
  exit 4
fi

cd "$repo_root"

"$python_bin" evaluation/memory_v3/validate.py

api_python="$repo_root/services/api/.venv/bin/python"
if [[ ! -x "$api_python" ]]; then
  echo "ERROR: API Python environment is unavailable." >&2
  exit 4
fi
"$api_python" scripts/run-memory-v3-compiler-eval.py --provider none

bash "$repo_root/scripts/run-memory-eval.sh"

cd "$repo_root/services/realtime-agent"
"$python_bin" -m pytest -q tests/test_memory_v3_evaluation.py

cd "$repo_root"
"$python_bin" scripts/run-memory-v3-baselines.py "$@"
