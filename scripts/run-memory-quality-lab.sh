#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval_dir="$repo_root/evaluation/memory"
fixture_dir="$eval_dir/fixtures"
schema_dir="$eval_dir/schemas"
report_dir="$eval_dir/reports"
tmp_dir="$repo_root/tmp/memory_quality_lab_$$"
mobile_dir="$repo_root/apps/mobile"
agent_dir="$repo_root/services/realtime-agent"

PYTHON="python3"

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
DRY_RUN=false
MODE="run"
BASELINE_REPORT=""
COMPARE_BASELINE=""
while (($# > 0)); do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --baseline) MODE="baseline" ;;
    --compare) MODE="compare"; COMPARE_BASELINE="$2"; shift ;;
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
  $PYTHON "$schema_dir/validate_schemas.py" --fixture "$fixture_path" 2>/dev/null
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

total_duration_ms=$(( ($SECONDS - overall_start_sec) * 1000 ))

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------
ready=1
if [[ "$p0_failures" -gt 0 || "$p1_failures" -gt 0 ]] || ! $gate_passed; then
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
  exit 0
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
    'regression_count': len(regressions),
    'improvement_count': len(improvements),
    'verdict': 'reject' if regressions else ('improved' if improvements else 'unchanged'),
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

bl = c['baseline']
cd = c['candidate']
print(f\"Baseline: {bl['pass']}P/{bl['fail']}F/{bl['total']}T  (ready: {bl['ready']})\")
print(f\"Candidate: {cd['pass']}P/{cd['fail']}F/{cd['total']}T  (ready: {cd['ready']})\")
print()
print(f\"Regressions: {c['regression_count']}\")
for r in c['regressions']:
    print(f'  FAIL (was pass): {r}')
print(f\"Improvements: {c['improvement_count']}\")
for i in c['improvements']:
    print(f'  PASS (was fail): {i}')
print(f\"Unchanged: {len(c['unchanged'])}\")
if c['new_fixtures']:
    print(f\"New fixtures: {len(c['new_fixtures'])}\")
    for n in c['new_fixtures']:
        print(f'  NEW: {n}')
if c['removed_fixtures']:
    print(f\"Removed fixtures: {len(c['removed_fixtures'])}\")
    for r in c['removed_fixtures']:
        print(f'  REMOVED: {r}')
print()
print(f\"Verdict: {c['verdict'].upper()}\")
"

  rm -rf "$tmp_dir"

  if $PYTHON -c "
import json, sys
with open('$comparison_json', encoding='utf-8') as f:
    c = json.load(f)
sys.exit(0 if c['regression_count'] == 0 else 1)
" 2>/dev/null; then
    exit 0
  else
    echo "FAILED: candidate has regressions."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Output (default run mode)
# ---------------------------------------------------------------------------
echo ""
echo "=== Report ==="
echo "JSON: $report_json"
echo "MD:   $report_md"
echo ""
echo "Ready: $([ "$ready" -eq 1 ] && echo 'yes' || echo 'no')"
echo "Pass: $total_pass  Fail: $total_fail  Total: $((total_pass + total_fail))"

# Cleanup temp
rm -rf "$tmp_dir"

if [[ "$ready" -eq 1 ]]; then
  exit 0
else
  echo "FAILED: quality gate not ready."
  exit 1
fi
