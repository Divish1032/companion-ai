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
  `sha256:f53d00f74cef4a8d41b5e1428aa0f9ea963c963b11f7616449c37ede80611308`.
- Realtime-agent image: arm64
  `sha256:894ec58183c769c27863f1d93bb31fe8ffa39f8a0d41d9840e3221afd9980aee`.
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
- The first physical-phone interview case initially returned no candidate. A
  real-provider replay exposed both under-extraction and assistant-wording
  provenance errors. The extractor now treats explicit completed personal
  milestones as episodes, requires user-only sources for `evidence_role=user`,
  and requires `ADD` for a newly stated grounded episode. The rebuilt live API
  returned one normal-sensitivity `episode`, grounded only to the user turn,
  with the system-design assessment and action `ADD`.

## Remaining external evidence

- Physical Android durable-episode display/relaunch recall on the rebuilt stack
  and encrypted release-device migration. Debug voice capture, response, session
  summary display, and encrypted local database creation are confirmed.
- Full-Xcode iOS compile and iPhone behavior.
- Ubuntu host capacity, private gateway/rate limits, public mobile networking,
  and TURN fallback.

## Android startup incident

The first Wi-Fi debug phone attempt returned HTTP 503 from session creation even
though the realtime service recorded a successful assignment. A later attempt
joined LiveKit with excellent connection quality and published audio. This
identified a transient assignment-response race rather than a LAN/WebRTC
failure.

The API now retries the same idempotent assignment once for transport errors
and HTTP 502/503/504 responses. Final assignment failure and normal session end
also call the realtime cancellation endpoint so orphan agents cannot consume
the concurrency limit. The rebuilt local stack created and ended a session
successfully; active-agent count returned to zero.

## Android memory and TTS observation

On the next Wi-Fi debug run, the phone captured a design-interview utterance,
showed the assistant text response, completed the voice session, and displayed
a session summary in `What I remember`. The provider transcript changed the
original wording from "mushkil laga" to an equivalent dislike assessment, which
is a separate STT-quality observation. Same-session recall worked, but the old
extractor returned zero durable candidates for the replay, leading to the
episode-extraction correction recorded above.

The same run showed assistant text much earlier than voice. Agent metrics
confirmed the old REST TTS path waited approximately 4.3-5.8 seconds for first
audio and buffered a complete WAV before publishing it. The agent now uses the
official Sarvam asynchronous HTTP streaming SDK with `linear16` output and
publishes canonical 20 ms frames as they arrive. Three local provider probes
produced first frames in 494, 1,487, and 1,462 ms; a probe from the rebuilt
container produced the first frame in 493 ms. These are development samples,
not a production latency SLO; physical-phone playback remains to be confirmed.
