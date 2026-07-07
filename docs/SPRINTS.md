# Sprint Execution Plan

Read `AGENT_CONTEXT.md` first. Use this file for sprint tasks, deliverables, and acceptance criteria.

Relevant architecture references are listed in `AGENT_CONTEXT.md`.

## 15. Sprint Plan

Each sprint is intended to be small enough for future AI coding agents to pick up and execute.

### Sprint -1: Validation Gates

Goal:

Remove architecture-killer unknowns before implementation commits to the voice pipeline.

Tasks:

- Validate Sarvam STT true streaming with Hindi/Hinglish sample audio and record whether partials arrive during speech.
- Validate Sarvam TTS streaming/chunked behavior and record time to first audio for short Hindi chunks.
- Lock the revised latency budget and filler-audio requirement.
- Lock endpointing state-machine defaults in config.
- Lock agent lifecycle: one room-specific agent task/process per active LiveKit room.
- Lock iOS `AVAudioSession` initial category/mode/options.
- Add initial crisis/safety resource list and crisis-detection phrase list.
- Add DPDP/privacy consent copy draft and provider-disclosure placeholder.
- Plan lightweight concept validation with 5-10 target users.

Deliverables:

- `docs/spikes/sarvam_streaming_validation.md`
- `docs/architecture/endpointing.md`
- `docs/architecture/agent_lifecycle.md`
- `docs/privacy/dpdp_mvp_notes.md`

Acceptance:

- Sarvam streaming behavior is known and documented.
- If Sarvam STT/TTS does not support needed streaming behavior, this PRD is updated before Sprint 0 implementation continues.
- Agent lifecycle and endpointing defaults are no longer open choices.

### Sprint 0: Repo and Architecture Foundation

Goal:

Create the monorepo structure and baseline tooling.

Tasks:

- Create `apps/mobile` Flutter project.
- Create `services/api` backend service.
- Create `services/realtime-agent` service.
- Create `infra/docker-compose.yml`.
- Create `config/personas/hindi_companion_v1.toml`.
- Create placeholder safety config for crisis phrases/resources.
- Add root README with local setup.
- Add `.env.example`.
- Add formatting/linting setup.
- Add basic CI script or local `make check`.

Deliverables:

- Repo builds locally.
- Empty Flutter app runs.
- Backend health endpoint works.
- Docker Compose starts Redis and placeholder services.

Acceptance:

- `make dev` or documented equivalent starts local stack.
- `make check` or documented equivalent passes.

### Sprint 1: Flutter Voice Chat Shell

Goal:

Build production-ready minimal UI without backend voice functionality.

Tasks:

- Implement `VoiceChatHomeScreen`.
- Add Riverpod app state.
- Add voice session state machine.
- Generate and persist anonymous device ID in secure storage.
- Add local Drift database.
- Add Drift schema versioning and migration hook.
- Add chat history list.
- Add clear history action.
- Add first-session privacy copy for microphone and AI processing.
- Add microphone permission flow.
- Add Android manifest microphone/audio permissions.
- Add iOS `Info.plist` microphone permission text.
- Configure baseline `audio_session` behavior for Android and iOS.
- Add initial local DB encryption plan; implement encryption before real-user field testing.
- Add mock conversation mode for UI development.
- Add compact waveform/audio activity placeholder.
- Add bad-transcript retry/re-speak UI affordance on final user bubbles.
- Benchmark local mute/duck path timing through Flutter/plugin/native APIs.

Deliverables:

- App opens directly to voice chat.
- No text input exists.
- Mock messages persist locally.

Acceptance:

- User can start mock session.
- User/AI mock transcript messages appear.
- Restarting app preserves messages.
- Clear history works.
- Anonymous device ID is created without PII.
- Re-speak affordance can replace the previous mock user turn.
- Android microphone permission flow works on a real device/emulator.
- iOS microphone permission flow works on a real device/simulator where supported.
- Barge-in mute/duck benchmark result is documented.

### Sprint 2: LiveKit Self-Hosted Local Integration

Goal:

Connect Flutter app to a self-hosted LiveKit room.

Tasks:

- Add LiveKit server to Docker Compose.
- Implement API token endpoint.
- Implement anonymous session creation endpoint.
- Enforce one active session per anonymous device for prototype.
- Enable durable rate-limit counters through Redis persistence or simple durable store.
- Send bounded recent local transcript context when a voice session starts.
- Implement Flutter LiveKit connection service.
- Publish microphone audio track.
- Subscribe to remote AI audio track placeholder.
- Add reliable and lossy data-channel send/receive abstractions.
- Add event `sequence` handling and client deduplication.
- Configure Opus/track publish defaults where LiveKit exposes them.
- Add reconnect/error UI states.

