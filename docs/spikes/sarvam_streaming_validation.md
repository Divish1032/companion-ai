# Sarvam Streaming Validation

Date: 2026-07-07

Sprint: Sprint -1 Validation Gates

Scope:

- Validate Sarvam STT streaming assumptions from official Sarvam docs.
- Validate Sarvam TTS streaming assumptions from official Sarvam docs.
- Run a small empirical spike only if local credentials are available.
- Record decision impact on Sprint 0 gating.

## Summary

Status: empirically validated in part, with one remaining nuance around STT partial semantics.

What is confirmed from official docs:

- Sarvam exposes a WebSocket STT endpoint at `wss://api.sarvam.ai/speech-to-text/ws`.
- Sarvam documents streaming STT as suitable for live microphone or call audio.
- Sarvam documents STT results as final transcript per utterance on VAD end-of-speech or explicit flush.
- Sarvam exposes VAD-related connection parameters on the STT WebSocket, including speech thresholds, pre-speech padding, interruption frames, and optional VAD signals.
- Sarvam exposes a WebSocket TTS endpoint at `wss://api.sarvam.ai/text-to-speech/ws`.
- Sarvam TTS WebSocket accepts incremental text messages plus an explicit flush/end signal.
- Sarvam TTS WebSocket returns audio chunks and can emit a completion event.
- Sarvam recommends keeping TTS WebSocket messages under 500 characters for lowest latency.
- Current published pricing and rate-limit pages support the PRD planning assumptions closely enough for Sprint -1.

What remains nuanced or partially open:

- The STT stream does emit transcript messages before the full 10-second clip ends, but in this probe those messages aligned with VAD-bounded utterance segments rather than token-by-token live partials.
- We still need a second probe on a more natural conversational Hindi or Hinglish sample to judge how stable these streamed segments are for continuation-sensitive endpointing.
- Raw documented TTS WebSocket JSON messages returned a structured `422` in this environment, while the official Sarvam Python SDK succeeded against the same account and models.

Decision:

- Treat Sarvam STT streaming as empirically confirmed for VAD-driven segmented transcript streaming.
- Do not yet assume token-level or constantly updating partials inside a single uninterrupted utterance.
- Treat Sarvam TTS streaming as empirically viable with the official SDK.
- Sprint 0 scaffolding can proceed, but Sprint 5 and endpointing design should assume "utterance-segment streaming confirmed, token-level partial semantics still not fully proven."

## Official Sources Reviewed

Reviewed on 2026-07-07.

Primary sources:

- Sarvam STT streaming guide: https://docs.sarvam.ai/api-reference-docs/api-guides-tutorials/speech-to-text/streaming-api
- Sarvam STT WebSocket reference: https://docs.sarvam.ai/api-reference-docs/speech-to-text/transcribe/ws
- Sarvam STT API selection guide: https://docs.sarvam.ai/api-reference-docs/api-guides-tutorials/speech-to-text/which-api-to-use
- Sarvam TTS overview: https://docs.sarvam.ai/api-reference-docs/api-guides-tutorials/text-to-speech/overview
- Sarvam TTS streaming WebSocket guide: https://docs.sarvam.ai/api-reference-docs/api-guides-tutorials/text-to-speech/streaming-api/web-socket
- Sarvam TTS WebSocket reference: https://docs.sarvam.ai/api-reference-docs/text-to-speech/stream
- Sarvam pricing: https://docs.sarvam.ai/api-reference-docs/pricing
- Sarvam rate limits: https://docs.sarvam.ai/api-reference-docs/ratelimits
- Sarvam changelog: https://docs.sarvam.ai/api-reference-docs/changelog

Relevant current doc facts captured from those pages:

- STT WebSocket uses `saaras:v3` by default and supports `transcribe`, `translate`, `verbatim`, `translit`, and `codemix` modes.
- STT WebSocket supports `16000` Hz and `8000` Hz connection sample rates.
- STT WebSocket supports `vad_signals`, `flush_signal`, `high_vad_sensitivity`, speech thresholds, interruption thresholds, and pre-speech padding fields.
- STT selection guide says WebSocket is for "results as the user speaks", but the results table documents final transcript per utterance, not explicitly partial transcript events.
- STT WebSocket reference shows an audio message shape and a transcription response shape containing `type`, `request_id`, `transcript`, and `metrics`.
- TTS WebSocket accepts config, text, flush, and ping messages and returns audio output plus optional completion events.
- TTS overview documents a WebSocket per-message limit of 2500 characters and recommends staying under 500 characters for lowest latency.
- TTS WebSocket docs expose `min_buffer_size` and `max_chunk_length`, which implies server-side buffering and chunk assembly rather than one-audio-file-only batch behavior.
- The changelog shows `saaras:v3` and stable `bulbul:v3` are current as of February 2026.

## Local Environment Check

Empirical spike status: run successfully on 2026-07-07 after a local `.env` file with `SARVAM_API_KEY` was added.

Local conditions:

- Auth source: local `.env`, not committed.
- Host environment: macOS local shell.
- Audio tooling: `ffmpeg`, `ffprobe`, Python 3.14.
- WebSocket client: local Python plus `websockets`.
- Official SDK validation: temporary local virtualenv with `sarvamai==0.1.28`.

Audio sample used:

- Source file: `https://upload.wikimedia.org/wikipedia/commons/0/0e/WDKB-SKVerma-Voice.ogg`
- Source page license: CC BY-SA 3.0 on Wikimedia Commons
- Local probe clip: 10-second excerpt converted to mono 16 kHz WAV
- Local path during probe: `/tmp/companion-ai-spike/hindi_clip.wav`

Additional hardening batch:

- Local Hindi dataset folder supplied by the user:
  `/Users/itachi/Documents/Codes, Keys & Files/CompanionAI/Indian_Languages_Audio_Dataset/Hindi`
- Five short files were sampled and converted locally to mono 16 kHz WAV for STT probing:
  - `2123.mp3`
  - `15681.mp3`
  - `22336.mp3`
  - `8664.mp3`
  - `938.mp3`
- Batch summary output was written locally to:
  `/tmp/companion-ai-hindi-batch/summary.json`

## Findings

## 1. STT streaming

What the docs support:

- Sarvam clearly supports live STT over WebSocket.
- The STT transport is continuous rather than 30-second request/response REST.
- The API exposes VAD and interruption controls that are useful for voice-agent integrations.
- `codemix` mode is explicitly documented, which is directionally aligned with Hindi/Hinglish support needs.

Empirical result:

- The probe streamed 50 small WAV chunks at 200 ms cadence over roughly 10.4 seconds.
- Sarvam returned `events` messages with `START_SPEECH` and `END_SPEECH`.
- Sarvam also returned `data` transcript messages before the full stream ended and before the explicit flush.
- First transcript arrived at about 1.5 seconds from probe start.
- Five transcript messages arrived during the 10-second stream.

Important nuance:

- In this probe, transcript messages appeared after VAD-bounded speech segments, not as token-by-token rolling partials within one uninterrupted segment.
- That means the provider is good enough for segmented live streaming, but this test does not prove the exact "always-updating partial transcript while the user is still in one continuous thought" behavior assumed in the most aggressive PRD reading.

Evidence from the run:

- Transcript before stream end: yes
- Transcript before explicit flush: yes
- Response types seen: `data`, `events`
- Error messages seen: none

Representative timings from the successful run:

- First `START_SPEECH`: about 525 ms
- First `END_SPEECH`: about 1376 ms
- First transcript `data`: about 1576 ms
- Stream send complete: about 10433 ms
- Explicit flush sent: about 10433 ms

Observed transcript quality on this sample:

- Mixed.
- The stream clearly returned Hindi transcript segments, but some segments were transliterated or mistranscribed, for example English-like or mixed-script fragments.
- This sample is expressive poetry rather than clean conversational speech, so quality should not be over-generalized.

Current confidence:

