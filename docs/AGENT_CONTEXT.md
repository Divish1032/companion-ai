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
- Sprint 0 repo and architecture foundation is complete.
- The next active sprint is Sprint 1: Flutter Voice Chat Shell, unless the user explicitly redirects.

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
- Sprint 8: `SPRINTS.md`, `architecture/observability_metrics.md`, `architecture/unit_economics.md`
- Sprint 9: `SPRINTS.md`, `architecture/backend_agent_livekit.md`
- Sprint 10: `SPRINTS.md`, all architecture files as needed
- Sprint 11: `SPRINTS.md`, `PRD_MASTER.md`, `architecture/unit_economics.md`, `architecture/safety_privacy.md`

## First Implementation Prompt

```text
Read docs/AGENT_CONTEXT.md and docs/SPRINTS.md. Start with Sprint -1 only.
Do not add auth. Do not add text input. Do not build video/avatar.
Validate Sarvam STT/TTS streaming behavior, lock endpointing defaults,
lock agent lifecycle, document the latency/filler-audio decision,
and add the initial safety/privacy notes specified in Sprint -1.
Keep changes scoped to Sprint -1 and document results clearly.
```
