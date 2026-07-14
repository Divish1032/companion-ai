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
- Benchmark practical local Hindi STT candidates against Sarvam STT.
- Lock the revised latency budget and filler-audio requirement.
- Lock endpointing state-machine defaults in config.
- Lock agent lifecycle: one room-specific agent task/process per active LiveKit room.
- Lock provider-by-leg interfaces and config-driven routing so STT, LLM, and TTS can be switched independently.
- Lock iOS `AVAudioSession` initial category/mode/options.
- Add initial crisis/safety resource list and crisis-detection phrase list.
- Add DPDP/privacy consent copy draft and provider-disclosure placeholder.
- Plan lightweight concept validation with 5-10 target users.

Deliverables:

- `docs/spikes/sarvam_streaming_validation.md`
- `docs/spikes/local_stt_benchmark.md`
- `docs/architecture/endpointing.md`
- `docs/architecture/agent_lifecycle.md`
- `docs/privacy/dpdp_mvp_notes.md`

Acceptance:

- Sarvam streaming behavior is known and documented.
- Local Hindi STT options are compared strongly enough to guide the prototype default.
- If Sarvam STT/TTS does not support needed streaming behavior, this PRD is updated before Sprint 0 implementation continues.
- Agent lifecycle and endpointing defaults are no longer open choices.
- Provider routing by leg is no longer an open architecture choice.

Sprint -1 exit summary:

- Passed:
  - Sarvam STT and TTS behavior were validated strongly enough to remove the original architecture-killer unknown.
  - Endpointing defaults, agent lifecycle, and privacy notes are locked in docs.
  - Provider-by-leg and per-language routing are now explicit architecture requirements.
- Provisional:
  - Hindi STT may default to backend-local Vosk for the prototype.
  - Sarvam STT remains the API-backed STT adapter and safer fallback path.
  - Sarvam TTS should prefer the official SDK path first.
- Still open but no longer blocking Sprint 0:
  - Final Hindi-default decision for Vosk on natural Hinglish and pause-heavy conversational audio.
  - Broader multi-language STT strategy beyond Hindi.

Sprint 0 readiness:

- Sprint -1 is complete enough to start Sprint 0.
- Remaining uncertainties are documented and narrowed; they are no longer architecture blockers.

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

Sprint 0 exit summary:

- Passed:
  - Monorepo structure exists with `apps/mobile`, `services/api`, `services/realtime-agent`, `infra`, and `config`.
  - Flutter app scaffold opens directly to a voice-only placeholder shell with no text input.
  - API and realtime-agent placeholders expose health endpoints.
  - Provider routing is config-driven by pipeline leg and language in `config/personas/hindi_companion_v1.toml`.
  - Docker Compose starts Redis and the placeholder services.
  - Root `make check` passes.
- Still open but intentionally deferred:
  - Real LiveKit, microphone, VAD, STT, LLM, and TTS pipeline implementation.
  - Production deployment to Ubuntu/Oracle Cloud.

Sprint 1 readiness:

- Sprint 0 is complete enough to start Sprint 1.
- Continue local development first; backend migration to Ubuntu can happen after the MVP sprints are ready.

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

### Sprint 5: STT Integration

Goal:

Stream user audio to the selected STT provider and receive partial/final transcripts.

Tasks:

- Implement `STTProvider` interface.
- Implement the selected first STT adapter.
- Convert audio frames to required format.
- Emit partial transcript events.
- Emit final transcript events.
- Persist final user transcript on device.
- Implement low-confidence/empty transcript repeat flow.
- Add STT failure handling.
- Add STT billing-unit/cost counters.
- Scaffold additional STT provider interface/config.

Deliverables:

- User speech becomes transcript.
- Partial transcript visible in app.

Acceptance:

- Hindi/Hinglish test audio transcribes.
- Empty transcript handled without LLM call.
- STT latency metrics logged.
- STT cost metrics logged.

Status:

- Complete and green as of 2026-07-08.
- Backend-local Vosk is the first Hindi STT adapter for Sprint 5.
- Sarvam STT remains scaffolded only as a future/fallback API-backed adapter path behind the same provider interface/config.
- Phone validation passed on Android over Wi-Fi with local Docker API, LiveKit, and realtime-agent.
- Validated Hindi phrase through phone mic: "namaste mera naam rahul hai aaj mera mood thoda theek nahi hai".
- Observed STT metrics: provider `vosk`, model `vosk-model-small-hi-0.22`, audio seconds `4.29`, provider cost units `0`.
- Android Studio debug runs need either `--dart-define=API_BASE_URL=http://<Mac LAN IP>:8000` or `adb reverse tcp:8000 tcp:8000` when using the default `http://localhost:8000`.

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

### Sprint 7.5: Conversation Memory and Context Quality

Status: Complete for the local MVP slice; Android same-session and
previous-session memory validation passed on the rebuilt debug APK.

Goal:

