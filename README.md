# Companion AI

Low-latency Hindi/Hinglish voice-only AI companion MVP for Android and iOS.

## Status

Active phase: Sprint 0 repo and architecture foundation.

Sprint -1 validation gates are complete enough to proceed. Sprint 0 is scaffold only: no auth, no text input, no video/avatar, and no real voice pipeline implementation.

## Repo Layout

- `apps/mobile`: Flutter Android/iOS app shell.
- `services/api`: FastAPI service for future room/session/config endpoints.
- `services/realtime-agent`: FastAPI placeholder plus STT/LLM/TTS provider interfaces and routing config.
- `infra/docker-compose.yml`: Redis plus placeholder services for local development.
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
make dev      # start Redis and placeholder services
make check    # docs, scaffold, Python, and Flutter checks
make mobile   # run the Flutter app
make logs     # follow Docker Compose logs
```

Health endpoints when `make dev` is running:

- API: `http://localhost:8000/health`
- Realtime agent: `http://localhost:8001/health`

## Provider Routing

Provider choices are config-driven by pipeline leg and language in `config/personas/hindi_companion_v1.toml`. Sprint 0 includes only interfaces and routing scaffolding; real STT, LLM, and TTS adapters are later-sprint work.

## Git Hooks

This repo uses local hooks from `.githooks/`.

```bash
git config core.hooksPath .githooks
git config commit.template .gitmessage
```
