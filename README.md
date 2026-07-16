# Companion AI

Companion AI is a voice-only Hindi/Hinglish companion for Android and iOS. It
uses Flutter for the phone app, LiveKit/WebRTC for realtime audio, and a
self-hosted Python agent for turn handling. This repository is the developer
source of truth for the mobile app, backend services, local tooling, and
single-node deployment assets.

For an operational command reference, see [commands.md](commands.md).

It intentionally does not include authentication, text chat, video/avatar
features, raw-audio storage, or cloud transcript/memory storage.

## What runs

```text
Flutter app -> API -> LiveKit room <-> realtime agent
                    |                 VAD, endpointing, STT, LLM, TTS
                    +-> Redis          session/rate-limit coordination
                    +-> Kokoro         private Hindi TTS service
```

- `apps/mobile`: Flutter Android/iOS voice UI, consent, session state, local
  chat history, and local memory.
- `services/api`: FastAPI session/token service plus stateless memory-model
  endpoints.
- `services/realtime-agent`: room-scoped agent supervisor and provider
  adapters. It handles VAD, endpointing, interruptions, STT, LLM, TTS, safety
  override, and LiveKit events.
- `infra/docker-compose.yml`: local Redis, LiveKit, Kokoro, API, and agent.
- `infra/production`: public single-node deployment tooling for Ubuntu/macOS.
- `config/personas/hindi_companion_v1.toml`: persona and provider routing.

For `hi-IN`, the normal keyless local path is Vosk STT, `persona_local` LLM,
and Kokoro TTS. Sarvam is a configured paid provider/fallback when the relevant
key is supplied. Provider selection stays config-driven rather than being
embedded in voice-turn logic.

## Memory and privacy model

The phone owns durable user data. Drift/SQLite stores transcripts, memory
records, provenance, claims, candidates, episodes, open threads, and job state;
ObjectBox stores the local vector index. Clear History deletes those local
artifacts. Raw audio is never stored.

Final turns first go through deterministic local admission rules. At query time,
the app combines deterministic SQLite/graph retrieval with local vector search,
then sends only a small, bounded context bundle to the API for the active voice
session. The API and realtime agent do not become a durable user-memory store.

Optional memory extraction is also phone-owned: the app sends at most a bounded
completed-turn window to `/v1/memory-judge`, receives untrusted candidate
proposals, then validates and commits or rejects them locally. It requires both
the phone build flag and the API's dedicated provider key. Optional embedding,
rerank, and planner endpoints are stateless compute; if unavailable, the phone
falls back to deterministic retrieval.

## Local development (macOS or Ubuntu)

Requirements:

- Docker Desktop (macOS) or Docker Engine with Compose plugin (Ubuntu)
- Flutter SDK; Android SDK for Android and Xcode for iOS development
- `uv` and Python 3.12 for service development

From the repository root:

```bash
cp .env.example .env
make setup
make dev
```

For actual local Vosk transcription, download and extract
`vosk-model-small-hi-0.22` so this path exists:

```text
models/vosk-model-small-hi-0.22/am/final.mdl
```

The Compose stack mounts `models/` read-only into the realtime agent. Without
the model, select/configure an available STT provider instead; do not treat a
missing model as a successful voice test.

Local endpoints:

```text
API:             http://localhost:8000/health
API readiness:   http://localhost:8000/readiness
Realtime agent:  http://localhost:8001/health
Agent readiness: http://localhost:8001/readiness
LiveKit:         ws://localhost:7880
```

Local LiveKit uses `devkey` / `secret` only. Never use those credentials in a
shared or public environment. Keep real keys in untracked environment files.

## Run the mobile app

```bash
cd apps/mobile
flutter run
```

Use the API URL that the target can reach:

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS simulator (or host-local desktop target)
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# Physical phone on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://<host-lan-ip>:8000
```

For a physical phone using local Docker, start LiveKit with the host LAN IPv4
advertised to WebRTC peers:

```bash
API_LIVEKIT_URL=ws://<host-lan-ip>:7880 LIVEKIT_NODE_IP=<host-lan-ip> \
  docker compose --env-file .env -f infra/docker-compose.yml up -d --build
```

Enable phone-side memory extraction only when the API is configured with its
provider key:

```bash
flutter run --dart-define=API_BASE_URL=http://<reachable-api-host>:8000 \
  --dart-define=ENABLE_MEMORY_EXTRACTION=true
```

## Configuration and optional providers

`.env` is for local Compose only and is gitignored. The root example documents
the common switches. `AGENT_SARVAM_API_KEY` enables Sarvam in the realtime
agent; `API_MEMORY_EXTRACTION_API_KEY` is separate and enables the API memory
judge. Never paste either key into source code, logs, or issues.

The base local path needs no paid key. Optional memory extraction requires:

```dotenv
API_ENABLE_MEMORY_EXTRACTION=true
API_MEMORY_EXTRACTION_BASE_URL=https://api.sarvam.ai/v1
API_MEMORY_EXTRACTION_API_KEY=
API_MEMORY_EXTRACTION_MODEL=sarvam-30b
API_MEMORY_EXTRACTION_TIMEOUT_SECONDS=20
```

## Debug and verify

```bash
make logs                 # follow all local service logs
make check                # docs, Python, and Flutter checks
make tts-kokoro-smoke     # validates all supported Hindi Kokoro voices
make tts-kokoro-benchmark # records local 1- and 5-request TTS metrics
make tts-e2e-sarvam       # one paid Sarvam fallback check
```

Useful first checks after `make dev`:

```bash
curl --fail http://localhost:8000/health
curl --fail http://localhost:8000/readiness
curl --fail http://localhost:8001/readiness
docker compose --env-file .env -f infra/docker-compose.yml ps
```

`/health` is process liveness. Use `/readiness` before diagnosing model or TTS
availability. It reports disabled/loading/ready/failed model state without
returning secrets or conversation content.

## Public deployment

The public stack includes Nginx TLS, LiveKit with embedded authenticated TURN,
Redis, Kokoro, API, and agent. From a checked-out release, deploy with:

```bash
./infra/production/scripts/deploy.sh
```

It prompts for the public DNS name, certificate email, and public IPv4, then
starts the stack and registers certificate renewal. DNS plus cloud firewall or
router forwarding are external prerequisites. Read the platform runbook before
running it:

- [Ubuntu deployment](docs/deployment/ubuntu.md)
- [macOS deployment](docs/deployment/macos.md)
- [production environment reference](infra/production/.env.example)

## Project guidance

Read [docs/AGENT_CONTEXT.md](docs/AGENT_CONTEXT.md) and the active sprint in
[docs/SPRINTS.md](docs/SPRINTS.md) before changing product behavior. The
architecture and privacy constraints in `docs/architecture/` are mandatory,
especially the no-raw-audio and phone-owned-memory boundaries.
