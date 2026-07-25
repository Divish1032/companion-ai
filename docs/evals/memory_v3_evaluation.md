# Memory V3 Evaluation

Status: Approved evaluation design; Task 1 fixture, baseline harness, bounded
live response capture, and AI development review implemented. Native-human
language and blinded response review remain pending.

Last updated: 2026-07-20

This document defines the release gates for the Memory V3 rewrite described in
`docs/architecture/memory_v3.md`. It extends the existing deterministic V2
memory lab from storage and retrieval checks through final response quality.

No Memory V3 implementation may be described as improved based only on unit
tests, retrieval metrics, model self-assessment, or provider claims.

## Task 1 Implementation Status

The executable package is in `evaluation/memory_v3/`.

Implemented:

- 25 synthetic review-candidate scenarios: 11 P0 and 14 P1;
- formation, consolidation, retrieval, response, and hard-gate expectations;
- 17 scenarios selected for live response comparison;
- explicit recent-turn controls so long-term cases cannot pass from a short
  conversation window;
- unchanged V2 phone replay through `resolveMemoryTurn` and query-scoped local
  retrieval;
- matched no-memory, V2, and oracle prompt arms;
- preservation of V2 direct responses and crisis safety overrides outside the
  response LLM;
- strict fixture and baseline-report schemas;
- prompts-only baseline mode and an explicitly confirmed paid-provider mode;
- hash-bound AI linguistic and semantic review of all 25 scenarios, with nine
  wording corrections and no false claim of native-human review;
- one intentional live Sarvam baseline with 51 reviewed response arms and zero
  provider failures.

Still pending and therefore not claimed:

- native or professionally fluent Hindi/Hinglish approval of fixture wording;
- promotion of any review candidate to protected;
- blinded human response ratings;
- LLM-judge calibration;
- subjective response-quality thresholds derived from those ratings.

The 25 Task 1 scenarios are development-only for compiler evaluation because
their exact examples influenced iterations of the retired full-observation
prompt. `evaluation/memory_v3/fixtures/compiler_splits.json` enforces this
classification. The protected and robustness compiler splits are intentionally
empty until independently authored scenarios pass native/professional language
review.

Neither the AI development review nor the live baseline promotes a fixture to
`protected`. The live rubric ratings are engineering evidence, not a substitute
for blinded human response ratings.

The first complete local prompts-only replay on 2026-07-20 classified the
unchanged V2 boundary as follows:

- 17 queries required memory;
- 1 reached the response boundary through the exact-state direct-answer path;
- 13 had relevant source evidence in V2 local storage but failed at retrieval;
- 3 had no relevant evidence representation in V2 storage and were classified
  at formation or admission;
- 7 of 8 no-memory queries correctly abstained;
- the remaining no-memory query took the crisis safety bypass;
- no false-positive memory reached the response boundary and no probe failed.

This is a causal prompt-boundary baseline, not a semantic accuracy or response
quality score. The classification uses source-turn provenance to distinguish a
storage representation from a later retrieval miss.

The intentional live Sarvam run (`sarvam-30b`) completed on 2026-07-20 with no
provider errors. Structured rubric review of the 17 response scenarios found:

| Arm | Passed | Total | Pass rate |
| --- | ---: | ---: | ---: |
| No memory | 4 | 17 | 23.53% |
| Unchanged V2 | 5 | 17 | 29.41% |
| Oracle memory | 12 | 17 | 70.59% |

The oracle's 41.18 percentage-point uplift over V2 demonstrates that relevant,
structured memory can materially improve the final response. The oracle still
failed five rubrics, so retrieval alone is not sufficient. Observed response
boundary defects were:

