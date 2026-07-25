# Memory V3 Local Storage

Status: Tasks 2 and 3 storage implemented; no V3 response-path cutover.

Last updated: 2026-07-20

This document records the concrete phone-owned SQLite design for Task 2 of
`memory_v3.md`. The implementation is in
`apps/mobile/lib/features/chat_history/data/memory_v3_schema.dart` and is part
of the same encrypted database as local transcripts.

The product is pre-release, so this is a clean V3 domain. It does not migrate,
copy, dual-write, or reinterpret V2 memory. V2 remains readable only as the
measured baseline until the later runtime and deletion gates pass.

## 1. Storage Boundary

The schema is created idempotently when the application database opens. It has
its own schema marker with version `3`; the legacy Drift schema version is not a
V3 compatibility contract.

No V3 table is read by the response path. Task 3 now writes locally validated
observations and content-free compiler outcomes behind a disabled-by-default
flag; it does not write any projection or change user responses. See
`memory_v3_compiler.md`.

## 2. Authoritative Data

### Observation ledger

- `memory_observations_v3` stores bounded admitted observations.
- `memory_observation_evidence_v3` stores ordered, exact evidence citations and
  the local transcript message identity, role, status, and STT provenance.
- `(compiler_request_id, candidate_id)` and `idempotency_key` are unique.
- SQLite triggers reject updates to observations and evidence. Privacy deletion
  remains possible and cascades to derived rows.
- Empty results, `forbidden`, `ephemeral`, and `never` candidates cannot enter the
  durable ledger. They remain compiler/admission outcomes, not stored memory.
- Assistant-only evidence is structurally limited to assistant commitments.
  The Task 3 phone validator verifies every exact fragment, offset, role,
  transcript status, and STT value against the immutable request snapshot.

### User-control overlay

`memory_user_controls_v3` is an append-only authoritative event stream for
confirm, reject, pin, unpin, and forget actions. It is not stored as mutable
state on observations. Projection IDs must be deterministic so these controls
can be reapplied after a rebuild.

### Compiler work and outcomes

`memory_compile_jobs_v3` and `memory_compile_job_messages_v3` hold durable
bounded formation work. Request messages are immutable snapshots and reject
updates. Formation receives no historical projection context; Task 4 owns a
separate consolidation request boundary. `memory_compile_runs_v3` and
`memory_compile_candidate_outcomes_v3` contain only redacted operational
metadata and also reject updates. They are not knowledge projections.

## 3. Rebuildable Projections

| Projection | Primary table | Citation table |
| --- | --- | --- |
| Current and historical claims | `memory_claims_v3` | `memory_claim_support_v3` |
| Specific experiences | `memory_episodes_v3` | `memory_episode_support_v3` |
| Episode participants | `memory_episode_entities_v3` | Grounded through the episode and entity |
| Open matters and commitments | `memory_threads_v3` | `memory_thread_support_v3` |
| Local entity graph | `memory_entities_v3`, `memory_entity_aliases_v3` | A required primary observation on every row |
| Temporal relations | `memory_relations_v3` | `memory_relation_support_v3` |
| Bounded summaries and patterns | `memory_reflections_v3` | `memory_reflection_support_v3` |

Every projection row has a non-null `primary_observation_id` foreign key. The
normalized citation table records all supporting or contradicting observations
where applicable. This makes unsupported rows fail closed and makes deletion of
source evidence invalidate derived state conservatively.

Claims preserve current, historical, uncertain, rejected, and expired states.
A partial unique index permits only one non-rejected current single-cardinality
claim per state key. Multi-valued relationships and preferences are not forced
through that constraint.

`memory_projection_state_v3` records the projection generation and rebuild
state. Clearing projections increments the generation but preserves the ledger
and user controls. Task 4 will own deterministic consolidation and rebuild.

## 4. Deletion Semantics

There are two deliberately different operations:

1. Projection reset deletes all derived tables, increments the generation, and
   preserves observations, evidence, and user controls for reconstruction.
2. Clear History deletes projections, user controls, evidence, observations,
   transcripts, V2 memory, jobs, telemetry, and vector artifacts through the
   existing product action. SQLite rows are removed in one transaction; the
   controller clears the rebuildable ObjectBox index immediately afterward.

Individual observation deletion is allowed for privacy even though updates are
forbidden. Foreign keys cascade that deletion to evidence and every projection
for which it is the primary support. Task 4 may then rebuild any still-supported
state from remaining observations.

## 5. Tasks 2 and 3 Invariants

Automated tests verify:

- all authoritative and projection tables exist in an in-memory database;
- foreign keys and bounded enum/score checks are active;
- observation, evidence, and user-control updates are rejected;
- compiler replay and projection citation constraints fail closed;
- request snapshots are bounded, immutable, leased, retried, and coalesced;
- the phone independently rejects bad evidence, role contamination, unsafe
  privacy labels and user-rejected replay;
- every seeded projection passes normalized support audit;
- a projection reset preserves the ledger and permits deterministic-ID rebuild;
- deleting an observation cascades derived state;
- Clear History leaves no V3 personal row or transcript.

The audit method reports foreign-key violations, observations without evidence,
and projections whose normalized support omits their primary observation. It is
diagnostic and never silently repairs corrupt state.

## 6. Deferred Work

Tasks 2 and 3 intentionally do not implement:

- a passing live Task 3.1 compiler model; historical full-observation runs
  failed, while the semantic-atom hybrid compiler still awaits independent
  robustness and native-reviewed protected evaluation as documented in
  `memory_v3_compiler.md`;
- phone runtime consolidation, temporal conflict resolution, entity linking,
  or projection rebuild writers (Task 4). The deterministic boundary and
  development-only reference are documented in
  `memory_v3_consolidation.md` but are not wired to this schema;
- lexical, vector, graph, temporal retrieval, or a V3 transport protocol
  (Task 5);
- memory-use planning or response-prompt changes (Task 6);
- usage and feedback learning (Task 7);
- V2 deletion or runtime cutover (Task 8).

The Task 1 live baseline explicitly blocks runtime cutover. A correct schema is
necessary, but it does not by itself resolve the measured prompt and
context-selection failures.
