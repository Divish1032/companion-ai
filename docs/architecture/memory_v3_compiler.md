# Memory V3 Compiler and Phone Admission

Status: Task 3.1 hybrid compiler implemented locally; protected and live exit
gates pending.

Last updated: 2026-07-20

This document records the implemented Task 3 boundary. The server is stateless
compute. The encrypted phone database owns jobs, validation, admission,
idempotency, controls, and all durable memory state.

## 1. Runtime Boundary

After a completed user and assistant exchange, the phone creates a bounded,
immutable request snapshot of at most 12 final messages. A newer unclaimed
snapshot for the same session coalesces the older one. A leased snapshot never
changes. Formation receives no historical memory context.

The background coordinator drains jobs after 15 seconds of idle time, at app
startup, and at session end. It uses a five-minute lease, at most five attempts,
and bounded exponential retry. Compiler failure never blocks or weakens the
voice response path.

The server endpoint is `POST /v1/memory/compile`. It validates the strict
request and asks one configured model for a minimal
`MemorySemanticEnvelopeV3`. The model selects predicates, exact evidence and
object quotes, grounded entities, modality, explicitness, temporal class,
categorical affect, and a conservative sensitivity hint. It receives neither
the full transcript nor any memory database content and cannot write phone
state.

The model does not construct a durable observation. Deterministic server code
owns unique candidate IDs, kind derivation, evidence roles and offsets, `ADD`,
STT confidence caps, temporal confidence, numeric affect mapping, utility,
privacy floors, and instruction-like confirmation. Negated, hypothetical,
quoted, ambiguous, ungrounded, safety-override, restricted, and forbidden atoms
are recorded as typed construction rejections for evaluation and never reach
phone admission. The public phone contract is `memory_compile_v3_1`.

Formation is append-only. Every candidate is an atomic `ADD` observation from
the current bounded turns. Corrections are new assertions and results are new
outcomes. Entity linking, `REINFORCE`, `SUPERSEDE`, thread closure, recurrence,
and reflection creation belong only to the separate Task 4 consolidation
contract.

