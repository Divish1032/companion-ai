# Master PRD

This is the strategic source of truth for the AI companion MVP: product thesis, scope, core requirements, major architecture decisions, assumptions, risks, and economics.

For implementation, read `AGENT_CONTEXT.md` and `SPRINTS.md` first, then only the architecture files relevant to the active sprint.

## 1. Executive Summary

Build a minimal but production-ready voice-only AI companion app for Hindi/Hinglish users in India. The app should feel like a real-time spoken companion, not a text chatbot with speech bolted on.

The MVP has no login/auth and no text input. The first screen is the actual voice chat experience. Users speak; the AI responds by voice; the app displays transcript-based chat history for continuity. Chat history is stored locally on device for MVP. Backend services are optimized for low latency, low overhead, and clear instrumentation of every stage: capture, transport, VAD, STT, LLM, TTS, playback.

The core architecture is:

```text
Flutter App
  -> self-hosted LiveKit WebRTC room
  -> realtime agent service
  -> VAD + endpointing
  -> Sarvam streaming STT
  -> LLM response generation
  -> Sarvam streaming TTS
  -> LiveKit audio track back to app
```

The product should be built as a serious foundation for future video/avatar support, but the MVP must remain voice-only and simple.

---

## 2. Product Thesis

India's next large consumer AI opportunity is not an English-first chat box. It is local-language, voice-first, emotionally useful AI that works on modest phones and variable mobile networks.

The MVP should prove three things:

1. Users in Tier 2/3 contexts are willing to speak to an AI companion in Hindi/Hinglish.
2. We can deliver first-audible-response latency low enough to feel conversational.
3. Unit economics can be controlled through concise responses, metered usage, and provider selection.

Primary validation metrics:

- At least 70% of field-test sessions reach 3+ user turns.
- At least 60% of field-test users say they would talk again.
- p50 first meaningful response is within the MVP target on real mobile networks.
- Empty/bad transcript recovery rate is measured and does not dominate sessions.
- Estimated provider cost per completed session is measured, not guessed.

Product validation before field testing:

- Run a lightweight concept test with 5-10 target users before broad beta.
- A Wizard-of-Oz or manually operated voice prototype is acceptable.
- Validate comfort with Hindi/Hinglish voice companion, privacy concerns, willingness to repeat after STT errors, and willingness to pay for minute-limited usage.
- Findings should inform persona, safety tone, and pricing assumptions.
- Own this as product/research work running in parallel with Sprints 0-2, so Sprint 6 persona work can use the findings.

This is not an "AI girlfriend" product spec by default. It is a broader AI companion foundation. Persona, safety, and positioning should be handled carefully in later product strategy.

---

## 3. MVP Scope

### 3.1 In Scope

- Flutter mobile app for Android and iOS.
- Android and iOS implementation from the same Flutter codebase.
- Voice-only chat.
- No auth/login.
- No text input box.
- Home screen is the chat screen.
- Local chat history persistence.
- User transcript messages shown in chat history.
- AI transcript messages shown in chat history.
- Tap-to-start voice session.
- Tap-to-end voice session.
- Continuous conversational mode while session is active.
- Barge-in: user can interrupt AI speech.
- Hindi/Hinglish MVP.
- Server-side VAD.
- Turn detection/endpointing beyond naive VAD.
- Self-hosted LiveKit.
- Server-generated room token.
- Configurable STT, LLM, and TTS integrations through backend adapters.
- LLM integration through backend abstraction.
- Latency metrics per conversation turn.
- Safety pipeline with crisis detection and India-specific resources.
- Minimal production observability.
- Ubuntu deployment for prototype testing.

### 3.2 Out of Scope for MVP

