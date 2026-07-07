#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "AGENTS.md"
  "README.md"
  "docs/README.md"
  "docs/AGENT_CONTEXT.md"
  "docs/SPRINTS.md"
  "docs/PRD_MASTER.md"
  "docs/architecture/voice_pipeline.md"
  "docs/architecture/mobile_app_native_audio.md"
  "docs/architecture/backend_agent_livekit.md"
  "docs/architecture/safety_privacy.md"
  "docs/architecture/observability_metrics.md"
  "docs/architecture/unit_economics.md"
  "docs/spikes/README.md"
  "docs/privacy/README.md"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "missing required file: $file" >&2
    exit 1
  fi
done

python3 - <<'PY'
from pathlib import Path
bad = []
for path in [*Path(".").glob("*.md"), *Path("docs").rglob("*.md")]:
    text = path.read_text(encoding="utf-8")
    chars = sorted({c for c in text if ord(c) > 127})
    if chars:
        bad.append((path, "".join(chars[:20])))
if bad:
    for path, chars in bad:
        print(f"non-ascii characters in {path}: {chars}")
    raise SystemExit(1)
PY

echo "docs verification passed"

