# Backend, Agent, LiveKit, and Deployment Architecture

Use this file for API service, LiveKit session/token flow, realtime agent lifecycle, provider interfaces, and Ubuntu deployment.

Related sprints: Sprint -1, Sprint 0, Sprint 2, Sprint 3, Sprint 5, Sprint 7, Sprint 9, Sprint 10.

## 11. Backend Requirements

### 11.1 API Service

Endpoints:

```text
GET /health
POST /v1/session
POST /v1/livekit/token
GET /v1/config
```

`POST /v1/session`:

- Creates anonymous session.
- Accepts device ID.
- Returns session ID and LiveKit room name.

`POST /v1/livekit/token`:

- Accepts session ID and device ID.
- Returns LiveKit JWT.
- Token TTL should be short.

No auth in MVP, but require:

- Device ID.
- Basic rate limits by IP/device.
- CORS locked to app/dev origins where applicable.

Rate limit starting points:

- Session creation per device/IP: conservative cap suitable for testing.
- LiveKit token minting per session/device: prevent token spam.
- Active sessions per anonymous device: 1 by default.
- Max session duration: configurable, for example 10-20 minutes during prototype.
- Max daily prototype minutes per device: configurable.
- Rate-limit counters must survive service restarts through Redis AOF/RDB persistence or a simple durable store.

### 11.2 Realtime Agent Service

Responsibilities:

- Join room as AI participant.
- Subscribe to user audio track.
- Run VAD and endpointing.
- Connect to STT provider.
- Manage transcript events.
- Call LLM provider.
- Call TTS provider.
- Publish AI audio track.
- Cancel streams on interruption.
- Emit metrics.

Agent lifecycle:

- The API service creates a LiveKit room name and session record.
- MVP decision: one room-specific agent task/process per active LiveKit room.
- The API service directly starts or assigns the room-specific agent before returning a successful session response when possible.
- Local prototype may run the API service and agent supervisor in one process, spawning one asyncio task per session.
- MVP deployment may split the agent supervisor into a separate process, but the dispatch contract remains direct and explicit.
- Initial concurrency target: support 5 simultaneous test sessions on the recommended 4 vCPU/8 GB Ubuntu instance.
- Set a configurable max concurrent agents per instance, initially 10, and reject/queue new sessions gracefully after the cap.
- Track per-agent resident memory during stress tests and expose a configurable `MAX_AGENT_MEMORY_MB` guardrail.
- Agent shutdown occurs when the client leaves, session expires, or max idle timeout is reached.
- Agent must clean up provider streams, pending TTS buffers, and Redis state on shutdown.
- If agent startup fails, the app must receive an error state rather than staying stuck in connecting/listening.

### 11.3 Provider Interfaces

Define interfaces:

```python
class STTProvider:
    async def stream(audio_frames) -> AsyncIterator[TranscriptEvent]:
        ...

class LLMProvider:
    async def stream(messages, context) -> AsyncIterator[str]:
        ...

class TTSProvider:
    async def stream(text_chunks) -> AsyncIterator[AudioFrame]:
        ...
```

Do not hard-code Sarvam throughout business logic. Keep Sarvam in adapters.

Provider behavior:

- MVP provider choice is per leg, not global.
- Sprint -1 provisional direction:
  - Hindi STT may default to backend-local Vosk if targeted conversational validation remains acceptable.
  - Sarvam remains a valid STT adapter and a likely default for languages not covered well by local STT.
  - LLM and TTS may still default to Sarvam initially.
- Interfaces must support multiple providers even if fallback providers are not enabled on day one.
- Identify fallback candidates before beta: Google Cloud Speech-to-Text for Hindi STT and Azure Cognitive Services for Hindi TTS.
- Provider selection must support language-based routing, for example Hindi STT using Vosk while another language uses Sarvam.
- Add provider timeouts, retry limits, and circuit-breaker style error handling.
- Log all provider fallback, retry, timeout, and rate-limit events.

### 11.4 Configuration

Use environment variables:

```text
APP_ENV
PUBLIC_BASE_URL
LIVEKIT_URL
LIVEKIT_API_KEY
LIVEKIT_API_SECRET
SARVAM_API_KEY
VOSK_MODEL_PATH
STT_PROVIDER
LLM_PROVIDER
TTS_PROVIDER
TTS_MODEL
STT_MODEL
REDIS_URL
LOG_LEVEL
PERSONA_CONFIG_PATH
MAX_CONCURRENT_AGENTS
MAX_AGENT_MEMORY_MB
MAX_SESSION_SECONDS
```

Configuration requirements:

- Support global defaults per leg.
- Support per-language overrides per leg.
- Keep routing decisions in config, not scattered through business logic.

Secrets must not be committed.

---

## 12. Deployment Requirements

### 12.1 Prototype Ubuntu Instance

Minimum:

```text
2 vCPU
4 GB RAM
40-80 GB SSD
Ubuntu 22.04 or 24.04
```

Recommended MVP:

```text
4 vCPU
8 GB RAM
80-100 GB SSD
Good network bandwidth
India region preferred
```

### 12.2 Services on Ubuntu

Use Docker Compose initially.

Services:

```text
livekit
coturn
redis
api-service
realtime-agent-service
caddy or nginx
```

Optional:

```text
postgres
prometheus
grafana
loki
```

### 12.3 Networking

Required:

- TLS domain.
- LiveKit WebRTC UDP ports open.
- TURN TLS/TCP fallback.
- Health checks.
- Firewall rules.

TURN requirements:

- coturn configured with authenticated access, not open relay.
- Prefer time-limited credentials generated by the API service or long-term credentials for prototype only.
- Configure TLS certificates for TURN/TLS.
- Define an explicit UDP relay port range, for example 49152-65535, and open it in firewall/security group.
- Test connectivity from at least one restrictive Indian mobile network before field testing.
- Add bandwidth limits appropriate for mono voice sessions.

Opus/WebRTC publish defaults where configurable:

- User mic uplink: mono, 20ms packet time, 16-24kbps, FEC on if available.
- AI voice downlink: mono, 20ms packet time, 24-32kbps, FEC on if available.
- Avoid stereo audio in MVP.

---