- Confirmed: STT live streaming transport exists.
- Confirmed: transcript messages can arrive before full-stream completion.
- Confirmed: VAD events are exposed and useful.
- Confirmed across multiple additional short Hindi clips: streamed transcript segments consistently arrived before stream completion.
- Still partially open: whether Sarvam gives stable within-utterance live partials for continuation-sensitive endpointing on natural Hinglish mobile speech and pause-heavy spontaneous conversation.

Additional hardening result on user-provided Hindi dataset:

- Five separate clips around 5 seconds each were probed.
- All five returned `data` transcript messages before stream end.
- All five returned `events` messages alongside transcripts.
- Transcript message count ranged from 3 to 4 per clip.
- VAD event count ranged from 6 to 8 per clip.
- First transcript arrival ranged from about 997 ms to about 4043 ms depending on segmentation.
- No STT error messages were observed in this batch.

Batch-level interpretation:

- This strengthens confidence that Sarvam STT is not behaving like simple batch transcription for short Hindi audio.
- The pattern still looks segment-oriented rather than token-by-token rolling partials.
- That behavior is usable for our MVP endpointing plan because the architecture already depends on VAD plus transcript state, not transcript-only turn taking.

## 2. TTS streaming

What the docs support:

- Sarvam supports both HTTP streaming and WebSocket TTS.
- WebSocket TTS is explicitly incremental: send config, send text chunks, flush when done, receive audio chunks as output.
- Completion events are supported.
- Character limits and low-latency guidance are documented.
- Model notes for `bulbul:v2` and `bulbul:v3` are current and explicit.

Empirical result:

- TTS worked successfully through the official Sarvam Python SDK.
- `bulbul:v3` produced first audio about 240 ms after text send on a short Hindi sentence.
- `bulbul:v3` returned 23 audio chunks for that short sentence in this probe.
- `bulbul:v2` produced first audio about 568 ms after text send on the same sentence and returned only 1 audio chunk in this probe.

Default test-input rule going forward:

- For latency and streaming validation, use small TTS prompts by default.
- Preferred test size: about 20 to 80 characters.
- Occasional secondary test size: about 100 to 200 characters.
- Avoid 500+ character prompts unless explicitly testing buffering, chunking limits, or worst-case cost.

Reason:

- Small prompts better represent the intended MVP reply style.
- They isolate first-audio latency from paragraph-length synthesis effects.
- They keep Sprint -1 and early integration testing cost-aware.

Important nuance:

- A raw WebSocket probe using the documented JSON message shapes returned a structured `422` error for both `bulbul:v2` and `bulbul:v3`: `Input parameters has to be a valid dictionary`.
- The official SDK succeeded immediately, which suggests either:
  - a raw-wire formatting nuance not obvious from the published docs, or
  - a docs-versus-runtime mismatch on direct WebSocket payload expectations.

Practical implication:

- We should integrate TTS through the official SDK first, or reproduce the SDK wire format before relying on a hand-rolled raw WebSocket client.

Current confidence:

- Confirmed: TTS streaming works empirically.
- Confirmed: `bulbul:v3` is comfortably inside the PRD target for first audio after short text chunk in this local probe.
- Confirmed: `bulbul:v2` also works, but was slower and less chunked for the same short prompt in this probe.
- Still useful to validate later: longer multi-chunk phrase buffering with natural LLM output.

## 3. Pricing and rate limits

Current official docs align with the PRD assumptions:

- STT pricing: `Rs 30/hour`, billed per second, rounded up per request.
- TTS pricing: `bulbul:v2` at `Rs 15/10K characters`; `bulbul:v3` at `Rs 30/10K characters`.
- STT WebSocket rate limit: starter plan shows 20 concurrent streams.
- TTS WebSocket rate limit: starter plan shows 60 concurrent streams, with `bulbul:v3` starter capped at 30 concurrent.

Implication:

- The PRD cost assumptions are still directionally reasonable, but real unit-economics logging remains mandatory once implementation starts.

## Method

Documentation method:

