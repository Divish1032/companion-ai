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

---
