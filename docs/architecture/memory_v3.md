# Memory V3 Architecture

Status: Approved design; Task 0 contracts only; runtime not implemented.

Last updated: 2026-07-20

This document is the source of truth for the Memory V3 rewrite. It supersedes
`docs/architecture/long_term_memory.md` for new memory implementation work. The
older document remains an implementation record for the V2 system until V2 is
removed.

The product is not released. Development memory data is disposable. Memory V3
does not require data migration, legacy schema compatibility, or a V2 protocol
compatibility layer.

## 1. Product Outcome

Companion AI must build useful long-term knowledge from natural Hindi/Hinglish
voice conversations and use that knowledge appropriately in later responses.
For each user turn, the memory system must:

1. Decide whether memory is useful.
2. Understand the current subject, time reference, affect, and support need.
3. Retrieve current or historically relevant evidence, or abstain.
4. Resolve corrections and change over time.
5. Choose whether a memory should be used silently, mentioned, confirmed, or
   ignored.
6. Give the response model a compact, evidence-backed memory brief.
7. Record whether the memory use was helpful or incorrect.
8. Preserve local ownership, deletion, privacy, and safety guarantees.

Memory quality is an end-to-end property:

```text
formation * retrieval * use decision * response quality
```

A failure in any factor makes the user feel forgotten or misunderstood.

## 2. Rewrite Boundary

### 2.1 Retain and adapt

- Encrypted, phone-owned SQLite storage.
- Local transcript history.
- ObjectBox as a rebuildable local vector index.
- Stateless backend model endpoints.
- Reliable, ordered LiveKit data-channel messages with sequence numbers.
- Background job durability, leases, retries, and idempotency concepts.
- Clear History and per-memory user controls.
- Safety override before normal response generation and TTS.
- Redacted latency, cost, and quality telemetry.
- Provider interfaces and deterministic no-memory fallback.

### 2.2 Replace

- Language-specific deterministic fact extraction as the primary memory writer.
- Split exact-claim and semantic-record admission paths.
- Truncated per-turn records presented as session summaries.
- Keyword-only memory routing.
- Uncalibrated additive retrieval ranking.
- The second legacy memory lookup round trip.
- Raw `label: content` memory injection.
- Positive/negative keyword-only affect detection.
- The mandatory acknowledgement-then-question response formula.
- Evaluation that stops before generated-response quality.

### 2.3 Do not add

- Auth or cloud-owned durable memory.
- Server-side transcript or memory persistence.
- Raw audio storage.
- Text input UI.
- Video or avatar features.
- Online reinforcement learning during the V3 implementation.
- A model path without a bounded deterministic fallback.

## 3. Non-Negotiable Invariants

1. The phone is the durable source of truth.
2. Model endpoints are stateless compute adapters.
3. The LLM proposes semantic observations or bounded request-local ambiguity
   decisions; it never chooses projection mutations or writes the database.
4. User facts require cited user evidence.
5. Assistant text may provide context but cannot prove a user fact.
6. Assistant text may create only assistant commitments.
7. Every derived claim, summary, reflection, and graph edge cites source
   observations.
8. Corrections preserve history. Current state is a projection, not destructive
   replacement.
9. High emotional salience does not increase factual confidence.
10. `NOOP` and retrieval abstention are successful outcomes.
11. Memory content is untrusted data and cannot override system or safety rules.
12. User rejection, deletion, and pinning override model proposals.
13. Clear History removes transcripts, observations, projections, jobs, graph
    rows, usage events, and vector artifacts.
14. A memory failure omits memory for that turn; it does not fail the voice turn.
15. Crisis handling remains outside normal memory-assisted generation.

## 4. Ownership and Runtime Boundaries

### 4.1 Flutter phone application

The phone owns:

- final transcript persistence;
- the unprocessed-turn buffer;
- memory jobs and leases;
- local validation and admission;
- the observation ledger;
- current claims, episodes, open threads, reflections, entities, and relations;
- lexical, temporal, graph, and vector candidate generation;
- deletion and user-control state;
- construction of `MemoryBriefV3`;
- memory usage and feedback events.

### 4.2 Stateless API

The API owns bounded compute adapters:

- `/v1/memory/compile` for observation proposals;
- `/v1/memory/consolidate` only for optional bounded request-local ambiguity
  decisions, if evaluation proves them necessary;
- `/v1/embeddings` for configured embeddings;
- `/v1/rerank` for optional candidate reranking;
- `/v1/memory/adjudicate` only if a distinct conflict-evaluation boundary is
  later proven necessary.

