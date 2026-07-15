# Companion AI

Low-latency Hindi/Hinglish voice-only AI companion MVP for Android and iOS.

## Status

Active phase: Sprint 7.5 local long-term-memory implementation complete; Sprints 8-10 validation and deployment hardening pending.

Sprint -1 through Sprint 7.5 are complete for the local MVP implementation and green under the documented checks. Sprint 7 turns final user transcripts into audible Hindi/Hinglish assistant responses through Sarvam Bulbul TTS and LiveKit audio playback. Sprint 7.5 adds phone-owned long-term memory with query-time retrieval, a local ObjectBox vector index, stateless API model contracts, and bounded asynchronous LLM candidate extraction. The pinned EmbeddingGemma ONNX artifact and configured real extractor are locally validated. Physical-device Phase 6 evidence, Ubuntu capacity, and public-network validation remain in Sprints 8-10. Auth, text input, video/avatar, cloud transcript storage, and raw audio persistence remain out of scope.

## Repo Layout

- `apps/mobile`: Flutter Android/iOS app shell.
- `services/api`: FastAPI service for session/config endpoints and stateless memory model adapters.
- `services/realtime-agent`: FastAPI agent supervisor plus STT/LLM/TTS provider interfaces, mocked providers, safety stub, and LiveKit RTC skeleton.
- `infra/docker-compose.yml`: Redis with persistence, local LiveKit, and placeholder services for local development.
- `config/personas/hindi_companion_v1.toml`: Hindi companion persona and provider routing.
- `config/safety/crisis_placeholder.toml`: placeholder crisis phrase/resource config.
- `docs`: product, sprint, architecture, privacy, and spike docs.
- `docs/deployment/ubuntu.md`: Ubuntu, model-cache, warm-up, readiness, and rollback handoff.

## Requirements

- Flutter SDK
- Docker Compose
- `uv`
- Python 3.12 for service runtime parity

The local `uv` checks may run on a newer compatible Python, but Docker images use Python 3.12.

## Local Setup

```bash
cp .env.example .env
cp services/api/.env.example services/api/.env
cp services/realtime-agent/.env.example services/realtime-agent/.env
make setup
```

Do not commit real secrets or provider API keys.

## Commands

```bash
make dev      # start Redis, LiveKit, API, and realtime-agent
make check    # docs, scaffold, Python, and Flutter checks
make mobile   # run the Flutter app
make logs     # follow Docker Compose logs
```

Health endpoints when `make dev` is running:

- API: `http://localhost:8000/health`
- Realtime agent: `http://localhost:8001/health`
- LiveKit: `ws://localhost:7880`

Local LiveKit runs in development mode with the documented dev credentials:

- API key: `devkey`
- API secret: `secret`

These are for local development only. Replace them through environment variables before any shared deployment.

For Android emulator networking, run the app with the host API URL:

```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For physical Android phone testing over Wi-Fi, start Docker with a LAN LiveKit URL and run Flutter with the Mac LAN API URL:

```bash
API_LIVEKIT_URL=ws://<Mac LAN IP>:7880 docker compose --env-file .env -f infra/docker-compose.yml up -d --build
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://<Mac LAN IP>:8000
```

If Android Studio launches without that dart define, this debug fallback also works:

```bash
adb reverse tcp:8000 tcp:8000
```

## Realtime Agent

During local Docker runs, the API calls `API_AGENT_ASSIGNMENT_URL` before returning a successful session. The realtime-agent joins the same room as `agent_<session_id>`, emits reliable `session_state` events (`listening`, `thinking`, `speaking`, `error`), and publishes generated placeholder audio for fake pipeline testing when supported by LiveKit RTC.

The filler-audio path is represented by reliable `filler_audio` start/stop events and a static-clip interface point. Real Hindi/Hinglish acknowledgment clips are deferred because no licensed/generated static audio assets are committed yet.

## Provider Routing

Provider choices are config-driven by pipeline leg and language in `config/personas/hindi_companion_v1.toml`. Hindi STT routes to `vosk`, Hindi LLM routes to the local `persona_local` provider for keyless local development, and Sarvam STT/LLM remain behind provider interfaces for configured API-backed use.

For local Vosk STT, download or mount `vosk-model-small-hi-0.22` under `models/` and set `AGENT_VOSK_MODEL_PATH` to the model directory visible to the realtime-agent process. Docker Compose mounts `../models:/models:ro` and sets `AGENT_VOSK_MODEL_PATH=/models/vosk-model-small-hi-0.22`. If the model path is absent, the agent still starts and emits an `stt_error` event on speech instead of fabricating a transcript. Local Vosk has zero provider cost units, but STT audio seconds are still counted and logged.

Sprint 5 phone validation on Android over Wi-Fi produced a final local Hindi transcript for "namaste mera naam rahul hai aaj mera mood thoda theek nahi hai" with Vosk metrics logged by realtime-agent.

Sprint 6 assistant text responses use the persona prompt, short history window, and response length limits in `config/personas/hindi_companion_v1.toml`. To use Sarvam chat completions, set `AGENT_LLM_PROVIDER=sarvam` and provide `AGENT_SARVAM_API_KEY` or root `SARVAM_API_KEY`; without a working provider the turn emits the configured graceful fallback response. The Sarvam-30B adapter was live-key smoke tested through `/v1/chat/completions`; it disables reasoning for short voice-turn responses so assistant content is returned within the small token cap.

Sprint 7.5 memory remains on device in the mobile Drift database. The app extracts conservative stable facts and previous-session summaries from complete final turns, excludes low-confidence/replaced/sensitive/noisy items, and sends only bounded structured `recent_turns` plus `memory_blocks` when starting a new voice session. The API stores that bundle only with the active session assignment, and the realtime agent builds redacted, source-labelled LLM prompt context with latest user text as authoritative.

Long-term-memory model serving is optional and disabled by default. The API image includes the model-serving dependencies and uses a persistent Hugging Face cache when enabled, but model weights must be downloaded, warmed, and capacity-tested on Ubuntu before real sessions. See `docs/deployment/ubuntu.md`; deterministic retrieval remains the fallback when model serving is unavailable.

## Git Hooks

This repo uses local hooks from `.githooks/`.

```bash
git config core.hooksPath .githooks
git config commit.template .gitmessage
```
