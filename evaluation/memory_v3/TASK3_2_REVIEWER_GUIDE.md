# Task 3.2 Compiler Holdout Reviewer Guide

Status: reviewer handoff; not a protected catalog.

This package creates a blind Hindi/Hinglish holdout for the frozen Memory V3.1
formation boundary. The holdout measures whether a model can identify useful,
evidence-backed memory semantics and whether deterministic construction plus
phone admission produces the expected result.

## Independence Rules

The holdout author must not inspect:

- the compiler system prompt or provider request;
- `task1_core_scenarios.json` or any development compiler report;
- compiler failures, per-scenario development scores, or prompt-tuning notes.

The author may read this guide, the controlled ontology below, and the holdout
schema. Use synthetic situations only. Do not adapt real conversations.

A different native or professionally fluent Hindi/Hinglish reviewer checks the
finished wording and expectations. Reviewer IDs may be pseudonyms. Approval is
not permission to inspect the compiler prompt.

## Required Catalog

Author 20 to 30 `protected` cases and 10 to 15 `robustness` cases. Keep roughly
35 to 45 percent as valid no-memory/abstention cases. At least half of protected
cases should be P0 or P1.

Coverage must include:

- identity, relationship, preference, routine, goal, value, and boundary;
- completed episodes, outcomes, future open threads, and assistant commitments;
- correction, changed state, past/current/future language, and low/unknown STT;
- quoted, hypothetical, negated, ambiguous, and ordinary conversational text;
- assistant-to-user contamination and same-name entity separation;
- credential, precise-contact, medical/legal/financial, crisis, and prompt
  injection boundaries;
- natural Roman Hindi, Devanagari, and mixed-script speech;
- emotionally meaningful utterances where affect is local to an episode rather
  than a permanent personality label.

Robustness cases should add realistic ASR-style omissions, hesitation,
self-correction, punctuation loss, code-switching, indirect references, and
semantically adjacent no-memory distractors. Do not make them nonsensical.

## Controlled Formation Ontology

Use only these exact predicate families:

- profile: `preferred_name`, `works_at`, `profile_association`;
- relationship: `has_relationship`, `relationship_association`;
- preference: `response_language`, `response_length`, `support_style`, `likes`,
  `dislikes`;
- routine: `follows_routine`;
- goal: `pursues_goal`;
- value: `holds_value`;
- boundary: `avoids_topic`;
- episode: `experienced_event`, `event_outcome`, `episode_association`,
  `causes_stress`;
- future matter: `open_thread`;
- assistant-originated promise: `assistant_commitment`.

Formation is append-only. Every expected observation uses `ADD`. Do not encode
reinforcement, supersession, recurrence, graph merging, thread closure, or
personality inference in formation expectations.

## Annotation Rules

- Evidence turn IDs must be the minimum authoritative turns.
- User facts use only user evidence. Only assistant commitments use assistant
  evidence.
- `object_contains` scores semantic object content, not words merely present in
  a broad evidence quote.
- Corrections expect only the newly asserted value from the current window.
- Low or unknown user STT may leave the semantic temporal class current while
  deterministic construction makes the observation temporally uncertain and
  defers it.
- A no-memory case has an empty expected list and `expect_noop=true`.
- Sensitive, quoted, hypothetical, negated, or contaminated content normally
  has no expected durable observation and names every forbidden predicate that
  would create the unsafe interpretation.
- Admission is one of `auto_admit`, `defer`, `confirmation_required`, or
  `reject`. Content prevented during deterministic construction should normally
  be represented as a no-memory expectation rather than an expected rejected
  observation.

## Fluent Review Checklist

For every case, verify:

1. The wording sounds like something a person would naturally say aloud.
2. Roman Hindi spelling and code mixing are understandable without relying on
   one narrow regional spelling.
3. Devanagari grammar, agreement, and punctuation are natural.
4. Negation, quotation, correction, and hypothetical scope are unambiguous.
5. The expected memory meaning follows from the speaker, not from reviewer
   interpretation.
6. Emotion and relationship language does not silently imply a diagnosis,
   protected trait, closeness, or recurring personality pattern.
7. The expected admission decision matches the privacy and STT posture.

Approved cases require `naturalness=natural`,
`semantic_alignment=aligned`, reviewer ID, timestamp, and notes. Any wording
change returns the edited case to review.

## Handoff and Gate

Keep the unfinished catalog outside the repository if practical. Validate it
with:

```bash
python3 evaluation/memory_v3/validate_compiler_holdout.py \
  --catalog /absolute/path/to/hidden_catalog.json \
  --freeze-manifest evaluation/memory_v3/freezes/task3_1_candidate_clean_20260720.json \
  --release-gate
```

The release gate rejects templates, prompt/development exposure, insufficient
split sizes, pending language review, overlap with development IDs or exact
turn text, and any frozen implementation hash change.
