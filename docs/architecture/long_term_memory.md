# Long-Term Memory Architecture

This document is the implementation handoff for making Companion AI's memory
long-term, meaningful, privacy-preserving, and low-latency.

Current status: a foundation slice has been implemented, but the full Phase 1-5
plan is **not complete end to end**. Treat the "Implemented so far" and
"Remaining work" sections as the source of truth before continuing.

Verified status:

- [x] Phase 1 foundations for the current dev-endpoint-backed MVP slice.
- [x] Phase 2 query-time retrieval for the current dev-endpoint-backed MVP
  slice.
- [ ] Phase 3 consolidation and graph intelligence.
- [ ] Phase 4 real model serving and ambiguity handling.
- [ ] Phase 5 evaluation, tuning, and Android validation.

## Goals

- Keep memory phone-owned and local-first.
- Make memory retrieval query-time and intent-aware, not only session-start.
- Avoid polluting LLM context with stale, sensitive, low-confidence, or vaguely
  related memories.
- Support Hindi/Hinglish now while preserving a language/script-aware design for
  future multilingual support.
- Use memory to improve conversation meaningfully, but prefer gentle
  clarification over overconfident recall.
- Keep raw audio out of storage.
- Do not add auth, cloud memory, text input, video/avatar, or server-side memory
  persistence unless the user explicitly changes scope.

## Target Architecture

### Storage Ownership

Drift/SQLite on the phone remains the durable source of truth for:

- memory records
- memory metadata
- entity graph
- edge graph
- contradiction ledger
- receipt state
- deletion/clear-history state
- local transcript history

ObjectBox should be added as a local vector index only:

- Store memory IDs and embeddings.
- Do not make ObjectBox the durable source of truth.
- Rebuild ObjectBox vectors from SQLite records if needed.
- Clear ObjectBox vectors when clear-history is used.

Server-side model endpoints are stateless compute:

- `/v1/embeddings` receives text and returns embeddings.
- `/v1/rerank` receives query/candidates and returns scores.
- Future planner endpoint, if added, receives query/context hints and returns a
  strict JSON retrieval plan.
- These endpoints must not store text, vectors, memories, transcripts, or user
  identifiers beyond normal redacted operational logs.

### Memory Types

Use these memory kinds:

- `core_profile`: name, language style, very important stable preferences.
- `semantic`: durable user facts, preferences, routines, goals, boundaries.
- `episodic`: specific past events and conversations.
- `session_summary`: rolling summaries by session, day, or topic.
- `procedural`: how this user wants the companion to behave.
- `safety_ephemeral`: short-lived safety context, never general personalization.

Each memory record should include:

- `id`
- `kind`
- `label`
- `content`
- `original_text`
- `canonical_text`
- `language`
- `script`: `latin`, `devanagari`, or `mixed`
- `source_turn_ids_json`
- `source_role`
- `transcript_status`
- `stt_confidence`
- `created_at`
- `updated_at`
- `last_used_at`
- `confidence_score`
- `importance_score`
- `recurrence_count`
- `sensitivity`
- `temporal_status`: `current`, `past`, `stale`, `uncertain`, `expired`
- `receipt_state`: `unconfirmed`, `confirmed`, `rejected`, `implicit`
- `superseded_by`
- `replacement_reason`
- `evidence_summary`

### Relationship Graph

Use typed temporal graph tables in SQLite.

Entity categories:

- people
- work roles
- places
- contexts
- goals
- stressors
- routines
- preferences
- boundaries

Edge relation types:

- `related_to`
- `causes_stress`
- `prefers`
- `works_at_context`
- `has_boundary`
- `recurs_with`
- `contradicts`
- `supersedes`

Each edge should include:

- source entity ID
- relation
- target entity ID
- evidence turn IDs
- confidence score
- frequency
- polarity: `positive`, `negative`, `neutral`
- sensitivity
- temporal status
- first seen timestamp
- last seen timestamp

The graph should help connect vague queries to relevant memories. Example:

```text
Past:
User says manager creates pressure at office.

Stored:
office -> related_to -> work
manager -> works_at_context -> office
manager -> causes_stress -> work_stress
office -> recurs_with -> work_stress

Current query:
"aaj office se aaya, bad day tha"

Retrieved context:
User has previously mentioned work stress related to office or manager pressure.

Assistant behavior:
"Office ka din heavy gaya lag raha hai. Kya ye manager/pressure wali baat se
related tha, ya kuch aur hua?"
```

Do not phrase plausible graph-expanded memory as certainty unless the user
directly asked for recall or the evidence is explicit.

