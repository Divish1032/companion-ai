# Observability and Metrics Architecture

Use this file for latency, quality, cost, and logging instrumentation.

Related sprints: Sprint 5, Sprint 7, Sprint 7.5, Sprint 8, Sprint 9, Sprint 10, Sprint 11.

## 13. Observability and Metrics

### 13.1 Required Metrics

Per turn:

- Audio capture start.
- VAD speech start.
- VAD speech end candidate.
- Endpoint commit.
- STT partial received.
- STT final received.
- LLM request start.
- LLM first token.
- LLM complete.
- TTS request start.
- TTS first audio.
- First audio published.
- Client first playback if client reports it.
- Barge-in timestamp.
- Cancel completion timestamp.

Cost metrics:

- STT audio seconds.
- STT billed units if provider exposes them.
- TTS generated characters.
- TTS billed units if provider exposes them.
- LLM input tokens.
- LLM output tokens.
- Estimated INR cost per turn.
- Estimated INR cost per session.
- Provider fallback/retry count.

Memory and model-serving metrics per turn or memory operation:

- Deterministic memory route and memory-needed decision.
- Embedding, local ObjectBox lookup, reranker, and planner latency.
- Configured and active embedding backend (`onnx` or `pytorch`) and fallback
  reason, if any.
- Cold model-load/download time separately from warm inference time.
- Candidate count, vector-hit count, reranked count, injected count, and
  memory lookup timeout count.
- Model unavailable/invalid-response count and deterministic fallback count.
- Configured model names, embedding dimension, enabled flags, and service
  revision for the test run.
- Model cache size, resident memory, CPU/GPU utilization, and warm readiness
  during Ubuntu load tests.

Quality metrics:

- Turn count.
- Interrupted turns.
- Failed turns.
- Empty transcripts.
- Re-speak/retry turns.
- Low-confidence transcript turns.
- Average response length.
- User session duration.
- Sessions with 3+ turns.
- Post-session willingness-to-talk-again rating if collected.

### 13.2 Logs

Production logs should include:

- Request IDs.
- Session IDs.
- Turn IDs.
- State transitions.
- Error codes.
- Provider latency.
- Memory route, model status, candidate/injected counts, and redacted model
  latency/fallback events.

Avoid raw transcript logging by default.

Embedding, reranker, and planner logs must not include request text, memory
text, vectors, or an anonymous device ID next to user content. A model
download/cache path may be logged only as an artifact identifier, revision, or
size/status measurement.

### Sprint 8 telemetry contract

Sprint 8 uses `telemetry_envelope_v1` for terminal turn records. It contains
only session/turn IDs, monotonic timestamps, redacted counters/statuses, rate
card version/fingerprint, integer micro-INR line items, cost-source labels, and
the terminal outcome. It must never contain transcript, memory, audio bytes,
vectors, device IDs, provider payloads, or free-form errors.

The realtime agent publishes the envelope to the mobile diagnostics channel and
may send it to the API's service-authenticated ingest endpoint. Local
development uses SQLite; production can configure a first-party Postgres DSN.
Raw terminal telemetry is retained for 30 days by default. Client playback is
reported only when a native playback observer can provide it; it is not used to
subtract server and client clocks. Dashboards show playback-report coverage
separately from server endpoint-to-first-published-audio latency.

The Android implementation currently observes an AudioManager playback
configuration change within a reliable TTS marker window. Its source is labeled
`android_audio_playback_configuration_proxy`, because the public Android API
does not expose a renderer-specific first-frame callback. It is coverage
evidence, not physical DAC latency. iOS reports no timestamp until a native
WebRTC renderer hook is supplied; missing reports remain missing.

### Memory judge operation contract

`memory_judge_v1` is a bounded local-window judgement. Its terminal outcomes
are `accepted`, `superseded`, `rejected`, `unavailable`, `timeout`, and
`invalid`; local validation may downgrade any proposal to rejected. Operation
records contain only timestamps, bounded-window count, attempt count, outcome,
accepted count, and cost source. They never contain the window, candidate,
notice, transcript, memory value, provider response, or free-form error. An
unpriced external judge is `unknown`, not zero cost, and makes that operation
record cost-incomplete. A delayed judge record appends instead of replacing the
immutable terminal voice-turn record.

---
