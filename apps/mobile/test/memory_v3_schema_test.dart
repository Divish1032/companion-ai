import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/chat_history/data/companion_memory_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('creates the isolated V3 ledger and projection schema', () async {
    await database.ensureMemoryV3Schema();

    final tableRows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'memory%v3%'",
        )
        .get();
    final tables = {for (final row in tableRows) row.read<String>('name')};

    expect(
      tables,
      containsAll(<String>{
        'memory_v3_schema_meta',
        'memory_observations_v3',
        'memory_observation_evidence_v3',
        'memory_user_controls_v3',
        'memory_compile_jobs_v3',
        'memory_compile_job_messages_v3',
        'memory_compile_runs_v3',
        'memory_compile_candidate_outcomes_v3',
        'memory_claims_v3',
        'memory_claim_support_v3',
        'memory_episodes_v3',
        'memory_episode_support_v3',
        'memory_episode_entities_v3',
        'memory_threads_v3',
        'memory_thread_support_v3',
        'memory_entities_v3',
        'memory_entity_aliases_v3',
        'memory_relations_v3',
        'memory_relation_support_v3',
        'memory_reflections_v3',
        'memory_reflection_support_v3',
        'memory_projection_state_v3',
      }),
    );
    final meta = await database
        .customSelect(
          'SELECT schema_version FROM memory_v3_schema_meta WHERE singleton_id = 1',
        )
        .getSingle();
    expect(meta.read<int>('schema_version'), memoryV3SchemaVersion);
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);
  });

  test('ledger, evidence, and user-control events are append-only', () async {
    await _insertSourceMessage(database);
    await _insertObservationWithEvidence(database);
    await database.customStatement(
      '''INSERT INTO memory_user_controls_v3 (
        id, idempotency_key, target_kind, target_id, action, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?)''',
      ['control_1', 'control_key_1', 'claim', 'claim_name', 'pin', 30],
    );

    await expectLater(
      database.customStatement(
        'UPDATE memory_observations_v3 SET object_text = ? WHERE id = ?',
        ['Diya', 'observation_name'],
      ),
      throwsA(
        predicate<Object>((error) => error.toString().contains('append-only')),
      ),
    );
    await expectLater(
      database.customStatement(
        'UPDATE memory_observation_evidence_v3 SET evidence_fragment = ? '
        'WHERE observation_id = ?',
        ['changed', 'observation_name'],
      ),
      throwsA(
        predicate<Object>((error) => error.toString().contains('append-only')),
      ),
    );
    await expectLater(
      database.customStatement(
        'UPDATE memory_user_controls_v3 SET action = ? WHERE id = ?',
        ['unpin', 'control_1'],
      ),
      throwsA(
        predicate<Object>((error) => error.toString().contains('append-only')),
      ),
    );

    expect(
      (await database
              .customSelect(
                'SELECT object_text FROM memory_observations_v3 WHERE id = ?',
                variables: [const Variable<String>('observation_name')],
              )
              .getSingle())
          .read<String>('object_text'),
      'Aditi',
    );
  });

  test('idempotency and citation constraints fail closed', () async {
    await _insertSourceMessage(database);
    await _insertObservationWithEvidence(database);

    await expectLater(
      _insertObservation(
        database,
        id: 'observation_duplicate',
        idempotencyKey: 'observation_key_duplicate',
      ),
      throwsA(anything),
    );
    await expectLater(
      _insertClaim(
        database,
        observationId: 'observation_missing',
        generation: 1,
      ),
      throwsA(anything),
    );
    await expectLater(
      database.customStatement(
        '''INSERT INTO memory_observations_v3 (
          id, schema_version, compiler_request_id, candidate_id,
          idempotency_key, kind, subject_entity_type, subject_mention,
          predicate, object_text, temporal_status, observed_at_ms, timezone,
          temporal_resolution_confidence, explicitness,
          epistemic_confidence, is_negated, is_hypothetical, is_quoted,
          salience, future_utility, proactive_allowed, confirmation_required,
          sensitivity, durable_eligibility, proposed_operation,
          admission_disposition, admission_reason, compiler_provider, compiler_model,
          compiler_prompt_version, compiler_contract_version,
          compiled_at_ms, admitted_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          'observation_forbidden',
          3,
          'compile_request_forbidden',
          'candidate_forbidden_123',
          'observation_key_forbidden',
          'profile',
          'user',
          'user',
          'preferred_name',
          'secret',
          'current',
          10,
          'Asia/Kolkata',
          1.0,
          'explicit',
          1.0,
          0,
          0,
          0,
          1.0,
          1.0,
          0,
          0,
          'forbidden',
          'never',
          'ADD',
          'auto_admit',
          'explicit_low_risk',
          'test',
          'test',
          'test',
          'memory_compile_v3_1',
          10,
          10,
        ],
      ),
      throwsA(anything),
    );
  });

  test(
    'projection reset preserves the ledger and supports deterministic rebuild',
    () async {
      await _insertSourceMessage(database);
      await _insertObservationWithEvidence(database);
      await _insertProjectionGraph(database, generation: 1);
      await database.customStatement(
        '''INSERT INTO memory_user_controls_v3 (
        id, idempotency_key, target_kind, target_id, action, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?)''',
        ['control_pin', 'control_pin_key', 'claim', 'claim_name', 'pin', 30],
      );

      expect(await database.auditMemoryV3Integrity(), isEmpty);
      await database.clearMemoryV3Projections(nowMs: 40);

      var counts = await database.memoryV3RowCounts();
      expect(counts['memory_observations_v3'], 1);
      expect(counts['memory_observation_evidence_v3'], 1);
      expect(counts['memory_user_controls_v3'], 1);
      for (final table in memoryV3ProjectionTablesInDeleteOrder) {
        expect(counts[table], 0, reason: '$table must be rebuildable');
      }
      final state = await database
          .customSelect(
            'SELECT generation, status FROM memory_projection_state_v3 '
            'WHERE singleton_id = 1',
          )
          .getSingle();
      expect(state.read<int>('generation'), 2);
      expect(state.read<String>('status'), 'empty');

      await _insertProjectionGraph(database, generation: 2);
      counts = await database.memoryV3RowCounts();
      expect(counts['memory_claims_v3'], 1);
      expect(counts['memory_relations_v3'], 1);
      expect(counts['memory_reflections_v3'], 1);
      expect(await database.auditMemoryV3Integrity(), isEmpty);
    },
  );

  test(
    'deleting ledger evidence cascades every dependent projection',
    () async {
      await _insertSourceMessage(database);
      await _insertObservationWithEvidence(database);
      await _insertProjectionGraph(database, generation: 1);

      await database.customStatement(
        'DELETE FROM memory_observations_v3 WHERE id = ?',
        ['observation_name'],
      );

      final counts = await database.memoryV3RowCounts();
      for (final entry in counts.entries) {
        expect(
          entry.value,
          0,
          reason: '${entry.key} retained deleted evidence',
        );
      }
    },
  );

  test(
    'Clear History removes transcripts and all V3 personal rows atomically',
    () async {
      await _insertSourceMessage(database, includeSession: true);
      await _insertObservationWithEvidence(database);
      await _insertProjectionGraph(database, generation: 1);
      await database.customStatement(
        '''INSERT INTO memory_user_controls_v3 (
        id, idempotency_key, target_kind, target_id, action, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?)''',
        [
          'control_forget',
          'control_forget_key',
          'claim',
          'claim_name',
          'forget',
          30,
        ],
      );

      await database.clearAllHistoryAndCompanionMemory();

      final counts = await database.memoryV3RowCounts();
      expect(counts.values, everyElement(0));
      expect(await database.select(database.chatMessages).get(), isEmpty);
      expect(await database.select(database.chatSessions).get(), isEmpty);
      expect(await database.auditMemoryV3Integrity(), isEmpty);
    },
  );
}

Future<void> _insertSourceMessage(
  AppDatabase database, {
  bool includeSession = false,
}) async {
  if (includeSession) {
    await database
        .into(database.chatSessions)
        .insert(
          ChatSessionsCompanion.insert(
            id: 'session_1',
            startedAt: 1,
            language: 'hi-IN',
          ),
        );
  }
  await database
      .into(database.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          id: 'message_name',
          sessionId: 'session_1',
          turnId: 'turn_name',
          role: 'user',
          messageText: 'Mera naam Aditi hai.',
          status: 'final',
          language: 'hi-IN',
          createdAt: 10,
          sttConfidence: const Value(0.99),
        ),
      );
}

Future<void> _insertObservationWithEvidence(AppDatabase database) async {
  await database.ensureMemoryV3Schema();
  await database.transaction(() async {
    await _insertObservation(database);
    await database.customStatement(
      '''INSERT INTO memory_observation_evidence_v3 (
        observation_id, evidence_ordinal, source_message_id, source_turn_id,
        source_role, evidence_fragment, start_char, end_char,
        transcript_status, stt_confidence, stt_provider, stt_model
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'observation_name',
        0,
        'message_name',
        'turn_name',
        'user',
        'Mera naam Aditi hai.',
        0,
        21,
        'final',
        0.99,
        'synthetic',
        'fixture',
      ],
    );
  });
}