The API must not persist request text, transcripts, observations, embeddings,
memory identifiers tied to a user, or compiled memory results.

### 4.3 Realtime agent

The realtime agent owns:

- current-turn safety classification;
- the reliable `memory_context_request_v3` request and timeout;
- prompt assembly from `MemoryBriefV3` and recent conversation;
- the normal response LLM call;
- output safety classification;
- TTS and playback;
- redacted turn-level telemetry.

The agent does not own a durable user-memory store or a second memory router.

## 5. End-to-End Flow

```text
final transcript and assistant response
  -> local unprocessed-turn buffer
  -> stateless LLM compiler
  -> evidence-backed candidate observations
  -> local validation and admission
  -> append-only observation ledger
  -> periodic consolidation and reflection
  -> current/episodic/thread/graph projections
  -> query-time candidate generation
  -> temporal resolution, rerank, diversity, and abstention
  -> MemoryBriefV3 with explicit use modes
  -> one response LLM call
  -> memory usage event and optional user feedback
```

Formation and consolidation never block a voice response. Immediate continuity
uses recent final turns and the unprocessed-turn buffer until durable formation
completes.

## 6. Canonical Domain Model

### 6.1 Observation ledger

`memory_observations_v3` is append-only and authoritative. An observation is a
bounded, evidence-backed statement about something the user or assistant said.
It includes:

- observation ID and schema version;
- kind, subject, controlled predicate, and object;
- source turn IDs, source roles, and exact evidence fragments;
- observed time and event time;
- explicitness, confidence, negation, hypothetical, and quoted status;
- optional affect and user assessment;
- salience, future utility, proactive-use permission, and confirmation need;
- sensitivity and durable-storage eligibility;
- proposed operation and compiler provenance.

Observations are facts about evidence, not automatically current truth.

### 6.2 Current claims

`memory_claims_v3` is a rebuildable projection of presently valid profile,
preference, routine, relationship, goal, boundary, and value claims. Each claim
contains:

- supporting and contradicting observation IDs;
- `valid_from_ms` and optional `valid_until_ms`;
- current, historical, uncertain, rejected, or expired status;
- epistemic confidence;
- user confirmation and pin state;
- last positive and negative use outcome.

Current claims do not erase historical claims.

### 6.3 Episodes

`memory_episodes_v3` represents specific experiences. An episode includes:

- event time or bounded unresolved time expression;
- people and entities involved;
- event statement and explicit user assessment;
- optional affect state with confidence;
- outcome and resolved/unresolved state;
- supporting observation IDs.

### 6.4 Open threads

`memory_threads_v3` represents prospective or unresolved matters:

- an upcoming event;
- an expected result;
- a user goal with a next checkpoint;
- an assistant commitment to follow up;
- an unresolved experience with an expected outcome.

A thread has an allowed follow-up mode, expected time when known, and status:
open, due, resolved, cancelled, stale, or rejected.

### 6.5 Entities and graph relations

Initial entity types:

- user;
- person;
- organization;
- place;
- event;
- goal;
- preference;
- routine;
- topic;
- value.

Initial relation families:

- `HAS_RELATIONSHIP`;
- `PREFERS`;
- `AVOIDS`;
- `PURSUES`;
- `EXPERIENCED`;
- `PARTICIPATED_IN`;
- `WORKS_WITH`;
- `ASSOCIATED_WITH`;
- `CAUSED`;
- `FOLLOWED_BY`;
- `CONTRADICTS`;
- `SUPERSEDES`.

Every relation stores supporting observation IDs and temporal validity. The LLM
may propose entity mentions and relations but cannot create arbitrary entity or
edge types. Entity merges require more than name similarity. Query-time graph
traversal must be anchored to a query entity and is normally limited to two
hops.

### 6.6 Reflections

`memory_reflections_v3` contains bounded, evidence-backed consolidation results:

- session summary;
- recurring pattern;
- relationship context;
- user value or support-style hypothesis;
- goal progress;
- temporal change summary.

A reflection is never independent evidence. It cites its observation IDs and is
invalid when all supporting observations are deleted or rejected.

### 6.7 Usage events

`memory_usage_events_v3` records:

- query-plan ID and response ID;
- generated candidate IDs;
- selected memory IDs;
- intended use modes;
- explicit feedback;
- weak implicit signals;
- later correction or successful thread closure.

Retrieval alone does not reinforce a memory. Reinforcement requires new evidence
or a positive use outcome.

## 7. Controlled Predicates

The V3 contract initially permits these observation predicates:

