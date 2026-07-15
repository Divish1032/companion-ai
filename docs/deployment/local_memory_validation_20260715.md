# Local Memory Model Validation - 2026-07-15

This record is redacted local-development evidence. It is not Ubuntu capacity,
public-network, TURN, or production readiness evidence.

## Artifact and image

- Host/runtime: Apple arm64, Docker Desktop.
- Embedding model: `google/embeddinggemma-300m`.
- Pinned repository revision:
  `57c266a740f537b4dc058e1b0cda161fd15afa75`.
- Artifact path:
  `/models/huggingface/embeddinggemma-onnx-fp32-r57c266a7`.
- Artifact size: approximately 1.2 GiB in the persistent Docker volume.
- Preparation result: created successfully; a second run returned `exists`
  with `revision_verified=true` from local revision metadata.
- API image: arm64
  `sha256:2138bb0976660cdcb40c7c9fc7091e705da396b2a558e18e7c8bd4c68d5247b2`.
- Gated repository access succeeded with a local read-only token. Legal and
  licence approval are deployment-owner decisions and were not asserted by
  this technical validation.

## Readiness and serving

- A cold container restart reported `loading` and rejected embedding requests
  with HTTP 503 until the model became ready, approximately 38 seconds later.
- Ready state reported the pinned revision, configured and active backend
  `onnx`, and dimension 768.
- A post-warm-up smoke request returned HTTP 200 in 272 ms with one
  768-dimensional vector.
- The local artifact identifies as `gemma3_text`. Transformers 4.57.x can emit
  an incorrect Mistral-regex warning for local non-Mistral artifacts, so the
  inapplicable Mistral tokenizer mutation is explicitly disabled.
- An isolated invalid-artifact-path container moved readiness to `failed` and
  returned HTTP 503 `embedding_unavailable`. The mobile deterministic fallback
  is covered by automated tests.

## Local load sample

- Sequential, 20 requests: 20/20 valid; p50 66.64 ms, p95 121.76 ms,
  maximum 468.34 ms.
- Concurrency 5, 25 requests: 25/25 valid; p50 215.82 ms, p95 412.19 ms,
  maximum 457.52 ms.
- Near-idle container memory observed after serving: API approximately
  1.95 GiB, realtime agent 433 MiB, LiveKit 80 MiB, Redis 12 MiB.

These values are a development-machine sample, not a production SLO.

## Extraction provider

- The configured real OpenAI-compatible provider passed strict-schema and
  source-provenance endpoint smoke tests.
- Local routine and assistant-commitment cases returned grounded candidates.
- Greeting and assistant-only user-fact cases failed closed.
- A provider-misclassified scripted sensitive case exposed a gap; the API now
  independently rejects non-normal sensitivity, recognized sensitive evidence,
  unknown sources, and role-inconsistent candidates. The repeated live endpoint
  check returned zero candidates for that case.
- An unavailable-provider endpoint returned HTTP 503 quickly, while mobile
  retry/backoff, lease recovery, backlog continuation, and non-blocking behavior
  are covered by automated tests.

## Remaining external evidence

- Physical Android voice capture, asynchronous extraction, app relaunch, and
  encrypted release-device migration.
- Full-Xcode iOS compile and iPhone behavior.
- Ubuntu host capacity, private gateway/rate limits, public mobile networking,
  and TURN fallback.