Make the companion remember useful context from the same session and previous local
sessions without polluting LLM prompts with bad STT, duplicate fragments, stale
assistant text, or unsafe inferred facts.

Tasks:

- Create a dedicated prompt/context builder for LLM calls.
- Represent context as structured messages and memory blocks, not ad hoc strings.
- Keep the latest user transcript as the highest-priority prompt input.
- Keep a bounded same-session working context of recent complete turns.
- Add a local previous-session memory summary that stays on device.
- Add a tiny local stable-facts store for explicit, useful facts such as preferred name,
  language style, and repeated safe preferences.
- Store memory provenance and quality metadata: source turn IDs, role, transcript status,
  STT confidence when available, created/updated timestamps, last-used timestamp, and
  confidence/importance score.
- Add memory admission rules so low-confidence, empty, repeat-requested, replaced,
  duplicate, or obviously fragmented STT turns do not enter LLM context.
- Add memory update rules: reinforce explicitly repeated facts, decay stale low-importance
  facts, and never infer sensitive or enduring emotional facts from one ambiguous turn.
- Add confidence/status metadata to transcript context sent from mobile to backend.
- Ensure only complete turns are eligible for memory: final user transcript plus final
  assistant transcript.
- Deduplicate repeated transcript fragments and repeated assistant replies before prompt
  assembly.
- Add a local retrieval/ranking step for memory selection using recency, relevance to the
  latest user turn, importance, and quality score. Keep it deterministic/simple for MVP;
  do not add an external vector database.
- Add correction handling so "Bad transcript? Re-speak" replacement removes or supersedes
  the noisy old turn from future context.
- Add memory source labels in prompt assembly, such as `latest_user`, `recent_turns`,
  `session_summary`, and `stable_facts`.
- Add strict prompt instructions that memory is fallible and the latest user message is
  authoritative.
- Add sensitive-memory guardrails: avoid storing crisis/self-harm events, medical/legal/
  financial claims, sexual content, or dependency phrases as stable facts; keep them only
  as short-lived safety context when needed.
- Keep all memory local-only for MVP; do not add cloud memory, auth, user accounts, vector
  databases, or raw audio storage.
- Ensure clear-history deletes local transcript history, session summaries, and stable
  facts.
- Add redacted diagnostics for prompt assembly: counts, roles, statuses, and character
  budgets, without logging full transcript text by default.
- Add tests for role correctness, noisy-STT exclusion, deduplication, replacement,
  clear-history erasure, and bounded prompt size.
- Add a small memory evaluation fixture with scripted Hindi/Hinglish turns that checks:
  same-session recall, previous-session recall, refusal to recall noisy STT, refusal to
  over-personalize from one turn, and no repetition from stale context.
- Validate on Android with at least one same-session memory recall and one previous-session
  memory recall.

Deliverables:

- LLM prompt context is precise, bounded, inspectable, and local-memory backed.
- Assistant can naturally remember a small number of useful facts without repeating noisy
  or stale transcript fragments.

Acceptance:

- Assistant can refer to a clear fact from earlier in the same session.
- Assistant can refer to one explicit stable fact from a previous local session.
- Low-confidence, empty, repeated, replaced, and repeat-requested transcripts are excluded
  from future LLM context.
- Assistant messages are never sent as user messages.
- Prompt context remains bounded by documented message and character limits.
- Prompt assembly chooses memory by documented priority: latest user turn first, then
  high-quality relevant memory, then recent complete turns, with stale/noisy memory omitted.
- Memory records include provenance and quality metadata sufficient to debug why a memory
  was included or excluded without logging full transcript text.
- Sensitive or safety-related events are not promoted into stable facts.
- Clear history removes transcript history and all local memory artifacts.
- No raw audio, cloud transcript storage, auth, text input, video/avatar, or vector DB is
  introduced.
- Android validation shows memory recall works without obvious repetition from noisy STT.

### Sprint 8: End-to-End Latency and Cost Instrumentation

Goal:

Make latency and cost visible enough to optimize rationally.

Tasks:

- Add turn-level metrics collector.
- Add client playback timestamp reporting.
- Add estimated cost calculator.
- Include LLM token cost in the cost calculator.
- Add memory pipeline metrics: deterministic route, memory-needed decision,
  embedding latency, local vector lookup latency, reranker latency, planner
  latency, candidate count, injected count, timeout/unavailable count, and
  deterministic fallback count.
- Separate cold model-load/warm-up latency from warm per-turn inference
  latency; never hide model loading inside the normal first-response metric.
- Record configured memory model names, embedding dimension, service version,
  and whether embeddings/reranking/planning were enabled for each test run.
- Add debug diagnostics panel in dev builds.
- Export session metrics as JSON/CSV.
- Add basic dashboard logs.
- Add explicit audio-format logging for capture/transport/provider conversion.
- Add cost assumption comparison and >50% overage flag.
- Include self-hosted memory model serving in the cost view as amortized
  Ubuntu compute/storage cost and model-download/cache size; embeddings,
  reranking, and planning have no per-request provider bill when served locally.