- User auth.
- Social login.
- Payments/subscriptions.
- Push notifications.
- Video calling.
- 3D avatar.
- Image/video understanding.
- Multi-language switching beyond Hindi/Hinglish.
- Full long-term cloud memory graph.
- Human handoff.
- Admin dashboard.
- Fine-tuning models.
- Self-hosting LLM/TTS.
- Large-scale custom STT infrastructure beyond a simple backend-local prototype deployment.
- Public App Store/Play Store production release.
- End-to-end encryption beyond transport security.

### 3.3 Phase 2 Candidates

- Marathi, Bengali, Tamil, Telugu.
- Voice persona selection.
- Cloud memory linked to anonymous device ID or real auth.
- Subscription and minute wallet.
- 3D avatar with local rendering.
- Viseme/blendshape streaming.
- Public App Store/Play Store release hardening.
- Offline fallback modes.
- Model/provider routing by leg, cost, and language.

---

## 4. Product Requirements

### 4.1 Home Screen

The home screen is the full product experience.

Required elements:

- Header with app name and compact connection/session state.
- Scrollable chat history.
- Transcript bubbles for user and AI turns.
- Current live transcript area while user is speaking.
- Current AI speaking/generating state.
- Large voice control button.
- Lightweight waveform or audio activity indicator.
- Permission/error state for microphone.
- Reconnect state if network drops.
- No text field.
- No send button.
- No onboarding carousel for MVP.
- No marketing hero screen.

Expected states:

```text
Idle
Requesting microphone permission
Connecting
Listening
User speaking
Thinking
AI speaking
Interrupted
Reconnecting
Error
Session ended
```

### 4.2 Voice Interaction

User flow:

1. User opens app.
2. App shows prior local chat history.
3. User taps voice button.
4. App requests microphone permission if needed.
5. App creates/joins LiveKit room.
6. User speaks naturally.
7. Server detects speech and starts streaming to STT.
8. Partial transcript may appear in UI.
9. Endpointing decides when user turn is complete.
10. LLM starts generating response.
11. TTS starts streaming audio as soon as enough text is available.
12. App plays AI audio.
13. If user speaks during AI playback, app/server interrupts AI output.

### 4.3 Chat History

MVP history is local-only.

Persist:

- Session ID.
- Message ID.
- Turn ID.
- Role: `user` or `assistant`.
- Transcript text.
- Created timestamp.
- Language code.
- Latency summary if available.
- Message status: `partial`, `final`, `interrupted`, `error`.

Do not persist raw audio in MVP.

Rationale:

- No auth means server-side identity is weak.
- Local history is enough to validate product UX.
- Avoid early privacy/compliance complexity.

### 4.4 STT Error Recovery

Because the MVP has no text input, it needs a voice-first correction path for bad transcription.

Required recovery behavior:

- Every final user transcript bubble should expose a lightweight "say again" or retry affordance.
- The user can re-speak the previous turn without sending the bad transcript to the LLM again.
- If STT confidence is low, transcript is empty, or endpointing produced a very short ambiguous utterance, the assistant should ask the user to repeat instead of guessing.
- Common correction phrases such as "nahi, mera matlab..." or "galat suna" should trigger replacement of the previous user turn rather than creating an unrelated new turn.
- The UI should make it clear when the last user turn was replaced.
- The backend should log retry/re-speak events as quality metrics.

### 4.5 Conversation Context

The visible chat history is local, but the AI still needs short-term context.

MVP context rules:

- During an active voice session, the realtime agent keeps the current session transcript in Redis or in process memory.
- On app session start, the client may send a small recent-history window from local storage to the backend, only after the user starts a voice session.
- The recent-history window should be limited by count and size, for example last 10-20 turns or a max character/token budget.
- Do not upload the full local chat history by default.
- Do not store uploaded recent history permanently on the backend in MVP.
- Include a client-visible privacy note that voice/transcript content is sent to AI providers for processing.

### 4.6 Anonymous Device Identity

No auth does not mean no identity at all.

MVP identity rules:

