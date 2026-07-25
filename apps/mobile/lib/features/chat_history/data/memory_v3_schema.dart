part of 'app_database.dart';

/// Memory V3 has no legacy migration contract. These tables are created as an
/// isolated empty domain beside V2 while the measured V2 baseline remains
/// available. Task 3 may write validated atomic observations behind a disabled
/// flag; response-path readers are introduced only by later gates.
const memoryV3SchemaVersion = 3;

const memoryV3ProjectionTablesInDeleteOrder = <String>[
  'memory_claim_support_v3',
  'memory_episode_entities_v3',
  'memory_episode_support_v3',
  'memory_thread_support_v3',
  'memory_relation_support_v3',
  'memory_reflection_support_v3',
  'memory_claims_v3',
  'memory_threads_v3',
  'memory_relations_v3',
  'memory_entity_aliases_v3',
  'memory_episodes_v3',
  'memory_reflections_v3',
  'memory_entities_v3',
];

const memoryV3PersonalDataTablesInDeleteOrder = <String>[
  ...memoryV3ProjectionTablesInDeleteOrder,
  'memory_compile_candidate_outcomes_v3',
  'memory_compile_runs_v3',
  'memory_compile_job_messages_v3',
  'memory_compile_jobs_v3',
  'memory_user_controls_v3',
  'memory_observation_evidence_v3',
  'memory_observations_v3',
];

const _memoryV3CountedTables = <String>[
  'memory_observations_v3',
  'memory_observation_evidence_v3',
  'memory_user_controls_v3',
  'memory_compile_jobs_v3',
  'memory_compile_job_messages_v3',
  'memory_compile_runs_v3',
  'memory_compile_candidate_outcomes_v3',
  ...memoryV3ProjectionTablesInDeleteOrder,
];

