#!/usr/bin/env bash
# =============================================================================
# Memory Quality Lab — deterministic regression gate for Hindi/Hinglish memory.
#
# Usage:
#   scripts/run-memory-quality-lab.sh           # full run
#   scripts/run-memory-quality-lab.sh --dry-run # list what would run
#   scripts/run-memory-quality-lab.sh --ci      # silent, exit code only
#   scripts/run-memory-quality-lab.sh --baseline  # save current as baseline
#   scripts/run-memory-quality-lab.sh --compare <baseline.json>  # diff
#
# CI integration:
#   - Schedule only after verifying stability locally for ≥10 consecutive runs.
#   - Keep fast gate (run-memory-eval.sh) on every push; lab on PR only.
#   - Retention: 7 days for reports, 30 days for baselines in CI artifacts.
#   - Restrict access to repository maintainers only.
#   - The lab must never replace the fast deterministic gate.
#
# Performance:
#   - Fast gate (run-memory-eval.sh):        target <10s  (measured ~7s)
#   - Full lab (run-memory-quality-lab.sh):  target <90s  (measured ~52s)
#   - If full lab exceeds 120s, CI should flag but not block.
# =============================================================================
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval_dir="$repo_root/evaluation/memory"
fixture_dir="$eval_dir/fixtures"
schema_dir="$eval_dir/schemas"
report_dir="$eval_dir/reports"
tmp_dir="$repo_root/tmp/memory_quality_lab_$$"
mobile_dir="$repo_root/apps/mobile"
agent_dir="$repo_root/services/realtime-agent"

# Fixture validation needs PyYAML + jsonschema. Both are declared and locked by
# the realtime-agent project, so use that managed interpreter instead of an
# arbitrary system Python whose packages vary by developer machine.
PYTHON="$agent_dir/.venv/bin/python"
if [[ ! -x "$PYTHON" ]] || ! "$PYTHON" -c 'import jsonschema, yaml' >/dev/null 2>&1; then
  echo "ERROR: memory-lab Python dependencies are unavailable." >&2
  echo "Run 'uv sync' in $agent_dir, then retry." >&2
  exit 4
fi

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
DRY_RUN=false
MODE="run"
BASELINE_REPORT=""
COMPARE_BASELINE=""
RUN_BENCHMARK=false
AUDIT_SCRIPT=""
while (($# > 0)); do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --baseline) MODE="baseline" ;;
    --compare) MODE="compare"; COMPARE_BASELINE="$2"; shift ;;
    --ci) MODE="ci" ;;
    --benchmark) RUN_BENCHMARK=true ;;
    --audit) AUDIT_SCRIPT="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Production-target rejection
# ---------------------------------------------------------------------------
reject_production_target() {
  local offenders=()
  for var in LIVEKIT_URL LIVEKIT_API_KEY LIVEKIT_API_SECRET API_BASE_URL SARVAM_API_KEY; do
    if [[ -n "${!var:-}" ]]; then
      offenders+=("$var=${!var}")
    fi
  done
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "ERROR: Production-looking environment variables are set. Refusing to run." >&2
    for o in "${offenders[@]}"; do
      echo "  $o" >&2
    done
    exit 3
  fi
}

reject_production_target

# Audit-only mode: skip all other stages, run only the conversation audit
if [[ -n "$AUDIT_SCRIPT" ]]; then
  echo "=== Conversation Audit ==="
  echo "Script: $AUDIT_SCRIPT"
  echo ""

  audit_db="$tmp_dir/audit_conversation.db"
  audit_trace_json="$tmp_dir/audit_trace.json"
  mkdir -p "$tmp_dir" "$report_dir"

  echo -n "[tracer] "
  tracer_output=$(
    cd "$mobile_dir" && \
    AUDIT_SCRIPT="$AUDIT_SCRIPT" \
    AUDIT_DB_PATH="$audit_db" \
    flutter test test/memory_conversation_tracer_test.dart --reporter compact 2>&1
  ) || true

  tracer_clean=$(echo "$tracer_output" | tr -d '\r')
  contract_match=$(echo "$tracer_clean" | grep '{"conversation_id"' | head -1 || true)
  if [[ -n "$contract_match" ]]; then
    echo "$contract_match" | $PYTHON -c "