- Generate a random anonymous device ID on first app launch.
- Store it in secure local storage.
- Do not derive it from phone number, email, advertising ID, contacts, IMEI, or other PII.
- Use it for session creation, rate limiting, and debugging.
- Treat it as resettable if the app is deleted/reinstalled.
- Do not use it as a long-term user profile without later consent/auth changes.
- Do not log the anonymous device ID next to raw transcript text.
- Use separate opaque session IDs for metrics where possible.
- Document that anonymous identifiers can still become behavioral profiles if retained too long.

### 4.7 No Text Input

There must be no text input box in the MVP.

Reason:

- The product must force validation of voice UX.
- Text fallback can hide voice latency/quality problems.
- The target audience and differentiation are voice-first.

Optional debug-only text input may exist behind a compile-time developer flag, but must not be visible in normal builds.

---

## 5. Non-Functional Requirements

### 5.1 Latency Targets

Do not promise sub-500ms full turn latency in MVP. Use realistic engineering targets.

Target metrics:

```text
Client barge-in mute:                 p50 < 100ms, p95 < 180ms
Server speech-start detection:        p50 < 120ms, p95 < 250ms
End-of-turn decision after user stops: p50 < 350ms, p95 < 700ms
LLM first token after final transcript:p50 < 400ms, p95 < 1000ms
TTS first audio after text chunk:      p50 < 500ms, p95 < 1200ms
First meaningful AI response total:   p50 < 1500ms, p95 < 3500ms
```

Stretch target:

```text
First meaningful AI response p50 < 1000ms on good networks
```

Perceived-latency requirement:

- Add a filler-audio fast path using 5-10 pre-synthesized Hindi/Hinglish acknowledgment clips.
- Filler audio may play immediately after endpoint commit when LLM/TTS is expected to exceed the natural pause threshold.
- Examples: "Haan, samajh raha hoon...", "Ek second, soch raha hoon...", "Theek hai, sun raha hoon..."
- Maintain filler variants by tone, at minimum neutral, empathetic, and energetic.
- Select filler tone from simple last-turn sentiment/intent when available; default to neutral if uncertain.
- Cross-fade or cleanly stop filler audio when real TTS audio is ready.
- Filler audio must not mask crisis/safety situations; safety responses should bypass casual filler.

Measure from:

- user speech stop timestamp
- server endpoint commit timestamp
- STT final timestamp
- LLM first token timestamp
- TTS first byte timestamp
- client first playback timestamp
- first filler audio playback timestamp when used

### 5.2 Cost Targets

MVP should instrument cost per minute, not guess it.

Initial estimated provider costs:

- STT: Sarvam STT around INR 30/hour, billed per second.
- TTS: Bulbul v2 around INR 15/10K chars, Bulbul v3 around INR 30/10K chars.
- LLM: much cheaper than STT/TTS for normal short turns.
- Infra: lower than STT/TTS at early scale, but not zero.

Sprint -1 measured note:

- A real Bulbul v3 usage example cost about INR 7 for about 2400 characters.
- This is consistent with published pricing and confirms that long spoken responses can quickly dominate provider cost.

Working cost assumption for planning:

```text
Lean voice minute with short AI reply: INR 0.8 - INR 1.2
Natural voice minute with Bulbul v3:   INR 1.2 - INR 1.8
Managed/inefficient path:              INR 1.8 - INR 2.8+
```

Measured Bulbul v3 response-cost examples:

```text
200 chars reply:   about INR 0.6
300 chars reply:   about INR 0.9
600 chars reply:   about INR 1.8
1200 chars reply:  about INR 3.6
2400 chars reply:  about INR 7.2
```

Cost controls:

- Keep AI responses concise.
- Stream TTS only for committed text chunks.
- Stop TTS immediately on barge-in.
- Do not send silence to STT when avoidable.
- Cache/reuse persona/system prompt.
- Keep memory injection compact.
- Log chars generated per minute.
- Log STT seconds per minute.
- Log LLM input/output tokens and estimated LLM INR cost even if it is expected to be smaller than STT/TTS.
- Add provider billing-unit counters as soon as STT/TTS are integrated.
- Flag any measured cost that exceeds planning assumptions by more than 50%.
- Cap assistant response length aggressively if Bulbul v3 remains the default voice.