- `preferred_name`;
- `has_relationship`;
- `response_language`;
- `response_length`;
- `support_style`;
- `likes`;
- `dislikes`;
- `avoids_topic`;
- `follows_routine`;
- `pursues_goal`;
- `holds_value`;
- `experienced_event`;
- `event_outcome`;
- `open_thread`;
- `assistant_commitment`;
- `works_at`;
- `profile_association`;
- `relationship_association`;
- `episode_association`;
- `causes_stress`;

`recurring_pattern` is a later evidence-derived consolidation output, not a
formation predicate an LLM may propose from one bounded window.

Adding a predicate requires a contract version update, fixtures, and admission
and retrieval behavior. A free-form predicate is not allowed.

## 8. Compiler Contract and Triggering

### 8.1 Input

The compiler receives:

- one to twelve final or corrected messages;
- stable turn IDs and roles;
- timestamps and timezone;
- language and script metadata;
- STT confidence and model metadata;
- the fixed semantic-atom ontology supplied by the compiler prompt.

The compiler never receives the complete transcript or complete knowledge base.

### 8.2 Output

The model returns zero or more minimal `MemorySemanticAtomV3` proposals with
exact evidence quotes. It does not generate kinds, candidate IDs, evidence
roles or offsets, numeric confidence, privacy admission, utility, database
operations, or mutation targets. Deterministic server code derives those fields,
rejects ungrounded/modality-sensitive atoms, and emits append-only
`MemoryObservationV3` candidates for the phone to validate again. An empty atom
list means no memory. Formation cannot see or mutate historical state.
Corrections and results remain new observations until bounded consolidation
resolves them.

An empty candidate list is correct when nothing has future value.

### 8.3 Triggers

Compiler jobs are enqueued after a completed user/assistant exchange and drained:

- after a short idle window;
- on session end;
- when the bounded buffer reaches its maximum;
- on the next app launch if work remains.

The compiler is not on the response critical path. A compiler outage keeps the
job local and does not weaken current-turn safety.

### 8.4 Model selection

The configured model must pass the same Hindi/Hinglish compiler fixture set.
Selection is based on grounded precision, recall by memory type, temporal and
correction accuracy, strict-schema reliability, latency, and measured cost. No
model quality is assumed from provider marketing or model size.

## 9. Local Validation and Admission

The phone is the actual judge. Before committing a candidate it checks:

1. Contract version and strict schema.
2. Known source turns and unique evidence references.
3. Evidence fragment occurrence in the cited turn.
4. Correct role provenance.
5. STT status and confidence.
6. Allowed kind, predicate, operation, and time range.
7. Sensitivity and durable-storage policy.
8. Duplicate and same-evidence replay.
9. User rejection, deletion, pin, and confirmation state.
10. Whether the candidate is append-only and contains no historical target.

Admission tiers:

- Tier A: explicit, grounded, low-risk observations may auto-admit.
- Tier B: implied or interpretive observations remain observations until
  repeated evidence supports consolidation.
- Tier C: high-impact corrections preserve old state and may require stronger
  evidence or confirmation.
- Tier D: restricted or forbidden content follows the privacy policy and cannot
  be made durable by model confidence alone.

Small deterministic parsers may remain only for safety and explicit memory
control commands where missing the command would be harmful. They are not the
primary semantic extractor.

## 10. Consolidation

The concrete deterministic-first boundary and offline policy are defined in
`memory_v3_consolidation.md`.

### 10.1 Session consolidation

At session end, local consolidation may derive:

- a cited session summary;
- episode grouping;
- thread creation or closure;
- entity linking;
- a candidate recurring pattern;
- user goal progress;
- assistant commitment status.

### 10.2 Periodic consolidation

Periodic consolidation operates on new observations plus only relevant current
projections. The phone deterministically applies reinforcement, supersession,
thread lifecycle, graph, and reflection policy. An optional remote model may
only answer a bounded ambiguity question over opaque request-local references:
match one offered candidate, mark the items distinct, or abstain. It cannot
propose any state operation, ID, statement, temporal status, confidence, or
deletion. The phone validates an accepted link and owns every projection
transition.

### 10.3 Evidence quorum

Evidence requirements are calibrated by memory type:

- one strong explicit statement may establish a preferred name;
- one explicit statement or repeated feedback may establish a support
  preference;
- a recurring stressor requires independent supporting episodes;
- a personality or value hypothesis requires repeated evidence and remains
  uncertain until sufficiently supported or confirmed.

No universal recurrence count is assumed before evaluation.

## 11. Retrieval V3

### 11.1 One reliable protocol

The realtime agent sends one `memory_context_request_v3`. The phone combines the
latest transcript with local recent turns and memory, then returns one
`memory_context_response_v3` carrying `MemoryBriefV3`.

