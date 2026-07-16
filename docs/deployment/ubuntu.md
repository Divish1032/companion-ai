# Ubuntu Deployment Runbook

This is the single-node public-network deployment runbook for phone testing.
It covers the Docker Compose stack and the optional stateless long-term-memory
model service. It is not a production-release guide or a substitute for a
managed high-availability deployment.

## One-command install

After the external prerequisites below are complete, the full host setup and
application deployment is one interactive command from a checked-out copy of
this repository:

```bash
git clone git@github.com:Divish1032/companion-ai.git /opt/companion/app
cd /opt/companion/app
git checkout main
./infra/production/scripts/deploy.sh
```

The command asks for the public DNS hostname, Let's Encrypt contact email, and
the server's public IPv4 address. It installs Docker Engine/Compose and helper
tools on Ubuntu when Docker is absent; downloads the Hindi Vosk model; creates
`/opt/companion/runtime/production.env` with generated LiveKit and telemetry
secrets; renders LiveKit configuration; starts Redis, LiveKit (with embedded
authenticated TURN), Kokoro, API, realtime agent, and Nginx; obtains a TLS
certificate; and installs the twice-daily certificate-renewal timer.

For unattended rebuilds, supply every value explicitly. Use an approved Vosk
model artifact URL if your environment does not permit the default public
`rhasspy/vosk-models` mirror:

```bash
./infra/production/scripts/deploy.sh --non-interactive \
  --domain voice.example.com \
  --email ops@example.com \
  --node-ip 203.0.113.10 \
  --vosk-url 'https://your-approved-artifacts.example/vosk-model-small-hi-0.22.zip'
```

Do not create or commit a repository-root `.env` for production. The only
runtime secret file is `/opt/companion/runtime/production.env`, mode `0600`.

## Deployment shape

Run these services on the Ubuntu host:

```text
nginx                TLS and public HTTP/WebSocket entry point
livekit              WebRTC SFU
LiveKit embedded TURN authenticated TURN fallback
redis                durable rate-limit/session support
api                  sessions, tokens, memory model endpoints
realtime-agent       VAD, STT, LLM, TTS, room agent
kokoro-tts           private CPU Hindi TTS service; primary TTS for hi-IN
```

Phone-owned SQLite/Drift memory and the ObjectBox vector index remain on the
phone. The API's `/v1/embeddings`, `/v1/rerank`, and `/v1/memory-plan` routes
are stateless compute only; they must not become a server-side memory store.

## Host prerequisites

- Ubuntu 22.04 or 24.04.
- Candidate starting point: 4 vCPU, 8 GB RAM, and 80-100 GB SSD.
- A DNS name resolving to the server's public IPv4 before deployment. Let's
  Encrypt will not issue a certificate for a bare IP address.
- At the cloud provider/network edge, allow TCP `80`, `443`, `7881`, and
  `5349`; UDP `3478`, `40000-40100`, and `50000-50100`. The script adds these
  rules only when UFW is already active; it intentionally does not enable a
  new host firewall because doing so could lock out a custom SSH setup.
- If the repository is private, a GitHub deploy key or other read-only Git
  access must be configured before `git clone`.
- A private host directory for the Hugging Face model cache, separate from
  application/session data and excluded from routine application backups.

The 4 vCPU/8 GB size is only a starting point, not a capacity commitment. It
must accommodate LiveKit, the agent, and the resident Kokoro model as well as
optional model experiments. Hindi/Hinglish traffic does not require a GPU, but
the measured 1- and 5-session Kokoro latency, CPU, RAM, and fallback rate must
pass the deployment gate before selecting an instance size.

## Optional model configuration

Memory extraction is independent of the optional embedding/reranker/planner
models. The deployment creates these extraction settings in `production.env`:

```dotenv
API_ENABLE_MEMORY_EXTRACTION=true
API_MEMORY_EXTRACTION_BASE_URL=https://api.sarvam.ai/v1
API_MEMORY_EXTRACTION_API_KEY=
API_MEMORY_EXTRACTION_MODEL=sarvam-30b
API_MEMORY_EXTRACTION_TIMEOUT_SECONDS=20
```