Future<void> _insertObservation(
  AppDatabase database, {
  String id = 'observation_name',
  String idempotencyKey = 'observation_key_name',
}) {
  return database.customStatement(
    '''INSERT INTO memory_observations_v3 (
      id, schema_version, compiler_request_id, candidate_id,
      idempotency_key, kind, subject_entity_type, subject_mention,
      predicate, object_text, temporal_status, observed_at_ms, timezone,
      temporal_resolution_confidence, explicitness,
      epistemic_confidence, is_negated, is_hypothetical, is_quoted,
      salience, future_utility, proactive_allowed, confirmation_required,
      sensitivity, durable_eligibility, proposed_operation,
      admission_disposition, admission_reason, compiler_provider, compiler_model,
      compiler_prompt_version, compiler_contract_version,
      compiled_at_ms, admitted_at_ms
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
    [
      id,
      3,
      'compile_request_name',
      'candidate_name_12345678',
      idempotencyKey,
      'profile',
      'user',
      'user',
      'preferred_name',
      'Aditi',
      'current',
      10,
      'Asia/Kolkata',
      1.0,
      'explicit',
      0.99,
      0,
      0,
      0,
      0.9,
      0.95,
      0,
      0,
      'normal',
      'automatic',
      'ADD',
      'auto_admit',
      'explicit_low_risk',
      'synthetic',
      'fixture',
      'memory_semantic_atoms_v3_1',
      'memory_compile_v3_1',
      20,
      21,
    ],
  );
}

Future<void> _insertProjectionGraph(
  AppDatabase database, {
  required int generation,
}) async {
  await database.transaction(() async {
    await database.customStatement(
      '''INSERT INTO memory_entities_v3 (
        id, projection_generation, entity_type, canonical_name,
        disambiguation_key, status, confidence, primary_observation_id,
        created_at_ms, rebuilt_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'entity_user',
        generation,
        'user',
        'User',
        'self',
        'current',
        1.0,
        'observation_name',
        22,
        22,
      ],
    );
    await database.customStatement(
      '''INSERT INTO memory_entities_v3 (
        id, projection_generation, entity_type, canonical_name,
        disambiguation_key, status, confidence, primary_observation_id,
        created_at_ms, rebuilt_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'entity_aditi',
        generation,
        'person',
        'Aditi',
        'preferred_name_aditi',
        'current',
        0.99,
        'observation_name',
        22,
        22,
      ],
    );
    await database.customStatement(
      '''INSERT INTO memory_entity_aliases_v3 (
        entity_id, alias, normalized_alias, alias_type, confidence,
        primary_observation_id, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        'entity_aditi',
        'Aditi',
        'aditi',
        'exact_transcript',
        0.99,
        'observation_name',
        22,
      ],
    );
    await _insertClaim(
      database,
      observationId: 'observation_name',
      generation: generation,
    );
    await database.customStatement(
      '''INSERT INTO memory_claim_support_v3 (
        claim_id, observation_id, support_kind
      ) VALUES (?, ?, ?)''',
      ['claim_name', 'observation_name', 'supporting'],
    );
    await database.customStatement(
      '''INSERT INTO memory_episodes_v3 (
        id, projection_generation, title, event_statement, resolution_state,
        temporal_status, confidence, salience, sensitivity,
        primary_observation_id, created_at_ms, rebuilt_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'episode_name_intro',
        generation,
        'Name introduction',
        'The user introduced herself as Aditi.',
        'resolved',
        'past',
        0.99,
        0.4,
        'normal',
        'observation_name',
        22,
        22,
      ],
    );
    await database.customStatement(
      'INSERT INTO memory_episode_support_v3 '
      '(episode_id, observation_id) VALUES (?, ?)',
      ['episode_name_intro', 'observation_name'],
    );
    await database.customStatement(
      '''INSERT INTO memory_episode_entities_v3 (
        episode_id, entity_id, participant_role
      ) VALUES (?, ?, ?)''',
      ['episode_name_intro', 'entity_aditi', 'subject'],
    );
    await database.customStatement(
      '''INSERT INTO memory_threads_v3 (
        id, projection_generation, thread_kind, subject_text, statement,
        follow_up_mode, status, confidence, primary_observation_id,
        created_at_ms, rebuilt_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'thread_name_confirmation',
        generation,
        'unresolved_experience',
        'user',
        'Use the preferred name Aditi.',
        'explicit_only',
        'resolved',
        0.99,
        'observation_name',
        22,
        22,
      ],
    );
    await database.customStatement(
      'INSERT INTO memory_thread_support_v3 '
      '(thread_id, observation_id) VALUES (?, ?)',
      ['thread_name_confirmation', 'observation_name'],
    );
    await database.customStatement(
      '''INSERT INTO memory_relations_v3 (
        id, projection_generation, source_entity_id, relation_family,
        target_entity_id, statement, temporal_status, confidence,
        primary_observation_id, created_at_ms, rebuilt_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'relation_user_aditi',
        generation,
        'entity_user',
        'ASSOCIATED_WITH',
        'entity_aditi',
        'The user is associated with the preferred name Aditi.',
        'current',
        0.99,
        'observation_name',
        22,
        22,
      ],
    );
    await database.customStatement(
      '''INSERT INTO memory_relation_support_v3 (
        relation_id, observation_id, support_kind
      ) VALUES (?, ?, ?)''',
      ['relation_user_aditi', 'observation_name', 'supporting'],
    );
    await database.customStatement(
      '''INSERT INTO memory_reflections_v3 (
        id, projection_generation, reflection_kind, statement, status,
        confidence, evidence_count, primary_observation_id,
        created_at_ms, rebuilt_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'reflection_name',
        generation,
        'session_summary',
        'The user asked to be called Aditi.',
        'active',
        0.99,
        1,
        'observation_name',
        22,
        22,
      ],
    );
    await database.customStatement(
      'INSERT INTO memory_reflection_support_v3 '
      '(reflection_id, observation_id) VALUES (?, ?)',
      ['reflection_name', 'observation_name'],
    );
  });
}

Future<void> _insertClaim(
  AppDatabase database, {
  required String observationId,
  required int generation,
}) {
  return database.customStatement(
    '''INSERT INTO memory_claims_v3 (
      id, projection_generation, state_key, cardinality, subject_text,
      predicate, statement, normalized_value_json, status, confidence,
      user_confirmation_state, is_pinned, primary_observation_id,
      created_at_ms, rebuilt_at_ms
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
    [
      'claim_name',
      generation,
      'user.profile.preferred_name',
      'single',
      'user',
      'preferred_name',
      'The user prefers to be called Aditi.',
      '{"text":"Aditi"}',
      'current',
      0.99,
      'confirmed',
      0,
      observationId,
      22,
      22,
    ],
  );
}
