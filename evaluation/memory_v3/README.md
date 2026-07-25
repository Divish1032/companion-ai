# Memory V3 Evaluation Package

This directory is the executable Task 1 companion to
`docs/evals/memory_v3_evaluation.md`. It does not implement Memory V3 runtime
behavior.

Contents:

- `fixtures/task1_core_scenarios.json`: synthetic Hindi/Hinglish review
  candidates and deterministic expectations.
- `fixtures/compiler_splits.json`: disjoint development, robustness, and
  protected assignments. The latter two remain empty until independent
  authoring/review; the harness refuses an empty protected claim.
- `schemas/fixture_catalog.schema.json`: strict fixture catalog contract.
- `schemas/baseline_report.schema.json`: reproducible prompt/response artifact
  contract.
- `schemas/compiler_report.schema.json`: transcript-redacted Task 3 compiler
  formation report contract.
- `schemas/compiler_holdout_catalog.schema.json`: independently authored Task
  3.2 protected/robustness catalog contract.
- `freezes/task3_1_candidate_clean_20260720.json`: byte-level Task 3.1 candidate
  boundary that holdout results must match.
- `TASK3_2_REVIEWER_GUIDE.md`: blind authoring and fluent-review protocol.
- `schemas/consolidation_transition_catalog.schema.json` and
  `fixtures/consolidation_transition_cases.json`: development-only Task 4
  transition workbench; these are not protected fixtures.
- `validate.py`: JSON Schema and cross-reference validation.
- `LANGUAGE_REVIEW.md`: per-scenario human review and promotion workflow.
- `baselines/`: documentation for generated baseline artifacts. Generated
  reports are local artifacts and are not committed by default.

The Task 1 arms are:

- `no_memory`: the current persona and recent turns with durable memory removed.
- `v2`: the unchanged phone V2 replay, retrieval result, and current agent
  prompt builder.
- `oracle`: the same current prompt builder with the minimum fixture-authored
  memory plus an evaluator-only use plan. This is an upper-bound diagnostic, not
  a production prompt path.

`v3` is intentionally absent until a V3 runtime exists.

Task 3.1 adds a separate opt-in compiler formation harness. It evaluates model
semantic atoms, deterministic construction, and the actual reusable Dart phone
admission validator as distinct stages. Reports include typed transport/schema
failures, optimal bipartite matching, exact versus structural results,
repetitions, checkpoints, requested/actual model provenance, p50/p95/max
latency, tokens, and reviewed-rate cost when configured. Reports never contain
transcript or evidence text. An explicit debug artifact is synthetic-only and
must be written under ignored `tmp/`. Formation is atomic `ADD` only and does
not claim Task 4 consolidation or V3 response quality. Historical and hybrid
smoke decisions are recorded under `reviews/`.

Task 3.2 uses a separate catalog authored without access to the compiler prompt
or development fixtures. The freeze verifier rejects any changed compiler,
constructor, admission, contract, or evaluator artifact. Remote holdout runs
require the complete catalog size, no-memory distribution, hard-gate coverage,
and independent natural/aligned language approval; `--allow-unreviewed` cannot
override that boundary. The committed catalog is a structural template only
and cannot pass the release gate.

The Task 4 workbench is deterministic and offline. It validates projection
transitions and order-independent rebuild from synthetic admitted-observation
summaries. It never opens the app database, calls a model, or changes retrieval,
prompting, or responses.

Queries contain no recent turns unless `recent_turn_ids` is explicitly present.
This prevents a long-term-memory case from passing because the answer happened
to remain in the short conversation window. Pronoun and immediate-continuity
cases opt into only the exact recent turns they require.

## Honesty Rules

- Synthetic wording is not called protected until language review is approved.
- Prompt capture is not called response evaluation.
- Mock-model output is not a product-quality baseline.
- A paid or remote model is never called unless the operator explicitly chooses
  a provider mode and supplies credentials.
- A baseline records the exact Git revision, dirty state, fixture hash, persona
  hash, provider, model, and prompt messages.

## Commands

Validate fixture and schema contracts:

```bash
services/realtime-agent/.venv/bin/python evaluation/memory_v3/validate.py
```

Create matched prompt baselines using the current V2 replay:

```bash
services/realtime-agent/.venv/bin/python scripts/run-memory-v3-baselines.py \
  --provider none
```

Live response capture is deliberately opt-in and is documented by the runner's
`--help` output. It must use only synthetic fixtures. The runner also refuses
paid calls while language reviews remain pending unless the operator supplies a
separate explicit unreviewed-fixture override.

Validate the compiler harness without making a remote call:

```bash
services/api/.venv/bin/python scripts/run-memory-v3-compiler-eval.py \
  --provider none
```

Verify the frozen Task 3.1 boundary and structural holdout template:

```bash
services/api/.venv/bin/python evaluation/memory_v3/verify_compiler_freeze.py
services/api/.venv/bin/python evaluation/memory_v3/validate_compiler_holdout.py
```

The real independently authored catalog must additionally pass
`validate_compiler_holdout.py --catalog <private-catalog> --release-gate` before
any remote protected or robustness run.

Validate the development-only Task 4 transition workbench:

```bash
services/api/.venv/bin/python evaluation/memory_v3/validate_consolidation.py
```

Run the deliberately narrow deterministic-only ablation through the same
constructor and production phone validator:

```bash
services/api/.venv/bin/python scripts/run-memory-v3-compiler-eval.py \
  --provider none \
  --pipeline deterministic_only
```

Remote compiler comparison requires `--allow-remote`, credentials, a model,
and the separately explicit `--allow-unreviewed` flag while language review is
pending. Repeated comparisons use `--repetitions`; split selection uses
`--split`. See `docs/architecture/memory_v3_compiler.md`.

For DeepSeek V4, pass `--request-profile deepseek_json_object` and a
`DEEPSEEK_API_KEY` environment variable. This selects provider JSON Object mode
plus non-thinking extraction while retaining strict local schema and grounding
validation. The V3 runtime remains disabled unless the model passes the entire
formation gate.

`deepseek_json_object_thinking` is available only as an explicit comparison
profile. The July 2026 evaluation found materially worse latency and no quality
gate pass, so neither DeepSeek profile is approved for runtime use.

## Promotion to Protected

A review candidate becomes protected only after a native or professionally
fluent Hindi/Hinglish reviewer records approval in the catalog. P0/P1 behavior
expectations remain release-blocking once promoted. Changing approved wording
returns that scenario to pending review.