## Retrieval Pipeline

### Retrieval Paths

Implement five retrieval paths:

1. Core profile path
   - Deterministic and tiny.
   - Used for name/language-style/preference recall and light personalization.

2. Semantic path
   - Preferences, routines, goals, durable facts, boundaries.
   - Uses metadata filters, FTS, vector search, graph expansion, and ranking.

3. Episodic path
   - Specific past events and conversations.
   - Useful for "last time", "kal", "pichli baar", "that office thing".

4. Summary path
   - Session/topic/day summaries.
   - Useful for broad summary questions.

5. Safety path
   - Short-lived safety context only.
   - Must not be mixed into normal personalization.

### Query-Time Flow

Target flow for a final STT transcript:

```text
backend receives final user transcript
  -> input safety classification
  -> deterministic memory router
  -> if memory not needed, continue to LLM without long-term memory
  -> if memory needed, compute query embedding through stateless /v1/embeddings
  -> send reliable memory_lookup_request to mobile
  -> mobile retrieves from SQLite + FTS + ObjectBox + graph
  -> mobile sends reliable memory_lookup_response
  -> backend optionally reranks through stateless /v1/rerank
  -> prompt builder injects top memory packets only
  -> LLM response
  -> output safety classification
  -> TTS only after safety approval or safety override
```

Timeout budgets:

- Mobile memory lookup: 200 ms.
- Reranker: 120 ms.
- Planner: 100 ms.
- On timeout or invalid output, continue without long-term memory.

### Query Router

Use deterministic routing first.

Routes:

- `none`: greetings, short acks, no-memory-needed turns.
- `core_profile`: name/language/preference recall.
- `semantic`: durable personal context.
- `episodic`: temporal or event recall.
- `summary`: broad memory summary questions.
- `safety`: crisis/safety path.
- `broad_safe`: ambiguous fallback with strict budget.

Only use a small planner model when deterministic confidence is low. The planner
must return strict JSON only, such as:

```json
{
  "need_memory": true,
  "route": "episodic",
  "memory_types": ["episodic", "session_summary"],
  "entities": ["office"],
  "time_hint": "recent",
  "top_k": 6
}
```

The planner must not directly access memory or call tools. The app/backend
executes the plan deterministically.

## Context Injection Rules

- Latest user transcript is always authoritative.
- Inject no more than 6 memory packets.
- Group packets by source/type.
- Include source labels and metadata.
- Do not inject raw full history.
- Do not inject low-confidence, stale, contradicted, expired, or sensitive
  blocked memory.
- Greetings like "hi" should retrieve nothing or only tiny core profile.
- Emotionally sensitive memory should be phrased as possible context, not fact.
- Crisis/safety override must happen before TTS and must not be overridden by
  memory.

Memory packet shape:

```json
{
  "memory_id": "memory_semantic_work_stress_manager",
  "kind": "semantic",
  "label": "recurring_work_stressor",
  "content": "User has previously mentioned work stress related to office or manager pressure.",
  "canonical_text": "work stress office manager pressure",
  "source_turn_ids": ["turn_1"],
  "confidence_score": 0.68,
  "importance_score": 0.72,
  "temporal_status": "current",
  "sensitivity": "normal",
  "evidence_summary": "Recurring work/office stress signal from local turns."
}
```

## Memory Creation And Consolidation

After complete turns or session end:

1. Extract candidate memories from final user transcript plus final assistant
   transcript only.
2. Reject low-confidence, empty, replaced, repeat-requested, fragmented, or
   sensitive turns.
3. Normalize Hindi/Hinglish/English/Devanagari into canonical text.
4. Generate embeddings through stateless `/v1/embeddings`.
5. Store durable record metadata in SQLite.
6. Store memory ID + embedding in ObjectBox.
7. Extract/update graph entities and edges.
8. Update contradiction/supersession links.
9. Decay stale low-importance memories.
10. Ask receipt questions for important uncertain memories.

Example memory receipt:

```text
"Main yaad rakhun ki tumhe advice se pehle bas sunna pasand hai?"
```

Do not create enduring emotional facts from one ambiguous turn. Example:

- Good: "User had a bad day at office today." as episodic/past.
- Bad: "User is a sad person." as semantic/current.

## Safety And Privacy

Clear history must delete:

- chat messages
- sessions
- memory records
- graph entities
- graph edges
- contradiction records
- ObjectBox vector entries
- session summaries
- local memory receipts

API session context:

- The API may pass memory context to realtime-agent assignment.
- It must scrub durable `recent_context_json` after successful assignment.
- It must scrub durable `recent_context_json` on end/expiry.
- It must not retain uploaded local history as permanent backend memory.

Server logs for embedding/rerank/planner endpoints:

- OK: request ID, model, dimension, input count, input length, latency, status.
- Not OK: transcript text, memory text, embeddings, user profile, raw device ID
  next to transcript.

Sensitive categories must not enter normal long-term personalization:

- crisis/self-harm
- medical/legal/financial claims
- sexual content
- dependency phrases
- trauma-adjacent information

These may only become short-lived safety context when needed.

## Implemented So Far

Implemented in the foundation slice:

- Expanded Drift memory schema to schema version 3.
- Added memory metadata fields:
  - original/canonical text
  - language/script
  - recurrence count
  - sensitivity
  - temporal status
  - receipt state
  - replacement reason
  - evidence summary
- Added SQLite graph tables:
  - `memory_entities`
  - `memory_edges`
  - `memory_contradictions`
- Kept existing app call sites working through:
  - `upsertUserMessageAndExtractMemory`
  - `upsertAssistantMessageAndSummarizeTurn`
  - `readMemoryContext`
- Added deterministic graph signals for office/work/manager/stress.
- Added graph-expanded recall for vague office-day queries.
- Changed preferred-name memory from old `stable_fact` style to `core_profile`.
- Changed language-style memory to `procedural`.
- Changed safe preference memory to `semantic`.
- Added richer memory context payload from mobile to API.
- Added a vector index interface and in-memory test implementation:
  - `apps/mobile/lib/features/chat_history/data/memory_vector_index.dart`
- Added real local ObjectBox vector-index scaffolding:
  - ObjectBox dependency and generated model/codegen
  - `ObjectBoxMemoryVector` entity with ObjectBox internal ID, memory ID,
    embedding vector, and updated timestamp
  - HNSW index over the configured local memory embedding dimension
  - production `MemoryVectorIndex` implementation backed by ObjectBox
  - open-or-recreate recovery path if the local ObjectBox vector store cannot
    be opened
  - local test/runtime ObjectBox binary is required for plain unit tests, per
    the ObjectBox package README
- Added memory model config constants and `AppConfig` fields for embedding
  model, embedding dimension, and reranker model.
- Wired clear-history UX path to delete ObjectBox vector entries through the
  vector-index interface.
- Added stateless API endpoint contracts:
  - `POST /v1/embeddings`
  - `POST /v1/rerank`
- Added deterministic dev implementations for embeddings/rerank:
  - `services/api/app/embedding_service.py`
- Added mobile embedding sync for admitted memory records:
  - calls stateless `POST /v1/embeddings` with explicit 768-dimension request
  - writes returned embeddings into the local `MemoryVectorIndex`
  - can rebuild an empty ObjectBox vector index from durable SQLite memory
    records
  - keeps SQLite memory admission durable even when embedding/vector sync fails
  - logs redacted failure diagnostics without memory text
  - uses fakes for unit/widget tests that do not need native ObjectBox
- Added vector-backed mobile query-time lookup:
  - embeds the latest user query through the stateless embeddings endpoint
  - searches local ObjectBox/`MemoryVectorIndex`
  - merges vector hits with existing deterministic SQLite/graph retrieval
  - still applies confidence, sensitivity, temporal, supersession, and greeting
    guardrails before returning memory packets
  - falls back to deterministic SQLite retrieval if embedding or vector search
    fails
- Added query-time rerank integration:
  - calls stateless `POST /v1/rerank` after deterministic/vector retrieval
  - reorders selected candidates only
  - falls back to original ranking if rerank fails or returns invalid IDs
- Kept session-start memory context tiny:
  - recent complete transcript context is still sent as fallback context
  - durable memory context at session assignment is limited to core profile and
    language-style procedural memory
  - semantic/episodic/session-summary recall happens through live query-time
    lookup instead
- Fixed API durable session-context retention:
  - clear context after successful assignment
  - clear context on end
  - clear context on expiry
- Broadened realtime prompt parsing to accept:
  - `core_profile`
  - `semantic`
  - `episodic`
  - `session_summary`
  - `procedural`
  - `safety_ephemeral`
- Added prompt grouping:
  - `[core_profile]`
  - `[procedural_memory]`
  - `[semantic_memory]`
  - `[episodic_memory]`
  - `[session_summary]`
- Added deterministic realtime memory router:
  - `services/realtime-agent/app/memory_router.py`