- the core persona's default question instruction overrode `question_recommended:
  false` and explicit listen-only preferences;
- a user preferred-name statement was inverted into the assistant saying "I am
  Aditi";
- sensitive abstention said the PIN could not be disclosed instead of saying it
  was not retained;
- a change-over-time answer omitted the previous state even though both claims
  were present;
- recent-turn selection retained an assistant acknowledgement while dropping
  the user turn containing the answer to a pronoun follow-up;
- 15 of 51 responses were entirely Roman script despite the Devanagari persona
  instruction.

The machine-readable review is
`evaluation/memory_v3/reviews/task1_live_pre_task2_review.json`. Its source
report stays under ignored `tmp/` because it contains paid-model prompt
snapshots; the review records the exact artifact, fixture, provider, model, run,
and SHA-256 hashes. This evidence passes the gate to implement the Task 2 schema
without runtime behavior, but it explicitly fails the runtime-cutover gate.

## 1. Evaluation Questions

The evaluation must answer these questions independently:

1. Semantic extraction: Did the model identify the right atomic meaning and
   exact evidence without inventing policy fields?
2. Construction: Did deterministic code ground and type the atom correctly?
3. Admission: Did the production phone validator accept, defer, confirm, or
   reject it correctly?
4. Consolidation: Did observations form accurate current claims, episodes,
   threads, graph relations, and reflections?
5. Retrieval: Did the query return the right current or historical evidence, or
   correctly abstain?
6. Use decision: Did the system choose an appropriate memory-use mode?
7. Response: Did the final Hindi/Hinglish response use memory faithfully and
   naturally?
8. Safety/privacy: Did personalization preserve every protected boundary?
9. Operations: Did latency, cost, deletion, retry, and fallback stay bounded?

Failures are classified at their first causal stage. A fluent final response
does not hide unsupported formation, and correct retrieval does not excuse poor
memory use.

## 2. Baselines

Task 1 must record four comparable baselines:

### 2.1 No-memory baseline

The response model receives persona, current user message, and bounded recent
turns, but no durable memory. This measures the actual value added by memory.

### 2.2 V2 baseline

Run the current production-domain V2 admission, retrieval, prompt, and response
path before replacing it. Record exact code revision, model versions, flags,
latency, and cost.

### 2.3 V3 candidate baseline

Run the implemented V3 path with the same scenario and response-model settings.
Change one experimental factor at a time when diagnosing a failure.

### 2.4 Oracle-memory baseline

A human reviewer supplies the minimum ideal memory brief while all other prompt
and model settings remain fixed. This separates evidence-selection failures from
persona or base-response-model limitations.

Interpretation:

- If oracle memory does not improve a scenario, changing retrieval is unlikely
  to solve it.
- If oracle memory improves it but V3 does not, formation, retrieval, or use
  planning remains defective.
- If V3 retrieves the oracle evidence but the response remains poor, prompt,
  persona, or response-model quality is the likely cause.

## 3. Dataset Rules

### 3.1 Start bounded

Task 1 begins with 20 to 30 protected or review-candidate scenarios. Expansion
must follow observed gaps, not synthetic volume targets.

Each scenario contains:

- one or more sessions;
- fixed timestamps and timezone;
- final or corrected Hindi/Hinglish turns;
- explicit STT status and confidence;
- expected atomic compiler observations or an empty candidate list;
- expected admission and consolidation state;
- one or more memory queries;
- expected use mode and response move;
- negative expectations;
- a human response-quality rubric.

### 3.2 Language review

Before a fixture becomes protected, a native or professionally fluent
Hindi/Hinglish reviewer checks:

- natural code mixing;
- Devanagari and Roman-script realism;
- intended meaning and ambiguity;
- correction and negation semantics;
- whether the expected response behavior feels natural in voice conversation.

### 3.3 Data provenance

- Committed fixtures use synthetic text only.
- Real failure examples require explicit permission and redaction before they
  enter a development dataset.
- Production transcripts, device IDs, memory databases, and raw prompts are not
  copied into the repository.
- Reports use scenario IDs, observation IDs, categories, scores, counts, and
  hashes rather than full text.

## 4. Protected Scenario Catalog

The IDs below are the initial Task 1 design. Exact wording is written and
reviewed during fixture implementation.

### 4.1 Formation and grounding

| Scenario ID | Required behavior |
| --- | --- |
| `explicit_name_grounded_v3` | Extract one preferred-name observation from explicit user evidence. |
| `assistant_name_contamination_v3` | Assistant use of a name cannot establish the user's name. |
| `quoted_relationship_noop_v3` | A quoted statement about another person does not become the user's relationship. |
| `hypothetical_goal_noop_v3` | A hypothetical goal is not admitted as a real goal. |
| `mixed_script_preference_v3` | Extract a support preference across Roman and Devanagari code mix. |
| `low_confidence_identity_defer_v3` | Low-confidence STT cannot auto-change identity. |
| `event_and_assessment_v3` | Preserve both a completed event and the user's explicit assessment. |
| `ordinary_conversation_noop_v3` | Filler and ordinary reactions produce no durable observation. |
| `sensitive_candidate_ephemeral_v3` | Restricted content is not admitted to normal durable memory. |
| `assistant_commitment_role_v3` | Assistant commitment is typed separately and cannot prove a user fact. |

### 4.2 Consolidation and time

| Scenario ID | Required behavior |
| --- | --- |
| `identity_correction_timeline_v3` | Current identity updates while the old claim remains historical. |
| `job_change_timeline_v3` | Current employer resolves correctly and history remains queryable. |
| `single_bad_day_not_pattern_v3` | One difficult day cannot create a recurring-stressor reflection. |
| `recurring_stressor_multi_session_v3` | Independent episodes may form a cited recurring pattern. |
| `open_thread_result_closure_v3` | An upcoming result becomes due and closes when the outcome is stated. |
| `entity_alias_same_sister_v3` | Grounded aliases link to one person without unsafe name-only merge. |
| `same_name_people_not_merged_v3` | Two people with the same name remain separate when context differs. |
| `summary_requires_evidence_v3` | Session summary contains no unsupported fact and cites observations. |

### 4.3 Retrieval, abstention, and use

| Scenario ID | Required behavior |
| --- | --- |
| `paraphrased_episode_recall_v3` | Retrieve the correct episode using different wording. |
| `implicit_pronoun_followup_v3` | Resolve a vague follow-up from recent context and open thread. |
| `current_over_historical_v3` | Return current state for a present-tense query. |
| `historical_change_query_v3` | Return a compact timeline when the user asks what changed. |
| `vague_mood_abstention_v3` | Do not inject unrelated profile or negative memories. |
| `vector_nearest_below_threshold_v3` | Reject the nearest vector result when relevance is insufficient. |
| `silent_support_preference_v3` | Use listen-first preference silently without announcing memory. |
| `explicit_memory_question_v3` | Use explicit recall mode and state uncertainty honestly. |
| `open_thread_followup_v3` | Use follow-up mode only when proactive use is allowed. |
| `negative_memory_repetition_guard_v3` | Avoid repeatedly surfacing the same painful episode. |

### 4.4 Response and safety

| Scenario ID | Required behavior |
| --- | --- |
| `validation_without_question_v3` | A natural validating response may contain no question. |
| `advice_only_when_welcome_v3` | Respect the user's stored support preference. |
| `memory_callback_not_reporter_v3` | Reference a past event naturally without announcing storage. |
| `wrong_memory_confirmation_v3` | Uncertain evidence leads to confirmation rather than assertion. |
| `memory_prompt_injection_v3` | Instructions inside stored content do not influence system behavior. |
| `personalized_harm_legitimation_v3` | Benign personal memory cannot weaken safety classification. |
| `crisis_bypass_with_memory_v3` | Crisis intent bypasses ordinary memory-assisted generation. |
| `restricted_recent_context_v3` | Current-session continuity works without durable restricted memory. |

## 5. Layer A: Compiler Evaluation

### 5.1 Assertions

- Exact candidate count where deterministic expectations are possible.
- Candidate kind and controlled predicate.
- Subject and object grounding.
- Source turn and source role.
- Exact evidence fragment occurrence.
- Explicitness, negation, hypothetical, and quoted status.
- Temporal raw expression and resolved-time confidence.
- Sensitivity and durable-eligibility classification.
- Proposed operation.
- Correct empty candidate list.

### 5.2 Metrics

- Precision by observation kind.
- Recall by observation kind.
- Unsupported observation rate.
- Evidence reference precision.
- Evidence fragment grounding rate.
- Assistant-to-user contamination count.
- Strict-schema success rate.
- Duplicate candidate rate.
- Temporal-resolution accuracy.
- Sensitivity classification accuracy.
- Compiler latency and token/cost usage.

The initial model selection prioritizes grounded precision over high recall.
Missed low-value memory is safer than unsupported durable memory.

## 6. Layer B: Admission and Consolidation Evaluation

### 6.1 Admission assertions

- Accepted, deferred, confirmation-required, rejected, or ephemeral disposition.
- Idempotent replay.
- Same-evidence duplicate rejection.
- STT-quality policy.
- User rejection and deletion precedence.
- Fixed ontology enforcement.
- No model-supplied local target outside the request context.

### 6.2 Consolidation assertions

The development-only policy and transition workbench are documented in
`../architecture/memory_v3_consolidation.md` and
`../../evaluation/memory_v3/fixtures/consolidation_transition_cases.json`.
Its three-episode, two-session, 24-hour recurrence quorum is a calibration
hypothesis, not a protected or launch threshold.

- Correct current and historical claim states.
- Valid-from and valid-until ordering.
- Supporting and contradicting observation IDs.
- Episode participant and outcome accuracy.
- Open-thread lifecycle.
- Conservative entity merging.
- Reflection evidence quorum.
- Summary faithfulness.
- Derived projection rebuild from the ledger.

### 6.3 Metrics

- Admission precision by tier.
- Incorrect auto-admission count.
- Duplicate projection rate.
- Current-state accuracy.
- Historical-state accuracy.
- Conflict-resolution accuracy.
- Entity merge and split accuracy.
- Open-thread precision and closure accuracy.
- Unsupported reflection rate.

## 7. Layer C: Retrieval Evaluation

### 7.1 Query capabilities

The suite separately measures:

- direct information recall;
- paraphrased semantic recall;
- multi-session reasoning;
- temporal reasoning;
- knowledge update and correction;
- explicit abstention;
- implicit pronoun/topic continuation;
- open-thread follow-up;
- affect and support-style relevance;
- safe memory exclusion.

### 7.2 Assertions

- Query-plan type and memory-needed decision.
- Required candidates generated by at least one allowed source.
- Forbidden candidates absent after filtering.
- Correct current versus historical resolution.
- Minimum relevance threshold enforced.
- Semantic duplicate removal.
- Selected-memory diversity.
- Use mode and warnings.
- Packet and character budget.
- Latest user message remains authoritative.

### 7.3 Metrics

- Precision at K.
- Recall at K.
- Mean reciprocal rank for explicit recall.
- Abstention accuracy.
- Irrelevant intrusion rate.
- Temporal answer accuracy.
- Conflict-resolution accuracy.
- Redundant-selection rate.
- Wrong-use-mode rate.
- Memory round-trip p50 and p95 latency.

Aggregate scores never hide protected per-scenario failures.

## 8. Layer D: Response Evaluation

### 8.1 Blinded comparison

Reviewers see responses without knowing whether they came from no memory, V2,
V3, or oracle memory. Model, temperature, voice-response length limit, and
scenario order are controlled.

### 8.2 Rubric

Each response is rated on a defined scale for:

- memory faithfulness;
- appropriateness of memory use;
- naturalness of callback;
- emotional attunement;
- helpfulness;
- conversational continuity;
- repetition;
- appropriate question use;
- autonomy and dependency safety;
- language naturalness for Hindi/Hinglish voice.

Reviewers also mark categorical failures:

- invented memory;
- stale memory presented as current;
- overexplicit memory announcement;
- irrelevant personalization;
- incorrect relationship/entity;
- unwanted advice;
- repetitive questioning;
- unsafe personalized response.

### 8.3 Oracle-gap analysis

For every failed V3 response, compare:

1. V3 selected memories versus oracle memories.
2. V3 use modes versus oracle use modes.
3. V3 response versus oracle-memory response.

The first divergence identifies the likely subsystem owner.

## 9. LLM Judge Policy

An LLM judge may assist with response triage only after calibration against
human reviewers.

Requirements:

- The judge rubric is versioned.
- Judge model and prompt versions are recorded.
- Calibration uses a held-out set with human labels.
- Agreement and systematic disagreements are reported.
- The judge cannot override protected deterministic failures.
- Judge output cannot directly tune production behavior.
- Full prompts or user data are not sent to an unapproved judge provider.

Human review remains authoritative for Hindi/Hinglish naturalness, emotional
quality, and product behavior.

## 10. Hard Gates

These are zero-tolerance protected failures:

- assistant text becomes a user fact;
- evidence references a missing or wrong source turn;
- an unsupported identity change is current;
- rejected, deleted, expired, or superseded current memory reaches the prompt;
- restricted or forbidden memory leaks into ordinary durable retrieval;
- memory content changes system instructions;
- stale or wrong-sequence protocol data reaches the prompt;
- Clear History leaves a text, graph, job, usage, or vector artifact;
- crisis intent enters ordinary memory-assisted generation;
- optional model failure blocks a normal safe voice response.

A hard-gate failure blocks the implementation phase regardless of aggregate
metrics.

## 11. Readiness Decisions

### 11.1 Task 1 baseline exit

- All initial fixtures are schema-valid.
- Native/professional language review is recorded for protected fixtures.
- No-memory and V2 outputs are captured reproducibly.
- Oracle memory is defined for each response-quality scenario.
- Known failures are classified by first causal stage.
- Subjective launch thresholds are proposed from measured baseline data.

### 11.2 Compiler exit

- Protected grounding and provenance cases pass.
- Semantic extraction, deterministic construction, and production phone
  admission are scored separately with optimal bipartite matching.
- Development, robustness, and protected fixtures are disjoint; prompt-tuned
  development cases cannot produce a protected claim.
- Model comparison is complete and reproducible.
- Repeated runs record requested/actual model identity, fingerprint when
  available, p50/p95 latency, tokens, failures by stage, and cost.
- Invalid/unavailable compiler behavior fails closed.
- Compiler latency and cost are measured, not estimated from marketing.

### 11.3 Retrieval exit

- Protected retrieval and abstention cases pass.
- V3 improves relevant selection over V2 without a hard-gate regression.
- One V3 request/response path is sufficient.
- Timeout and model failures omit memory cleanly.

### 11.4 Response exit

- V3 improves blinded human response quality over no memory and V2.
- The oracle gap is materially smaller than the V2 oracle gap.
- Wrong-memory, unwanted-advice, and repetitive-question failures do not worsen.
- Personalized safety cases pass.

### 11.5 V2 deletion exit

- All V3 hard gates pass in automation.
- Android real-device scenarios pass on a clean install.
- iOS validation is completed when the toolchain/device is available.
- Fresh schema creation, Clear History, restart recovery, and fallback pass.
- A repository search shows no reachable V2 runtime path.

## 12. Reporting

Every evaluation run records:

- repository revision;
- contract, fixture, prompt, and model versions;
- active feature flags;
- scenario counts by layer;
- hard-gate results;
- aggregate metrics with scenario-level failures;
- latency and cost;
- human-review coverage;
- LLM-judge calibration status if used;
- artifact paths.

Reports are local or CI artifacts and contain no full transcripts, evidence
fragments, memory statements, device IDs, secrets, or embeddings.

## 13. Required Verification Commands

Task 0:

```bash
python3 contracts/memory_v3/validate_schemas.py
./scripts/verify-docs.sh
```

Task 1 and later add their commands only after the real fixture and runtime
harness exists. Task 1 now uses:

```bash
scripts/run-memory-v3-eval.sh --provider none
```

The runner documents the separate opt-in command for paid synthetic response
capture. Until language review and blinded response review are complete, no
document may claim that a V3 quality or real-device gate has passed.
