# Memory V3 Consolidation and Projection Rebuild

Status: offline Task 4 design and reference policy only; no runtime wiring.

Last updated: 2026-07-20

This document defines how admitted observations become rebuildable phone-owned
state. It narrows Section 10 of `memory_v3.md` and the projection tables in
`memory_v3_storage.md`. Until the Task 3 protected compiler gate passes, this
design may be exercised only by the synthetic offline workbench.

## 1. Authority Boundary

The observation ledger and user-control stream are authoritative. Claims,
episodes, threads, entities, relations, and reflections are disposable
projections. The phone alone:

- chooses projection IDs and state keys;
- applies current, historical, due, resolved, rejected, and expired states;
- sets temporal bounds, confidence, support, and contradiction links;
- creates, updates, or closes projection rows;
- applies user confirmation, rejection, pin, forget, and deletion precedence;
- rebuilds all projections from the ledger and controls.

An LLM is optional and untrusted. It cannot return a mutation operation,
database ID, replacement statement, temporal state, reflection, numeric
confidence, or deletion target.

## 2. Deterministic-First Transition Policy

Projection rebuild consumes admitted observations in `(observed_at_ms, id)`
order. The same ledger, controls, policy version, and generation must produce
the same semantic rows and deterministic IDs.

| Input | Deterministic transition |
| --- | --- |
| First explicit single-cardinality value | Create one current claim. |
| Exact normalized repeat of that value | Add support; do not create a duplicate. |
| Later explicit different value for the same state key | Make the old claim historical at the new observation time and create the new current claim. Preserve both. |
| Multi-valued preference or relationship | Keep a value-specific state key; never supersede another value merely because the predicate matches. |
| Specific experience | Create or support an episode. Affect and user assessment remain episode-local. |
| Prospective event or assistant commitment | Create an open thread with a policy-bounded follow-up mode. |
| Explicitly linked outcome | Resolve only the linked thread. Text similarity alone cannot close a thread. |
| Entity mention | Create a distinct entity unless exact deterministic evidence or an accepted bounded coreference decision links it. Name equality alone is insufficient. |
| Controlled relationship | Create only an allowed relation family and cite every supporting observation. |
| Repeated exact stress context | Create an uncertain recurring-pattern reflection only after the configured evidence quorum. |

The initial single-cardinality predicates are `preferred_name`, `works_at`,
`response_language`, `response_length`, and `support_style`. This list is a
versioned local policy, not an LLM decision.

## 3. Optional Ambiguity Adjudication

Most transitions need no model. When exact local rules cannot safely decide
semantic equivalence, entity coreference, episode coreference, or whether an
outcome refers to one of a small set of threads, the phone may create a bounded
question using `memory_consolidation.schema.json`.

The request contains only opaque request-local item and source references. The
model may choose one offered candidate, say the items are distinct, or abstain,
and must select only from allowed evidence-signal enums. The phone rejects a
decision when:

- the question, item, or selected candidate was not in the request;
- the signal was not allowed for that question;
- the answer is missing, duplicated, malformed, or inconsistent;
- the task-specific local acceptance rule is not met;
- a user rejection, deletion, or confirmation rule takes precedence.

Abstention or any service failure leaves items distinct and does not block a
voice response. Accepted adjudication is only a bounded link input to the local
transition engine; it is never itself a database mutation.

## 4. Temporal and Confidence Rules

- A current single-cardinality correction sets the prior claim's
  `valid_until_ms` to the new observation time and preserves its original
  `valid_from_ms`.
- Past observations do not silently replace current state.
- Uncertain or confirmation-required observations cannot become current merely
  because another observation is similar.
- Model confidence is not accepted. A projection carries evidence-derived
  confidence and explicit support count; repetition is not treated as an
  independent probability when the evidence is duplicated.
- Retrieval or successful generation never changes truth confidence. Task 7
  usage feedback affects selection policy separately.

All time interpretation is based on the admitted observation's normalized
temporal fields. Consolidation does not reinterpret raw temporal prose.

## 5. Affect, Sentiment, and Human-Like Continuity

Affect is not a durable personality label. An episode may retain the user's
explicit assessment plus bounded emotion, valence, and intensity from its
grounded observation. This supports later empathetic continuity such as
remembering that an interview felt frustrating without claiming the user is an
anxious person.

A cross-session emotional pattern requires distinct episodes, distinct
sessions, time separation, complete citations, and an `uncertain` reflection.
The offline development policy starts with three episodes across at least two
sessions and at least 24 hours. That threshold is a calibration hypothesis, not
a launch constant. Protected evaluation must measure false patterns and missed
patterns before the policy is promoted.

Generated session summaries, personality inferences, and unrestricted
free-form reflections are excluded from the first Task 4 slice. They add less
value than accurate claims, episodes, and threads while carrying much greater
distortion risk.

## 6. Entity and Graph Safety

Entity IDs are deterministic hashes of a versioned local namespace and the
primary grounded mention. Aliases are evidence-backed. Two people with the same
name remain separate without explicit relational or contextual evidence. A
merge is represented by deterministic rebuild output, not destructive source
rewriting.

Only controlled relation families in the storage schema are legal. A relation
requires source and target entities, temporal status, a primary observation,
and normalized support. Deleting its last valid support removes it on rebuild.

## 7. Rebuild and Failure Behavior

The runtime implementation must build a new projection generation in one local
transaction, audit citations and foreign keys, and mark it ready only after all
checks pass. On failure, the previous ready generation remains usable. A clean
rebuild must be semantically identical to incremental application.

Projection reset preserves observations and user controls. Clear History and
individual deletion follow `memory_v3_storage.md`; deleted or rejected evidence
can never be recreated by consolidation.

## 8. Offline Exit Criteria

Before phone runtime work starts, the development workbench must demonstrate:

- current and historical correction timelines;
- exact reinforcement without duplicate projections;
- multi-valued preservation;
- same-name entity separation and evidence-backed alias linking;
- open-thread creation and exact linked closure;
- no reflection from one episode;
- cited recurrence only after the provisional quorum;
- deterministic replay and input-order behavior;
- no projection from deferred, rejected, or unsupported input;
- no LLM-generated mutation authority.

These are development checks. Task 4 remains blocked from runtime and response
paths until Task 3.2 passes the frozen protected and robustness evaluation.