### 5.3 Reliability

The MVP should handle:

- Microphone permission denied.
- Network interruption.
- LiveKit reconnect.
- Backend restart during idle state.
- STT provider failure.
- TTS provider failure.
- User interruption during AI speech.
- App background/foreground on Android and iOS.

### 5.4 Privacy

MVP must:

- Not store raw audio.
- Store transcripts locally.
- Expose a "clear chat history" control.
- Show concise privacy copy before or during first microphone/session start.
- Explain that voice/transcripts are sent to backend and AI providers for processing.
- Allow the user to clear local transcript history.
- Use TLS for backend APIs.
- Avoid logging sensitive transcripts in production logs by default.
- Use redacted logs for metrics.
- Encrypt local transcript storage or explicitly document why encryption is deferred for prototype-only builds.
- Link or reference AI provider data-handling policies before field testing.

Minimum first-session consent copy:

```text
Your voice and transcript are sent to our server and AI providers to understand and respond.
We do not store raw audio in this MVP. Chat history is saved on this device.
You can clear chat history anytime.
Tap Agree to continue.
```

DPDP readiness requirements for field testing:

- Record user consent locally with timestamp and copy version.
- Provide a clear-history action that functions as local erasure.
- Provide contact/grievance details in settings or privacy copy, even if minimal during MVP.
- Maintain a list of third-party processors used for STT, LLM, and TTS.
- Add breach/incident response ownership before any broad beta.

### 5.5 Device Targets

Primary target devices:

- 4GB RAM minimum.
- Budget wired/Bluetooth earphones.
- Variable 4G/5G networks.
- Android 10+ preferred.
- iOS 16+ preferred.

The app must avoid heavy local ML in MVP.

---

## 6. Technical Architecture

### 6.1 Recommended Tech Stack

#### Mobile App

```text
Framework: Flutter
Language: Dart
State management: Riverpod
Realtime audio: LiveKit Flutter client
Local database: Drift + SQLite
Permissions: permission_handler
Audio session handling: audio_session
Secure local ID: flutter_secure_storage
Logging/diagnostics: structured app logger
```

Why Flutter:

- Fast cross-platform path.
- Good Android and iOS support.
- Mature UI layer.
- Acceptable performance for audio UI.
- One shared product architecture for both platforms.

Why LiveKit Flutter:

- WebRTC audio stack.
- Opus, jitter buffer, reconnect behavior.
- Data channels for transcript/events.
- Future video/avatar path.

Audio transport requirements:

- Use WebRTC native audio capture/playback path through LiveKit.
- Prefer Opus for network audio transport.
- Enable or preserve WebRTC echo cancellation, noise suppression, and automatic gain control unless testing proves they hurt quality.
- Do not route microphone PCM through Dart for realtime transport.
- Server-side agent should normalize provider-facing audio format in one place before STT.
- Log input/output audio format decisions, including sample rate, channel count, and codec where available.

#### Realtime Transport

```text
Self-hosted LiveKit server
Single-node for prototype
Redis only when multi-node is needed
coturn for TURN fallback
TLS termination through Caddy or Nginx
```

Prototype topology:

```text
Phone App
  -> LiveKit SFU on Ubuntu
  -> Realtime Agent joins same room
  -> STT provider selected by config
  -> LLM provider selected by config
  -> TTS provider selected by config
```

#### Backend Services

Recommended split:

```text
api-service:
  - room creation
  - LiveKit token minting
  - config endpoint
  - health checks

realtime-agent-service:
  - joins LiveKit rooms as AI participant
  - subscribes to user audio
  - runs VAD/endpointing
  - streams audio to STT
  - streams text to LLM
  - streams text to TTS
  - publishes AI audio track
  - emits data-channel events

worker-service later:
  - post-session memory extraction
  - analytics aggregation
```