V3 removes the backend marker router and second legacy lookup after the V3 gate
passes.

### 11.2 Query plan

The query plan captures:

- memory-needed decision;
- query type;
- subject entities;
- temporal scope;
- current topic;
- current affect and support need;
- candidate memory kinds;
- explicit versus implicit recall;
- response latency path: fast, normal, or deep.

The latest user text remains an authoritative user-role message. It is not copied
as an instruction inside the system memory brief.

### 11.3 Candidate generation

Candidate sources:

- exact current claims;
- recent final and unprocessed turns;
- FTS/lexical retrieval;
- vector retrieval;
- temporal index;
- entity graph;
- episodes and open threads;
- cited reflections and session summaries.

### 11.4 Selection

Selection considers:

- semantic and entity relevance;
- temporal compatibility;
- evidence confidence;
- current or historical status;
- query type;
- thread relevance;
- pin and confirmation state;
- prior positive or negative use outcomes;
- redundancy and diversity;
- sensitivity and proactive-use permission;
- repeated-negative-memory risk.

Minimum relevance thresholds and abstention are mandatory. Vector nearest
neighbors are candidates, not automatic selections.

### 11.5 Retrieval paths

- Fast: exact state and immediate continuity.
- Normal: one or two high-utility memories for ordinary responses.
- Deep: explicit history, change-over-time, summary, or multi-session questions.

Deep retrieval may use a more capable reranker if measured quality justifies its
latency and cost.

## 12. Memory Use and Prompt Contract

Each selected memory receives one use mode:

- `SILENT_PERSONALIZATION`;
- `BRIEF_CALLBACK`;
- `EXPLICIT_RECALL`;
- `ASK_CONFIRMATION`;
- `FOLLOW_UP_THREAD`;
- `DO_NOT_USE`.

`MemoryBriefV3` contains:

- current response policy;
- bounded current dialogue state;
- query plan;
- selected evidence statements;
- time, confidence, relevance reason, use mode, and warnings;
- a recommended conversational act;
- whether a question is useful.

Prompt order:

1. Safety and assistant identity.
2. Persona principles.
3. Response policy.
4. Current dialogue state.
5. Structured memory brief.
6. Relevant recent turns.
7. Latest user message.

Prompt budgeting trims individual low-utility memories. It must not delete the
entire memory and policy section as one unit.

The persona supports validation, reflection, listening, clarification, advice,
celebration, encouragement, follow-up, gentle challenge, direct answer, and quiet
presence. A question is not mandatory.

## 13. Affect and Procedural Memory

Current affect is working state, not a durable trait. It may include:

- emotion category;
- valence and arousal;
- intensity;
- target or cause;
- confidence;
- within-session change;
- likely support need.

Episode affect stores only explicit or cautiously inferred event-level state.
Consolidation cannot promote one event into a personality claim.

Procedural memory may include:

- listen before advice;
- direct versus gentle wording;
- short versus reflective replies;
- preferred frequency of follow-up questions;
- proactive callback permission;
- preferred level of challenge.

Negative current affect must not automatically retrieve more negative memories.
Selection applies diversity, repeated-use penalties, and an anti-rumination
guard.

## 14. Feedback

Initial explicit feedback categories:

- helpful;
- wrong memory;
- irrelevant memory;
- too much advice;
- too many questions;
- repetitive;
- wrong tone.

Weak implicit signals may include immediate correction, repeated questions,
barge-in, and early exit. They are diagnostic and do not directly rewrite facts.

Feedback first updates procedural preferences and memory-use utility. Learned
ranking or model training is a later evidence-based decision. Session duration
is not a reward target.

## 15. Sensitivity Defaults

Until the product owner explicitly changes privacy posture:

- normal, explicit, low-risk information may be durable automatically;
- restricted information is ephemeral unless the user explicitly requests a
  future approved durable-memory mode;
- crisis and self-harm context is safety-ephemeral only;
- credentials, precise account/contact secrets, and forbidden data are never
  durable memory.

Sensitive storage policy is separate from current-session continuity. Ephemeral
context may support a coherent safe response without entering durable memory,
indexes, graph, or later proactive recall.

## 16. Observability and Failure Behavior

Production telemetry contains IDs, versions, counts, categories, statuses,
scores, timings, budgets, and error codes, but no transcript, evidence fragment,
memory statement, embedding, or device identifier beside user content.

Required health signals:

- compiler configured and enabled state;
- last successful compiler job time;
- pending job count and oldest age;
- compiler invalid-output and timeout count;
- validator disposition counts by reason;
- consolidation operation counts;
- retrieval candidate sources, selected count, and abstention;
- memory context round-trip latency;
- prompt budget by section;
- use modes and feedback category.