Set `API_MEMORY_EXTRACTION_API_KEY` on the host and restart `api`. For actual
phone-side extraction jobs, build/run Flutter with
`--dart-define=ENABLE_MEMORY_EXTRACTION=true`; without this mobile flag, the
phone deliberately does not enqueue extraction work.

1. The deploy command mounts a persistent host directory as
   `HF_HOME=/models/huggingface` for the
   API container. The current Compose development file uses a named
   `memory-model-cache` volume; the Ubuntu deployment should use an explicitly
   backed-up-or-excluded host volume so cache retention is intentional.
3. Keep Qwen flags disabled for the first deployment; enable EmbeddingGemma
   after its artifact is prepared:

   ```text
   API_ENABLE_MEMORY_EMBEDDINGS=true
   API_ENABLE_MEMORY_RERANKER=false
   API_ENABLE_MEMORY_PLANNER=false
   ```

4. Keep the optional model names and embedding dimension aligned across API and
   mobile only when running an explicitly approved experiment:

   ```text
   API_MEMORY_EMBEDDING_MODEL=google/embeddinggemma-300m
   API_MEMORY_EMBEDDING_REVISION=57c266a740f537b4dc058e1b0cda161fd15afa75
   API_MEMORY_EMBEDDING_DIMENSION=768
   API_MEMORY_EMBEDDING_BACKEND=onnx
   API_MEMORY_EMBEDDING_MODEL_PATH=/models/huggingface/embeddinggemma-onnx-fp32-r57c266a7
   API_MEMORY_RERANKER_MODEL=Qwen/Qwen3-Reranker-0.6B
   API_MEMORY_PLANNER_MODEL=Qwen/Qwen3-0.6B
   ```

5. Keep EmbeddingGemma enabled for embedding creation and Qwen flags disabled.
   An unavailable EmbeddingGemma model must fail closed to deterministic mobile
   retrieval and must not block a voice turn.

## Model installation and warm-up

The API image installs the optional `model-serving` dependencies, but it does
not bake model weights into the image. Weights are downloaded lazily by the
configured Hugging Face model names and must persist in the cache volume.

Before accepting real sessions:

1. Create the persistent Hugging Face cache volume.
2. Run `scripts/prepare_embedding_onnx.py` once per model revision to
   create the complete Sentence Transformer artifact in the persistent cache.
   Then start the API; startup warm-up loads that artifact before readiness.
3. Record the exact model repository revision, licence/terms review, cache
   size, download result, and serving image digest in the deployment notes.
   The configured revision is exposed by `/readiness`, and the preparation
   script refuses an existing artifact without matching revision metadata.
4. Start the API with EmbeddingGemma enabled and Qwen flags disabled. Run smoke
   requests against `/readiness` and `/v1/embeddings`. Verify the
   active backend, response dimensions/schema, and redacted readiness status.
5. Keep EmbeddingGemma enabled for embedding creation. Keep Qwen reranking and
   planning disabled; deterministic reranking/planning and deterministic local
   fallback remain the default safety path.
6. Use the exact pinned `kokoro-tts` image digest from
   `infra/docker-compose.yml`. Do not expose port 8880 publicly: the
   realtime-agent reaches it only over the Docker network. Keep the local
   loopback binding only for host diagnostics. Configure `AGENT_KOKORO_BASE_URL`
   to the Docker service URL, and keep `AGENT_SARVAM_API_KEY` available for the
   existing Bulbul fallback.

## Hindi TTS installation, readiness, and rollback

Kokoro is the primary Hindi TTS provider and Sarvam Bulbul remains the fallback.
The public voice catalogue contains four native Hindi packs, not custom or
cloned user voices. Treat a new image, voice catalogue, or instance type as a
new quality and capacity validation.

Before accepting sessions:

1. Start `kokoro-tts` and wait for its `/health` liveness check.
2. Wait for realtime-agent `/readiness` to return `ready` with four checked
   voices. It performs a full all-pack warm-up using a fixed non-user phrase;
   `/health` alone is not readiness proof. Run `make tts-kokoro-smoke` as an
   independent all-voice deployment check; it rejects empty or malformed PCM.
3. Run `make tts-kokoro-benchmark` with the intended host shape. Preserve its
   redacted JSON output together with CPU and resident-memory observations at
   one and five concurrent requests. The command intentionally does not print
   response text or audio.
4. Run an end-to-end Hindi voice turn and a controlled Kokoro-unavailable test
   with a valid Sarvam key. Confirm the reliable provider-change event, Sarvam
   fallback audio, and that no text or PCM appears in logs. The controlled
   local command is `make tts-e2e-sarvam`; it sends one fixed short phrase and
   has a small paid Sarvam cost.

If Kokoro is unavailable or does not meet the measured latency/quality gate,
roll back without removing Sarvam:

```text
AGENT_TTS_PROVIDER=sarvam
AGENT_TTS_FALLBACK_PROVIDER=
```

Restart only `realtime-agent`; this leaves the mobile public voice IDs and
session API unchanged. Re-enable Kokoro only after the all-voice smoke and
benchmark gates pass. A post-audio Kokoro failure is not replayed, preventing
duplicate spoken content; the following synthesis uses Sarvam for the session.

The warm-up operation must not log request text, memory text, vectors, or
device IDs. If the ONNX artifact fails to load, the API does not load another
model; embedding requests fail closed, mobile retrieval continues with
deterministic fallback behavior, and readiness becomes `failed`.

## Readiness and rollback

`/health` only proves that the API process is running. The deployment must also
expose model-serving readiness that distinguishes:

```text
disabled -> downloading/loading -> ready -> failed
```

Do not advertise a model as ready merely because its Python dependency is
installed. After an API container restart, readiness must wait for the selected
weights to be available and warm. If a model fails later, disable its flag or
restart with the model disabled; the voice pipeline must continue without that
memory feature.

Rollback is intentionally simple:

```text
API_ENABLE_MEMORY_EMBEDDINGS=false
API_ENABLE_MEMORY_RERANKER=false
API_ENABLE_MEMORY_PLANNER=false
```

This must not require a mobile schema migration or delete phone-owned memory.

## Network and privacy checks

- Put the API and LiveKit behind TLS; use secure WebSocket signaling in the
  mobile build.
- LiveKit's embedded TURN service mints authenticated credentials and uses the
  bounded relay range. Test at least one restrictive mobile network.
- Apply request and payload rate limits to the memory endpoints. No-auth MVP
  does not mean unlimited model compute.
- Keep the model cache outside the public web root and readable only by the
  API container/user.
- Confirm logs contain only request IDs, model IDs/revisions, dimensions,
  counts, timings, statuses, and resource measurements - not transcript or
  memory content.
- Confirm Kokoro and agent logs contain no TTS input text, no raw PCM, and no
  public exposure of port 8880. The voice ID sent by mobile is a public label;
  provider speaker mappings remain server-side.
- Confirm preview assets are only the committed fixed synthetic clips under
  `services/api/app/static/tts-previews/`, with the pinned image/pack/checksum
  manifest. Do not create previews from user or conversation audio.
- Confirm clear history deletes the phone's SQLite/ObjectBox memory artifacts;
  there should be no corresponding server-side memory deletion workflow
  because the server must not retain those records.

## Deployment evidence to retain

For each Ubuntu test run, retain a short redacted record of:

- host shape, region, image digests, and model revisions;
- cache download/load status and cache size;
- optional experiment load/compatibility status and end-to-end first-response
  latency;
- resident memory and CPU/GPU usage at 1 and 5 concurrent sessions;
- model timeout/unavailable/fallback counts;
- Kokoro all-voice smoke output, 1/5-concurrency benchmark JSON, and the
  corresponding CPU/RAM measurements;
- Android and iPhone public-network results, including TURN fallback.

Do not treat Mac-only Docker results or cold model-download latency as proof of
production-like voice latency.