1. Review only official Sarvam docs and official Sarvam legal pages relevant to Sprint -1.
2. Cross-check transport, response shape, pricing, and rate-limit pages for internal consistency.
3. Compare those facts against PRD assumptions in `docs/PRD_MASTER.md`.

Empirical method used:

1. Create a 10-second 16 kHz mono WAV clip from a publicly licensed Hindi speech file.
2. Run a raw STT WebSocket probe that:
   - splits the WAV into 200 ms mini-WAV chunks
   - sends them at real-time cadence
   - logs every inbound message with timestamps
   - sends explicit flush at the end
3. Repeat the STT probe across five short user-provided Hindi dataset clips to check whether the behavior generalizes beyond one sample.
4. Run a raw TTS WebSocket probe for both `bulbul:v2` and `bulbul:v3`.
5. When raw TTS returned structured `422` errors, run the official Sarvam Python SDK as a control path for the same short Hindi text.
6. Record first-audio timing and chunk counts from the SDK-based TTS runs.

Default TTS probe input policy:

- Start with one short Hindi line around 20 to 80 characters.
- Optionally add one slightly longer line around 100 to 200 characters.
- Do not use paragraph-length TTS inputs for routine validation.

Artifacts created during validation:

- Repo probe script: `scripts/spikes/sarvam_ws_probe.py`
- Local output JSON: `/tmp/companion-ai-spike/results.json`
- Temporary SDK virtualenv: `/tmp/companion-ai-spike/venv`

## Exact Next Validation Step

Remaining focused question:

- Do we get useful transcript updates during one longer uninterrupted conversational utterance, or mainly after VAD-bounded sub-segments?

Next step:

1. Collect or record 2 to 3 specifically conversational or Hinglish samples, because generic short Hindi clips are now already covered.
2. Make sure at least one sample includes a mid-thought pause and one includes natural code-mixing.
3. Re-run the STT probe on those targeted samples.
4. Compare:
   - number of transcript `data` messages per utterance
   - whether any transcript arrives before a clear `END_SPEECH`
   - whether continuation markers survive reliably enough for endpointing
5. If necessary, revise the endpointing plan to rely primarily on:
   - VAD timing
   - transcript segment boundaries
   - repeat flow on ambiguous short turns

Separate TTS follow-up:

- If we want a custom raw WebSocket adapter instead of the official SDK, inspect the SDK wire format or test a lower-level capture. The current raw JSON attempt is not yet sufficient proof for direct adapter implementation.

## Limitations

- The STT probe used a public Hindi poetry clip, not a natural back-and-forth mobile conversation.
- Transcript quality on this sample should not be treated as a production benchmark.
- The TTS empirical success path used the official SDK, while the raw documented WebSocket shape returned `422` in this environment.
- We did not verify provider privacy or subprocessing terms beyond public legal pages and product docs.

## Decision Impact

Sprint -1 gate status:

- STT live streaming transport: pass.
- STT streamed transcript segments before full-stream completion: pass.
- STT streamed transcript segments before full-stream completion across one public sample plus five additional Hindi dataset clips: pass.
- STT exact token-level partial semantics: still partially open, but no longer architecture-killer unknown.
- TTS streaming with official SDK: pass.
- TTS first-audio latency for short Hindi chunk:
  - `bulbul:v3`: pass in this local probe
  - `bulbul:v2`: pass, but slower

Architecture impact:

- Keep Sarvam behind provider interfaces exactly as planned.
- Keep filler-audio as a required perceived-latency mitigation for MVP.
- Do not let provider VAD replace our server-side endpointing policy.
- Do not assume STT partials exist until raw WebSocket messages prove they do.

Implementation impact on later sprints:

- Sprint 0 scaffolding can proceed.
- Sprint 5 STT integration should target streamed segment updates plus VAD events as the baseline proven behavior.
- Endpointing should not depend on token-by-token transcript updates inside one uninterrupted utterance unless later probes prove that behavior clearly.
- TTS integration should start from the official SDK path or a validated adapter based on SDK-observed behavior, not from assumptions about the raw WebSocket JSON alone.
