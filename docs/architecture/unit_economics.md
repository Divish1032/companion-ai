# Unit Economics and Pricing Guardrails

Use this file when working on cost instrumentation, pricing assumptions, or field-test economics.

## Cost Targets

MVP should instrument cost per minute, not guess it.

Initial estimated provider costs:

- STT: Sarvam STT around INR 30/hour, billed per second.
- TTS: Bulbul v2 around INR 15/10K chars, Bulbul v3 around INR 30/10K chars.
- LLM: expected to be smaller than STT/TTS, but must still be measured.
- Infra: lower than STT/TTS at early scale, but not zero.

Working cost assumption for planning:

```text
Lean voice minute with short AI reply: INR 0.8 - INR 1.2
Natural voice minute with Bulbul v3:   INR 1.2 - INR 1.8
Managed/inefficient path:              INR 1.8 - INR 2.8+
```

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
