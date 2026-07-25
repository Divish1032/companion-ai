# Agent Rules for Companion AI

This file applies to the whole repository. Follow it in every new coding session unless the user explicitly overrides it.

## Project Context

This project is a low-latency Hindi/Hinglish voice-only AI companion MVP for Android and iOS.

Core stack:

- Flutter mobile app for Android and iOS.
- Self-hosted LiveKit for realtime WebRTC audio.
- Realtime backend agent for VAD, endpointing, STT, LLM, TTS, and playback.
- Sarvam is the initial target provider, but provider integrations must stay behind interfaces.

## Required Reading Order

Before making project changes:

1. Read `docs/AGENT_CONTEXT.md`.
2. Read `docs/SPRINTS.md`.
3. Read only the architecture files relevant to the active sprint.
4. Use `docs/PRD_MASTER.md` for product/source-of-truth questions.

## Operating Strategy

Use a narrow-context, evidence-first workflow. The goal is high-quality work with minimal irrelevant reading, minimal token waste, and minimal hallucination risk.

Default loop:

1. Identify the active sprint or user-requested task.
2. Read only the sprint section and relevant architecture files listed in `docs/AGENT_CONTEXT.md`.
3. Search before assuming. Prefer `rg` and targeted file reads over opening large files.
4. Extract the exact requirements and acceptance criteria for the task.
5. Make the smallest coherent change that satisfies the task.
6. Verify with commands/tests/checks appropriate to the change.
7. Report only what changed, what was verified, and what remains uncertain.

Do not load the entire documentation set unless the user asks for a full audit or the task genuinely crosses multiple architecture areas.

## Token Efficiency Rules

- Prefer `rg` over broad file reads.
- Prefer reading specific sections over full files.
- Prefer existing docs and local code over re-deriving context.
- Do not paste long source excerpts back to the user unless requested.
- Do not restate the PRD in final answers.
- Summarize only decision-relevant facts.
- Keep intermediate updates short and concrete.
- If a task is scoped to one sprint, do not discuss later sprints unless they affect the current decision.
- If requirements are already documented, cite the file path and section instead of rewriting them.

## Hallucination Reduction Rules

- Treat undocumented provider behavior as unknown.
- If an implementation depends on current third-party API behavior, verify official docs or run a spike before coding against assumptions.
- When unsure, say what is known, what is inferred, and what must be validated.
- Do not invent Sarvam, LiveKit, Flutter, Android, or iOS API details.
- Do not invent pricing, latency, or billing behavior. Measure or cite.
- Do not create fake benchmark numbers. If tests were not run, say so.
- Do not claim compliance with DPDP, App Store rules, or platform background-mode rules without evidence.

## Decision Strategy

Prefer decisions that are:

- Reversible.
- Measurable.
- Narrowly scoped to the active sprint.
- Compatible with the documented architecture.
- Cheap to validate before full implementation.

Escalate or stop for user review when:

- A Sprint -1 gate fails.
- A provider API behaves differently than the PRD assumes.
- A change would add auth, text input, video/avatar, raw audio storage, or cloud transcript storage.
- A change would materially alter unit economics, privacy posture, or safety behavior.
- A task requires real API keys or external accounts the agent does not have.

## Output Strategy

For implementation work, final responses should be short:

- Files changed.
- Verification run.
- Acceptance criteria satisfied.
- Blockers or follow-up tasks.

Avoid long narrative unless the user explicitly asks for analysis.

## Planning Strategy

- Use a plan only when the task has multiple meaningful steps.
- Do not create a plan for trivial edits or one-command checks.
- Keep plans tied to sprint acceptance criteria.
- Update plan status as work progresses.
- Do not use planning as a substitute for reading the relevant files.
- Once enough context is gathered, implement rather than continuing to analyze.

## Current Sprint Rule

Default active sprint is **Sprint -1: Validation Gates** until the user explicitly moves the project forward.

Do not start Sprint 0 or app scaffolding until Sprint -1 outputs are created or the user explicitly says to skip them.

Sprint -1 expected outputs:

- `docs/spikes/sarvam_streaming_validation.md`
- `docs/architecture/endpointing.md`
- `docs/architecture/agent_lifecycle.md`
- `docs/privacy/dpdp_mvp_notes.md`

## Active Memory V3 Rewrite

