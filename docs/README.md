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
  model-serving contracts, privacy boundaries, and remaining validation for the
  legacy V2 implementation.
- `architecture/memory_v3.md`: approved source of truth for the active memory
  rewrite, including ownership, compiler, consolidation, retrieval, prompt use,
  feedback, privacy, observability, and the V2 retain/replace/delete map.
- `architecture/memory_v3_storage.md`: concrete Task 2 observation ledger,
  authoritative user controls, cited projections, rebuild, and deletion rules.
- `architecture/memory_v3_compiler.md`: Task 3 stateless compiler, durable phone
  jobs, authoritative local admission, failure behavior, and model-eval gate.
- `architecture/memory_v3_consolidation.md`: Task 4 deterministic phone-owned
  transitions, bounded ambiguity adjudication, temporal state, graph safety,
  affect policy, and offline exit criteria.
- `deployment/ubuntu.md`: Ubuntu deployment, model-cache, warm-up, readiness,
  and rollback runbook for public-network testing.

## Evaluation References

- `evals/memory_v3_evaluation.md`: protected scenarios, baselines, metrics, hard
  gates, and rollout criteria for the Memory V3 rewrite.
- `../contracts/memory_v3/`: versioned JSON Schemas for compiler,
  consolidation, query-time retrieval, `MemoryBrief`, and memory-use feedback.
- `../evaluation/memory_v3/`: executable Task 1 fixture catalog, strict report
  schemas, V2 replay probe, and matched no-memory/V2/oracle baseline harness.

## Spike Outputs

- `spikes/sarvam_streaming_validation.md`: create during Sprint -1.
- `spikes/local_stt_benchmark.md`: create during Sprint -1.

## Privacy Outputs

- `privacy/dpdp_mvp_notes.md`: create during Sprint -1.