- Added mobile handler for reliable `memory_lookup_request` and response event
  `memory_lookup_response`.
- Added backend query-time memory lookup before LLM:
  - reliable `memory_lookup_request` send when deterministic route needs memory
  - pending response map keyed by turn ID and request sequence
  - 200 ms timeout fallback
  - stale/out-of-order response ignored
  - returned memory packets injected into prompt context for that turn only
  - safety and greeting/no-memory routes bypass lookup
- Added tests for:
  - typed memory metadata
  - graph-expanded office/manager recall
  - stateless embedding/rerank endpoints
  - API context scrubbing
  - typed prompt memory injection
  - ObjectBox vector wrapper upsert/search/clear
  - embedding sync success/failure fallback and ObjectBox rebuild from SQLite
  - vector-backed lookup hit, vector failure fallback, stale/sensitive vector
    exclusion, and clear-history vector deletion
  - HTTP embedding/rerank client payloads and rerank ordering/fallback
  - tiny session-start memory context
  - query-time memory lookup success, timeout, stale response, and safety/greeting
    bypass

Verification already run and passed:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd services/api && uv run ruff check app tests && uv run pytest
cd services/realtime-agent && uv run ruff check app tests && uv run pytest
```

## Remaining Work

### Phase 1 Remaining: Foundations

- No remaining Phase 1 implementation tasks for the current dev-endpoint-backed
  MVP slice.
- When real EmbeddingGemma is selected in Phase 4, regenerate ObjectBox model
  code if the production embedding dimension differs from the current configured
  dimension.

### Phase 2 Remaining: Query-Time Retrieval

- No remaining Phase 2 implementation tasks for the current dev-endpoint-backed
  MVP slice.
- Real reranker/model-serving replacement remains Phase 4 work.

### Phase 3 Remaining: Consolidation And Graph Intelligence

- Add a post-session/local background consolidation job.
- Expand deterministic extraction beyond office/manager:
  - family/relationships
  - routines
  - goals
  - boundaries
  - comfort style
  - rituals
  - taboo topics
  - recurring stressors
- Add alias linking:
  - boss/manager/sir
  - office/work/kaam
  - Hindi/Devanagari/Hinglish variants
- Add contradiction and supersession handling beyond preferred-name updates.
- Add decay policy:
  - stale low-importance memories decay first
  - high-confidence confirmed core profile decays slowly or never
  - episodic memories become past summaries over time
- Add memory receipts UX/events.
- Persist receipt results as `confirmed` or `rejected`.

### Phase 4 Remaining: Precision And Ambiguity

- Replace deterministic dev `/v1/embeddings` internals with real
  EmbeddingGemma serving.
- Replace deterministic dev `/v1/rerank` internals with real
  Qwen3-Reranker-0.6B serving.
- Add optional strict-JSON Qwen3-0.6B planner only for low-confidence routing.
- Planner must output retrieval plans only; it must not access memory directly.
- Add strict validation and timeout fallback for planner output.
- Add config flags:
  - enable/disable embeddings
  - enable/disable reranker
  - enable/disable planner
  - timeout budgets
  - model names/dimensions

### Phase 5 Remaining: Evaluation And Tuning

- Add a Hindi/Hinglish memory eval harness.
- Include scenarios:
  - exact recall
  - cross-language recall
  - vague query abstention
  - office/manager graph-expanded recall
  - contradiction and supersession
  - temporal past/current distinction
  - sensitive memory exclusion
  - no over-personalization from one ambiguous turn
  - low-latency timeout fallback
  - context budget enforcement
- Add Android validation:
  - same-session recall
  - previous-session recall
  - graph-expanded recall
  - "hi" no-overretrieval
- Add redacted metrics:
  - memory route
  - lookup latency
  - candidates returned
  - candidates injected
  - timeout count
  - no-memory decisions
  - context character budget

## Known Gaps And Constraints

- Real ObjectBox HNSW wrapper is wired and admitted memories are synced to it
  through the stateless embeddings endpoint, but the endpoint still uses a
  deterministic dev embedding implementation.
- Real EmbeddingGemma inference is not wired yet.
- Real Qwen reranker/planner inference is not wired yet.
- Query-time backend wait on mobile memory response is wired for deterministic
  routes, mobile lookup can use local vector hits, and reranking is wired against
  the stateless dev rerank endpoint.
- Current graph extraction is intentionally narrow and deterministic.
- Current embedding/rerank API implementations are deterministic dev stubs.
- Do not claim full Phase 1-5 completion until all remaining work is done and
  verified.
