# Hindi/Hinglish Long-Term Memory Evaluation

Run the automated suite from the repository root:

```bash
scripts/run-memory-eval.sh
```

The suite is a regression gate for the phone-owned Hindi/Hinglish MVP. It must
pass before a real-phone memory validation run.

## Automated scenarios

| Scenario | Expected result |
| --- | --- |
| Exact identity and language recall | Only the matching core-profile or procedural record is returned. |
| Hinglish and Devanagari aliases | Explicit office/work/manager aliases can ground graph expansion. |
| Vague emotional turn | No unrelated name or language-style record is injected. |
| Greeting | No long-term memory lookup is sent. |
| Contradiction and supersession | Replaced records do not remain retrievable. |
| Temporal decay | Stale low-value records decay before confirmed core profile records. |
| Sensitive content | Sensitive and rejected records are excluded from retrieval and embedding sync. |
| Receipt rejection | An explicit rejection expires the candidate memory. |
| Timeout/failure | Lookup continues without memory when mobile/vector/rerank paths fail. |
| Context budget | Prompt context remains bounded and reports its character count. |
| Strategy isolation | `hi-IN` resolves deterministic retrieval/reranking/planning and invokes no model path. |
| Live ingestion | Final LiveKit user/assistant events run exact admission and enqueue one idempotent background job. |
| Candidate provenance | Assistant-only text cannot become a user fact; unknown source turns are rejected. |
| Window isolation | A valid turn from the same session but outside the claimed extraction window is rejected. |
| Local schema defense | Malformed items, out-of-range scores, extra output properties, and incomplete strict schemas fail closed. |
| Retry lifecycle | HTTP timeout, terminal 4xx, exponential retry cap, stale lease recovery, and backlog continuation are covered. |
| Episodes | Typed episodes retain source turn IDs and retrieval expands the surrounding raw turns. |
| Open threads | A future event can be found from a vague Hindi/Hinglish follow-up. |
| Sensitive candidates | The LLM proposal is rejected locally and never becomes a retrievable record. |
| Receipt isolation | Unconfirmed memory is excluded from lexical, graph, vector, session-start, and realtime prompt paths. |
| Encryption migration | Existing plaintext SQLite data is migrated to SQLite3MultipleCiphers without row loss. |

## Pass criteria

- All automated checks pass.
- No test relies on raw audio or cloud memory persistence.
- Hindi/Hinglish strategy isolation remains true.
- Safety/sensitive-memory exclusion has zero failures.
- Context injection stays within the configured six packets and character budget.
- The stateless extraction API accepts only its strict bounded schema and is
  fail-closed while disabled or unavailable.

## Real-phone protocol

Use a newly rebuilt app and clear history before this run. Record only redacted
backend/mobile logs and do not place sensitive personal information in the test
conversation.

1. State a name and an explicit language-style preference; ask each back.
2. State an explicit office/manager stressor, confirm its receipt, then ask
   later: "aaj office ka din heavy tha".
3. Say a vague turn such as "aaj mood off hai" and verify no name/language
   preference is introduced.
4. Say "hi" and verify no memory packet is returned.
5. Start a new session and repeat the grounded office recall.
6. Explicitly say "nahi yaad mat rakhna" for a pending memory; verify it is not
   recalled afterwards.

## Historical measured phone run: 2026-07-11

The phone was connected over Wi-Fi debugging and the stack advertised
deterministic retrieval, reranking, and planning for `hi-IN`. Redacted evidence
showed the following results:

| Scenario | Result | Redacted evidence |
| --- | --- | --- |
| Hindi profile admission and recall | Pass | 48 ms admission lookup; 21 ms recall lookup; 1/1 then 2/2 candidates; 1,584-char maximum context |
| Hindi office-stressor admission | Pass | 47 ms; 3/3 candidates; 713-char context; one pending receipt |
| Hindi receipt confirmation | Pass | Receipt changed to `confirmed`; pending count became zero |
| Hindi graph-expanded office recall | Pass | 40 ms; 2/2 candidates; 1,996-char context |
| Vague emotional turn | Pass | Broad-safe route; 38 ms; 0/0 candidates; no-memory decision |
| Greeting | Pass | `none` route; lookup not attempted; 0/0 candidates; 836-char context |
| Previous-session recall | Pass | New session ID; 37 ms; 2/2 candidates; 733-char context |
| Explicit rejection and exclusion | Pass | Fixed APK preserved `rejected/expired`; rejected record was not re-admitted or injected; two unrelated past summaries were returned |

The phone run used only non-sensitive content. No transcript text is included in
this evidence table. This run predates the current EmbeddingGemma/ONNX default
and the latest topic/coalescing/echo fixes. Phase 5 is not closed until the
rebuilt APK is installed and all affected scenarios are repeated, including the
final rejection/exclusion scenario. The automated docs gate is also currently
blocked by pre-existing non-ASCII characters in the untracked
`docs/MEMORY_QUALITY_LAB_PLAN.md` file. The Android acceptance protocol itself
has passed on the fixed APK; Phase 5 should not be called repository-green
until that unrelated docs gate is repaired.

Capture `companion.memory`, `companion.voice.memory`, `memory_lookup_metrics`,
`memory_lookup_response`, and `prompt_context`. The logs must contain route,
strategy, counts, latency, and context budget but no transcript or memory text.
