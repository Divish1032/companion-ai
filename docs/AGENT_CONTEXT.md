# Agent Context

This project is a low-latency Hindi/Hinglish voice-only AI companion MVP for Android and iOS.

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

## Current Execution Flow

1. Read `SPRINTS.md`.
2. Read only the architecture files relevant to the active sprint.
3. Keep changes scoped to the active sprint.
4. Verify the acceptance criteria for that sprint.
5. Update docs when a validation spike changes an assumption.

## Current Project Status

- Sprint -1 validation gates are complete enough to proceed.
- Sprints 0 through 7.5 are complete for the local MVP implementation and are
  green under the documented checks.
- Sprint 5 phone validation passed on Android over Wi-Fi with backend-local Vosk Hindi STT.
- Sprint 6 added LLM integration, persona config, safety override before response playback,
  assistant transcript events, local assistant transcript persistence, and Sarvam-30B
  validation.
- Sprint 7.5 delivered the local conversation-memory and context-quality slice
  after Sprint 7.
- The long-term-memory Phases 1-5 foundation, query-time local retrieval, and
  rebuilt-APK Hindi/Hinglish validation are complete. Ubuntu capacity/latency
  validation and GPU-dependent Qwen reranking/planning remain Sprints 8-10
  hardening work.
- The post-Phase-5 memory layer adds encrypted phone-owned storage, a
  strict-schema stateless background LLM candidate endpoint, idempotent local
  extraction jobs, deterministic admission, typed episodes/open threads,
  FTS5 + vector + graph + temporal retrieval, episode-window expansion, an
  active-dialogue-state prompt block, and per-memory confirm/forget controls.

## Active Memory Program

Memory V3 is the approved rewrite direction. Tasks 0 and 1 freeze architecture,
machine-readable boundaries, fixtures, and measured no-memory/V2/oracle
baselines. The bounded live Sarvam review is complete; native-human language
review and blinded human scoring remain pending. Tasks 2 and 3 add the isolated
V3 ledger/projection schema plus a stateless compiler and authoritative local
admission pipeline behind a disabled flag. Task 3.1 now limits the LLM to
semantic atoms; deterministic server code constructs append-only observations,
and the evaluator executes the production phone validator. Historical
full-observation model comparisons failed; the new compiler has not yet passed
development, independent robustness, native-reviewed protected, or live exit
gates. Task 4 runtime work and V3 cutover remain blocked. No V3
response-quality claim exists.

For any memory task, read in this order:

1. `architecture/memory_v3.md` for the target behavior and implementation gates.
2. `architecture/memory_v3_storage.md` for the concrete Task 2 phone schema.
3. `architecture/memory_v3_compiler.md` for Task 3 jobs, validation, and gates.
4. `architecture/memory_v3_consolidation.md` for Task 4 projection transitions.
5. `evals/memory_v3_evaluation.md` for protected scenarios and release criteria.
6. `../contracts/memory_v3/` for request, response, and storage-boundary schemas.
7. `architecture/long_term_memory.md` only to understand the V2 implementation
   being retained, replaced, or deleted.

V3 has no migration or backward-compatibility requirement because the product
is pre-release. V2 may remain temporarily as a measured baseline, but no new V2
memory feature should be added and no V2 runtime path should survive after V3
passes its shadow and response-quality gates.

## Sprint Reading Guide

- Sprint -1: `SPRINTS.md`, `architecture/voice_pipeline.md`, `architecture/backend_agent_livekit.md`, `architecture/safety_privacy.md`
- Sprint 0: `SPRINTS.md`, `PRD_MASTER.md`
- Sprint 1: `SPRINTS.md`, `architecture/mobile_app_native_audio.md`, `architecture/safety_privacy.md`
- Sprint 2: `SPRINTS.md`, `architecture/mobile_app_native_audio.md`, `architecture/backend_agent_livekit.md`
- Sprint 3: `SPRINTS.md`, `architecture/backend_agent_livekit.md`, `architecture/voice_pipeline.md`, `architecture/safety_privacy.md`
- Sprint 4: `SPRINTS.md`, `architecture/voice_pipeline.md`
- Sprint 5: `SPRINTS.md`, `architecture/backend_agent_livekit.md`, `architecture/observability_metrics.md`
- Sprint 6: `SPRINTS.md`, `architecture/safety_privacy.md`
- Sprint 7: `SPRINTS.md`, `architecture/voice_pipeline.md`, `architecture/backend_agent_livekit.md`
- Sprint 7.5: `SPRINTS.md`, `architecture/long_term_memory.md`, `architecture/safety_privacy.md`, `architecture/backend_agent_livekit.md`, `architecture/observability_metrics.md`
- Sprint 8: `SPRINTS.md`, `architecture/long_term_memory.md`, `architecture/observability_metrics.md`, `architecture/unit_economics.md`
- Sprint 9: `SPRINTS.md`, `architecture/long_term_memory.md`, `architecture/backend_agent_livekit.md`, `deployment/ubuntu.md`
- Sprint 10: `SPRINTS.md`, `architecture/long_term_memory.md`, `architecture/backend_agent_livekit.md`, `architecture/observability_metrics.md`, `architecture/safety_privacy.md`, `deployment/ubuntu.md`
- Sprint 11: `SPRINTS.md`, `PRD_MASTER.md`, `architecture/unit_economics.md`, `architecture/safety_privacy.md`
- Memory V3 rewrite: `architecture/memory_v3.md`,
  `architecture/memory_v3_storage.md`, `evals/memory_v3_evaluation.md`,
  `../contracts/memory_v3/`, then only the task-relevant legacy V2 files.

## First Implementation Prompt

```text
Read docs/AGENT_CONTEXT.md and docs/SPRINTS.md. Start with Sprint -1 only.
Do not add auth. Do not add text input. Do not build video/avatar.
Validate Sarvam STT/TTS streaming behavior, lock endpointing defaults,
lock agent lifecycle, document the latency/filler-audio decision,
and add the initial safety/privacy notes specified in Sprint -1.
Keep changes scoped to Sprint -1 and document results clearly.
```