import sys, re, json
line = sys.stdin.read()
m = re.search(r'\{.*\}', line)
if m:
    with open('$audit_trace_json', 'w') as f:
        json.dump(json.loads(m.group(0)), f, indent=2)
    print('OK')
" 2>/dev/null
    echo ""

    if [[ -s "$audit_trace_json" ]]; then
      echo "[audit]"
      audit_output_json="$report_dir/audit_$(date -u +%Y%m%d_%H%M%S).json"
      $PYTHON "$repo_root/scripts/audit-conversation.py" "$audit_trace_json" "$AUDIT_SCRIPT" --output "$audit_output_json" 2>&1
      echo ""
      echo "Audit report: $audit_output_json"
    else
      echo "FAILED: trace file empty"
    fi
  else
    echo "FAILED (no trace output)"
    echo "$tracer_output" | tail -5 >&2
  fi

  rm -rf "$tmp_dir"
  exit 0
fi

# ---------------------------------------------------------------------------
# Dry-run
# ---------------------------------------------------------------------------
if $DRY_RUN; then
  echo "Dry-run mode: would run the following without executing:"
  echo ""
  echo "  [1] Existing gate:    scripts/run-memory-eval.sh"
  echo "  [2] Schema validation: $schema_dir/validate_schemas.py --fixture ..."
  echo "  [3] Fixture runner:    FIXTURE_JSON=... flutter test test/memory_fixture_runner_test.dart"
  echo "  [4] Agent contract:    uv run --no-sync python tests/agent_contract_test.py ..."
  echo "  [5] Report:            $report_dir/report-<run_id>.json"
  echo "  [6] Baseline:          --baseline saves current report as baseline"
  echo "  [7] Compare:           --compare <baseline.json> diffs against saved baseline"
  echo "  [8] Benchmark:          --benchmark adds retrieval precision/recall/MRR metrics"
  echo ""
  echo "Fixtures to run ($(find "$fixture_dir" -name '*.yaml' -type f 2>/dev/null | wc -l | tr -d ' ') files):"
  find "$fixture_dir" -name '*.yaml' -type f | sort | while read -r f; do
    echo "  $(basename "$f")"
  done
  echo ""
  echo "Temporary directory:    $tmp_dir"
  echo "Report directory:       $report_dir"
  exit 0
fi

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
mkdir -p "$report_dir" "$tmp_dir"

run_id="lab_$(date -u +%Y%m%d_%H%M%S)_$$"
git_revision="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || echo 'unknown')"
git_dirty="False"
if [[ -n "$(git -C "$repo_root" status --porcelain 2>/dev/null)" ]]; then
  git_dirty="True"
fi
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
overall_start_sec=$SECONDS

report_json="$report_dir/report-$run_id.json"
report_md="$report_dir/report-$run_id.md"

# ---------------------------------------------------------------------------
# Helper: fixture schema hash
# ---------------------------------------------------------------------------
fixture_schema_hash() {
  if command -v shasum &>/dev/null; then
    shasum -a 256 "$schema_dir/fixture_schema.json" | awk '{print $1}'
  elif command -v sha256sum &>/dev/null; then
    sha256sum "$schema_dir/fixture_schema.json" | awk '{print $1}'
  else
    echo "unavailable"
  fi
}

# ---------------------------------------------------------------------------
# Helper: convert YAML fixture to JSON
# ---------------------------------------------------------------------------
yaml_to_json() {
  local yaml_path="$1"
  local json_path="$2"
  $PYTHON -c "
import json, sys, yaml
with open('$yaml_path', encoding='utf-8') as f:
    data = yaml.safe_load(f)
with open('$json_path', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False)
"
}

