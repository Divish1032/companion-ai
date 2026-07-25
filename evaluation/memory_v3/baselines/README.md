# Memory V3 Baseline Artifacts

Baseline reports are generated, versioned evidence rather than hand-written
fixtures. The default runner writes them under `tmp/memory_v3_baselines/` so a
developer does not accidentally commit paid-model output or large synthetic
prompt snapshots.

A report may be promoted into this directory only after review confirms:

- it contains synthetic fixture text only;
- provider and model settings are complete;
- V2 replay completed without falling back to fabricated memory;
- no-memory, V2, and oracle arms share the same query and response model;
- live responses are present only when a real provider was intentionally run;
- the report validates against `schemas/baseline_report.schema.json`.

No Task 1 response baseline has been approved merely because this directory
exists.
