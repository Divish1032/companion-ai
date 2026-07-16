# Production single-node deployment

This directory deploys the single-node Ubuntu or macOS shape without exposing
Redis, the API container, the realtime agent, or Kokoro to the public Internet.

It uses LiveKit's embedded TURN server, not a separate coturn container. This
is deliberate: LiveKit mints and supplies TURN credentials to the Flutter SDK
over the authenticated signaling connection. The server exposes TURN/UDP on
`3478`, TURN/TLS on `5349`, TURN relay UDP on `40000-40100`, LiveKit TCP
fallback on `7881`, and media UDP on `50000-50100`.

## One command

From a Git checkout, run:

```bash
./infra/production/scripts/deploy.sh
```

It prompts for the public domain, certificate contact email, and public IPv4.
On Ubuntu it can install Docker Engine/Compose; on macOS Docker Desktop and
Homebrew must already be installed and Docker Desktop must be running. The
command generates and protects the runtime environment file, downloads Vosk,
obtains TLS, starts all services, and registers certificate renewal.

Read [the Ubuntu runbook](../../docs/deployment/ubuntu.md) or
[the macOS runbook](../../docs/deployment/macos.md) before running it: DNS and
cloud firewall/router rules are external to the host and cannot safely be
configured by this script.

## Required input

`DEPLOY_DOMAIN` must be a real DNS name pointing to the VM before certificate
issuance. The host cannot securely serve the mobile app from a bare IP address.
The initial deployment starts with EmbeddingGemma disabled until a user who has
accepted its Hugging Face terms provides a read-only `HF_TOKEN` and the model
artifact has been prepared and checked through `/readiness`.

## Runtime secrets

The command creates `production.env` outside the checkout: `/opt/companion/runtime`
on Ubuntu and `~/.local/share/companion-ai` on macOS. It generates the LiveKit
secret and telemetry token automatically. Memory extraction is configured with
Sarvam's OpenAI-compatible endpoint and is enabled by default, but needs the
separate `API_MEMORY_EXTRACTION_API_KEY` before the API can call the provider.
`AGENT_SARVAM_API_KEY` is required for realtime conversational inference and
the realtime TTS fallback. Add `HF_TOKEN`
only after accepting the model terms and before an explicit artifact-preparation
flow; EmbeddingGemma, reranking, and planner flags remain disabled by default.

Do not use the source-tree `.env.example` as a deployed secret file and never
commit `production.env`.

LiveKit is intentionally on the Compose network and publishes only its
signaling, TCP fallback, TURN, relay, and WebRTC UDP ports. The gateway reaches
it by the `livekit` service name; do not substitute a host Docker bridge IP.