Implementation recommendation for MVP:

```text
Python 3.12 + asyncio for realtime-agent-service
FastAPI for api-service
uv for dependency management
LiveKit Agents or LiveKit SDK where useful
Custom provider adapters
```

Reasoning:

- Most latency is network/model latency, not Python CPU overhead.
- Python has mature audio/VAD tooling.
- LiveKit Agents ecosystem is designed for realtime voice agents.
- Faster implementation than a from-scratch Go media agent.
- Keep adapters abstract so a Go/Rust rewrite remains possible later.

Performance note:

If Python service overhead becomes measurable, optimize specific hot paths first. Do not rewrite the entire backend prematurely.

#### Data Stores

MVP:

```text
Redis:
  - session registry
  - rate-limit counters with persistence enabled
  - cross-agent cancel/interruption pub-sub when needed

In-process agent memory:
  - active turn buffers
  - current transcript state
  - short-lived provider stream handles

SQLite on device:
  - chat history
```

Optional backend persistence:

```text
Postgres:
  - anonymous device records
  - usage metrics
  - aggregate latency/cost events
```

Do not require Postgres for the first working voice loop.

#### AI Providers

Initial providers:

```text
STT: backend-local Vosk for Hindi is provisionally acceptable after Sprint -1 benchmark; Sarvam Saaras v3 remains the API-backed STT adapter and fallback path
TTS: Sarvam Bulbul v2/v3 streaming
LLM: Sarvam-30B first, with provider abstraction
```

Provider abstractions should allow:

- Vosk for Hindi STT
- Sarvam-30B
- Sarvam-105B for quality tests
- Google Cloud Speech-to-Text Hindi as an STT fallback candidate
- Azure Cognitive Services Hindi neural voices as a TTS fallback candidate
- OpenAI/Gemini/other later if needed
- Local model later if economics justify it

Provider-routing requirements:

- Every pipeline leg must be independently swappable:
  - STT
  - LLM
  - TTS
- Routing must support global defaults plus per-language overrides.
- Example intended flexibility:
  - Hindi STT -> Vosk
  - Telugu STT -> Sarvam
  - Hindi TTS -> Sarvam Bulbul v2
- Core turn logic, endpointing, lifecycle, and app event contracts must remain provider-agnostic.

Pre-implementation provider gate:

- Before Sprint 0 implementation proceeds beyond scaffolding, run a streaming validation spike.
- Verify Sarvam STT emits useful partials during a 10-second Hindi/Hinglish audio stream.
- Verify Sarvam TTS can produce incremental audio from chunked text quickly enough for the target pipeline.
- Benchmark practical backend-local Hindi STT options against Sarvam STT.
- If either API behaves like batch processing, update this PRD before building the voice pipeline.

---

## 16. Key Assumptions

- Sarvam APIs are available and stable enough for MVP testing after Sprint -1 validation proves required streaming behavior where Sarvam remains in use.
- Backend-local Vosk may be acceptable for Hindi STT prototype use if targeted conversational validation remains acceptable.
- TTS cost is the dominant provider cost.
- Python backend overhead is not the main latency bottleneck.
- Flutter + LiveKit is sufficient for low-latency audio UX on target Android phones and iPhones.
- No auth is acceptable for prototype/MVP validation.
- Local history is acceptable for MVP.
- Users tolerate p50 around 1000-1500ms first meaningful response if perceived latency is improved with natural filler audio.
- Crisis/safety handling and privacy consent are required before real-user testing.

---

## 17. Open Questions

