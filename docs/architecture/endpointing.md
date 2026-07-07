# Endpointing Defaults

Date locked: 2026-07-07

Sprint: Sprint -1 Validation Gates

Scope:

- Lock the MVP endpointing state machine.
- Lock default thresholds and fallback rules from the PRD and existing architecture docs.
- Remove endpointing as an open architecture choice before implementation.

## Decision

The MVP uses server-authoritative endpointing with three inputs:

- server-side VAD
- STT transcript state
- timing and silence windows

VAD is required for speech detection, but VAD alone must never commit a user turn.

Client-side audio activity may improve local UI responsiveness and local playback ducking, but it is never the final turn authority.

## State Machine

Canonical state machine:

```text
Idle
  -> SpeechCandidate
SpeechCandidate
  -> InSpeech
  -> Idle
InSpeech
  -> EndpointCandidate
  -> ForcedEndpoint
EndpointCandidate
  -> InSpeech
  -> CommitTurn
ForcedEndpoint
  -> CommitTurn
CommitTurn
  -> Thinking
```

State meanings:

- `Idle`: no active user utterance.
- `SpeechCandidate`: possible user speech, not yet confirmed strongly enough to start a turn.
- `InSpeech`: active confirmed user turn; audio is flowing to STT.
- `EndpointCandidate`: silence suggests the user may be done, but we wait for continuation checks.
- `ForcedEndpoint`: max utterance duration reached; commit even if the user does not fully pause.
- `CommitTurn`: finalize transcript for the turn and hand off to LLM pipeline.

## Default Thresholds

These values are locked as MVP defaults and must be configurable, not hard-coded in business logic.

- Minimum confirmed speech before a turn starts: `200 ms`
- Pre-speech audio buffer forwarded to STT: `180 ms`
- Silence before `EndpointCandidate`: `600 ms`
- Extended silence when continuation risk is high: `1000 ms`
- Forced endpoint timeout: `9 s`
- Server barge-in confirmation: `200 ms`
- VAD processing window: `30 ms`
- STT forwarding chunk size target: `100-200 ms`

Why these defaults:

- They stay inside the ranges already documented in `docs/architecture/voice_pipeline.md`.
- They balance speed with reduced false commits for Hindi/Hinglish pauses and discourse particles.
- They leave room for Sprint 4 tuning without reopening the architecture decision.

## Commit Rules

Commit a user turn only when all applicable rules are satisfied:

1. Speech has already been confirmed.
2. Silence has held for at least the current endpoint window.
3. No resumed speech has appeared during the endpoint window.
4. Transcript state does not strongly suggest continuation.

Continuation risk should block immediate commit when the last partial or final visible text ends in a likely continuation marker such as:

- `toh`
- `aur`
- `phir`
- `matlab`
- `haan`
- `ruk`

The continuation-marker list is a heuristic, not the only rule. Timing, resumed speech, and confidence signals still matter.

## Empty and Low-Confidence Turns

Rules:

- Do not call the LLM for an empty turn.
- Do not call the LLM for a very short, low-confidence, or highly ambiguous turn.
- Ask the user to repeat instead of guessing.

Examples of turns that should trigger repeat flow:

- no transcript text after commit
- transcript contains only noise-like text
- transcript is too short to infer intent and confidence is low

## Forced Endpoint Behavior

Forced endpoint exists to cap:

- runaway user turns
- cost exposure
- STT buffering growth
- poor UX where the assistant never responds

MVP rule:

- At `9 s`, commit the best available transcript and continue.
- If the transcript is effectively empty, use repeat flow instead of LLM generation.

Forced endpoint should be logged distinctly from normal endpoint commits.

## STT Relationship

The endpointing layer assumes STT and VAD run concurrently after speech confirmation.

Rules:

- Do not wait for end-of-speech before starting STT.
- Keep endpointing independent from provider-specific VAD.
- If useful STT partials are available, use them for continuation checks.
- If Sarvam does not provide useful partials, keep this state machine but fall back to timing-plus-final-transcript behavior and re-evaluate the PRD before Sprint 5.

## Barge-In Relationship

Server-side barge-in is confirmed after about `200 ms` of user speech.

On confirmed barge-in:

1. Cancel active LLM generation.
2. Cancel active TTS generation.
3. Stop queued playback cleanly.
4. Return to listening state.
5. Start a fresh user turn using the same speech-confirmation logic.

Client-side early duck or mute is allowed, but only as a responsiveness aid.

## Filler-Audio Decision

Filler audio remains required for MVP perceived latency.

Rules:

- Filler audio may start only after `CommitTurn`.
- Filler audio is allowed only when safety has not triggered a crisis override.
- Filler audio must stop cleanly when real TTS is ready.
- Endpointing does not wait for filler audio; filler audio is downstream from commit.

This keeps endpointing simple while preserving the PRD latency strategy.

## Ownership Boundary

Server owns:

- VAD authority
- endpointing authority
- barge-in authority
- commit timestamps

Client owns:

- waveform and local speaking indication
- optional immediate local duck or mute
- presentation of listening, thinking, and speaking states

## Metrics To Emit

At minimum, emit:

- speech candidate start timestamp
- speech confirmed timestamp
- endpoint candidate timestamp
- commit timestamp
- forced endpoint flag
- repeat-flow flag
- barge-in stage
- silence window used for commit

These metrics are required to tune Sprint 4 without reopening the architecture.