# ---------------------------------------------------------------------------
# Helper: validate fixture against schema
# ---------------------------------------------------------------------------
validate_fixture() {
  local fixture_path="$1"
  "$PYTHON" "$schema_dir/validate_schemas.py" --fixture "$fixture_path"
}

# ---------------------------------------------------------------------------
# Stage 1: Run existing gate
# ---------------------------------------------------------------------------
echo "=== Stage 1: Existing deterministic gate ==="
gate_start_sec=$SECONDS
gate_passed=true
if ! bash "$repo_root/scripts/run-memory-eval.sh" 2>&1; then
  gate_passed=false
fi
gate_duration_ms=$(( ($SECONDS - gate_start_sec) * 1000 ))

if ! $gate_passed; then
  echo "WARNING: Existing gate failed. Quality Lab continues but will report 'not ready'." >&2
fi

# ---------------------------------------------------------------------------
# Stage 2: Run fixture pipeline
# ---------------------------------------------------------------------------
echo ""
echo "=== Stage 2: Structured fixtures ==="

fixture_files=$(find "$fixture_dir" -name '*.yaml' -type f 2>/dev/null | sort)
if [[ -z "$fixture_files" ]]; then
  echo "No fixture files found in $fixture_dir"
  fixture_files=""
fi

all_results_json="["
fixture_start_sec=$SECONDS
total_pass=0
total_fail=0
p0_failures=0
p1_failures=0
p2_failures=0
p3_observations=0
first_result=true

for fixture_yaml in $fixture_files; do
  fixture_id="$(basename "$fixture_yaml" .yaml)"
  fixture_json="$tmp_dir/${fixture_id}.json"
  contract_json="$tmp_dir/${fixture_id}_contract.json"

  echo ""
  echo "--- Fixture: $fixture_id ---"

  # Schema validation
  echo -n "  [validate] "
  if validate_fixture "$fixture_yaml"; then
    echo "OK"
  else
    echo "FAILED"
    result_entry="{\"fixture_id\":\"$fixture_id\",\"passed\":false,\"severity\":\"P1\",\"failure_category\":\"PROTOCOL\",\"assertion\":\"schema_validation\"}"
    if $first_result; then first_result=false; else all_results_json+=","; fi
    all_results_json+="$result_entry"
    total_fail=$((total_fail + 1))
    p1_failures=$((p1_failures + 1))
    continue
  fi

  # Convert YAML to JSON for Dart
  echo -n "  [convert] "
  if yaml_to_json "$fixture_yaml" "$fixture_json"; then
    echo "OK"
  else
    echo "FAILED"
    result_entry="{\"fixture_id\":\"$fixture_id\",\"passed\":false,\"severity\":\"P1\",\"failure_category\":\"PROTOCOL\",\"assertion\":\"yaml_to_json\"}"
    if $first_result; then first_result=false; else all_results_json+=","; fi
    all_results_json+="$result_entry"
    total_fail=$((total_fail + 1))
    p1_failures=$((p1_failures + 1))
    continue
  fi

  # Run Dart fixture runner
  echo -n "  [dart] "
  export FIXTURE_JSON="$fixture_json"

  dart_output=$(
    cd "$mobile_dir" && \
    flutter test test/memory_fixture_runner_test.dart --reporter compact 2>&1
  ) || true

  # Check if the Dart test passed (strip carriage returns from Flutter output)
  dart_clean=$(echo "$dart_output" | tr -d '\r')
  if echo "$dart_clean" | grep -q 'All tests passed'; then
    # Extract the JSON contract line (prefixed with "Shell: " by compact reporter)
    contract_match=$(echo "$dart_clean" | grep '{"fixture_id"' | head -1 || true)
    if [[ -n "$contract_match" ]]; then
      echo "$contract_match" | $PYTHON -c "
import sys, re, json
line = sys.stdin.read()
m = re.search(r'\{.*\}', line)
if m:
    obj = json.loads(m.group(0))
    print(json.dumps(obj, ensure_ascii=False))
