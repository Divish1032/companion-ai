# Memory V3 Synthetic Holdout Failure Findings

Status: closed failed experiment; not an active implementation path.

## What was attempted

An isolated DeepSeek authoring harness generated a private 35-scenario Task 3.2
compiler review candidate. Deterministic normalization supplied envelope IDs,
split assignments, script labels, and other structural fields. Additional
generation passes then filled machine-detected predicate, admission, language,
and hard-gate quotas.

The generated catalog, authoring harness, repair logic, provenance, checkpoints,
and the replacement freeze created for those checks were removed. The catalog
was never promoted to protected status and was never run against the compiler.

## Why it was rejected

The catalog passed JSON Schema and aggregate distribution checks but was not a
valid semantic benchmark. Review found:

- kind/predicate mismatches, including `preferred_name` under `preference` and
  `causes_stress` under `preference`;
- quoted or negated observations annotated for automatic admission even though
  deterministic phone policy rejects them;
- low-confidence STT observations annotated for automatic admission below the
  phone's threshold;
- a confirmation-required expectation whose text could not trigger the actual
  deterministic confirmation rule;
- subject and target expectations incompatible with the compiler's normalized
  entity representation;
- valuable preferences, boundaries, relationships, future matters, and values
  incorrectly labeled as no-memory to satisfy an abstention quota;
- questions, capability statements, and unsupported alarm/reminder responses
  mislabeled as durable assistant commitments;
- Devanagari and mixed-script coverage concentrated in no-memory safety or
  hypothetical cases, leaving positive extraction in those scripts untested;
- scenario tags that disagreed with the actual text script;
- brittle `object_contains` expectations that required a particular English
  paraphrase rather than accepting a correct evidence-grounded Hindi meaning;
- an evaluator boundary where `after_turn_id` labels did not cause incremental
  compilation because the runner supplied the complete session once.

These errors could make a correct compiler score worse and an incorrect
compiler score better. Aggregate ontology and script quotas therefore did not
establish benchmark quality.

## Root causes

1. The author was isolated from implementation details, but the authoring
   contract did not fully specify the normalized representation the evaluator
   required.
2. Structural validation checked counts and schema shape without proving that
   an expected outcome was reachable through deterministic construction and
   admission.
3. Quota-repair generation optimized missing labels instead of conversational
   realism and product value.
4. A single AI-authored catalog was asked to supply language naturalness,
   semantic ground truth, adversarial coverage, and evaluator compatibility.
5. Work on the formation benchmark displaced the already-planned end-to-end
   consolidation, retrieval, memory-use, and response path.

## Decisions retained

- Durable truth and mutation remain phone-owned.
- Transcript evidence remains immutable and locally grounded.
- An LLM remains an untrusted semantic proposal engine, not a database or graph
  mutation authority.
- Privacy, sensitivity, speaker provenance, modality, STT quality, and admission
  remain deterministic gates.
- V3 remains disabled until end-to-end quality and safety gates pass.
- The existing no-memory, V2, and oracle response evidence remains the target;
  the oracle already demonstrated material response uplift and exposed concrete
  prompt-boundary defects.

## Rules for future evaluation

- Do not promote AI-generated wording or annotations as protected truth.
- Validate expectation reachability through the real constructor and phone
  admission policy before model scoring.
- Do not use predicate or no-memory quotas as substitutes for scenario quality.
- Separate formation correctness from consolidation, retrieval, memory-use, and
  response quality, and classify a failure at its first causal stage.
- Prefer evidence-grounded semantic assertions over translation-sensitive
  substring requirements.
- Exercise positive and abstention behavior in every important language/script
  category rather than satisfying aggregate turn counts.
- Do not create another authoring harness until a concrete evaluation consumer
  and its representation contract are both stable.
- The generic holdout validator currently requires non-null user STT confidence
  even though runtime admission distinguishes unknown confidence and defers it.
  Fix that only with the next intentional evaluator freeze; it was not retained
  as an incidental change from this failed experiment.

## Current direction

No new memory architecture is introduced by these findings. The existing V3
direction remains broadly valid. Work should continue by executing the missing
runtime vertical slice: trusted observations into consolidation, retrieval,
bounded `MemoryBrief` construction, memory-use selection, and response
injection behind a disabled or shadow flag. Formation should then be improved
only where end-to-end failures are causally traced to formation.
