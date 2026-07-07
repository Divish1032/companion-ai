# Companion AI

Low-latency Hindi/Hinglish voice-only AI companion MVP for Android and iOS.

## Status

Active phase: Sprint 2 LiveKit self-hosted local integration.

Sprint -1 validation gates, Sprint 0 monorepo scaffolding, and Sprint 1 Flutter voice chat shell are complete. Sprint 2 connects the app to local self-hosted LiveKit only: no STT, LLM, TTS, VAD, auth, text input, or video/avatar.

## Repo Layout

- `apps/mobile`: Flutter Android/iOS app shell.
- `services/api`: FastAPI service for future room/session/config endpoints.
- `services/realtime-agent`: FastAPI placeholder plus STT/LLM/TTS provider interfaces and routing config.
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
make dev      # start Redis, LiveKit, API, and realtime-agent placeholders
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

## Provider Routing

Provider choices are config-driven by pipeline leg and language in `config/personas/hindi_companion_v1.toml`. The repo includes only interfaces and routing scaffolding; real STT, LLM, and TTS adapters are later-sprint work.

## Git Hooks

This repo uses local hooks from `.githooks/`.

```bash
git config core.hooksPath .githooks
git config commit.template .gitmessage
```