" > "$contract_json" 2>/dev/null
      echo "OK"
    else
      echo "FAILED (no contract output)"
      result_entry="{\"fixture_id\":\"$fixture_id\",\"passed\":false,\"severity\":\"P1\",\"failure_category\":\"FALLBACK\",\"assertion\":\"dart_no_output\"}"
      if $first_result; then first_result=false; else all_results_json+=","; fi
      all_results_json+="$result_entry"
      total_fail=$((total_fail + 1))
      p1_failures=$((p1_failures + 1))
      continue
    fi
  else
    echo "FAILED"
    result_entry="{\"fixture_id\":\"$fixture_id\",\"passed\":false,\"severity\":\"P1\",\"failure_category\":\"ADMISSION\",\"assertion\":\"dart_test_failure\"}"
    if $first_result; then first_result=false; else all_results_json+=","; fi
    all_results_json+="$result_entry"
    total_fail=$((total_fail + 1))
    p1_failures=$((p1_failures + 1))
    continue
  fi

  # Check if fixture has agent_context_expect
  has_agent=$($PYTHON -c "
import yaml
with open('$fixture_yaml', encoding='utf-8') as f:
    d = yaml.safe_load(f)
print('yes' if d.get('agent_context_expect') else 'no')
" 2>/dev/null)

  agent_pass=true
  if [[ "$has_agent" == "yes" ]]; then
    echo -n "  [agent] "
    agent_output=$(
      cd "$agent_dir" && \
      uv run --no-sync python tests/agent_contract_test.py "$contract_json" "$fixture_yaml" 2>&1
    ) || true

    if echo "$agent_output" | $PYTHON -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('agent_passed',False) else 1)" 2>/dev/null; then
      echo "OK"
    else
      echo "FAILED"
      echo "$agent_output" | $PYTHON -c "
import json, sys
try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, TypeError):
    print('    agent contract returned invalid JSON')
else:
    for failure in data.get('agent_failures', []):
        print(f'    {failure}')
