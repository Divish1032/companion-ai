# Unit Economics and Pricing Guardrails

Use this file when working on cost instrumentation, pricing assumptions, or field-test economics.

Long-term-memory model serving is a self-hosted infrastructure cost, not a
provider billing unit. Track its amortized CPU/GPU, RAM, disk, bandwidth, and
model-cache costs separately from STT/LLM/TTS so a memory-quality improvement
does not appear to be free.

## Cost Targets

MVP should instrument cost per minute, not guess it.

Initial estimated provider costs:

- STT: Sarvam STT around INR 30/hour, billed per second.
- TTS: Bulbul v2 around INR 15/10K chars, Bulbul v3 around INR 30/10K chars.
- LLM: expected to be smaller than STT/TTS, but must still be measured.
- Infra: lower than STT/TTS at early scale, but not zero.
- Memory model serving: no per-request provider charge when enabled locally,
  but it adds model-cache storage, warm resident memory, CPU/GPU time, and
  potentially a larger Ubuntu instance.

Sprint -1 measured note:

- A real Bulbul v3 usage example observed about INR 7 for about 2400 characters.
- That measured result is consistent with the published Bulbul v3 rate and confirms that long spoken replies can dominate per-turn cost very quickly.

Working cost assumption for planning:

```text
Lean voice minute with short AI reply: INR 0.8 - INR 1.2
Natural voice minute with Bulbul v3:   INR 1.2 - INR 1.8
Managed/inefficient path:              INR 1.8 - INR 2.8+
```

Measured TTS cost examples at Bulbul v3 pricing:

```text
200 chars reply:   about INR 0.6
300 chars reply:   about INR 0.9
600 chars reply:   about INR 1.8
1200 chars reply:  about INR 3.6
2400 chars reply:  about INR 7.2
```

Interpretation:

- Bulbul v3 is acceptable only if assistant replies stay short.
- If average spoken replies drift into 1000 to 2500 characters, TTS alone will likely break MVP unit-economics targets.
- Cost control must focus on response length first, not only provider choice.

## Required Cost Metrics

- STT audio seconds.
- STT billed units if provider exposes them.
- TTS generated characters.
- TTS billed units if provider exposes them.
- LLM input tokens.
- LLM output tokens.
- Estimated LLM INR cost.
- Estimated INR cost per turn.
- Estimated INR cost per session.
- Provider fallback/retry count.
- Memory-enabled versus memory-disabled session cost and latency delta.
- Embedding/reranker/planner request counts, model cache size, and amortized
  model-serving infrastructure cost.

## Cost Controls

- Keep AI responses concise.
- Stream TTS only for committed text chunks.
- Stop TTS immediately on barge-in.
- Do not send silence to STT when avoidable.
- Cache/reuse persona/system prompt.
- Keep memory injection compact.
- Log LLM input/output tokens and estimated LLM INR cost.
- Add provider billing-unit counters as soon as STT/TTS are integrated.
- Flag any measured cost that exceeds planning assumptions by more than 50%.
- Cap default assistant reply length aggressively when using Bulbul v3.
- Compare Bulbul v2 versus Bulbul v3 on actual user-perceived quality before making v3 the default.
- Prefer short filler audio plus concise spoken answers over long narrated paragraphs.
- Keep memory model serving disabled until warm latency and resource usage are
  measured; deterministic memory retrieval remains the safe fallback.

## Pricing Position

Do not launch broad subscription until measured costs are known.

Future pricing model:

```text
Free trial:
  5-10 total voice minutes

Starter:
  TBD after measured COGS and retention

Core:
  TBD after measured COGS and retention

Premium:
  larger minute bundle only if measured margins support it

Top-ups:
  prepaid minute packs priced from measured per-minute cost
```

Avoid unlimited or high daily caps until:

- TTS cost is reduced.
- Average response length is controlled.
- Retention is proven.
- Power-user behavior is understood.
- Real measured cost per minute is known across normal, noisy, retry-heavy, and power-user sessions.

Current recommendation:

- Do not assume Bulbul v3 is a safe default for MVP economics.
- Treat Bulbul v3 as quality-first and cost-sensitive.
- Require measured average TTS characters per turn before pricing decisions.

## Sprint 8 rate-card implementation

Cost calculations use integer micro-INR and an effective-dated rate-card
fingerprint. Vosk and the local persona provider have no external provider
charge, not zero infrastructure cost. Unknown external providers (including a
configured memory extractor without a reviewed rate) make a session cost
incomplete instead of contributing zero. The current Bulbul v3 natural-voice
scenario compares active voice-minute cost against INR 1.80 and emits an overage
at INR 2.70/minute; this remains a planning guardrail rather than an invoice.
