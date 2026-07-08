# Companion AI

Low-latency Hindi/Hinglish voice-only AI companion MVP for Android and iOS.

## Status

Active phase: Sprint 6 LLM integration and persona complete.

Sprint -1 through Sprint 6 are complete and green. Sprint 6 turns final user transcripts into concise Hindi/Hinglish assistant text responses through the LLM provider interface, emits assistant transcript partial/final events, and applies crisis safety overrides before any playback path. Real TTS, auth, text input, and video/avatar remain out of scope.

## Repo Layout

- `apps/mobile`: Flutter Android/iOS app shell.
- `services/api`: FastAPI service for future room/session/config endpoints.
- `services/realtime-agent`: FastAPI agent supervisor plus STT/LLM/TTS provider interfaces, mocked providers, safety stub, and LiveKit RTC skeleton.
- `infra/docker-compose.yml`: Redis with persistence, local LiveKit, and placeholder services for local development.
- `config/personas/hindi_companion_v1.toml`: Hindi companion persona and provider routing.
- `config/safety/crisis_placeholder.toml`: placeholder crisis phrase/resource config.
- `docs`: product, sprint, architecture, privacy, and spike docs.

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
API_LIVEKIT_URL=ws://<Mac LAN IP>:7880 docker compose -f infra/docker-compose.yml up -d --build
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

## Git Hooks

This repo uses local hooks from `.githooks/`.

```bash
git config core.hooksPath .githooks
git config commit.template .gitmessage
```