extension MemoryV3SchemaStore on AppDatabase {
  Future<void> ensureMemoryV3Schema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_v3_schema_meta (
        singleton_id INTEGER PRIMARY KEY NOT NULL CHECK (singleton_id = 1),
        schema_version INTEGER NOT NULL CHECK (schema_version = 3),
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_observations_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        schema_version INTEGER NOT NULL CHECK (schema_version = 3),
        compiler_request_id TEXT NOT NULL,
        candidate_id TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL CHECK (kind IN (
          'profile', 'relationship', 'preference', 'routine', 'goal',
          'value', 'boundary', 'episode', 'open_thread',
          'assistant_commitment'
        )),
        subject_entity_type TEXT NOT NULL CHECK (subject_entity_type IN (
          'user', 'person', 'organization', 'place', 'event', 'goal',
          'preference', 'routine', 'topic', 'value'
        )),
        subject_mention TEXT NOT NULL CHECK (length(subject_mention) BETWEEN 1 AND 120),
        subject_relationship_hint TEXT,
        predicate TEXT NOT NULL CHECK (predicate IN (
          'preferred_name', 'has_relationship', 'response_language',
          'response_length', 'support_style', 'likes', 'dislikes',
          'avoids_topic', 'follows_routine', 'pursues_goal', 'holds_value',
          'experienced_event', 'event_outcome', 'open_thread',
          'assistant_commitment', 'works_at', 'profile_association',
          'relationship_association', 'episode_association',
          'causes_stress'
        )),
        object_text TEXT NOT NULL CHECK (length(object_text) BETWEEN 1 AND 500),
        normalized_value_json TEXT,
        target_entity_type TEXT CHECK (target_entity_type IS NULL OR target_entity_type IN (
          'user', 'person', 'organization', 'place', 'event', 'goal',
          'preference', 'routine', 'topic', 'value'
        )),
        target_entity_mention TEXT,
        target_relationship_hint TEXT,
        user_assessment TEXT,
        temporal_status TEXT NOT NULL CHECK (temporal_status IN (
          'current', 'past', 'future', 'uncertain'
        )),
        observed_at_ms INTEGER NOT NULL CHECK (observed_at_ms >= 0),
        timezone TEXT NOT NULL CHECK (length(timezone) BETWEEN 1 AND 64),
        event_start_at_ms INTEGER CHECK (event_start_at_ms IS NULL OR event_start_at_ms >= 0),
        event_end_at_ms INTEGER CHECK (event_end_at_ms IS NULL OR event_end_at_ms >= 0),
        temporal_raw_expression TEXT,
        temporal_resolution_confidence REAL NOT NULL CHECK (
          temporal_resolution_confidence BETWEEN 0.0 AND 1.0
        ),
        explicitness TEXT NOT NULL CHECK (explicitness IN (
          'explicit', 'implied', 'assistant_only'
        )),
        epistemic_confidence REAL NOT NULL CHECK (
          epistemic_confidence BETWEEN 0.0 AND 1.0
        ),
        is_negated INTEGER NOT NULL CHECK (is_negated IN (0, 1)),
        is_hypothetical INTEGER NOT NULL CHECK (is_hypothetical IN (0, 1)),
        is_quoted INTEGER NOT NULL CHECK (is_quoted IN (0, 1)),
        affect_emotion TEXT CHECK (affect_emotion IS NULL OR affect_emotion IN (
          'joy', 'sadness', 'anger', 'fear', 'frustration', 'loneliness',
          'anxiety', 'shame', 'relief', 'pride', 'excitement',
          'disappointment', 'tiredness', 'neutral', 'other'
        )),
        affect_valence REAL CHECK (affect_valence IS NULL OR affect_valence BETWEEN -1.0 AND 1.0),
        affect_arousal REAL CHECK (affect_arousal IS NULL OR affect_arousal BETWEEN 0.0 AND 1.0),
        affect_intensity REAL CHECK (affect_intensity IS NULL OR affect_intensity BETWEEN 0.0 AND 1.0),
        affect_target TEXT,
        affect_cause TEXT,
        affect_confidence REAL CHECK (affect_confidence IS NULL OR affect_confidence BETWEEN 0.0 AND 1.0),
        salience REAL NOT NULL CHECK (salience BETWEEN 0.0 AND 1.0),
        future_utility REAL NOT NULL CHECK (future_utility BETWEEN 0.0 AND 1.0),
        proactive_allowed INTEGER NOT NULL CHECK (proactive_allowed IN (0, 1)),
        confirmation_required INTEGER NOT NULL CHECK (confirmation_required IN (0, 1)),
        sensitivity TEXT NOT NULL CHECK (sensitivity IN ('normal', 'restricted')),
        durable_eligibility TEXT NOT NULL CHECK (durable_eligibility IN (
          'automatic', 'explicit_only'
        )),
        privacy_reason TEXT,
        proposed_operation TEXT NOT NULL CHECK (proposed_operation = 'ADD'),
        admission_disposition TEXT NOT NULL CHECK (admission_disposition IN (
          'auto_admit', 'defer', 'confirmation_required'
        )),
        admission_reason TEXT NOT NULL CHECK (length(admission_reason) BETWEEN 1 AND 300),
        compiler_provider TEXT NOT NULL,
        compiler_model TEXT NOT NULL,
        compiler_prompt_version TEXT NOT NULL,
        compiler_contract_version TEXT NOT NULL,
        compiled_at_ms INTEGER NOT NULL CHECK (compiled_at_ms >= 0),
        admitted_at_ms INTEGER NOT NULL CHECK (admitted_at_ms >= compiled_at_ms),
        CHECK (event_end_at_ms IS NULL OR event_start_at_ms IS NULL OR event_end_at_ms >= event_start_at_ms),
        CHECK ((target_entity_type IS NULL) = (target_entity_mention IS NULL)),
        CHECK (explicitness != 'assistant_only' OR kind = 'assistant_commitment'),
        UNIQUE (compiler_request_id, candidate_id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_observation_evidence_v3 (
        observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        evidence_ordinal INTEGER NOT NULL CHECK (evidence_ordinal BETWEEN 0 AND 11),
        source_message_id TEXT NOT NULL REFERENCES chat_messages(id) ON DELETE RESTRICT,
        source_turn_id TEXT NOT NULL,
        source_role TEXT NOT NULL CHECK (source_role IN ('user', 'assistant')),
        evidence_fragment TEXT NOT NULL CHECK (length(evidence_fragment) BETWEEN 1 AND 500),
        start_char INTEGER CHECK (start_char IS NULL OR start_char >= 0),
        end_char INTEGER CHECK (end_char IS NULL OR end_char >= 1),
        transcript_status TEXT NOT NULL CHECK (transcript_status IN (
          'final', 'final_corrected', 'safety_override'
        )),
        stt_confidence REAL CHECK (stt_confidence IS NULL OR stt_confidence BETWEEN 0.0 AND 1.0),
        stt_provider TEXT,
        stt_model TEXT,
        PRIMARY KEY (observation_id, evidence_ordinal),
        UNIQUE (observation_id, source_message_id, start_char, end_char),
        CHECK (end_char IS NULL OR start_char IS NULL OR end_char > start_char)
      )
    ''');

    // User controls are authoritative overlays rather than mutable fields on
    // the append-only observation ledger. Projection IDs must be deterministic
    // so controls survive a projection rebuild.
    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_user_controls_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        target_kind TEXT NOT NULL CHECK (target_kind IN (
          'observation', 'claim', 'episode', 'open_thread', 'entity',
          'relation', 'reflection'
        )),
        target_id TEXT NOT NULL,
        action TEXT NOT NULL CHECK (action IN (
          'confirm', 'reject', 'pin', 'unpin', 'forget'
        )),
        source_turn_id TEXT,
        reason TEXT,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_compile_jobs_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        request_hash TEXT NOT NULL UNIQUE,
        language TEXT NOT NULL CHECK (length(language) BETWEEN 2 AND 32),
        timezone TEXT NOT NULL CHECK (length(timezone) BETWEEN 1 AND 64),
        now_ms INTEGER NOT NULL CHECK (now_ms >= 0),
        status TEXT NOT NULL CHECK (status IN (
          'pending', 'processing', 'retry', 'succeeded', 'dead'
        )),
        attempts INTEGER NOT NULL CHECK (attempts BETWEEN 0 AND 5),
        lease_expires_at_ms INTEGER,
        next_attempt_at_ms INTEGER,
        last_error_code TEXT,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= created_at_ms),
        completed_at_ms INTEGER,
        CHECK (lease_expires_at_ms IS NULL OR lease_expires_at_ms >= 0),
        CHECK (next_attempt_at_ms IS NULL OR next_attempt_at_ms >= 0),
        CHECK (completed_at_ms IS NULL OR completed_at_ms >= created_at_ms)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_compile_job_messages_v3 (
        job_id TEXT NOT NULL REFERENCES memory_compile_jobs_v3(id) ON DELETE CASCADE,
        message_ordinal INTEGER NOT NULL CHECK (message_ordinal BETWEEN 0 AND 11),
        source_message_id TEXT NOT NULL REFERENCES chat_messages(id) ON DELETE RESTRICT,
        source_session_id TEXT NOT NULL,
        source_turn_id TEXT NOT NULL,
        source_role TEXT NOT NULL CHECK (source_role IN ('user', 'assistant')),
        source_text TEXT NOT NULL CHECK (length(source_text) BETWEEN 1 AND 1600),
        transcript_status TEXT NOT NULL CHECK (transcript_status IN (
          'final', 'final_corrected', 'safety_override'
        )),
        language TEXT NOT NULL CHECK (length(language) BETWEEN 1 AND 32),
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        stt_confidence REAL CHECK (stt_confidence IS NULL OR stt_confidence BETWEEN 0.0 AND 1.0),
        PRIMARY KEY (job_id, message_ordinal),
        UNIQUE (job_id, source_message_id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_compile_runs_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        job_id TEXT NOT NULL REFERENCES memory_compile_jobs_v3(id) ON DELETE CASCADE,
        attempt INTEGER NOT NULL CHECK (attempt BETWEEN 1 AND 5),
        status TEXT NOT NULL CHECK (status IN (
          'succeeded', 'unavailable', 'timeout', 'invalid', 'rejected'
        )),
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        prompt_version TEXT NOT NULL,
        usage_source TEXT NOT NULL CHECK (usage_source IN (
          'provider_reported', 'estimated', 'unknown'
        )),
        input_tokens INTEGER NOT NULL CHECK (input_tokens >= 0),
        output_tokens INTEGER NOT NULL CHECK (output_tokens >= 0),
        estimated_micro_inr INTEGER CHECK (estimated_micro_inr IS NULL OR estimated_micro_inr >= 0),
        candidate_count INTEGER NOT NULL CHECK (candidate_count BETWEEN 0 AND 24),
        admitted_count INTEGER NOT NULL CHECK (admitted_count BETWEEN 0 AND candidate_count),
        deferred_count INTEGER NOT NULL CHECK (deferred_count BETWEEN 0 AND candidate_count),
        rejected_count INTEGER NOT NULL CHECK (rejected_count BETWEEN 0 AND candidate_count),
        duplicate_count INTEGER NOT NULL CHECK (duplicate_count BETWEEN 0 AND candidate_count),
        error_code TEXT,
        started_at_ms INTEGER NOT NULL CHECK (started_at_ms >= 0),
        completed_at_ms INTEGER NOT NULL CHECK (completed_at_ms >= started_at_ms),
        UNIQUE (job_id, attempt),
        CHECK (admitted_count + deferred_count + rejected_count + duplicate_count <= candidate_count)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_compile_candidate_outcomes_v3 (
        job_id TEXT NOT NULL REFERENCES memory_compile_jobs_v3(id) ON DELETE CASCADE,
        candidate_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        predicate TEXT NOT NULL,
        proposed_operation TEXT NOT NULL CHECK (proposed_operation = 'ADD'),
        disposition TEXT NOT NULL CHECK (disposition IN (
          'admitted', 'deferred', 'confirmation_required', 'rejected',
          'duplicate', 'noop'
        )),
        reason TEXT NOT NULL CHECK (length(reason) BETWEEN 1 AND 120),
        observation_id TEXT REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        PRIMARY KEY (job_id, candidate_id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_entities_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        projection_generation INTEGER NOT NULL CHECK (projection_generation >= 1),
        entity_type TEXT NOT NULL CHECK (entity_type IN (
          'user', 'person', 'organization', 'place', 'event', 'goal',
          'preference', 'routine', 'topic', 'value'
        )),
        canonical_name TEXT NOT NULL CHECK (length(canonical_name) BETWEEN 1 AND 160),
        disambiguation_key TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN (
          'current', 'historical', 'uncertain', 'rejected'
        )),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        rebuilt_at_ms INTEGER NOT NULL CHECK (rebuilt_at_ms >= 0),
        UNIQUE (entity_type, disambiguation_key)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_entity_aliases_v3 (
        entity_id TEXT NOT NULL REFERENCES memory_entities_v3(id) ON DELETE CASCADE,
        alias TEXT NOT NULL CHECK (length(alias) BETWEEN 1 AND 160),
        normalized_alias TEXT NOT NULL,
        alias_type TEXT NOT NULL CHECK (alias_type IN (
          'exact_transcript', 'relationship', 'nickname', 'model_proposed',
          'user_confirmed'
        )),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        PRIMARY KEY (entity_id, normalized_alias, alias_type)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_claims_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        projection_generation INTEGER NOT NULL CHECK (projection_generation >= 1),
        state_key TEXT NOT NULL,
        cardinality TEXT NOT NULL CHECK (cardinality IN ('single', 'multiple')),
        subject_text TEXT NOT NULL,
        subject_entity_id TEXT REFERENCES memory_entities_v3(id) ON DELETE SET NULL,
        predicate TEXT NOT NULL CHECK (predicate IN (
          'preferred_name', 'has_relationship', 'response_language',
          'response_length', 'support_style', 'likes', 'dislikes',
          'avoids_topic', 'follows_routine', 'pursues_goal', 'holds_value',
          'works_at', 'profile_association', 'relationship_association',
          'episode_association', 'causes_stress'
        )),
        statement TEXT NOT NULL CHECK (length(statement) BETWEEN 1 AND 500),
        normalized_value_json TEXT,
        status TEXT NOT NULL CHECK (status IN (
          'current', 'historical', 'uncertain', 'rejected', 'expired'
        )),
        valid_from_ms INTEGER CHECK (valid_from_ms IS NULL OR valid_from_ms >= 0),
        valid_until_ms INTEGER CHECK (valid_until_ms IS NULL OR valid_until_ms >= 0),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        user_confirmation_state TEXT NOT NULL CHECK (user_confirmation_state IN (
          'unconfirmed', 'confirmed', 'rejected'
        )),
        is_pinned INTEGER NOT NULL CHECK (is_pinned IN (0, 1)),
        last_positive_use_at_ms INTEGER CHECK (last_positive_use_at_ms IS NULL OR last_positive_use_at_ms >= 0),
        last_negative_use_at_ms INTEGER CHECK (last_negative_use_at_ms IS NULL OR last_negative_use_at_ms >= 0),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        rebuilt_at_ms INTEGER NOT NULL CHECK (rebuilt_at_ms >= 0),
        CHECK (valid_until_ms IS NULL OR valid_from_ms IS NULL OR valid_until_ms >= valid_from_ms)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_claim_support_v3 (
        claim_id TEXT NOT NULL REFERENCES memory_claims_v3(id) ON DELETE CASCADE,
        observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        support_kind TEXT NOT NULL CHECK (support_kind IN ('supporting', 'contradicting')),
        PRIMARY KEY (claim_id, observation_id, support_kind)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_episodes_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        projection_generation INTEGER NOT NULL CHECK (projection_generation >= 1),
        title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 160),
        event_statement TEXT NOT NULL CHECK (length(event_statement) BETWEEN 1 AND 500),
        user_assessment TEXT,
        outcome TEXT,
        resolution_state TEXT NOT NULL CHECK (resolution_state IN (
          'resolved', 'unresolved', 'uncertain', 'rejected', 'expired'
        )),
        temporal_status TEXT NOT NULL CHECK (temporal_status IN (
          'past', 'current', 'future', 'uncertain'
        )),
        event_start_at_ms INTEGER CHECK (event_start_at_ms IS NULL OR event_start_at_ms >= 0),
        event_end_at_ms INTEGER CHECK (event_end_at_ms IS NULL OR event_end_at_ms >= 0),
        temporal_raw_expression TEXT,
        affect_emotion TEXT,
        affect_valence REAL CHECK (affect_valence IS NULL OR affect_valence BETWEEN -1.0 AND 1.0),
        affect_intensity REAL CHECK (affect_intensity IS NULL OR affect_intensity BETWEEN 0.0 AND 1.0),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        salience REAL NOT NULL CHECK (salience BETWEEN 0.0 AND 1.0),
        sensitivity TEXT NOT NULL CHECK (sensitivity IN ('normal', 'restricted')),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        rebuilt_at_ms INTEGER NOT NULL CHECK (rebuilt_at_ms >= 0),
        CHECK (event_end_at_ms IS NULL OR event_start_at_ms IS NULL OR event_end_at_ms >= event_start_at_ms)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_episode_support_v3 (
        episode_id TEXT NOT NULL REFERENCES memory_episodes_v3(id) ON DELETE CASCADE,
        observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        PRIMARY KEY (episode_id, observation_id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_episode_entities_v3 (
        episode_id TEXT NOT NULL REFERENCES memory_episodes_v3(id) ON DELETE CASCADE,
        entity_id TEXT NOT NULL REFERENCES memory_entities_v3(id) ON DELETE CASCADE,
        participant_role TEXT NOT NULL CHECK (length(participant_role) BETWEEN 1 AND 80),
        PRIMARY KEY (episode_id, entity_id, participant_role)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_threads_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        projection_generation INTEGER NOT NULL CHECK (projection_generation >= 1),
        thread_kind TEXT NOT NULL CHECK (thread_kind IN (
          'upcoming_event', 'expected_result', 'goal_checkpoint',
          'assistant_commitment', 'unresolved_experience'
        )),
        subject_text TEXT NOT NULL,
        statement TEXT NOT NULL CHECK (length(statement) BETWEEN 1 AND 500),
        related_episode_id TEXT REFERENCES memory_episodes_v3(id) ON DELETE SET NULL,
        follow_up_mode TEXT NOT NULL CHECK (follow_up_mode IN (
          'none', 'explicit_only', 'contextual', 'proactive'
        )),
        expected_start_at_ms INTEGER CHECK (expected_start_at_ms IS NULL OR expected_start_at_ms >= 0),
        expected_end_at_ms INTEGER CHECK (expected_end_at_ms IS NULL OR expected_end_at_ms >= 0),
        status TEXT NOT NULL CHECK (status IN (
          'open', 'due', 'resolved', 'cancelled', 'stale', 'rejected'
        )),
        resolved_at_ms INTEGER CHECK (resolved_at_ms IS NULL OR resolved_at_ms >= 0),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        rebuilt_at_ms INTEGER NOT NULL CHECK (rebuilt_at_ms >= 0),
        CHECK (expected_end_at_ms IS NULL OR expected_start_at_ms IS NULL OR expected_end_at_ms >= expected_start_at_ms)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_thread_support_v3 (
        thread_id TEXT NOT NULL REFERENCES memory_threads_v3(id) ON DELETE CASCADE,
        observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        PRIMARY KEY (thread_id, observation_id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_relations_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        projection_generation INTEGER NOT NULL CHECK (projection_generation >= 1),
        source_entity_id TEXT NOT NULL REFERENCES memory_entities_v3(id) ON DELETE CASCADE,
        relation_family TEXT NOT NULL CHECK (relation_family IN (
          'HAS_RELATIONSHIP', 'PREFERS', 'AVOIDS', 'PURSUES', 'EXPERIENCED',
          'PARTICIPATED_IN', 'WORKS_WITH', 'ASSOCIATED_WITH', 'CAUSED',
          'FOLLOWED_BY', 'CONTRADICTS', 'SUPERSEDES'
        )),
        target_entity_id TEXT NOT NULL REFERENCES memory_entities_v3(id) ON DELETE CASCADE,
        statement TEXT NOT NULL CHECK (length(statement) BETWEEN 1 AND 500),
        temporal_status TEXT NOT NULL CHECK (temporal_status IN (
          'current', 'historical', 'future', 'uncertain', 'expired', 'rejected'
        )),
        valid_from_ms INTEGER CHECK (valid_from_ms IS NULL OR valid_from_ms >= 0),
        valid_until_ms INTEGER CHECK (valid_until_ms IS NULL OR valid_until_ms >= 0),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        rebuilt_at_ms INTEGER NOT NULL CHECK (rebuilt_at_ms >= 0),
        CHECK (source_entity_id != target_entity_id),
        CHECK (valid_until_ms IS NULL OR valid_from_ms IS NULL OR valid_until_ms >= valid_from_ms)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_relation_support_v3 (
        relation_id TEXT NOT NULL REFERENCES memory_relations_v3(id) ON DELETE CASCADE,
        observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        support_kind TEXT NOT NULL CHECK (support_kind IN ('supporting', 'contradicting')),
        PRIMARY KEY (relation_id, observation_id, support_kind)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_reflections_v3 (
        id TEXT PRIMARY KEY NOT NULL,
        projection_generation INTEGER NOT NULL CHECK (projection_generation >= 1),
        reflection_kind TEXT NOT NULL CHECK (reflection_kind IN (
          'session_summary', 'recurring_pattern', 'relationship_context',
          'value_hypothesis', 'support_style_hypothesis', 'goal_progress',
          'temporal_change_summary'
        )),
        statement TEXT NOT NULL CHECK (length(statement) BETWEEN 1 AND 500),
        status TEXT NOT NULL CHECK (status IN (
          'active', 'historical', 'uncertain', 'rejected', 'expired'
        )),
        confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
        evidence_count INTEGER NOT NULL CHECK (evidence_count >= 1),
        valid_from_ms INTEGER CHECK (valid_from_ms IS NULL OR valid_from_ms >= 0),
        valid_until_ms INTEGER CHECK (valid_until_ms IS NULL OR valid_until_ms >= 0),
        primary_observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        created_at_ms INTEGER NOT NULL CHECK (created_at_ms >= 0),
        rebuilt_at_ms INTEGER NOT NULL CHECK (rebuilt_at_ms >= 0),
        CHECK (valid_until_ms IS NULL OR valid_from_ms IS NULL OR valid_until_ms >= valid_from_ms)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_reflection_support_v3 (
        reflection_id TEXT NOT NULL REFERENCES memory_reflections_v3(id) ON DELETE CASCADE,
        observation_id TEXT NOT NULL REFERENCES memory_observations_v3(id) ON DELETE CASCADE,
        PRIMARY KEY (reflection_id, observation_id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_projection_state_v3 (
        singleton_id INTEGER PRIMARY KEY NOT NULL CHECK (singleton_id = 1),
        schema_version INTEGER NOT NULL CHECK (schema_version = 3),
        generation INTEGER NOT NULL CHECK (generation >= 1),
        status TEXT NOT NULL CHECK (status IN ('empty', 'building', 'ready', 'failed')),
        last_observation_admitted_at_ms INTEGER,
        updated_at_ms INTEGER NOT NULL CHECK (updated_at_ms >= 0)
      )
    ''');

    await _ensureMemoryV3Indexes();
    await _ensureMemoryV3AppendOnlyTriggers();

    final now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT OR IGNORE INTO memory_v3_schema_meta '
      '(singleton_id, schema_version, created_at_ms) VALUES (1, ?, ?)',
      [memoryV3SchemaVersion, now],
    );
    await customStatement(
      'INSERT OR IGNORE INTO memory_projection_state_v3 '
      '(singleton_id, schema_version, generation, status, updated_at_ms) '
      "VALUES (1, ?, 1, 'empty', ?)",
      [memoryV3SchemaVersion, now],
    );
    final version = await customSelect(
      'SELECT schema_version FROM memory_v3_schema_meta WHERE singleton_id = 1',
    ).getSingle();
    if (version.read<int>('schema_version') != memoryV3SchemaVersion) {
      throw StateError(
        'Unsupported Memory V3 schema. Clear the disposable development database.',
      );
    }
  }

  Future<void> _ensureMemoryV3Indexes() async {
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS memory_observations_v3_time_idx ON memory_observations_v3(observed_at_ms, id)',
      'CREATE INDEX IF NOT EXISTS memory_observations_v3_predicate_idx ON memory_observations_v3(predicate, temporal_status, admitted_at_ms)',
      'CREATE INDEX IF NOT EXISTS memory_evidence_v3_turn_idx ON memory_observation_evidence_v3(source_turn_id, source_role)',
      'CREATE INDEX IF NOT EXISTS memory_controls_v3_target_idx ON memory_user_controls_v3(target_kind, target_id, created_at_ms)',
      'CREATE INDEX IF NOT EXISTS memory_compile_jobs_v3_ready_idx ON memory_compile_jobs_v3(status, next_attempt_at_ms, created_at_ms)',
      'CREATE INDEX IF NOT EXISTS memory_compile_job_messages_v3_message_idx ON memory_compile_job_messages_v3(source_message_id)',
      'CREATE INDEX IF NOT EXISTS memory_compile_outcomes_v3_observation_idx ON memory_compile_candidate_outcomes_v3(observation_id)',
      'CREATE INDEX IF NOT EXISTS memory_claims_v3_lookup_idx ON memory_claims_v3(status, predicate, valid_from_ms)',
      "CREATE UNIQUE INDEX IF NOT EXISTS memory_claims_v3_single_current_idx ON memory_claims_v3(state_key) WHERE cardinality = 'single' AND status = 'current' AND user_confirmation_state != 'rejected'",
      'CREATE INDEX IF NOT EXISTS memory_claim_support_v3_observation_idx ON memory_claim_support_v3(observation_id, support_kind)',
      'CREATE INDEX IF NOT EXISTS memory_episodes_v3_time_idx ON memory_episodes_v3(temporal_status, event_start_at_ms)',
      'CREATE INDEX IF NOT EXISTS memory_episode_support_v3_observation_idx ON memory_episode_support_v3(observation_id)',
      'CREATE INDEX IF NOT EXISTS memory_threads_v3_due_idx ON memory_threads_v3(status, expected_start_at_ms)',
      'CREATE INDEX IF NOT EXISTS memory_thread_support_v3_observation_idx ON memory_thread_support_v3(observation_id)',
      'CREATE INDEX IF NOT EXISTS memory_entity_aliases_v3_lookup_idx ON memory_entity_aliases_v3(normalized_alias, confidence)',
      'CREATE INDEX IF NOT EXISTS memory_relations_v3_source_idx ON memory_relations_v3(source_entity_id, relation_family, temporal_status)',
      'CREATE INDEX IF NOT EXISTS memory_relations_v3_target_idx ON memory_relations_v3(target_entity_id, relation_family, temporal_status)',
      'CREATE INDEX IF NOT EXISTS memory_relation_support_v3_observation_idx ON memory_relation_support_v3(observation_id, support_kind)',
      'CREATE INDEX IF NOT EXISTS memory_reflections_v3_lookup_idx ON memory_reflections_v3(status, reflection_kind, rebuilt_at_ms)',
      'CREATE INDEX IF NOT EXISTS memory_reflection_support_v3_observation_idx ON memory_reflection_support_v3(observation_id)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _ensureMemoryV3AppendOnlyTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS memory_observations_v3_no_update
      BEFORE UPDATE ON memory_observations_v3 BEGIN
        SELECT RAISE(ABORT, 'memory_observations_v3 is append-only');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS memory_observation_evidence_v3_no_update
      BEFORE UPDATE ON memory_observation_evidence_v3 BEGIN
        SELECT RAISE(ABORT, 'memory_observation_evidence_v3 is append-only');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS memory_user_controls_v3_no_update
      BEFORE UPDATE ON memory_user_controls_v3 BEGIN
        SELECT RAISE(ABORT, 'memory_user_controls_v3 is append-only');
      END
    ''');
    for (final table in const <String>[
      'memory_compile_job_messages_v3',
      'memory_compile_runs_v3',
      'memory_compile_candidate_outcomes_v3',
    ]) {
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_no_update
        BEFORE UPDATE ON $table BEGIN
          SELECT RAISE(ABORT, '$table is append-only');
        END
      ''');
    }
  }

  /// Deletes only rebuildable projections. The ledger and authoritative user
  /// controls remain untouched so Task 4 can reconstruct deterministic IDs.
  Future<void> clearMemoryV3Projections({required int nowMs}) async {
    await ensureMemoryV3Schema();
    await transaction(() async {
      for (final table in memoryV3ProjectionTablesInDeleteOrder) {
        await customStatement('DELETE FROM $table');
      }
      await customStatement(
        'UPDATE memory_projection_state_v3 '
        "SET generation = generation + 1, status = 'empty', "
        'last_observation_admitted_at_ms = NULL, updated_at_ms = ? '
        'WHERE singleton_id = 1',
        [nowMs],
      );
    });
  }

  Future<Map<String, int>> memoryV3RowCounts() async {
    await ensureMemoryV3Schema();
    final counts = <String, int>{};
    for (final table in _memoryV3CountedTables) {
      final row = await customSelect(
        'SELECT COUNT(*) AS count FROM $table',
      ).getSingle();
      counts[table] = row.read<int>('count');
    }
    return counts;
  }

  /// Task-gate audit, not a repair function. Later writers must commit an
  /// observation with evidence and every projection with normalized support in
  /// one transaction.
  Future<List<String>> auditMemoryV3Integrity() async {
    await ensureMemoryV3Schema();
    final problems = <String>[];
    final foreignKeyRows = await customSelect('PRAGMA foreign_key_check').get();
    for (final row in foreignKeyRows) {
      final table = row.data['table'];
      if (table is String && table.endsWith('_v3')) {
        problems.add('foreign_key:$table');
      }
    }
    final unsupportedQueries = <(String, String)>[
      (
        'claim',
        'SELECT id FROM memory_claims_v3 c WHERE NOT EXISTS '
            '(SELECT 1 FROM memory_claim_support_v3 s '
            'WHERE s.claim_id = c.id AND s.observation_id = c.primary_observation_id)',
      ),
      (
        'episode',
        'SELECT id FROM memory_episodes_v3 e WHERE NOT EXISTS '
            '(SELECT 1 FROM memory_episode_support_v3 s '
            'WHERE s.episode_id = e.id AND s.observation_id = e.primary_observation_id)',
      ),
      (
        'thread',
        'SELECT id FROM memory_threads_v3 t WHERE NOT EXISTS '
            '(SELECT 1 FROM memory_thread_support_v3 s '
            'WHERE s.thread_id = t.id AND s.observation_id = t.primary_observation_id)',
      ),
      (
        'relation',
        'SELECT id FROM memory_relations_v3 r WHERE NOT EXISTS '
            '(SELECT 1 FROM memory_relation_support_v3 s '
            'WHERE s.relation_id = r.id AND s.observation_id = r.primary_observation_id)',
      ),
      (
        'reflection',
        'SELECT id FROM memory_reflections_v3 r WHERE NOT EXISTS '
            '(SELECT 1 FROM memory_reflection_support_v3 s '
            'WHERE s.reflection_id = r.id AND s.observation_id = r.primary_observation_id)',
      ),
    ];
    final observationsWithoutEvidence = await customSelect(
      'SELECT id FROM memory_observations_v3 o WHERE NOT EXISTS '
      '(SELECT 1 FROM memory_observation_evidence_v3 e '
      'WHERE e.observation_id = o.id)',
    ).get();
    for (final row in observationsWithoutEvidence) {
      problems.add('observation_without_evidence:${row.read<String>('id')}');
    }
    for (final (kind, sql) in unsupportedQueries) {
      final rows = await customSelect(sql).get();
      for (final row in rows) {
        problems.add(
          '${kind}_without_primary_support:${row.read<String>('id')}',
        );
      }
    }
    final reflectionCounts = await customSelect(
      'SELECT r.id FROM memory_reflections_v3 r WHERE r.evidence_count != '
      '(SELECT COUNT(DISTINCT s.observation_id) '
      'FROM memory_reflection_support_v3 s WHERE s.reflection_id = r.id)',
    ).get();
    for (final row in reflectionCounts) {
      problems.add(
        'reflection_evidence_count_mismatch:${row.read<String>('id')}',
      );
    }
    return problems;
  }
}