For every task that creates, retrieves, injects, evaluates, or deletes companion
memory, the Memory V3 program is the active product direction even when the
general sprint list still describes the shipped V2 implementation.

Before changing memory code:

1. Read `docs/architecture/memory_v3.md`.
2. Read `docs/architecture/memory_v3_storage.md` for storage or deletion work.
3. Read `docs/architecture/memory_v3_consolidation.md` for consolidation,
   temporal state, graph, or reflection work.
4. Read `docs/evals/memory_v3_evaluation.md`.
5. Read the relevant schemas in `contracts/memory_v3/`.
6. Read `docs/architecture/long_term_memory.md` only when inspecting the legacy
   V2 behavior or the retain/replace/delete map.

Memory V3 rules:

- Treat `docs/architecture/memory_v3.md` as the source of truth for new memory
  behavior. The V2 long-term-memory document is historical implementation
  evidence, not the V3 target.
- No data migration or backward compatibility is required before release.
- Keep durable memory and all mutation authority on the phone. Server-side LLMs
  are stateless proposal engines and must never choose database IDs to mutate.
- Require evidence-backed observations and deterministic local validation before
  admission. An LLM output is an untrusted candidate, not stored truth.
- Use one V3 query planner, candidate generator, selector, and `MemoryBrief`
  injection path. Do not add a parallel retrieval shortcut.
- Keep protected evaluation fixtures ahead of implementation and compare V3
  against no-memory, V2, and oracle-memory baselines.
- Task 1 fixtures in `evaluation/memory_v3/` remain review candidates until a
  native or professionally fluent Hindi/Hinglish reviewer approves them. Do not
  claim protected coverage while review is pending.
- Task 2 V3 tables are an isolated schema only. Do not wire them into compiler,
  retrieval, or response behavior before their later implementation gates.
- Run `scripts/run-memory-v3-eval.sh --provider none` for the reproducible V2
  prompt-boundary baseline. Paid response capture requires the runner's explicit
  confirmation flags and approved credentials.
- Do not remove the V2 runtime path until the V3 shadow and response-quality
  gates in the evaluation document pass. Once they pass, delete V2 rather than
  retaining dual production paths.
- Run `python3 contracts/memory_v3/validate_schemas.py` whenever a Memory V3
  contract changes.

## Non-Negotiables

- Do not add auth unless explicitly requested.
- Do not add text chat UI or a text input box.
- Do not build video/avatar features in MVP tasks.
- Do not persist raw audio.
- Do not process raw realtime audio frames in Dart.
- Keep provider integrations behind interfaces.
- Keep latency and cost metrics from the beginning.
- Do not skip Sprint -1 validation gates.
- Crisis/safety overrides must happen before TTS.
- Do not hard-code secrets or API keys.

## Architecture Rules

- Flutter owns UI, app state, local chat history presentation, and high-level session commands.
- Native/WebRTC layers own latency-critical audio capture, playback, routing, interruption handling, and background-session behavior.
- Server-side VAD is required, but VAD alone must not decide final turn commits.
- Endpointing must use the state machine and thresholds documented in the architecture docs.
- The realtime agent lifecycle is one room-specific agent task/process per active LiveKit room for MVP.
- Critical LiveKit data-channel events must use a reliable/ordered path and sequence numbers.
- Partial transcript/live diagnostic events may use a faster lossy path.

## Safety and Privacy Rules

- No raw audio storage in MVP.
- Transcript storage must be local for MVP unless the user explicitly changes scope.
- Before real-user field testing, local transcript storage must be encrypted or the test must be restricted to non-sensitive scripted conversations.
- First microphone/session start must show consent copy explaining backend and AI-provider processing.
- India-specific crisis resources must remain available in the safety layer.
- If crisis intent is detected, bypass normal LLM companion response and use a predefined crisis-safe response.

## Implementation Discipline

- Keep changes scoped to the active sprint.
- Do not implement later-sprint features early unless the user explicitly requests it.
- Prefer simple, measurable implementation over speculative abstractions.
- Add or update tests when changing behavior.
- Add docs when a validation spike changes an assumption.
- If provider docs, pricing, or API behavior may have changed, verify current official docs before relying on old assumptions.

## Verification

For each completed sprint/task, report:

- What changed.
- Which acceptance criteria were verified.
- Which commands/tests were run.
- Any blockers or assumptions that remain.
