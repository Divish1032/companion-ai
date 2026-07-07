# Local STT Benchmark

Date: 2026-07-07

Sprint: Sprint -1 Validation Gates hardening

Scope:

- Compare practical local STT options against Sarvam STT.
- Focus on backend-local prototype feasibility, not on-device Flutter execution.
- Keep the benchmark narrow, CPU-oriented, and tied to Hindi MVP needs.

## Question

Can we offload STT away from Sarvam and run it locally for the prototype, then later on an Ubuntu instance, while keeping acceptable Hindi voice-agent behavior?

## Candidates Tested

- `faster-whisper` with Whisper `base`, CPU, `int8`
- `whisper.cpp` with `ggml-base.bin`, CPU, no GPU
- `Vosk` with `vosk-model-small-hi-0.22`
- Comparison baseline: Sarvam STT WebSocket results already captured in `sarvam_streaming_validation.md`

Reason for these choices:

- They are practical open-source STT options with official public docs and active usage.
- They can run without paid STT API calls.
- They represent different tradeoffs:
  - Whisper-family multilingual quality-first direction
  - Vosk streaming and lightweight offline direction

## Official Sources Reviewed

- OpenAI Whisper repo: https://github.com/openai/whisper
- Whisper real-time limitation note: https://github.com/openai/whisper/discussions/2
- faster-whisper repo: https://github.com/SYSTRAN/faster-whisper
- whisper.cpp repo: https://github.com/ggml-org/whisper.cpp
- whisper.cpp streaming example: https://github.com/ggml-org/whisper.cpp/blob/master/examples/stream/README.md
- Vosk repo: https://github.com/alphacep/vosk-api
- Vosk model list: https://alphacephei.com/vosk/models

## Test Set

Five short Hindi clips from the user-provided dataset:

- `2123.mp3`
- `15681.mp3`
- `22336.mp3`
- `8664.mp3`
- `938.mp3`

Preparation:

- Each clip was converted locally to mono 16 kHz WAV.
- Typical duration was about 5 seconds per clip.

Important limitation:

- No ground-truth transcript metadata was found alongside the dataset.
- So this benchmark is strong on latency and qualitative output quality, but not on strict WER.

## Method

Local benchmark method:

1. Convert each MP3 clip to mono 16 kHz WAV.
2. Run each engine on the same five WAV files.
3. Capture:
   - total transcription time per file
   - first emitted segment time where feasible
   - transcript output
4. Compare local outputs with prior Sarvam STT behavior on the same files.

Benchmark artifacts:

- Local benchmark script: `scripts/spikes/local_stt_benchmark.py`
- Local results JSON: `/tmp/local-stt-bench/benchmark_results.json`
- Sarvam comparison summary: `/tmp/companion-ai-hindi-batch/summary.json`

Important apples-to-oranges note:

- Sarvam was tested as a streaming WebSocket STT service.
- The local benchmark here was mostly offline file transcription on local CPU.
- So the local totals are best interpreted as backend processing speed and transcript plausibility, not as end-to-end mobile realtime latency.

## Results Summary

Sarvam STT baseline on the same five Hindi clips:

- First transcript average: about `2346 ms`
- Average transcript segments per clip: `3.2`
- Streamed transcript updates arrived before stream completion on all five clips
- VAD events were present

### faster-whisper

Config:

- Model: `base`
- Device: CPU
- Compute type: `int8`

Observed averages:

- Average total time: about `4070 ms`
- Average first segment time: about `3529 ms`

Qualitative result:

- Weak on these Hindi clips in this CPU-friendly configuration.
- Outputs often came back in mixed scripts such as Urdu, Tamil, or Romanized fragments.
- One file produced many noisy micro-segments and visibly degraded output.

Interpretation:

- This specific `base` setup is not good enough to replace Sarvam STT for Hindi MVP use.
- Whisper-family local STT may still be viable, but likely needs a larger model or different deployment profile, which means more compute and slower CPU inference.

### whisper.cpp

Config:

- Model: `ggml-base.bin`
- CPU only
- `whisper-cli` with explicit Hindi language setting

Observed averages:

- Average total time: about `2372 ms`
- First segment timing was not captured in this simple CLI benchmark

Qualitative result:

- Faster than the tested faster-whisper configuration on average in this setup.
- Still poor transcript quality on several files.
- Some outputs were mixed-script or clearly wrong, including one clip that devolved into repeated numeric symbols.

Interpretation:

- `whisper.cpp` is operationally attractive and lightweight, but the tested `base` model quality was not strong enough for this Hindi prototype.
- As with faster-whisper, better quality likely requires a larger model and therefore higher compute cost.

### Vosk

Config:

- Model: `vosk-model-small-hi-0.22`

Observed averages:

- Average total time: about `435 ms`
- First segment time where observed: about `304 ms`

Qualitative result:

- Best local result of the three on this Hindi-only batch.
- Outputs stayed in Devanagari and were generally coherent.
- Still imperfect, but much closer to usable Hindi transcript text than the tested Whisper `base` setups.

Interpretation:

- Vosk is the strongest immediate candidate for backend-local Hindi STT in a low-cost prototype.
- It is also the lightest option operationally among the tested candidates.

## Side-by-Side Takeaway

On this benchmark:

- Sarvam STT had the best proven streaming behavior.
- Vosk had the best local CPU practicality and the best local transcript plausibility.
- The tested Whisper-family `base` setups were not convincing enough for Hindi MVP replacement.

Short version:

- Best streaming baseline: Sarvam
- Best cheap local candidate: Vosk
- Best future-upside family if we later allow more compute: Whisper-family

## Decision Impact

What this does support:

- Yes, we can seriously consider offloading STT away from Sarvam for prototype cost control.
- If the goal is cheapest practical backend-local Hindi STT right now, Vosk is the best result from this spike.

What this does not prove yet:

- That Vosk is good enough for the core product requirement of Hindi plus Hinglish conversational companion UX.
- That a larger self-hosted Whisper model would not beat Vosk with acceptable latency on stronger hardware.
- That any local model here is already better than Sarvam on real spontaneous user speech.

## Recommendation

Recommendation for the prototype:

- If the main goal is reducing STT API cost quickly, run one more targeted local spike with Vosk on:
  - conversational Hindi
  - Hinglish
  - pause-heavy speech
  - mild mobile noise

If those targeted samples hold up:

- Use local Vosk as the prototype STT path.
- Keep Sarvam STT behind the provider interface as a fallback or comparison path.

If Hinglish quality matters more than lowest cost:

- Do not switch to local Whisper-family STT based on this `base` benchmark alone.
- Either:
  - keep Sarvam STT for now, or
  - run one more benchmark with a larger Whisper-family model on stronger hardware

## Concrete Recommendation For This Repo

Current best next step:

1. Keep the current architecture decision that STT stays behind `STTProvider`.
2. Add a Vosk spike on conversational Hinglish before making a replacement decision.
3. Do not replace Sarvam STT with tested Whisper `base` configurations from this spike.

Provisional call:

- Local STT is viable enough to pursue.
- Vosk is the only tested local option that currently looks promising for a low-cost Hindi prototype.
- Sarvam still has the stronger demonstrated streaming contract and remains the safer default until Hinglish-local validation passes.

## Limitations

- No ground-truth transcripts were available in the dataset folder.
- The local benchmark was CPU-only and intentionally used small practical models.
- The Whisper-family result here should not be generalized to all model sizes.
- The Sarvam comparison is streaming, while the local benchmark was mostly file-based processing.