Deliverables:

- App joins LiveKit room.
- App publishes mic audio.
- Backend can mint room tokens.
- Critical events can be sent over reliable channel.

Acceptance:

- LiveKit room visible in server logs.
- App connection state updates correctly.
- Disconnect/reconnect handled gracefully.
- Data-channel final/error events are not lost in a basic simulated-loss test.

### Sprint 3: Realtime Agent Skeleton

Goal:

Create agent that joins LiveKit room and reacts to audio/data events.

Tasks:

- Implement realtime agent service.
- Implement direct room-specific agent spawn/assignment for new sessions.
- Join room as AI participant.
- Subscribe to user audio.
- Emit session state events over data channel.
- Add structured turn IDs.
- Add cancellation primitives.
- Add fake TTS audio response for pipeline testing.
- Add filler-audio playback path using static Hindi/Hinglish acknowledgment clips.
- Add safety classifier stub before TTS.
- Add provider interface implementations with mocked providers.
- Clean up agent state on client leave, expiry, or idle timeout.

Deliverables:

- Agent joins same room as app.
- App receives agent events.
- App can play fake response audio if supported.

Acceptance:

- Starting app session creates room and agent participant.
- Agent emits `listening`, `thinking`, `speaking` states.
- Agent failure produces an app-visible error state.
- Filler audio can play and stop cleanly before fake TTS response.

### Sprint 4: VAD and Endpointing

Goal:

Detect user speech reliably and commit turns.

Tasks:

- Integrate Silero VAD server-side.
- Process LiveKit audio frames.
- Emit speech start/end events.
- Implement endpointing state machine with config thresholds.
- Add pre-speech buffer forwarding to STT path.
- Add barge-in event path.
- Add VAD config thresholds.
- Create representative Hindi/Hinglish sample audio set for endpointing tests.
- Add sample audio tests for long pause, cough/noise, trailing particles, and forced endpoint.

Deliverables:

- Server detects speech.
- App state changes to user speaking/listening.
- Endpoint commit events generated.

Acceptance:

- Clean sample audio produces correct speech boundaries.
- Long pause test does not always prematurely commit.
- Barge-in during fake AI speech cancels speaking state.
- Forced endpoint prevents runaway utterances.

### Sprint 5: Sarvam STT Integration

Goal:

Stream user audio to Sarvam STT and receive partial/final transcripts.

Tasks:

- Implement `STTProvider` interface.
- Implement Sarvam STT adapter.
- Convert audio frames to required format.
- Emit partial transcript events.
- Emit final transcript events.
- Persist final user transcript on device.
- Implement low-confidence/empty transcript repeat flow.
- Add STT failure handling.
- Add STT billing-unit/cost counters.
- Scaffold fallback STT provider interface/config.

Deliverables:

- User speech becomes transcript.
- Partial transcript visible in app.

Acceptance:

- Hindi/Hinglish test audio transcribes.
- Empty transcript handled without LLM call.
- STT latency metrics logged.
- STT cost metrics logged.

### Sprint 6: LLM Integration and Persona

Goal:

Generate concise companion responses.

Tasks:

- Implement `LLMProvider` interface.
- Implement Sarvam-30B adapter or selected first LLM.
- Load system/persona prompt from version-controlled config.
- Add short history window.
- Add response length controls.
- Add response-length validator/truncator before TTS.
- Add input safety checks and prompt-injection guard.
- Add output safety checks and crisis override before TTS.
- Stream LLM tokens.
- Emit assistant transcript partial/final events.

Deliverables:

- Final user transcript produces AI text response.

Acceptance:

- AI replies in natural Hindi/Hinglish.
- Average response remains concise.
- LLM errors produce graceful fallback.
- Overlong LLM output is clipped at a safe boundary before TTS.
- Crisis test phrases trigger safety response, not normal companion reply.

### Sprint 7: Sarvam TTS and Audio Playback

Goal:

Convert AI text response into streamed voice.

Tasks:

- Implement `TTSProvider` interface.
- Implement Sarvam Bulbul adapter.
- Implement text chunking.
- Stream TTS audio frames back into LiveKit.
- App subscribes and plays AI audio.
- Stop TTS on barge-in.
- Add 50-80ms fade-out path for interrupted TTS where possible.
- Validate chunk boundaries against actual Hindi/Hinglish LLM output.
- Log TTS chars, provider billing units, and latency.
- Scaffold fallback TTS provider interface/config.

Deliverables:

- Full voice-to-voice conversation works.

Acceptance:

- User speaks; AI responds audibly.
- AI transcript appears.
- Barge-in stops AI audio.
- TTS latency metrics logged.
- TTS cost metrics logged.

### Sprint 8: End-to-End Latency and Cost Instrumentation

Goal:

Make latency and cost visible enough to optimize rationally.

Tasks:

- Add turn-level metrics collector.
- Add client playback timestamp reporting.
- Add estimated cost calculator.
- Include LLM token cost in the cost calculator.
- Add debug diagnostics panel in dev builds.
- Export session metrics as JSON/CSV.
- Add basic dashboard logs.
- Add explicit audio-format logging for capture/transport/provider conversion.
- Add cost assumption comparison and >50% overage flag.

Deliverables:

- Every turn has latency breakdown and cost estimate.

Acceptance:

- Can inspect p50/p95 latency from test sessions.
- Can inspect INR/session estimate.
- Cost overage warnings appear when assumptions are exceeded.

### Sprint 9: Ubuntu Deployment

Goal:

Deploy prototype stack to Ubuntu instance for real phone testing.

Tasks:

- Write Docker Compose production-ish config.
- Configure LiveKit domain/TLS.
- Configure coturn.
- Configure authenticated TURN credentials and relay port range.
- Configure API service domain/TLS.
- Add deployment README.
- Add health checks.
- Add log rotation.
- Add restart policy.
- Run real mobile-network test before treating latency numbers as valid.

Deliverables:

- Phone can connect over public internet.
- LiveKit room works on mobile data.

Acceptance:

- Real Android phone completes voice conversation over 4G/5G.
- Real iPhone completes voice conversation over Wi-Fi and mobile data where available.
- TURN fallback works when UDP is blocked.
- At least one restrictive/mobile-network TURN test is documented.

### Sprint 10: MVP Hardening

Goal:

Polish the MVP for limited external testing.

Tasks:

- Improve UI state transitions.
- Add offline/network error UI.
- Add provider timeout handling.
- Add rate limiting.
- Add crash/error reporting if selected.
- Validate Android audio focus, route changes, and foreground-service need.
- Validate iOS `AVAudioSession`, route changes, interruption events, and background-audio need.
- Re-run Flutter/plugin event timing benchmark for local mute/duck during barge-in.
- Implement native Kotlin/Swift immediate mute/duck bridge if Flutter/plugin timing misses latency target.
- Add Kotlin/Swift platform bridges only for gaps that Flutter plugins cannot cover.
- Test audio route changes: speaker -> wired -> Bluetooth -> speaker.
- Add local transcript encryption or explicitly limit build to internal scripted testing.
- Validate DPDP consent copy and provider-disclosure copy.
- Tune VAD thresholds.
- Tune endpointing.
- Tune response length prompt.
- Tune TTS chunking.
- Add privacy copy and clear history.
- Run 5-concurrent-session stress test.
- Monitor per-agent RSS/memory usage during stress test.
- Run overnight or 24-hour soak test if practical.

Deliverables:

- Internal Android build candidate.
- Internal iOS/TestFlight-ready build candidate.

Acceptance:

- 10+ real sessions complete without manual intervention.
- No text input.
- History persists.
- Barge-in works acceptably.
- p50 first meaningful response is measured and documented.
- No severe privacy/safety blocker remains before field testing.
- All 5 concurrent stress-test sessions complete at least 3 turns each.
- No agent is killed by OOM and no agent exceeds configured memory guardrail without an explicit follow-up issue.
- No cross-room audio, transcript, or state leakage is observed.

### Sprint 11: Hindi Field Test

Goal:

Validate with representative users.

Tasks:

- Recruit 10-20 Hindi/Hinglish speakers from target audience.
- Start recruiting before Sprint 10 completes because participant recruitment has lead time.
- Collect consented feedback.
- Do not collect raw audio unless explicit consent and storage plan exist.
- Capture subjective ratings:
  - response speed
  - voice naturalness on a 1-5 scale
  - Hindi comfort
  - emotional usefulness
  - willingness to pay
- Capture metrics:
  - session length
  - turns/session
  - interruptions
  - failed turns
  - cost/session
  - re-speak/retry rate
  - sessions with 3+ turns
  - first-session drop-off before 3 turns
  - would-talk-again rating

Deliverables:

- Field test report.
- Ranked issue list.
- Go/no-go recommendation for paid MVP.

Acceptance:

- At least 70% of sessions reach 3+ user turns, or failure causes are documented.
- At least 60% of users say they would talk again, or failure causes are documented.
- Product team can decide whether to continue, pivot, or rework core pipeline.

---
