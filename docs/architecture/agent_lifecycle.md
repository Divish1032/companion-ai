# Agent Lifecycle

Date locked: 2026-07-07

Sprint: Sprint -1 Validation Gates

Scope:

- Lock the MVP lifecycle for the realtime voice agent.
- Confirm one room-specific agent task or process per active LiveKit room.
- Define startup, steady-state, cancellation, and shutdown behavior.

## Decision

MVP architecture uses one room-specific agent task or process per active LiveKit room.

This is a hard Sprint -1 decision.

Why:

- simple routing
- simple failure isolation
- simple cancellation semantics
- no queue or webhook ambiguity
- lower architecture churn before measuring concurrency

This decision comes directly from the PRD and `docs/architecture/backend_agent_livekit.md`.

## Core Invariants

- A session has exactly one active LiveKit room.
- A room has at most one active assistant agent.
- The agent joins the same room as the user app.
- The agent lifecycle is explicit, not event-discovered later by background polling.
- If agent startup fails, the session creation flow must surface an app-visible error state.
- Safety overrides happen before any filler audio or TTS playback.

## Lifecycle Phases

```text
SessionRequested
  -> AgentAssigned
  -> RoomJoined
  -> Listening
  -> Thinking
  -> Speaking
  -> Listening
  -> ShuttingDown
  -> Terminated
```

Additional failure path:

```text
SessionRequested
  -> AgentStartupFailed
  -> Terminated
```

## Startup Flow

1. Client requests anonymous session creation from the API service.
2. API service creates a session record and LiveKit room name.
3. API service starts or assigns the room-specific agent before returning success when possible.
4. Agent initializes room-scoped runtime state:
   - turn buffers
   - provider clients
   - cancellation tokens
   - metric handles
   - sequence counters for critical events
5. Agent joins the target LiveKit room as the AI participant.
6. Agent subscribes to the user audio track.
7. Agent emits a reliable state event that the session is ready or listening.

If any startup phase fails:

- close or mark the session failed
- release temporary resources
- emit an error state to the client
- do not leave the app stuck in a connecting state

## Steady-State Responsibilities

Per active room, the agent is responsible for:

- subscribing to user audio
- normalizing incoming audio once for downstream providers
- running VAD and endpointing
- streaming audio to STT
- emitting transcript and state events
- invoking LLM
- chunking text for TTS
- streaming audio to TTS
- publishing AI audio back into the room
- canceling work on barge-in
- logging latency and cost metrics

Room-scoped state that must remain isolated per agent:

- current session metadata
- current turn id
- transcript state
- VAD state
- active provider stream handles
- filler-audio playback state
- pending TTS buffers
- cancellation primitives

## Event Reliability Rules

Critical events must use a reliable and ordered data-channel path with sequence numbers:

- session ready
- final transcript
- final assistant message
- error
- state transitions that unblock UI state
- turn commit

Non-critical live events may use a faster lossy path:

- partial transcript
- live diagnostics
- audio-level updates

This keeps UI integrity while allowing lower-latency live updates.

## Cancellation Rules

The agent must support immediate cancellation for:

- user barge-in during thinking
- user barge-in during TTS generation
- user barge-in during playback
- room disconnect
- session expiry
- idle timeout
- explicit user stop

Cancellation order on barge-in:

1. mark current assistant turn interrupted
2. cancel LLM stream
3. cancel TTS stream
4. drop queued audio not yet published
5. stop filler audio if active
6. emit updated listening state

The goal is a clean reset to listening without leaking provider work.

## Shutdown Conditions

Shutdown is triggered when any of the following occurs:

- client leaves the room
- session hits max duration
- idle timeout expires
- unrecoverable provider or room error occurs
- agent supervisor explicitly terminates the session

On shutdown, the agent must:

1. stop accepting new audio
2. cancel active provider streams
3. clear pending TTS and filler buffers
4. flush final metrics
5. remove room-scoped state from memory
6. clean up Redis or shared registry entries if present
7. leave the LiveKit room
8. emit a terminal state if the client is still connected

## Failure Handling

Expected failure classes:

- agent startup failure
- STT provider failure
- TTS provider failure
- LLM provider failure
- LiveKit disconnect or reconnect failure
- internal timeout or resource exhaustion

MVP failure policy:

- fail the current turn when possible, not the whole process by default
- fail the whole session when the room or agent is no longer trustworthy
- always emit an app-visible error state rather than silently hanging

## Concurrency Guardrails

Initial target from current architecture:

- support 5 simultaneous test sessions on the recommended 4 vCPU and 8 GB instance
- configure max concurrent agents per instance, initially `10`
- expose a `MAX_AGENT_MEMORY_MB` guardrail

If the instance is at concurrency cap:

- reject or queue new sessions explicitly
- do not oversubscribe by silently spawning unbounded agent tasks

## Deployment Flexibility

The dispatch contract is fixed even if process topology changes later.

Allowed MVP topologies:

- local prototype: API service and agent supervisor in one process, one async task per room
- deployed MVP: separate agent supervisor process or service, still one room-specific agent per room

Not allowed in MVP:

- shared pooled agent serving multiple user rooms at once
- queue-first architecture that delays room assignment
- deferred or best-effort agent attach after the app is already told the session is ready

## Metrics To Emit

Emit at minimum:

- session requested timestamp
- agent assigned timestamp
- room joined timestamp
- first listening-ready timestamp
- per-turn thinking start timestamp
- first TTS audio timestamp
- shutdown reason
- startup failure reason
- barge-in cancellation stage
- resident memory snapshot per agent during load tests

These metrics are necessary to validate the one-agent-per-room decision before any scale-out redesign.

