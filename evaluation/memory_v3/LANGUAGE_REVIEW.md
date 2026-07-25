# Memory V3 Hindi/Hinglish Language Review

All Task 1 scenarios are synthetic review candidates. This checklist must be
completed by a native or professionally fluent Hindi/Hinglish reviewer before a
scenario is promoted to `protected`.

Review each scenario independently in
`fixtures/task1_core_scenarios.json`:

1. Read every user and assistant turn aloud as a voice conversation.
2. Confirm that Roman Hindi, Devanagari, and code mixing sound natural for the
   intended speaker.
3. Confirm that negation, correction, quotation, uncertainty, pronouns, and time
   expressions carry the intended meaning.
4. Check that `object_contains`, consolidation expectations, query expectations,
   oracle memory, and the response rubric match that meaning.
5. Check that the expected response would feel respectful and natural, not like
   a database report.
6. For P0 safety wording, perform both language and safety review.

If approved, update only that scenario:

- set `language_review.status` to `approved`;
- set `language_review.reviewer_id` to a non-secret reviewer identifier;
- set `language_review.reviewed_at` to an ISO 8601 UTC timestamp;
- record concise notes;
- set `protection` to `protected`.

If wording changes after approval, return the scenario to `review_candidate`
and `language_review.status` to `pending` until it is reviewed again.

Run after every review edit:

```bash
services/realtime-agent/.venv/bin/python evaluation/memory_v3/validate.py
```

Do not bulk-approve the catalog and do not list Codex or an automated LLM as the
native language reviewer.

The separate `reviews/task1_ai_development_review.json` is a structured AI
semantic review used only to unblock engineering development. It is bound to an
exact catalog hash and does not change `language_review`, promote fixtures to
`protected`, or authorize real-user testing.
