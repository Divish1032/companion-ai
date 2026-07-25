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
  "docs/architecture/long_term_memory.md"
  "docs/architecture/memory_v3.md"
  "docs/architecture/memory_v3_storage.md"
  "docs/architecture/memory_v3_compiler.md"
  "docs/architecture/memory_v3_consolidation.md"
  "docs/evals/memory_v3_evaluation.md"
  "docs/deployment/ubuntu.md"
  "docs/spikes/README.md"
  "docs/privacy/README.md"
  "contracts/memory_v3/README.md"
  "contracts/memory_v3/memory_observation.schema.json"
  "contracts/memory_v3/memory_semantic_atoms.schema.json"
  "contracts/memory_v3/memory_compile_request.schema.json"
  "contracts/memory_v3/memory_compile_response.schema.json"
  "contracts/memory_v3/memory_consolidation.schema.json"
  "contracts/memory_v3/memory_context_request.schema.json"
  "contracts/memory_v3/memory_brief.schema.json"
  "contracts/memory_v3/memory_usage_event.schema.json"
  "contracts/memory_v3/validate_schemas.py"
  "evaluation/memory_v3/README.md"
  "evaluation/memory_v3/LANGUAGE_REVIEW.md"
  "evaluation/memory_v3/fixtures/task1_core_scenarios.json"
  "evaluation/memory_v3/fixtures/compiler_splits.json"
  "evaluation/memory_v3/schemas/fixture_catalog.schema.json"
  "evaluation/memory_v3/schemas/baseline_report.schema.json"
  "evaluation/memory_v3/schemas/compiler_report.schema.json"
  "evaluation/memory_v3/schemas/compiler_holdout_catalog.schema.json"
  "evaluation/memory_v3/schemas/compiler_freeze.schema.json"
  "evaluation/memory_v3/schemas/consolidation_transition_catalog.schema.json"
  "evaluation/memory_v3/schemas/development_review.schema.json"
  "evaluation/memory_v3/schemas/live_response_review.schema.json"
  "evaluation/memory_v3/reviews/task1_ai_development_review.json"
  "evaluation/memory_v3/reviews/task1_live_pre_task2_review.json"
  "evaluation/memory_v3/reviews/task3_1_hybrid_smoke_review.json"
  "evaluation/memory_v3/fixtures/compiler_holdout_catalog.template.json"
  "evaluation/memory_v3/fixtures/consolidation_transition_cases.json"
  "evaluation/memory_v3/freezes/task3_1_candidate_clean_20260720.json"
  "evaluation/memory_v3/TASK3_2_REVIEWER_GUIDE.md"
  "evaluation/memory_v3/verify_compiler_freeze.py"
  "evaluation/memory_v3/validate_compiler_holdout.py"
  "evaluation/memory_v3/consolidation_reference.py"
  "evaluation/memory_v3/validate_consolidation.py"
  "evaluation/memory_v3/validate.py"
  "scripts/run-memory-v3-baselines.py"
  "scripts/run-memory-v3-compiler-eval.py"
  "scripts/run-memory-v3-eval.sh"
  "apps/mobile/test/memory_v3_baseline_probe_test.dart"
  "apps/mobile/test/memory_v3_schema_test.dart"
  "apps/mobile/test/memory_v3_compiler_test.dart"
  "apps/mobile/test/memory_v3_admission_test.dart"
  "apps/mobile/tool/memory_v3_admission_bridge.dart"
  "apps/mobile/lib/features/chat_history/data/memory_v3_admission.dart"
  "services/api/app/memory_v3_compiler.py"
  "services/api/tests/test_memory_v3_compiler.py"
  "services/realtime-agent/tests/test_memory_v3_evaluation.py"
  "services/realtime-agent/tests/test_memory_v3_consolidation.py"
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
for path in [
    *Path(".").glob("*.md"),
    *Path("docs").rglob("*.md"),
    *Path("contracts").rglob("*.md"),
]:
    text = path.read_text(encoding="utf-8")
    chars = sorted({c for c in text if ord(c) > 127})
    if chars:
        bad.append((path, "".join(chars[:20])))
if bad:
    for path, chars in bad:
        print(f"non-ascii characters in {path}: {chars}")
    raise SystemExit(1)
PY

python3 contracts/memory_v3/validate_schemas.py
python3 evaluation/memory_v3/validate.py
python3 evaluation/memory_v3/verify_compiler_freeze.py
python3 evaluation/memory_v3/validate_compiler_holdout.py
python3 evaluation/memory_v3/validate_consolidation.py

echo "docs verification passed"
