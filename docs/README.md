# Companion AI Documentation Map

Use this map to avoid loading the entire master PRD for every task.

## Start Here

- `AGENT_CONTEXT.md`: short operating rules for coding agents.
- `SPRINTS.md`: sprint tasks, deliverables, and acceptance criteria.
- `PRD_MASTER.md`: product source of truth and high-level decisions.

## Architecture References

- `architecture/voice_pipeline.md`: VAD, endpointing, audio frames, barge-in, TTS chunking.
- `architecture/mobile_app_native_audio.md`: Flutter app, local history, Android/Kotlin and iOS/Swift audio boundaries.
- `architecture/backend_agent_livekit.md`: API service, LiveKit, agent lifecycle, provider interfaces, deployment.
- `architecture/safety_privacy.md`: safety pipeline, crisis handling, DPDP/privacy requirements.
- `architecture/observability_metrics.md`: latency, quality, and cost metrics.
- `architecture/unit_economics.md`: cost assumptions, pricing cautions, and measurement requirements.
- `architecture/long_term_memory.md`: phone-owned memory, query-time retrieval,
  model-serving contracts, privacy boundaries, and remaining validation.
- `deployment/ubuntu.md`: Ubuntu deployment, model-cache, warm-up, readiness,
  and rollback runbook for public-network testing.

## Spike Outputs

- `spikes/sarvam_streaming_validation.md`: create during Sprint -1.
- `spikes/local_stt_benchmark.md`: create during Sprint -1.

## Privacy Outputs

- `privacy/dpdp_mvp_notes.md`: create during Sprint -1.