Model, compiler, vector, reranker, consolidation, or phone timeout failures must
continue with recent conversation and no long-term memory for that turn.

## 17. V2 Retain, Replace, and Delete Map

| V2 area | V3 decision | Notes |
| --- | --- | --- |
| `database_encryption.dart` | Retain | Continue encrypted phone ownership. |
| Transcript/session tables and UI | Retain | Reuse as evidence and recent context. |
| ObjectBox vector wrapper | Adapt | Index V3 projection IDs only; remain rebuildable. |
| LiveKit reliable sequencer | Retain | Add one V3 request/response contract. |
| Safety classifier and crisis override | Retain | Run before memory-assisted generation. |
| Clear History and memory-control UI | Adapt | Target all V3 ledger and projection data. |
| Background job lease/retry pattern | Adapt | Use for compiler and consolidation jobs. |
| Provider interfaces and telemetry | Adapt | Add versioned V3 model stages and metrics. |
| `companion_memory.dart` extraction rules | Replace then delete | Keep only explicit safety/control parsing if required. |
| `companion_memory_store.dart` claim path | Replace then delete | Use observation ledger and current projection. |
| V2 memory tables in `app_database.dart` | Replace then delete | No migration or compatibility layer. |
| `memory_candidate_model.dart` | Replace then delete | Use generated/validated V3 contract models. |
| `long_term_memory_service.dart` | Replace | V3 compiler and consolidation coordinator. |
| `memory_embedding_service.dart` | Adapt | Candidate indexing and retrieval use V3 IDs. |
| API `memory_extraction.py` | Replace | Implement strict V3 compile/consolidate adapters. |
| Realtime `memory_router.py` | Delete after V3 retrieval | Phone returns the complete V3 brief. |
| V2 handlers in `voice_chat_controller.dart` | Replace | One V3 request handler. |
| V2 handlers in agent `lifecycle.py` | Replace | One correlated V3 request and timeout. |
| Memory logic in agent `context.py` | Replace | Structured brief, use modes, and section budgets. |
| Fixed persona response formula | Replace | Conversational act selection; questions optional. |
| V2 memory fixtures | Retain selectively | Preserve valid safety/provenance behavior; rewrite contracts. |
| V2 retrieval benchmark | Replace | Add V3 compiler, temporal, abstention, and response layers. |
| `docs/architecture/long_term_memory.md` | Historical reference | Remove or archive only after V2 deletion. |

## 18. Implementation Gates

1. Task 0: architecture, evaluation design, and machine contracts.
2. Task 1: V3 fixtures and no-memory/V2/oracle baselines.
3. Task 2: clean ledger and projection schema. Implemented as an isolated,
   non-runtime schema; see `memory_v3_storage.md`.
4. Task 3: atomic compiler and local validation. The full-observation model
   approach failed its live exit gate. Task 3.1 replaces it with semantic atoms,
   deterministic construction, and production-validator evaluation parity.
   Local implementation is complete behind a disabled flag; the new live and
   protected gates remain pending. See `memory_v3_compiler.md`.
5. Task 4: consolidation, temporal state, and graph. The deterministic-first
   authority boundary and offline development policy are specified in
   `memory_v3_consolidation.md`; runtime work remains blocked until Task 3
   passes.
6. Task 5: retrieval, abstention, and one V3 protocol.
7. Task 6: structured prompt use, affect, and persona behavior.
8. Task 7: feedback and usage learning.
9. Task 8: real-device evaluation and V2 deletion.

Each gate requires updated documentation, tests, measured evidence, and a
coherent commit. A later gate cannot compensate for a failed safety, provenance,
deletion, or grounding gate.

## 19. Definition of Done

Memory V3 is complete when protected Hindi/Hinglish evaluation demonstrates:

- grounded explicit fact recall;
- meaningful event recall with paraphrased queries;
- open-thread follow-up;
- temporal current-versus-historical reasoning;
- relationship and goal evolution;
- support-style personalization;
- appropriate silent versus explicit memory use;
- abstention on irrelevant or unsupported memory;
- no assistant-to-user fact contamination;
- no unsupported graph/reflection content;
- no repeated painful-memory overuse;
- feedback-linked procedural adaptation;
- complete deletion and clear-history behavior;
- safe fallback under every optional model failure;
- improved blinded response quality over both V2 and no-memory baselines.

Subjective launch thresholds are set only after Task 1 records the baseline.
Protected safety and provenance violations remain zero-tolerance.