- Keep memory diagnostics redacted: counts, model IDs, timings, statuses, and
  budgets only; do not export transcript or memory text by default.

Deliverables:

- Every turn has latency breakdown and cost estimate.

Acceptance:

- Can inspect p50/p95 latency from test sessions.
- Can inspect INR/session estimate.
- Cost overage warnings appear when assumptions are exceeded.
- Can inspect warm p50/p95 memory lookup and model inference latency separately
  from cold model download/load time.
- A model timeout, unavailable response, invalid response, or disabled flag is
  visible as a fallback event and the voice turn remains measurable.
- Memory-enabled and memory-disabled sessions can be compared without
  exposing transcript text in diagnostics.

### Sprint 9: Ubuntu Deployment

Goal:

Deploy prototype stack to Ubuntu instance for real phone testing.

This sprint owns the remaining Phase 4 operational work:

- Deploy the prepared FP32 ONNX EmbeddingGemma artifact to Ubuntu with a
  persistent Hugging Face cache.
- Keep EmbeddingGemma enabled for embedding creation and keep Qwen reranking and
  planning disabled.
- Measure Ubuntu CPU warm p50/p95 latency, cold startup time, resident memory,
  and concurrent-session behavior.
- Restart the API and confirm cached artifact reuse, readiness transitions, and
  deterministic mobile fallback if ONNX loading fails.

Tasks:

- Write Docker Compose production-ish config.
- Configure LiveKit domain/TLS.
- Configure coturn.
- Configure authenticated TURN credentials and relay port range.
- Configure API service domain/TLS.
- Add deployment README.
- Add the stateless optional memory model-serving setup to the deployment
  runbook: install the API `model-serving` extra, persist the Hugging Face cache
  on a host volume, and document model revisions and licence acceptance. This
  must not change the deterministic Hindi/Hinglish path.
- Add a one-shot or admin-only model warm-up/check command for
  `/v1/embeddings`, `/v1/rerank`, and `/v1/memory-plan`; do not make the first
  real user turn pay the model download/load cost.
- Add model-serving readiness/health output that distinguishes disabled,
  downloading/loading, ready, and failed states.
- Benchmark an optional model-serving footprint only after the relevant
  hardware is available. Do not enable optional flags based only on the generic
  4 vCPU/8 GB recommendation.
- Keep model endpoints bounded and rate-limited; retain only redacted
  operational logs and no request text, vectors, or durable user memory.
- Add health checks.
- Add log rotation.
- Add restart policy.
- Ensure the model-cache volume survives API container replacement but is not
  included in application backups or exposed through the public web server.
- Document rollback: disable memory model flags and return to deterministic
  embedding/rerank plus no-planner fallback without changing the mobile schema.
- Run real mobile-network test before treating latency numbers as valid.

Deliverables:

- Phone can connect over public internet.
- LiveKit room works on mobile data.

Acceptance:

- Real Android phone completes voice conversation over 4G/5G.
- Real iPhone completes voice conversation over Wi-Fi and mobile data where available.
- TURN fallback works when UDP is blocked.
- At least one restrictive/mobile-network TURN test is documented.
- A fresh Ubuntu deployment can reproduce the model cache and pass embedding,
  rerank, and planner smoke checks before flags are enabled for real sessions.
- After a container restart, cached weights are reused and the service reports
  readiness only after the selected models are usable.
- If model download, loading, licensing, capacity, or latency validation fails,
  the deployment remains on deterministic fallback and voice sessions still
  work.

### Sprint 10: MVP Hardening

Goal:

Polish the MVP for limited external testing.

Tasks:

- Improve UI state transitions.
- Add offline/network error UI.
- Add provider timeout handling.
- Add rate limiting.
- Add memory endpoint rate limits and payload limits for embeddings, reranking,
  and planning; verify that model endpoints cannot be used as an unbounded
  unauthenticated compute or storage surface.
- Test memory fallback paths for disabled/unavailable optional models, invalid
  model/dimension contracts, stale responses, and
  ObjectBox rebuild failures.
- Run 5-concurrent-session tests with memory flags enabled and disabled; track
  API/model-serving RSS separately from per-agent RSS and define the measured
  memory guardrail.
- Validate cold-start behavior after API restart, cache loss, and partial model
  failure. A memory failure must omit memory for that turn, not fail the voice
  session or bypass safety ordering.
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
- Run the Hindi/Hinglish memory evaluation fixture: exact recall, previous-
  session recall, graph-expanded recall, greeting no-overretrieval, vague-query
  abstention, contradiction/supersession, sensitive-memory exclusion, and
  timeout fallback.
- Validate that model-serving and memory diagnostics contain no transcript,
  memory content, embeddings, or device identifier next to user content.
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
- Memory model failure, cache rebuild, or API restart does not cause cross-user
  memory leakage or block a normal voice turn.
- With memory serving enabled, all model requests stay within the measured
  host resource guardrail and the deterministic fallback remains available.

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