- Which exact Sarvam TTS model should be default: Bulbul v2 for cost or v3 for quality?
- Does Sarvam streaming TTS support the exact chunking behavior we need? This must be answered in Sprint -1.
- Is Vosk good enough on natural Hinglish and pause-heavy conversational Hindi to become the prototype STT default?
- For non-Hindi languages such as Telugu, should STT route to Sarvam while Hindi routes to Vosk?
- Should first LLM be Sarvam-30B or another low-latency model with better Hindi conversation quality?
- What is the best initial region for Ubuntu deployment based on target users?
- Should chat history be local only, or also synced by anonymous device ID after MVP?
- What is the intended brand/persona boundary for emotional companionship?
- What exact provider privacy policies and data-processing terms must be disclosed before field testing?

---

## 18. Technical Decision Records

### TDR-001: Use Flutter

Decision:

Use Flutter for the mobile app.

Reason:

Fast cross-platform development, good enough performance, strong UI tooling, and one shared product surface for Android and iOS.

### TDR-002: Use Self-Hosted LiveKit

Decision:

Use self-hosted LiveKit for realtime transport.

Reason:

LiveKit gives WebRTC audio, Opus, jitter handling, reconnects, data channels, and future video path. Self-hosting avoids LiveKit Cloud per-minute fees, though infra cost remains.

### TDR-003: Use VAD but Not VAD-Only Turn Taking

Decision:

Use server-side VAD for speech detection and barge-in, plus endpointing/turn logic for final user turn commit.

Reason:

VAD detects speech presence but does not understand whether the user is done.

### TDR-004: Keep Providers Swappable By Leg

Decision:

Keep STT, LLM, and TTS independently swappable through stable interfaces and config-driven routing.

Reason:

Provider choice may differ by language, cost, quality, and deployment constraints. The architecture must allow Hindi STT to use one provider while another language or pipeline leg uses another.

### TDR-004A: Do Not Self-Host LLM/TTS In MVP

Decision:

Do not self-host LLM or TTS in MVP.

Reason:

Quality, latency, and time-to-market matter more initially. Self-hosting those legs adds substantial infrastructure and model-serving complexity before validating demand.

### TDR-004B: STT May Be API-Based Or Backend-Local

Decision:

Allow STT to be either API-based or backend-local, as long as it stays behind `STTProvider` and is selected by config.

Reason:

Sprint -1 evidence shows local Hindi STT is worth pursuing for cost control, but only as a swappable backend leg rather than a hard-coded architecture commitment.

### TDR-005: Store Chat History Locally

Decision:

Store MVP chat history on device.

Reason:

No auth means cloud identity is weak. Local storage is simpler and more privacy-preserving for MVP.

### TDR-006: One Room-Specific Agent Per Session

Decision:

Use one room-specific realtime agent task/process per active LiveKit room for MVP.

Reason:

This removes queue/webhook ambiguity, keeps failure isolation simple, and avoids late architecture churn. Scale-out dispatch can be added after concurrency is measured.

### TDR-007: Safety Is a Pipeline Stage

Decision:

Run input/output safety checks and crisis overrides before TTS.

Reason:

Prompt-only safety is not enough for a human-facing companion product. Crisis content must not depend on a normal LLM response path.

### TDR-008: Validate Provider Streaming Before Building Voice Pipeline

Decision:

Sarvam STT/TTS behavior and at least one practical local Hindi STT option must be empirically validated in Sprint -1.

Reason:

The architecture depends on low-latency STT and incremental/low-latency TTS. If provider APIs are effectively batch-mode, or if local STT is not good enough for Hindi, the pipeline and cost strategy must be redesigned before implementation continues.

### TDR-008A: Sprint -1 Exit Status

Decision:

Treat Sprint -1 as passed for progression into Sprint 0, with a small number of explicit provisional decisions still under observation.

Reason:

The main architecture-killer unknowns were resolved strongly enough to proceed. Remaining questions such as final Vosk suitability for Hinglish are narrower product-quality and routing decisions, not blockers to repository scaffolding and baseline implementation.

---

## 19. Future Unit Economics Plan

Do not launch broad subscription until measured costs are known.

Recommended future pricing model:

```text
Free trial:
  5-10 total voice minutes

Starter:
  TBD after measured COGS and retention

Core:
  TBD after measured COGS and retention

Premium:
  larger minute bundle only if measured margins support it

Top-ups:
  prepaid minute packs priced from measured per-minute cost
```

Avoid unlimited or high daily caps until:

- TTS cost is reduced.
- Average response length is controlled.
- Retention is proven.
- Power-user behavior is understood.
- Real measured cost per minute is known across normal, noisy, retry-heavy, and power-user sessions.

---

## 20. Agent Implementation Rules

Future AI coding agents should follow these rules:

1. Do not add text chat UI unless explicitly requested.
2. Do not add auth unless explicitly requested.
3. Do not build video/avatar in MVP tasks.
4. Do not persist raw audio.
5. Keep provider integrations behind interfaces.
6. Keep latency metrics from the beginning.
7. Keep UI minimal but polished.
8. Prefer working voice loop over extra screens.
9. Do not optimize cost by making the product feel broken.
10. Do not hard-code secrets.
11. Do not silently swallow provider errors.
12. Do not assume local Mac testing proves mobile network performance.
13. Do not skip Sprint -1 validation gates.
14. Do not process raw realtime audio frames in Dart.
15. Do not use normal LLM output for crisis responses after a safety trigger.

---

## 21. Definition of MVP Done

The MVP is done when:

- Android and iOS Flutter apps open to the voice chat home screen.
- No text input exists.
- User can start a voice session.
- App connects to self-hosted LiveKit.
- Agent receives user audio.
- VAD detects speech and endpointing commits turns.
- STT produces Hindi/Hinglish transcript.
- LLM produces concise companion response.
- TTS produces audible AI voice.
- User can interrupt AI speech.
- Transcript chat history persists locally.
- Clear history works.
- Latency metrics are recorded per turn.
- Cost estimate is recorded per session.
- Ubuntu deployment works with real phone over mobile data.
- At least 10 real test sessions have been completed and reviewed.
- Sprint -1 provider validation and safety/privacy gates have passed or been explicitly reworked.

---

## 22. Local Development Plan

### 22.1 Mac-Only Development

The local Mac can be used for most prototype development.

Use Mac for:

- Flutter UI work.
- Local backend development.
- Local LiveKit testing through Docker.
- Provider adapter development.
- Mock audio/voice pipeline tests.
- Local database work.

Do not treat Mac-only testing as proof of production latency.

### 22.2 Ubuntu Development

Use Ubuntu instance when testing:

- Real Android phone over mobile network.
- Real iPhone over Wi-Fi and mobile data where available.
- Public WebRTC connectivity.
- TURN fallback.
- Reconnect behavior.
- Multi-device access.
- Long-running agent sessions.

Recommended prototype Ubuntu:

```text
4 vCPU
8 GB RAM
80-100 GB SSD
Ubuntu 22.04 or 24.04
```

### 22.3 Expected Root Commands

Future implementation should aim for simple commands like:

```bash
make setup
make dev
make check
make mobile
make logs
```

If `make` is not used, the README must provide equivalent commands.

### 22.4 Environment Files

Required templates:

```text
.env.example
services/api/.env.example
services/realtime-agent/.env.example
apps/mobile/.env.example or dart-define documentation
```

Never commit real API keys.

---

## 23. Major Risks and Mitigations

### 23.1 STT Quality Risk

Risk:

Hindi/Hinglish transcription may fail on noisy Tier 2/3 mobile audio or dialect-heavy speech.

Sprint -1 evidence:

- Sarvam STT shows the strongest proven streaming behavior so far.
- Vosk looks promising for Hindi-only local prototype use.
- The tested Whisper `base` configurations were not strong enough to replace Sarvam STT for this use case.

Mitigation:

- Build a representative audio test set early.
- Track empty transcript rate.
- Track manual user feedback on transcript quality.
- Keep STT provider pluggable.
- Validate Vosk specifically on Hinglish and pause-heavy conversational speech before making it the default Hindi STT path.

### 23.2 TTS Cost Risk

Risk:

TTS dominates unit economics and can make subscription pricing unprofitable.

Sprint -1 evidence:

- Bulbul v3 costing about INR 7 for about 2400 characters is consistent with list pricing and is expensive enough to make long companion responses unsafe for MVP margins.

Mitigation:

- Keep responses concise.
- Measure TTS chars/session.
- Compare Bulbul v2 vs v3.
- Add minute-wallet pricing later.

### 23.3 Latency Risk

Risk:

The product feels slow even if individual components are fast.

Mitigation:

- Stream every stage.
- Use endpointing carefully.
- Start TTS before full answer completes.
- Log p50/p95 per stage.

### 23.4 Barge-In Risk

Risk:

If interruption feels bad, the product feels non-human.

Mitigation:

- Client local mute on likely speech.
- Server VAD confirmation.
- Aggressive cancellation of LLM/TTS.
- Clear playback queues.

### 23.5 LiveKit Ops Risk

Risk:

Self-hosted LiveKit reduces vendor cost but adds deployment and networking complexity.

Mitigation:

- Start single-node.
- Use Docker Compose.
- Configure coturn early.
- Add health checks and logs.
- Scale only after concurrency requires it.

### 23.6 No Auth Risk

Risk:

No auth limits cloud memory, cross-device sync, abuse prevention, and paid usage.

Mitigation:

- Use anonymous device ID.
- Local-only history.
- Basic rate limiting.
- Add auth only after voice loop is validated.

### 23.7 Provider Streaming Risk

Risk:

If Sarvam STT/TTS streaming behaves like batch processing, the planned low-latency pipeline will not work as designed.

Mitigation:

- Run Sprint -1 streaming validation before pipeline implementation.
- Keep provider interfaces independent of Sarvam.
- Keep provider routing configurable by leg and language.
- Identify STT/TTS fallback candidates before beta.

### 23.7A Local STT Coverage Risk

Risk:

A local Hindi STT engine may reduce cost but may not generalize cleanly to Hinglish or to later Indian languages such as Telugu, Marathi, Bengali, or Tamil.

Mitigation:

- Treat local STT as language-specific, not automatically universal.
- Keep Sarvam STT and other providers available behind the same interface.
- Route providers by leg and language through config.
- Do not couple endpointing or app contracts to one STT adapter.

### 23.8 Abuse and Prompt-Injection Risk

Risk:

Voice input can include prompt-injection attempts, replayed audio, harassment, or abusive high-usage patterns.

Mitigation:

- Add prompt-injection guard before LLM calls.
- Keep system prompts outside user-visible context.
- Bind LiveKit tokens to session/device identity where possible.
- Rate-limit sessions and daily minutes per anonymous device.
- Log abuse signals without storing raw audio.

---

## 24. Reference Links

Use these links to verify pricing, transport choices, and turn-taking assumptions before implementation.

- Sarvam pricing: https://docs.sarvam.ai/api-reference-docs/pricing
- Sarvam rate limits: https://docs.sarvam.ai/api-reference-docs/ratelimits
- Sarvam STT: https://www.sarvam.ai/apis/speech-to-text
- LiveKit self-hosting: https://docs.livekit.io/transport/self-hosting/
- LiveKit SFU architecture: https://docs.livekit.io/reference/internals/livekit-sfu/
- LiveKit turn detector: https://docs.livekit.io/agents/logic/turns/turn-detector/
- Silero VAD: https://github.com/snakers4/silero-vad
- Moshi real-time speech dialogue paper: https://arxiv.org/abs/2410.00037
- Seamless streaming speech paper: https://arxiv.org/abs/2312.05187
- Hindi multi-accent ASR benchmark: https://arxiv.org/html/2408.11440v1

---
