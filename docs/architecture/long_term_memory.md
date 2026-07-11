# Long-Term Memory Architecture

This document is the implementation handoff for making Companion AI's memory
long-term, meaningful, privacy-preserving, and low-latency.

Current status: Phases 1-4 are implemented for the current MVP scope. Hindi/Hinglish
uses an explicitly selected EmbeddingGemma-plus-deterministic memory policy. The
full Phase 1-5 plan is **not complete end to end** until Phase 5
phone retesting and its documentation gate are finished.
Treat the "Implemented so far" and
"Remaining work" sections as the source of truth before continuing.

Verified status:

- [x] Phase 1 foundations for the current dev-endpoint-backed MVP slice.
- [x] Phase 2 query-time retrieval for the current dev-endpoint-backed MVP
  slice.
- [x] Phase 3 consolidation and graph intelligence dev implementation for the
  deterministic/local MVP slice. Manual Android validation is still required
  before treating it as field-tested.
- [x] Phase 4 model-serving and backend selection. EmbeddingGemma is used for
  embedding creation, while deterministic reranking and planning remain the
  Hindi/Hinglish default. GPU-dependent Qwen work is deferred.
- [ ] Phase 5 evaluation, tuning, and Android validation.
  Automated Hindi/Hinglish evaluation and the redacted fixed-code Android
  scenarios are complete; the repository docs gate has an unrelated blocker.

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
  -> deterministic memory router + resolve one language-scoped memory strategy
  -> if memory not needed, continue to LLM without long-term memory
  -> send reliable memory_lookup_request to mobile
  -> mobile applies the selected strategy:
       deterministic: SQLite metadata + canonical/alias matching + graph
       hybrid_vector: deterministic candidates + ObjectBox vector candidates
  -> mobile sends reliable memory_lookup_response
  -> optional configured reranker only when that language selected one
  -> prompt builder injects top memory packets only
  -> LLM response
  -> output safety classification
  -> TTS only after safety approval or safety override