" 2>/dev/null || true
      agent_pass=false
    fi
  else
    echo "  [agent] skipped (no agent_context_expect)"
  fi

  # Determine pass/fail
  if [[ "$agent_pass" == "true" ]]; then
    is_protected=$($PYTHON -c "
import yaml
with open('$fixture_yaml', encoding='utf-8') as f:
    d = yaml.safe_load(f)
print(str(d.get('protected', False)).lower())
" 2>/dev/null)

    if [[ "$is_protected" == "true" ]]; then
      severity="P1"
    else
      severity="P2"
    fi
    result_entry="{\"fixture_id\":\"$fixture_id\",\"passed\":true,\"severity\":\"$severity\"}"
    if $first_result; then first_result=false; else all_results_json+=","; fi
    all_results_json+="$result_entry"
    total_pass=$((total_pass + 1))
    echo "  PASS"
  else
    is_protected=$($PYTHON -c "
import yaml
with open('$fixture_yaml', encoding='utf-8') as f:
    d = yaml.safe_load(f)
print(str(d.get('protected', False)).lower())
" 2>/dev/null)

    if [[ "$is_protected" == "true" ]]; then
      severity="P1"
      p1_failures=$((p1_failures + 1))
    else
      severity="P2"
      p2_failures=$((p2_failures + 1))
    fi
    result_entry="{\"fixture_id\":\"$fixture_id\",\"passed\":false,\"severity\":\"$severity\",\"failure_category\":\"RETRIEVAL\",\"assertion\":\"agent_or_dart\"}"
    if $first_result; then first_result=false; else all_results_json+=","; fi
    all_results_json+="$result_entry"
    total_fail=$((total_fail + 1))
    echo "  FAIL ($severity)"
  fi
done

all_results_json+="]"
fixture_duration_ms=$(( ($SECONDS - fixture_start_sec) * 1000 ))

# ---------------------------------------------------------------------------
# Stage 3: Agent tests (existing)
# ---------------------------------------------------------------------------
echo ""
echo "=== Stage 3: Existing agent tests ==="
agent_start_sec=$SECONDS
agent_passed=true
if ! (cd "$agent_dir" && uv run --no-sync pytest -q tests/test_context.py tests/test_lifecycle.py tests/test_provider_routing.py 2>&1); then
  agent_passed=false
fi
agent_duration_ms=$(( ($SECONDS - agent_start_sec) * 1000 ))

# ---------------------------------------------------------------------------
# Stage 4: Retrieval benchmark (precision/recall/MRR per category)
# ---------------------------------------------------------------------------
benchmark_json_path="$repo_root/evaluation/memory/benchmark/benchmark_config.json"
benchmark_output_json=""
benchmark_start_sec=0
benchmark_duration_ms=0
benchmark_passed=true

if $RUN_BENCHMARK; then
  echo ""
  echo "=== Stage 4: Retrieval benchmark ==="
  if [[ ! -f "$benchmark_json_path" ]]; then
    echo "  SKIP: benchmark config not found at $benchmark_json_path"
    benchmark_passed=false
  else
    benchmark_start_sec=$SECONDS
    benchmark_output_json="$tmp_dir/benchmark_output.json"
    echo -n "  [benchmark] "
    benchmark_output=$(
      cd "$mobile_dir" && \
      BENCHMARK_JSON="$benchmark_json_path" flutter test test/memory_benchmark_runner_test.dart --reporter compact 2>&1
    ) || true

    benchmark_clean=$(echo "$benchmark_output" | tr -d '\r')
    if echo "$benchmark_clean" | grep -q 'All tests passed'; then
      contract_match=$(echo "$benchmark_clean" | grep '{"query_results"' | head -1 || true)
      if [[ -n "$contract_match" ]]; then
        echo "$contract_match" | $PYTHON -c "
import sys, re, json
line = sys.stdin.read()
m = re.search(r'\{.*\}', line)
if m:
    with open('$benchmark_output_json', 'w') as f:
        json.dump(json.loads(m.group(0)), f, indent=2)
" 2>/dev/null
        if "$PYTHON" -c "
import json, sys
with open('$benchmark_output_json', encoding='utf-8') as f:
    data = json.load(f)
overall = data.get('overall', {})
sys.exit(0 if overall.get('fail_count', 1) == 0 and overall.get('total_irrelevant_intrusions', 1) == 0 else 1)
"; then
          echo "OK"
          benchmark_passed=true
        else
          echo "FAILED (retrieval assertions)"
          benchmark_passed=false
        fi
      else
        echo "FAILED (no output)"
        benchmark_passed=false
      fi
    else
      echo "FAILED"
      benchmark_passed=false
    fi
    benchmark_duration_ms=$(( ($SECONDS - benchmark_start_sec) * 1000 ))
  fi
fi

total_duration_ms=$(( ($SECONDS - overall_start_sec) * 1000 ))

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------
ready=1
if [[ "$p0_failures" -gt 0 || "$p1_failures" -gt 0 ]] || ! $gate_passed; then
  ready=0
fi
if $RUN_BENCHMARK && ! $benchmark_passed; then
  ready=0
fi

schema_hash=$(fixture_schema_hash)
total_tests=$((total_pass + total_fail))

# Build report JSON via Python (uses json.loads for safe JSON parsing)
# Save results JSON to a temp file first
results_file="$tmp_dir/results.json"
echo "$all_results_json" > "$results_file"

$PYTHON -c "
import json
with open('$results_file', encoding='utf-8') as f:
    results = json.load(f)
data = {
    'run_id': '$run_id',
    'git_revision': '$git_revision',
    'git_dirty': $git_dirty,
    'schema_version': 1,
    'fixture_schema_hash': '$schema_hash',
    'started_at': '$started_at',
    'duration_ms': $total_duration_ms,
    'suite_durations_ms': {
        'existing_gate': $gate_duration_ms,
        'fixture_runner': $fixture_duration_ms,
        'agent_tests': $agent_duration_ms,
    },
    'summary': {
        'pass': $total_pass,
        'fail': $total_fail,
        'total': $total_tests,
        'ready': bool($ready),
        'p0_failures': $p0_failures,
        'p1_failures': $p1_failures,
        'p2_failures': $p2_failures,
        'p3_observations': $p3_observations,
    },
    'results': results,
}
with open('$report_json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

# Inject benchmark section into report if benchmark ran
if $RUN_BENCHMARK && [[ -n "$benchmark_output_json" ]] && [[ -f "$benchmark_output_json" ]]; then
  $PYTHON "$repo_root/scripts/benchmark-metrics.py" "$benchmark_output_json" > "$tmp_dir/benchmark_metrics.json" 2>/dev/null
  if [[ -s "$tmp_dir/benchmark_metrics.json" ]]; then
    $PYTHON -c "
import json
with open('$report_json', encoding='utf-8') as f:
    report = json.load(f)
with open('$tmp_dir/benchmark_metrics.json', encoding='utf-8') as f:
    benchmark = json.load(f)
report['suite_durations_ms']['benchmark'] = $benchmark_duration_ms
report['benchmark'] = benchmark
with open('$report_json', 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2, ensure_ascii=False)
" 2>/dev/null
  fi
fi

# ---------------------------------------------------------------------------
# Markdown report
# ---------------------------------------------------------------------------
cat > "$report_md" <<MDREPORT
# Memory Quality Lab Report

**Run ID:** \`$run_id\`
**Git revision:** \`$git_revision\` (dirty: $([ "$git_dirty" == "True" ] && echo 'yes' || echo 'no'))
**Fixture schema hash:** \`$schema_hash\`
**Started:** $started_at
**Duration:** ${total_duration_ms} ms

## Summary

| Metric | Value |
|--------|-------|
| Ready | **$([ "$ready" -eq 1 ] && echo 'yes' || echo 'no')** |
| Pass | $total_pass |
| Fail | $total_fail |
| Existing gate | $($gate_passed && echo 'pass' || echo 'FAIL') |
| P0 failures | $p0_failures |
| P1 failures | $p1_failures |
| P2 failures | $p2_failures |
| P3 observations | $p3_observations |

## Suite durations

| Stage | Duration (ms) |
|-------|---------------|
| Existing gate | $gate_duration_ms |
| Fixture runner | $fixture_duration_ms |
| Agent tests | $agent_duration_ms |
$([ "$RUN_BENCHMARK" = true ] && echo "| Benchmark | $benchmark_duration_ms |" || true)

## Results

| Fixture | Passed | Severity |
|---------|--------|----------|
MDREPORT

$PYTHON -c "
import json
with open('$results_file', encoding='utf-8') as f:
    results = json.load(f)
for r in results:
    fid = r['fixture_id']
    passed = r['passed']
    sev = r.get('severity', '-')
    print(f'| {fid} | {passed} | {sev} |')
" >> "$report_md"

echo "" >> "$report_md"
echo "Report contains no transcript, memory, packet, or prompt text." >> "$report_md"

# Append benchmark metrics to markdown if available
if $RUN_BENCHMARK && [[ -s "$tmp_dir/benchmark_metrics.json" ]]; then
  echo "" >> "$report_md"
  echo "## Retrieval Benchmark" >> "$report_md"
  echo "" >> "$report_md"
  echo "| Category | Precision | Recall | F1 | MRR | Intrusions | Passed |" >> "$report_md"
  echo "|----------|-----------|--------|-----|-----|------------|--------|" >> "$report_md"
  $PYTHON -c "
import json
with open('$tmp_dir/benchmark_metrics.json', encoding='utf-8') as f:
    m = json.load(f)
by_cat = m.get('by_category', {})
for cat, v in sorted(by_cat.items()):
    p = v['precision']; r = v['recall']; f1 = v['f1']; mrr = v['mrr']
    intr = v['irrelevant_intrusions']; qp = v['queries_passed']
    print(f'| {cat} | {p:.3f} | {r:.3f} | {f1:.3f} | {mrr:.3f} | {intr} | {qp} |')
overall = m.get('overall', {})
print(f'| **Overall** | {overall[\"precision\"]:.3f} | {overall[\"recall\"]:.3f} | {overall[\"f1\"]:.3f} | {overall[\"mrr\"]:.3f} | {overall[\"irrelevant_intrusions\"]} | {overall[\"queries_passed\"]} |')
" >> "$report_md"
fi

# ---------------------------------------------------------------------------
# Baseline mode: save report as named baseline
# ---------------------------------------------------------------------------
if [[ "$MODE" == "baseline" ]]; then
  baseline_name="baseline_$(date -u +%Y%m%d_%H%M%S)"
  baseline_file="$report_dir/$baseline_name.json"
  cp "$report_json" "$baseline_file"
  echo ""
  echo "Baseline saved: $baseline_file"
  rm -rf "$tmp_dir"
  if [[ "$ready" -eq 1 ]]; then exit 0; else exit 1; fi
fi

# ---------------------------------------------------------------------------
# Compare mode: diff against a baseline report
# ---------------------------------------------------------------------------
if [[ "$MODE" == "compare" ]]; then
  if [[ ! -f "$COMPARE_BASELINE" ]]; then
    echo "ERROR: baseline file not found: $COMPARE_BASELINE" >&2
    rm -rf "$tmp_dir"
    exit 4
  fi

  comparison_json="$report_dir/comparison_$(date -u +%Y%m%d_%H%M%S).json"
  $PYTHON -c "
import json

with open('$COMPARE_BASELINE', encoding='utf-8') as f:
    baseline = json.load(f)
with open('$report_json', encoding='utf-8') as f:
    candidate = json.load(f)

baseline_results = {r['fixture_id']: r for r in baseline.get('results', [])}
candidate_results = {r['fixture_id']: r for r in candidate.get('results', [])}
all_ids = sorted(set(list(baseline_results.keys()) + list(candidate_results.keys())))

regressions = []
improvements = []
unchanged = []
new_fixtures = []
removed_fixtures = []
benchmark_regressions = []

for fid in all_ids:
    bl = baseline_results.get(fid)
    cd = candidate_results.get(fid)
    if bl is None:
        new_fixtures.append(fid)
    elif cd is None:
        removed_fixtures.append(fid)
    elif bl.get('passed') and not cd.get('passed'):
        regressions.append(fid)
    elif not bl.get('passed') and cd.get('passed'):
        improvements.append(fid)
    else:
        unchanged.append(fid)

baseline_benchmark = baseline.get('benchmark', {}).get('overall')
candidate_benchmark = candidate.get('benchmark', {}).get('overall')
if baseline_benchmark and not candidate_benchmark:
    benchmark_regressions.append('benchmark results missing')
elif baseline_benchmark and candidate_benchmark:
    for metric in ('precision', 'recall', 'mrr'):
        if candidate_benchmark.get(metric, 0) < baseline_benchmark.get(metric, 0):
            benchmark_regressions.append(f'{metric} decreased')
    if candidate_benchmark.get('irrelevant_intrusions', 0) > baseline_benchmark.get('irrelevant_intrusions', 0):
        benchmark_regressions.append('irrelevant intrusions increased')

comparison = {
    'baseline': {
        'run_id': baseline.get('run_id'),
        'git_revision': baseline.get('git_revision'),
        'total': baseline['summary']['total'],
        'pass': baseline['summary']['pass'],
        'fail': baseline['summary']['fail'],
        'ready': baseline['summary']['ready'],
    },
    'candidate': {
        'run_id': candidate.get('run_id'),
        'git_revision': candidate.get('git_revision'),
        'total': candidate['summary']['total'],
        'pass': candidate['summary']['pass'],
        'fail': candidate['summary']['fail'],
        'ready': candidate['summary']['ready'],
    },
    'regressions': regressions,
    'improvements': improvements,
    'unchanged': unchanged,
    'new_fixtures': new_fixtures,
    'removed_fixtures': removed_fixtures,
    'readiness_regression': bool(baseline['summary']['ready'] and not candidate['summary']['ready']),
    'benchmark_regressions': benchmark_regressions,
    'regression_count': len(regressions),
    'improvement_count': len(improvements),
    'verdict': 'reject' if regressions or benchmark_regressions or (baseline['summary']['ready'] and not candidate['summary']['ready']) else ('improved' if improvements else 'unchanged'),
}
with open('$comparison_json', 'w', encoding='utf-8') as f:
    json.dump(comparison, f, indent=2, ensure_ascii=False)
"

  echo ""
  echo "=== Baseline vs Candidate ==="
  echo "Baseline: $COMPARE_BASELINE"
  echo "Candidate: $report_json"
  echo "Comparison: $comparison_json"
  echo ""
  $PYTHON -c "
import json
with open('$comparison_json', encoding='utf-8') as f:
    c = json.load(f)
bl = c['baseline']; cd = c['candidate']
print(f\"Baseline: {bl['pass']}P/{bl['fail']}F/{bl['total']}T  (ready: {bl['ready']})\")
print(f\"Candidate: {cd['pass']}P/{cd['fail']}F/{cd['total']}T  (ready: {cd['ready']})\")
print()
print(f\"Regressions: {c['regression_count']}\")
for r in c['regressions']: print(f'  FAIL (was pass): {r}')
if c.get('readiness_regression'):
    print('  FAIL: candidate readiness regressed')
for regression in c.get('benchmark_regressions', []):
    print(f'  FAIL: benchmark {regression}')
print(f\"Improvements: {c['improvement_count']}\")
for i in c['improvements']: print(f'  PASS (was fail): {i}')
print(f\"Unchanged: {len(c['unchanged'])}\")
if c['new_fixtures']:
    print(f\"New fixtures: {len(c['new_fixtures'])}\")
    for n in c['new_fixtures']: print(f'  NEW: {n}')
if c['removed_fixtures']:
    print(f\"Removed fixtures: {len(c['removed_fixtures'])}\")
    for r in c['removed_fixtures']: print(f'  REMOVED: {r}')
print()
print(f\"Verdict: {c['verdict'].upper()}\")
"
  rm -rf "$tmp_dir"

  if $PYTHON -c "
import json, sys
with open('$comparison_json', encoding='utf-8') as f:
    c = json.load(f)
sys.exit(0 if c.get('regression_count', 0) == 0 and not c.get('readiness_regression', False) and not c.get('benchmark_regressions') else 1)
" 2>/dev/null; then
    exit 0
  else
    echo "FAILED: candidate has regressions."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Output / CI mode
# ---------------------------------------------------------------------------
if [[ "$MODE" == "ci" ]]; then
  rm -rf "$tmp_dir"
  if [[ "$ready" -eq 1 ]]; then exit 0; else exit 1; fi
fi
echo ""
echo "=== Report ==="
echo "JSON: $report_json"
echo "MD:   $report_md"
echo ""
echo "Ready: $([ "$ready" -eq 1 ] && echo 'yes' || echo 'no')"
echo "Pass: $total_pass  Fail: $total_fail  Total: $((total_pass + total_fail))"

# Performance guardrail: warn if lab is unexpectedly slow
if [[ $total_duration_ms -gt 120000 ]]; then
  echo "WARNING: lab took ${total_duration_ms}ms, exceeds 120s guardrail." >&2
fi

# Cleanup temp
rm -rf "$tmp_dir"

if [[ "$ready" -eq 1 ]]; then
  exit 0
else
  echo "FAILED: quality gate not ready."
  exit 1
fi
