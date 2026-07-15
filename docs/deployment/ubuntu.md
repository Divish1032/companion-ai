# Ubuntu Deployment Runbook

This is the Sprint 9 handoff for public-network phone testing. It covers the
single-node Docker Compose deployment and the optional stateless long-term-memory
model service. It is not a production-release guide.

## Deployment shape

Run these services on the Ubuntu host:

```text
caddy or nginx       TLS and public HTTP/WebSocket entry point
livekit              WebRTC SFU
coturn               authenticated TURN fallback
redis                durable rate-limit/session support
api                  sessions, tokens, memory model endpoints
realtime-agent       VAD, STT, LLM, TTS, room agent
```

Phone-owned SQLite/Drift memory and the ObjectBox vector index remain on the
phone. The API's `/v1/embeddings`, `/v1/rerank`, and `/v1/memory-plan` routes
are stateless compute only; they must not become a server-side memory store.

## Host prerequisites

- Ubuntu 22.04 or 24.04.
- Recommended starting point: 4 vCPU, 8 GB RAM, and 80-100 GB SSD.
- Docker Engine and the Compose plugin.
- A DNS name and TLS certificate path for the API/LiveKit deployment.
- Firewall/security-group rules for HTTPS, LiveKit signaling/WebRTC, TURN
  TLS/TCP, and the explicitly configured TURN relay UDP range.
- A private host directory for the Hugging Face model cache, separate from
  application/session data and excluded from routine application backups.

The 4 vCPU/8 GB size is only a starting point for optional model experiments.
Hindi/Hinglish production traffic uses deterministic memory processing and does
not require model serving or GPU hardware.

## Configuration order

1. Copy the repository and environment templates to the host. Set real
   LiveKit, domain, TURN, and provider values; never use the local `devkey` or
   `secret` outside local development.
2. Mount a persistent host directory as `HF_HOME=/models/huggingface` for the
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
- Configure coturn with authenticated credentials and a bounded relay port
  range. Test at least one restrictive mobile network.
- Apply request and payload rate limits to the memory endpoints. No-auth MVP
  does not mean unlimited model compute.
- Keep the model cache outside the public web root and readable only by the
  API container/user.
- Confirm logs contain only request IDs, model IDs/revisions, dimensions,
  counts, timings, statuses, and resource measurements - not transcript or
  memory content.
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
- Android and iPhone public-network results, including TURN fallback.

Do not treat Mac-only Docker results or cold model-download latency as proof of
production-like voice latency.
