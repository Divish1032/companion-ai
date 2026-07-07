# Observability and Metrics Architecture

Use this file for latency, quality, cost, and logging instrumentation.

Related sprints: Sprint 5, Sprint 7, Sprint 8, Sprint 10, Sprint 11.

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

Avoid raw transcript logging by default.

---