```

Timeout budgets:

- Mobile memory lookup: 200 ms.
- Optional model-serving budgets are experimental only and are not acceptance
  criteria for the Hindi/Hinglish MVP. The deterministic mobile lookup budget
  remains 200 ms; on timeout or invalid output, continue without long-term
  memory.

### Query Router

Use deterministic routing first.

Routes:

- `none`: greetings, short acks, no-memory-needed turns.
- `core_profile`: name/language/preference recall.
- `semantic`: durable personal context.
- `episodic`: temporal or event recall.
- `summary`: broad memory summary questions.
- `safety`: crisis/safety path.
- `broad_safe`: ambiguous fallback with a zero-memory budget. This route is
  deliberately abstention-safe so a topic change cannot retrieve an unrelated
  session summary.

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

### Language-Scoped Strategy Selection

Every active room resolves exactly one configuration for each pipeline leg from
the persona's language route. This includes STT, LLM, TTS, and memory stages.
Memory stages are independent and intentionally named rather than inferred:

```toml
[memory.languages."hi-IN"]
retrieval = "hybrid_vector"
reranker = "deterministic"
planner = "deterministic"
```

Allowed memory strategy names are:

- retrieval: `deterministic`, `hybrid_vector`
- reranker: `deterministic`, `qwen3_reranker`
- planner: `deterministic`, `qwen3_planner`

The room agent resolves this configuration once and sends the selected retrieval
and reranker names in the reliable memory lookup request. The phone applies only
that selected strategy; it must not independently select or fail over to a
remote model. Unknown or invalid strategy names fail closed to all-deterministic.

Hindi/Hinglish MVP policy uses EmbeddingGemma for embedding creation and
deterministic safety/receipt/temporal filters, explicit aliases, graph
expansion, candidate merging, reranking, and planning. Core-profile and
procedural records are retrieved only for an explicit matching recall intent;
they are excluded from general turns. It must abstain rather than add vague
personal context. Qwen strategies remain disabled future experiments.

The mobile defaults use EmbeddingGemma-backed vector retrieval with deterministic
fallback, reranking, and planning. Qwen reranking and planning remain disabled.
A future language must explicitly select a non-deterministic strategy and enable
its corresponding model flag; omitting the strategy cannot activate Qwen
implicitly.

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
- Added language-scoped memory strategy selection alongside existing per-language
  STT/LLM/TTS provider routing:
  - persona config resolves exactly one retrieval, reranker, and planner strategy
    for the active room language
  - allowed names are validated and unknown values fail closed to all-deterministic
  - the agent sends selected retrieval/reranker strategy names in the reliable
    lookup request; mobile does not independently choose a remote model
  - Hindi/Hinglish (`hi-IN`) explicitly selects `hybrid_vector` retrieval with
    deterministic reranking and planning
  - `qwen3_reranker` and `qwen3_planner` remain opt-in future language
    strategies, with one active strategy per stage and session
- Tightened deterministic Hindi/Hinglish recall precision:
  - generic turns cannot inject unrelated `core_profile` or `procedural` memory
  - identity, language-style, and preference records require their matching
    explicit recall intent
  - the Devanagari spelling of `naam` is recognized alongside Roman `naam` and
    English `name`
  - explicit canonical aliases and graph expansion remain available for grounded
    queries such as office/manager work stress
- Added tests for:
  - typed memory metadata
  - graph-expanded office/manager recall
  - broader deterministic Phase 3 extraction categories
  - boss/manager/sir and office/work/kaam alias linking
  - non-name contradiction handling for explicit boundary updates
  - local consolidation decay and episodic-to-summary aging
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
  - language-scoped memory strategy resolution and safe default fallback
  - Hindi/Hinglish deterministic lookup with failing embedding/rerank clients,
    proving it does not invoke either model path
  - no unrelated preferred-name injection on a general emotional turn
- Added Phase 5 deterministic evaluation and observability:
  - `scripts/run-memory-eval.sh` runs the focused mobile and realtime-agent
    memory regression suite from the repository root
  - `docs/evals/hindi_hinglish_memory_eval.md` defines automated scenarios,
    pass criteria, and the real-phone protocol
  - realtime-agent emits a redacted `memory_lookup_metrics` record containing
    route, lookup attempt/latency, returned and injected counts, no-memory
    decision, context budget/usage, and resolved strategies; it never logs the
    query or memory content in this record
- Added an incremental Phase 3 local consolidation/graph slice:
  - public local `consolidateLocalMemory` entrypoint that operates on durable
    phone-owned SQLite memory records only
  - post-complete-turn consolidation trigger after local session summary creation
  - deterministic extraction for explicit family/relationship, routine, goal,
    boundary, comfort style, ritual, taboo-topic, and recurring-stressor
    statements
  - expanded entity/alias extraction for boss/manager/sir, office/work/kaam, and
    selected Hindi/Devanagari/Hinglish variants
  - graph edges for relationships, routines, goals, boundaries, comfort style,
    rituals, and recurring stressors
  - contradiction ledger updates for explicit non-name replacement statements
    such as boundary changes
  - deterministic multi-value memory IDs for selected labels, so distinct
    family relationships/routines/rituals/stressors can coexist while a
    correction to the same relationship supersedes that specific memory
  - expanded multi-value supersession coverage for goals and boundaries by
    topic qualifiers
  - local decay policy where stale low-importance memories decay first,
    confirmed high-confidence core profile memories are preserved, and old
    episodic records are aged into past session summaries
  - local pending-receipt query entrypoint for unconfirmed important memories
  - explicit voice-transcript receipt handling for `confirmed` and `rejected`
    results using narrow phrases such as "haan yaad rakhna" or "yaad mat
    rakhna"
  - receipt-control turns remain in local chat history and update the pending
    candidate state, but are excluded from stable-memory admission, graph
    extraction, embedding sync as new facts, and standalone session summaries
  - a receipt phrase without a pending candidate is still saved as chat but
    creates no long-term memory
  - rejected receipt memories are expired and excluded from retrieval and
    embedding sync
  - query-time voice receipt prompt plumbing:
    - mobile includes at most one pending receipt candidate in reliable
      `memory_lookup_response`
    - realtime-agent accepts `pending_receipts` beside `memory_packets`
    - prompt context adds a bounded `[memory_receipt]` instruction asking for
      at most one short voice-only confirmation question
    - confirmation/rejection remains phone-owned and is applied only from a
      later explicit user voice transcript
  - richer Hindi/Hinglish/Devanagari deterministic extraction and alias
    handling for family relationships, routines, goals, boundaries, comfort
    style, rituals, taboo topics, and recurring stressors
  - false-positive guards for question-shaped/speculative turns and sensitive
    medical/legal/financial/safety-adjacent turns
  - redacted dev diagnostics:
    - mobile SQLite memory admission, lookup, consolidation, receipt prompt,
      receipt result, and snapshot logs under `companion.memory`
    - mobile voice memory lookup response logs under `companion.voice.memory`
    - realtime-agent prompt and memory lookup logs include route, counts,
      latency, selected counts, and pending receipt counts without transcript
      text
  - local diagnostics snapshot API with counts by kind/label/receipt/temporal
    status and memory IDs only
  - receipt prompt bookkeeping fix:
    - added dedicated `receipt_prompted_at` local field so memory retrieval
      `last_used_at` does not suppress pending receipt prompts
    - mobile no longer marks a receipt as prompted merely because it attempted
      a lookup response; this prevents late/stale lookup responses from
      consuming a receipt prompt before the backend can use it
    - deterministic local persona provider now appends an explicit short
      voice receipt question when `[memory_receipt]` context is present

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
- No ObjectBox regeneration is required: EmbeddingGemma uses the existing
  configured 768-dimensional vector schema.

### Phase 2 Remaining: Query-Time Retrieval

- No remaining Phase 2 implementation tasks for the current deterministic
  Hindi/Hinglish MVP slice.
- EmbeddingGemma ONNX serving is enabled for Hindi/Hinglish after local
  real-weight validation. Qwen adapters remain disabled and are not a fallback;
  a future language must explicitly select any applicable strategy.

### Phase 3 Remaining: Consolidation And Graph Intelligence

- No remaining automated dev implementation tasks for the deterministic/local
  MVP slice.
- Manual Android validation completed on a real Wi-Fi Android debug device for:
  - clean local clear-history baseline clears local transcripts/memory/entities
  - office/manager stress admission as an unconfirmed
    `recurring_work_stressor`
  - graph alias creation for office/work/kaam and manager/boss/sir/Hindi
    variants
  - query-time memory lookup response under 200 ms after warm-up with
    `memory_packets > 0`
  - proactive receipt prompt path with realtime-agent
    `pending_receipts=1` and `memory_receipts_available=1`
  - visible voice receipt question:
    "Kya main office/manager pressure wali baat yaad rakhun?"
  - explicit "yaad rakhna" confirmation persists
    `receipt_state=confirmed` and appends the confirmation turn id
- Manual Android validation still recommended for:
  - same-session recall
  - previous-session recall
  - "hi" no-overretrieval
  - explicit "nahi yaad mat rakhna" rejects and removes a pending memory from
    future recall
  - Hindi/Hinglish/Devanagari phrasings for relationships, routines, goals,
    boundaries, comfort style, rituals, taboo topics, and recurring stressors
    are admitted only when explicit
  - question-shaped/speculative/sensitive turns are not stored as durable memory
- During manual validation, capture redacted logs for:
  - `companion.memory`
  - `companion.voice.memory`
  - realtime-agent `prompt_context`
  - realtime-agent `memory_lookup_response`
  - realtime-agent `memory_lookup_timeout`, if any

### Phase 4: Complete

- EmbeddingGemma-backed vector retrieval with deterministic reranking and
  planning is complete and is the default enabled path for Hindi/Hinglish. The
  API fails closed to deterministic mobile retrieval if ONNX is unavailable.
- The isolated EmbeddingGemma experiment is complete: the API endpoint accepted
  a non-sensitive Hindi test request and returned one 768-dimensional vector;
  the isolated warm endpoint request took 205.936 ms. EmbeddingGemma is enabled
  for normal embedding creation; reranking and planning remain deterministic.
- The complete FP32 ONNX Sentence Transformer artifact is persisted at the
  configured model-cache path and is the default backend on Mac and Ubuntu.
  PyTorch is used only by the offline artifact-preparation tool. It is not
  loaded as an API fallback.
- `/v1/embeddings`, `/v1/rerank`, and `/v1/memory-plan` enforce configured
  model/dimension contracts when an optional experiment is explicitly enabled.
  Disabled, unavailable, invalid, or timed-out model execution returns an
  explicit non-success response. Mobile/agent callers retain their existing
  deterministic fallback behavior and do not block a voice turn.
- Qwen reranking and planning are explicitly deferred until GPU hardware is
  available. No Qwen latency, precision, or enablement gate is required now.
- Phase 4 has no remaining implementation or validation work. Ubuntu deployment
  and operational benchmarking are scheduled under Sprint 9.

#### Phase 4 serving-host validation (2026-07-11)

- The API image now installs CPU-only PyTorch wheels and persists Hugging Face
  cache data in the `memory-model-cache` Docker volume. It does not pull unusable
  CUDA packages on Docker Desktop for Apple Silicon.
- Hugging Face access was subsequently configured with a fine-grained read token
  after accepting the Gemma licence. An isolated Mac Docker smoke test loaded
  `google/embeddinggemma-300m` successfully and produced a 768-dimensional
  vector for one non-sensitive Hindi test sentence. Cold load took 373,656 ms,
  warm inference took 216 ms, observed process RSS was 1,266,168 kB, and the
  cache reached approximately 1.7 GiB. These are compatibility measurements,
  not production latency evidence; no request text or token was retained.
- Qwen reranker and planner loading was explored only as a deferred hardware
  experiment. Both remain disabled and are not part of current acceptance.
- EmbeddingGemma is now enabled for embedding creation in the API/mobile
  configuration. Deterministic SQLite/graph retrieval remains the fallback when
  the model endpoint is unavailable or times out.
- API startup warms the enabled embedding model in the background from the
  persistent Hugging Face cache. `/health` remains a liveness check while
  `/readiness` reports `loading`, `ready`, or `failed`; embedding requests are
  rejected during loading/after failure so mobile uses deterministic fallback
  rather than triggering duplicate cold loads. No PyTorch runtime fallback is
  attempted.
- Reranker and planner remain deterministic and disabled for Qwen. The running
  phone stack uses EmbeddingGemma-backed vector retrieval with deterministic
  reranking and planning.

Phase 4 is complete. The Hindi/Hinglish product path uses EmbeddingGemma for
embedding creation with deterministic reranking, planning, and fallback. Qwen
work is deferred until future GPU hardware and is not a current acceptance item.

#### Embedding backend benchmark (2026-07-11)

The current PyTorch Sentence Transformers backend was compared with persisted
ONNX variants using non-sensitive Hindi/Hinglish samples:

| Backend | Warm p50 | Warm p95 | Quality check | Result |
| --- | ---: | ---: | --- | --- |
| PyTorch CPU baseline | 163.86 ms | 247.84 ms | Baseline | Current runtime |
| ONNX Runtime full precision | 46.64 ms | 56.81 ms | Cosine min/mean/max 1.0/1.0/1.0 across 8 samples | Adopted default |
| ONNX Runtime dynamic INT8 ARM64 | 45.20 ms | 62.95 ms | Cosine min/mean 0.9885/0.9905; top-1 agreement 6/6 | Not adopted yet |

The previous PyTorch endpoint container observed approximately 743 MiB resident memory.
The ONNX export process had a much higher temporary peak during conversion, so
export-time memory is tracked separately from steady-state serving memory. The
INT8 result was not treated as lossless despite preserving the small retrieval
sample's top-1 ranking. The official TEI ARM64 image tag documented for this
release was unavailable from the registry; the available x86 image under ARM
emulation was not used as a latency benchmark. Full-precision ONNX is now the
adopted backend; its persistent artifact and startup readiness are validated
locally. Ubuntu still needs its own host-level capacity validation.

### Phase 5 Validation Evidence (2026-07-11)

The Android measurements below are historical evidence from the earlier
deterministic-retrieval APK. They remain useful for admission, receipts, graph,
and privacy behavior, but Phase 5 must be rerun on the rebuilt APK with the
current EmbeddingGemma/ONNX backend and latest voice-turn fixes before closure.

- Completed automated evaluation:
  - `scripts/run-memory-eval.sh` is the required deterministic Hindi/Hinglish
    regression gate
  - the automated suite covers:
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
    - language-strategy isolation: Hindi/Hinglish uses EmbeddingGemma for
      embeddings and makes zero Qwen reranker/planner calls
    - profile-abstention: vague turns do not inject name/language-style context
    - redacted lookup metrics and context-budget reporting
- Android evidence collected with redacted logs:
  - Hindi-only profile admission and recall: pass; deterministic lookup was
    48 ms for admission and 21 ms for recall, with 1/1 and 2/2 candidates.
  - Hindi-only office-stressor admission and receipt confirmation: pass;
    47 ms lookup, 3/3 candidates, 713 context characters, then confirmed.
  - Hindi-only graph-expanded office recall: pass; 40 ms lookup, 2/2
    candidates, 1,996 context characters.
  - Vague emotional turn: pass; broad-safe route, 38 ms, 0/0 candidates,
    no-memory decision, and no new profile memory.
  - Greeting no-overretrieval: pass in the connected phone run; `none` route,
    lookup not attempted, 0/0 candidates, 836 context characters.
  - Previous-session recall: pass; a new session ID retrieved 2/2 candidates
    in 37 ms with 733 context characters.
  - Explicit receipt rejection and post-rejection exclusion: pass on the
    fixed APK; the record remained `rejected/expired` and was not re-admitted
    or injected. The query returned two unrelated past session summaries,
    which were excluded from the rejection decision.
- All Android acceptance scenarios now have evidence. Phase 5 is functionally
  complete, but the checklist remains open until the repository docs gate is
  repaired outside this scoped change.
- Redacted metrics implemented:
  - memory route
  - lookup latency
  - candidates returned
  - candidates injected
  - timeout count
  - no-memory decisions
  - context character budget
  - resolved retrieval/reranker/planner strategy
  - Implemented in realtime-agent `memory_lookup_metrics`; collect and assess
    these records during Android validation.

## Known Gaps And Constraints

- Real ObjectBox HNSW wrapper is wired and admitted memories are synced to it
  through the stateless EmbeddingGemma endpoint, with deterministic SQLite/graph
  fallback when the endpoint is unavailable.
- EmbeddingGemma was loaded and exercised locally. Ubuntu production deployment
  is tracked in Sprint 9; ONNX failure uses deterministic mobile retrieval and
  Qwen inference adapters remain intentionally deferred until GPU hardware exists.
- Query-time backend wait on mobile memory response is wired for vector routes,
  mobile lookup can use local EmbeddingGemma vector hits, and reranking remains
  deterministic.
- Current graph extraction and reranking/planning are intentionally narrow and
  deterministic.
- Current default embedding API behavior uses EmbeddingGemma, while reranking
  and planning remain deterministic and Qwen flags remain disabled.
- A rejected deterministic work-stressor memory is now protected from automatic
  re-admission; this is covered by the Flutter database regression test.
- Do not claim full Phase 1-5 completion until all remaining work is done and
  verified.

## Handoff Into Sprints 8-10

The local memory implementation is part of the completed Sprint 7.5 product
slice. The remaining sprint work is validation and operations, not a new
server-side memory store:

- Sprint 8 measures memory route/lookup/model latency, fallback behavior, and
  the amortized cost of self-hosted model serving.
- Sprint 9 deploys the stateless model endpoints with a persistent Hugging Face
  cache, explicit warm-up/readiness, model revision/licence records, and an
  Ubuntu rollback path. Weights are not downloaded on a user's first turn.
- Sprint 10 validates resource limits, endpoint rate limits, redaction,
  deterministic fallback, restart/cache-loss behavior, and Hindi/Hinglish
  memory quality on real devices.
