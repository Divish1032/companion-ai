# Memory V3 Contracts

These JSON Schemas freeze the Task 0 boundaries for the Memory V3 rewrite.
They are product contracts, not a second runtime implementation.

Files:

- `memory_observation.schema.json`: evidence-backed compiler candidate.
- `memory_semantic_atoms.schema.json`: minimal untrusted LLM semantic proposal
  before deterministic construction.
- `memory_compile_request.schema.json`: bounded stateless compiler input.
- `memory_compile_response.schema.json`: compiler result and model provenance.
- `memory_consolidation.schema.json`: optional bounded ambiguity adjudication;
  it contains request-local references and cannot propose mutations.
- `memory_context_request.schema.json`: reliable realtime-agent request to the
  phone.
- `memory_brief.schema.json`: phone-owned query plan and selected memory brief.
- `memory_usage_event.schema.json`: response-linked memory-use feedback.

Contract rules:

- Schema version is `3`.
- All objects reject unknown properties unless explicitly documented.
- The LLM never supplies a database ID to mutate.
- The LLM proposes semantic atoms, not observation IDs, numeric policy fields,
  operations, or durable truth. Deterministic code constructs atomic `ADD`
  candidates; an empty list represents no memory. Historical mutation and
  entity linking exist only in consolidation.
- A user observation requires user-role evidence.
- Relative schema references stay inside this directory.
- Consolidation state transitions, deterministic IDs, confidence, temporal
  state, and projection text remain phone-owned. A model may only choose among
  request-local ambiguity candidates or abstain.
- Adding a kind, predicate, adjudication task, use mode, or sensitivity state requires a
  schema update and protected fixtures.

Validate all schemas with:

```bash
python3 contracts/memory_v3/validate_schemas.py
```

Runtime Dart and Python models must be generated from or tested against these
contracts during their implementation task. The contracts remain authoritative
when provider response formats differ.