Sarvam's current official Chat Completions reference documents strict
`json_schema` output, bearer authentication, optional reasoning, token caps,
and the `choices[0].message.content` response used by this adapter. Formation
disables reasoning explicitly: the model guidance warns that reasoning can
consume the completion budget and leave no visible answer. It does not document
a `store` request field, so the adapter does not send one. Provider data
handling remains governed by the reviewed provider agreement rather than an
invented request guarantee. Verification sources: [Sarvam Chat Completions
reference](https://docs.sarvam.ai/api-reference/chat/chat-completions) and
[Sarvam-30B limitations](https://docs.sarvam.ai/api/getting-started/models/sarvam-30b#known-limitations).

The path is disabled by default on both sides:

- API: `ENABLE_MEMORY_V3_COMPILER=false`;
- phone: `ENABLE_MEMORY_V3_COMPILER=false`;
- phone timezone: `MEMORY_TIMEZONE=Asia/Kolkata` by default.

Enabling the API alone cannot create memory. Enabling the phone alone only
creates retryable local jobs if the API is unavailable.

## 2. Deterministic Construction and Phone Validation

Server construction performs exact, request-local checks before candidates are
returned. This is defense in depth, not mutation authority. The phone still
parses the response with an unknown-field-rejecting runtime model and runs the
reusable production admission validator in this order:

1. schema, contract, job, ontology, and kind-predicate compatibility;
2. append-only operation and kind-predicate compatibility;
3. unique source identity, final transcript status, exact fragment, and exact
   offsets;
4. user versus assistant role provenance;
5. safety-override exchange exclusion;
6. quoted, hypothetical, and negated-state exclusion;
7. independent local credential, crisis, and restricted-data policy;
8. exact local subject, relationship-hint, object, and target grounding;
9. STT, compiler confidence, and temporal confidence;
10. deterministic observation identity, user controls, and replay;
11. admission tier and atomic local write.

The LLM cannot override any check with a higher confidence score. The local
sensitivity classifier is deliberately independent of the model's privacy
label.

## 3. Admission Matrix

| Candidate state | Local result | Durable observation |
| --- | --- | --- |
| Explicit, exact, normal-risk, adequately confident `ADD` | `admitted` | Yes, `auto_admit` |
| Implied, low/unknown STT, low compiler confidence, or weak time resolution | `deferred` | Yes, no projection in Task 3 |
| Explicit correction represented as a grounded atomic new assertion | `admitted` | Yes, `auto_admit`; Task 4 resolves history |
| Explicit-only candidate or instruction-like memory | `confirmation_required` | Yes, no projection in Task 3 |
| Ungrounded subject/object/target/relationship, pure quoted, hypothetical, negated, role-contaminated, safety, restricted, forbidden, or user-rejected | `rejected` | No |
| Same semantic content and evidence replay | `duplicate` | No new row |
| Empty candidate list | successful empty run | No |

Low-quality evidence also downgrades temporal state to `uncertain` and caps
epistemic confidence. Deferred and confirmation-required observations cannot be
marked proactive. Assistant evidence can create only a typed
`assistant_commitment`; it can never establish a user fact.

## 4. Atomic State and Telemetry

Task 3 adds four local tables:

- `memory_compile_jobs_v3` for lease, retry, and completion state;
- `memory_compile_job_messages_v3` for immutable transcript snapshots;
- `memory_compile_runs_v3` for content-free model, usage, timing, and failure
  metadata;
- `memory_compile_candidate_outcomes_v3` for content-free disposition reasons.

A successful response writes accepted/deferred observations, exact evidence,
candidate outcomes, run metadata, and job completion in one transaction. A
failure writes only redacted run metadata and retry state. Production logs and
run tables contain IDs, counts, categories, timings, and error codes, but no
transcript, evidence fragment, memory statement, embedding, credential, or
device identifier.

Clear History deletes compiler work and outcomes before transcript rows in the
same local transaction. Observation, evidence, user controls, request
snapshots, run records, and candidate outcomes reject in-place updates.

## 5. Evaluation

Local contract and adversarial tests cover bounded snapshots, semantic-schema
parsing, deterministic IDs and ontology construction, exact offsets, typed
construction failures, strict phone parsing,
exact evidence, assistant contamination, low STT, privacy, safety override,
atomic correction, confirmation, replay, user-control precedence, assistant
commitments, empty results, retry, and deletion.

The remote formation harness is deliberately opt-in and stores only redacted
candidate signatures. It separately reports transport, provider-envelope,
semantic-schema, semantic extraction, deterministic construction, and actual
phone-admission results. Matching uses maximum-cardinality bipartite matching;
object scoring cannot pass from words that appear only in a broad evidence
span. It records p50/p95/max latency, requested and actual model identity,
fingerprint hash, tokens, cost when reviewed rates are supplied, repetitions,
and an incremental checkpoint after every request.

The committed Task 1 catalog is now explicitly `development` because exact
scenarios informed earlier prompt iterations. `protected` and `robustness`
splits remain empty rather than being fabricated. They require independently
authored fixtures and native/professional Hindi/Hinglish approval. Raw semantic
atoms and transcript-bearing debug state are written only when
`--debug-artifact` explicitly points inside ignored `tmp/`.

```bash
services/api/.venv/bin/python scripts/run-memory-v3-compiler-eval.py \
  --provider openai_compatible \
  --base-url "$MEMORY_V3_COMPILER_BASE_URL" \
  --model "$MEMORY_V3_COMPILER_MODEL" \
  --allow-remote \
  --split development \
  --repetitions 3 \
  --allow-unreviewed \
  --input-micro-inr-per-million REVIEWED_INPUT_RATE \
  --output-micro-inr-per-million REVIEWED_OUTPUT_RATE
```

The final flag is a development-only override while the synthetic Hinglish
catalog still awaits human language review. It must be an explicit operator
choice. Reports under `evaluation/memory_v3/compiler_runs/` are local and
ignored by Git.
If reviewed rates are omitted, token usage remains measured but currency cost
is honestly reported as unknown.

DeepSeek uses JSON Object mode rather than OpenAI strict JSON Schema. The
compiler still parses that object into the strict semantic-atom model and then
uses identical deterministic construction. Evaluate the configured,
officially verified model ID in non-thinking mode first:

```bash
services/api/.venv/bin/python scripts/run-memory-v3-compiler-eval.py \
  --provider deepseek \
  --request-profile deepseek_json_object \
  --base-url https://api.deepseek.com \
  --model deepseek-v4-flash \
  --api-key-env DEEPSEEK_API_KEY \
  --allow-remote \
  --allow-unreviewed
```

Keep `DEEPSEEK_API_KEY` only in the ignored local `.env` or process
environment; the evaluation runner loads the repository `.env` without
overriding an already exported value. A model name or provider-profile change
requires a fresh gate; it does not authorize enabling the V3 runtime.

Historical paid synthetic evaluation of the retired full-observation compiler
covered Sarvam-30B, Sarvam-105B, Qwen3-235B
Instruct, Kimi-K2.5, and DeepSeek V4 Flash/Pro. No candidate passed. The final atomic Sarvam-105B
adversarial run produced 12/12 schema-valid responses but only 46.67% exact
recall, 73.33% structural recall, 53.85% exact precision, and one
kind-predicate hard-policy violation. Mean latency was 2,861 ms and measured
cost was approximately INR 0.206 for 12 snapshots. The Hugging Face route later
returned HTTP 402 after its monthly included credits were exhausted; that
capacity failure is not scored as model quality.

DeepSeek V4 Flash non-thinking reached 53.33% exact recall, 66.67% precision,
73.33% structural recall, and 3,821 ms mean latency with two provider/schema
failures. V4 Pro non-thinking regressed to 26.67% exact recall and 50%
precision with four provider/schema failures. Pro thinking mode reached only
33.33% exact recall and 62.5% precision, produced five provider/schema
failures, and increased mean latency to 30,665 ms. All three had zero observed
hard-policy failures, but none warrants the full-catalog spend or runtime use.

Those scores do not qualify Task 3.1 and must not be compared as if only the
model changed; the contract, trust boundary, and evaluator all changed. The
redacted historical decision record and ignored-artifact hashes are in
`evaluation/memory_v3/reviews/task3_compiler_model_review.json`. Task 4 runtime
work and V3 cutover remain blocked. Task 3.1 first needs a development
comparison, independently authored robustness fixtures, native-reviewed
protected fixtures, repeated runs, and zero protected provenance/privacy
failures. Schema success is not sufficient.

A bounded Task 3.1 DeepSeek smoke found that JSON Object mode did not follow a
schema that was only described in prose: 2 of 4 initial requests failed strict
semantic parsing. Adding the exact semantic JSON Schema to that provider
profile removed schema errors in a two-scenario rerun and produced 2/2 semantic
and structural matches, but only 1/2 exact construction/admission matches. The
remaining deterministic support-style canonicalization gap was fixed and unit
tested without another paid call. This is diagnostic development evidence, not
a quality score, and did not justify a full repeated spend. The redacted record
is `evaluation/memory_v3/reviews/task3_1_hybrid_smoke_review.json`.

## 6. Deliberate Non-Goals

Task 3 does not:

- consolidate or historically reconcile observations into claims, episodes, threads, graphs, or
  reflections;
- retrieve V3 memory for a user query;
- change the response prompt or companion persona;
- show V3 memory notices to the user;
- dual-write or migrate V2 memory;
- enable V3 by default or delete the measured V2 baseline.
