import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'companion_memory.dart';

class MemoryTurnResolution {
  const MemoryTurnResolution({
    required this.directive,
    this.stateFacts = const <Map<String, Object?>>[],
    this.pendingCandidate,
    this.queryScope,
    this.policyCard = const <String, Object?>{},
  });

  final String directive;
  final List<Map<String, Object?>> stateFacts;
  final Map<String, Object?>? pendingCandidate;
  final String? queryScope;
  final Map<String, Object?> policyCard;
}

/// Versioned local claim ledger. It deliberately uses parameterized SQL rather
/// than the semantic-memory tables: exact state must not inherit vector or
/// ranking behavior from [MemoryRecords].
extension CompanionMemoryStore on AppDatabase {
  Future<void> ensureCompanionMemorySchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_claims (
        id TEXT PRIMARY KEY, state_key TEXT NOT NULL, subject TEXT NOT NULL,
        predicate TEXT NOT NULL, value_json TEXT NOT NULL, cardinality TEXT NOT NULL,
        category TEXT NOT NULL, assertion_kind TEXT NOT NULL, claim_state TEXT NOT NULL,
        source_turn_ids_json TEXT NOT NULL, transcript_status TEXT NOT NULL,
        transcript_quality TEXT NOT NULL, stt_confidence REAL,
        provider_metadata_json TEXT NOT NULL DEFAULT '{}',
        extraction_version TEXT NOT NULL, confirmation_state TEXT NOT NULL,
        supersedes_claim_id TEXT, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, confirmed_at INTEGER
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS companion_state (
        state_key TEXT PRIMARY KEY, active_claim_id TEXT NOT NULL,
        value_json TEXT NOT NULL, category TEXT NOT NULL, updated_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_entity_aliases (
        id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, alias TEXT NOT NULL,
        alias_type TEXT NOT NULL, source_turn_ids_json TEXT NOT NULL,
        confidence_score REAL NOT NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _ensureColumn('memory_claims', 'stt_confidence', 'REAL');
    await _ensureColumn(
      'memory_claims',
      'provider_metadata_json',
      "TEXT NOT NULL DEFAULT '{}'",
    );
  }

  Future<void> _ensureColumn(
    String table,
    String column,
    String definition,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    if (columns.any((entry) => entry.data['name'] == column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> clearCompanionMemory() async {
    await ensureCompanionMemorySchema();
    await transaction(() async {
      await customStatement('DELETE FROM memory_entity_aliases');
      await customStatement('DELETE FROM companion_state');
      await customStatement('DELETE FROM memory_claims');
    });
  }

  /// The product's Clear History action. Keep legacy history and the V2 ledger
  /// in one SQLite transaction so a partial clear cannot leave recoverable
  /// personal state behind.
  Future<void> clearAllHistoryAndCompanionMemory() async {
    await ensureCompanionMemorySchema();
    await transaction(() async {
      await customStatement('DELETE FROM memory_entity_aliases');
      await customStatement('DELETE FROM companion_state');
      await customStatement('DELETE FROM memory_claims');
      await customStatement('DELETE FROM memory_contradictions');
      await customStatement('DELETE FROM memory_edges');
      await customStatement('DELETE FROM memory_entities');
      await customStatement('DELETE FROM memory_records');
      await customStatement('DELETE FROM chat_messages');
      await customStatement('DELETE FROM chat_sessions');
    });
    markTablesUpdated([
      chatMessages,
      chatSessions,
      memoryRecords,
      memoryEntities,
      memoryEdges,
      memoryContradictions,
    ]);
  }

  Future<MemoryTurnResolution> resolveMemoryTurn({
    required String turnId,
    required String text,
    required String transcriptStatus,
    required double? sttConfidence,
    String? sttProvider,
    String? sttModel,
  }) async {
    await ensureCompanionMemorySchema();
    await _migrateLegacyCompanionStateIfNeeded();
    final analysis = analyzeMemoryTurn(text);
    final previousTurnId = await _previousFinalUserTurnId(turnId);
    if (analysis.action == MemoryActionKind.confirmCandidate) {
      return _confirmCandidate(turnId, previousTurnId);
    }
    if (analysis.action == MemoryActionKind.rejectCandidate) {
      await _rejectCandidate(previousTurnId);
      return MemoryTurnResolution(
        directive: 'companion',
        policyCard: await _policyCard(),
      );
    }
    if (analysis.action == MemoryActionKind.answerState) {
      await _expirePendingCandidates();
      final facts = await _facts(analysis.stateKey!);
      return MemoryTurnResolution(
        directive: facts.isEmpty ? 'fact_unknown' : 'fact_answer',
        stateFacts: facts,
      );
    }
    if (analysis.action == MemoryActionKind.retrieveSemantic) {
      await _expirePendingCandidates();
      return MemoryTurnResolution(
        directive: 'companion',
        queryScope: analysis.queryScope,
        policyCard: await _policyCard(),
      );
    }
    if (analysis.action != MemoryActionKind.setState ||
        analysis.candidate == null) {
      await _expirePendingCandidates();
      return MemoryTurnResolution(
        directive: 'companion',
        policyCard: await _policyCard(),
      );
    }

    final candidate = analysis.candidate!;
    final quality = transcriptQuality(
      status: transcriptStatus,
      confidence: sttConfidence,
    );
    return transaction(() async {
      final current = await _currentClaim(candidate.stateKey);
      final repeated = await _candidateWithSameValue(candidate, previousTurnId);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (current?['value_json'] == candidate.valueJson) {
        await _appendEvidenceTurn(current!, turnId, now);
        await _expirePendingCandidates();
        return MemoryTurnResolution(
          directive: 'setting_ack',
          stateFacts: await _facts(candidate.stateKey),
        );
      }
      if (repeated != null) {
        await _activate(repeated, candidate, current, now);
        await _expirePendingCandidates();
        return MemoryTurnResolution(
          directive: 'setting_ack',
          stateFacts: await _facts(candidate.stateKey),
        );
      }

      // A new explicit assertion means the user has moved on from any older
      // confirmation prompt. Never let a later bare "हाँ" confirm it.
      await _expirePendingCandidates();

      final id =
          'claim_${now}_${turnId.hashCode}_${candidate.stateKey.hashCode}';
      final pending =
          claimAdmission(candidate: candidate, quality: quality) ==
          ClaimAdmission.confirm;
      await customStatement(
        '''INSERT INTO memory_claims (
          id, state_key, subject, predicate, value_json, cardinality, category,
          assertion_kind, claim_state, source_turn_ids_json, transcript_status,
          transcript_quality, stt_confidence, provider_metadata_json,
          extraction_version, confirmation_state, supersedes_claim_id,
          created_at, updated_at, confirmed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          candidate.stateKey,
          candidate.subject,
          candidate.predicate,
          candidate.valueJson,
          candidate.cardinality.name,
          candidate.category,
          candidate.assertionKind,
          pending ? 'candidate' : 'current',
          jsonEncode([turnId]),
          transcriptStatus,
          quality.name,
          sttConfidence,
          jsonEncode({'provider': ?sttProvider, 'model': ?sttModel}),
          'deterministic_hi_v1',
          pending ? 'pending' : 'confirmed',
          current?['id'],
          now,
          now,
          pending ? null : now,
        ],
      );
      if (pending) {
        return MemoryTurnResolution(
          directive: 'confirmation',
          pendingCandidate: {
            'claim_id': id,
            'state_key': candidate.stateKey,
            'value': candidate.value,
            'category': candidate.category,
          },
        );
      }
      await _activate({'id': id}, candidate, current, now);
      return MemoryTurnResolution(
        directive: 'setting_ack',
        stateFacts: await _facts(candidate.stateKey),
      );
    });
  }

  Future<Map<String, Object?>?> _currentClaim(String stateKey) async {
    final rows = await customSelect(
      'SELECT * FROM memory_claims WHERE state_key = ? AND claim_state = ? '
      'ORDER BY updated_at DESC LIMIT 1',
      variables: [
        Variable.withString(stateKey),
        Variable.withString('current'),
      ],
    ).get();
    return rows.isEmpty ? null : rows.single.data;
  }

  Future<Map<String, Object?>?> _candidateWithSameValue(
    CompanionClaimCandidate candidate,
    String? previousTurnId,
  ) async {
    if (previousTurnId == null) return null;
    final rows = await customSelect(
      'SELECT * FROM memory_claims WHERE state_key = ? AND value_json = ? '
      'AND claim_state = ? AND confirmation_state = ? LIMIT 1',
      variables: [
        Variable.withString(candidate.stateKey),
        Variable.withString(candidate.valueJson),
        Variable.withString('candidate'),
        Variable.withString('pending'),
      ],
    ).get();
    for (final row in rows) {
      if (_stringList(
        row.data['source_turn_ids_json'],
      ).contains(previousTurnId)) {
        return row.data;
      }
    }
    return null;
  }

  Future<void> _activate(
    Map<String, Object?> claim,
    CompanionClaimCandidate candidate,
    Map<String, Object?>? current,
    int now,
  ) async {
    final id = claim['id'] as String;
    if (candidate.cardinality == ClaimCardinality.single &&
        current?['id'] is String) {
      await customStatement(
        'UPDATE memory_claims SET claim_state = ?, confirmation_state = ?, updated_at = ? WHERE id = ?',
        ['superseded', 'superseded', now, current!['id']],
      );
    }
    await customStatement(
      'UPDATE memory_claims SET claim_state = ?, confirmation_state = ?, confirmed_at = ?, updated_at = ? WHERE id = ?',
      ['current', 'confirmed', now, now, id],
    );
    if (candidate.cardinality == ClaimCardinality.single) {
      await customStatement(
        'INSERT OR REPLACE INTO companion_state (state_key, active_claim_id, value_json, category, updated_at) VALUES (?, ?, ?, ?, ?)',
        [candidate.stateKey, id, candidate.valueJson, candidate.category, now],
      );
    }
    if (candidate.value['entity_type'] == 'person') {
      await _upsertPersonAlias(
        name: candidate.value['text'] as String?,
        claimId: id,
        now: now,
      );
    }
  }

  Future<void> _appendEvidenceTurn(
    Map<String, Object?> claim,
    String turnId,
    int now,
  ) async {
    final sourceTurns = _stringList(claim['source_turn_ids_json']);
    if (!sourceTurns.contains(turnId)) sourceTurns.add(turnId);
    await customStatement(
      'UPDATE memory_claims SET source_turn_ids_json = ?, updated_at = ? WHERE id = ?',
      [jsonEncode(sourceTurns), now, claim['id']],
    );
  }

  Future<void> _upsertPersonAlias({
    required String? name,
    required String claimId,
    required int now,
  }) async {
    if (name == null || name.isEmpty) return;
    final entityId = 'person_${_entityToken(name)}';
    final claimRows = await customSelect(
      'SELECT source_turn_ids_json FROM memory_claims WHERE id = ?',
      variables: [Variable.withString(claimId)],
    ).get();
    final sourceTurns = claimRows.isEmpty
        ? '[]'
        : (claimRows.single.data['source_turn_ids_json'] as String? ?? '[]');
    await customStatement(
      '''INSERT OR IGNORE INTO memory_entities
         (id, kind, canonical_name, aliases_json, language, sensitivity,
          first_seen_at, last_seen_at, confidence_score)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        entityId,
        'person',
        name,
        jsonEncode([name]),
        'hi-IN',
        'normal',
        now,
        now,
        0.9,
      ],
    );
    await customStatement(
      'UPDATE memory_entities SET last_seen_at = ? WHERE id = ?',
      [now, entityId],
    );
    await customStatement(
      '''INSERT OR REPLACE INTO memory_entity_aliases
         (id, entity_id, alias, alias_type, source_turn_ids_json,
          confidence_score, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'alias_${entityId}_${_entityToken(name)}',
        entityId,
        name,
        'exact_transcript',
        sourceTurns,
        0.9,
        now,
        now,
      ],
    );
  }

  Future<MemoryTurnResolution> _confirmCandidate(
    String turnId,
    String? previousTurnId,
  ) async {
    return transaction(() async {
      final claim = await _pendingCandidateForSourceTurn(previousTurnId);
      if (claim == null) {
        await _expirePendingCandidates();
        return const MemoryTurnResolution(directive: 'companion');
      }
      final value = _decodeValue(claim['value_json']);
      final candidate = CompanionClaimCandidate(
        stateKey: claim['state_key']! as String,
        subject: claim['subject']! as String,
        predicate: claim['predicate']! as String,
        value: value,
        cardinality: claim['cardinality'] == 'multi'
            ? ClaimCardinality.multi
            : ClaimCardinality.single,
        category: claim['category']! as String,
        assertionKind: 'confirmation',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await _activate(
        claim,
        candidate,
        await _currentClaim(candidate.stateKey),
        now,
      );
      await customStatement(
        'UPDATE memory_claims SET source_turn_ids_json = ?, updated_at = ? WHERE id = ?',
        [
          jsonEncode([..._stringList(claim['source_turn_ids_json']), turnId]),
          now,
          claim['id'],
        ],
      );
      await _expirePendingCandidates();
      return MemoryTurnResolution(
        directive: 'setting_ack',
        stateFacts: await _facts(candidate.stateKey),
      );
    });
  }

  Future<void> _rejectCandidate(String? previousTurnId) async {
    final claim = await _pendingCandidateForSourceTurn(previousTurnId);
    if (claim == null) {
      await _expirePendingCandidates();
      return;
    }
    await customStatement(
      "UPDATE memory_claims SET claim_state = 'expired', confirmation_state = 'rejected', updated_at = ? WHERE id = ?",
      [DateTime.now().millisecondsSinceEpoch, claim['id']],
    );
    await _expirePendingCandidates();
  }

  Future<List<Map<String, Object?>>> _facts(String stateKey) async {
    final wildcard = stateKey.endsWith('.*');
    var rows = await customSelect(
      wildcard
          ? 'SELECT * FROM memory_claims WHERE claim_state = ? AND state_key LIKE ? ORDER BY updated_at DESC LIMIT 4'
          : 'SELECT c.* FROM companion_state s JOIN memory_claims c '
                'ON c.id = s.active_claim_id WHERE s.state_key = ? '
                'AND c.claim_state = ? LIMIT 1',
      variables: [
        if (wildcard) Variable.withString('current'),
        Variable.withString(
          wildcard
              ? '${stateKey.substring(0, stateKey.length - 1)}%'
              : stateKey,
        ),
        if (!wildcard) Variable.withString('current'),
      ],
    ).get();
    // Multi-valued state deliberately has no single-row projection. Resolve
    // an exact current claim directly so acknowledgements stay deterministic.
    if (!wildcard && rows.isEmpty) {
      rows = await customSelect(
        'SELECT * FROM memory_claims WHERE state_key = ? AND claim_state = ? '
        'ORDER BY updated_at DESC LIMIT 1',
        variables: [
          Variable.withString(stateKey),
          Variable.withString('current'),
        ],
      ).get();
    }
    return [
      for (final row in rows)
        {
          'claim_id': row.data['id'],
          'state_key': row.data['state_key'],
          'value': _decodeValue(row.data['value_json']),
          'value_type': row.data['category'],
        },
    ];
  }

  Future<String?> _previousFinalUserTurnId(String turnId) async {
    final currentRows = await customSelect(
      "SELECT session_id, created_at FROM chat_messages WHERE turn_id = ? "
      "AND role = 'user' AND status IN ('final', 'final_corrected') "
      'ORDER BY created_at DESC LIMIT 1',
      variables: [Variable.withString(turnId)],
    ).get();
    if (currentRows.isEmpty) return null;
    final current = currentRows.single.data;
    final sessionId = current['session_id'] as String?;
    final createdAt = current['created_at'] as int?;
    if (sessionId == null || createdAt == null) return null;
    final previousRows = await customSelect(
      "SELECT turn_id FROM chat_messages WHERE session_id = ? AND role = 'user' "
      "AND status IN ('final', 'final_corrected') AND created_at < ? "
      'ORDER BY created_at DESC LIMIT 1',
      variables: [Variable.withString(sessionId), Variable.withInt(createdAt)],
    ).get();
    return previousRows.isEmpty
        ? null
        : previousRows.single.data['turn_id'] as String?;
  }

  Future<Map<String, Object?>?> _pendingCandidateForSourceTurn(
    String? sourceTurnId,
  ) async {
    if (sourceTurnId == null) return null;
    final rows = await customSelect(
      'SELECT * FROM memory_claims WHERE claim_state = ? AND confirmation_state = ? '
      'ORDER BY updated_at DESC',
      variables: [
        Variable.withString('candidate'),
        Variable.withString('pending'),
      ],
    ).get();
    for (final row in rows) {
      if (_stringList(
        row.data['source_turn_ids_json'],
      ).contains(sourceTurnId)) {
        return row.data;
      }
    }
    return null;
  }

  Future<void> _expirePendingCandidates() => customStatement(
    "UPDATE memory_claims SET claim_state = 'expired', confirmation_state = 'expired', updated_at = ? "
    "WHERE claim_state = 'candidate' AND confirmation_state = 'pending'",
    [DateTime.now().millisecondsSinceEpoch],
  );

  Future<Map<String, Object?>> _policyCard() async {
    final rows = await customSelect(
      'SELECT predicate, value_json FROM memory_claims WHERE claim_state = ? '
      'AND state_key IN (?, ?, ?)',
      variables: [
        Variable.withString('current'),
        Variable.withString('user.preference.response_language'),
        Variable.withString('user.preference.response_length'),
        Variable.withString('user.preference.comfort_style'),
      ],
    ).get();
    return {
      for (final row in rows)
        if (row.data['predicate'] is String)
          row.data['predicate'] as String: _decodeValue(
            row.data['value_json'],
          )['text'],
    };
  }

  Future<void> _migrateLegacyCompanionStateIfNeeded() async {
    final existing = await customSelect(
      'SELECT id FROM memory_claims LIMIT 1',
    ).get();
    if (existing.isNotEmpty) return;

    final rows = await customSelect(
      "SELECT * FROM memory_records WHERE superseded_by IS NULL "
      "AND label IN ('preferred_name', 'language_style') "
      'ORDER BY updated_at DESC',
    ).get();
    final seenKeys = <String>{};
    for (final row in rows) {
      final record = row.data;
      final label = record['label'];
      final content = record['content'];
      if (label is! String || content is! String) continue;
      final stateKey = label == 'preferred_name'
          ? 'user.profile.preferred_name'
          : 'user.preference.response_language';
      if (!seenKeys.add(stateKey)) continue;
      final value = _legacyValue(label, content);
      if (value == null) continue;
      final id = 'legacy_claim_${record['id']}';
      final now = record['updated_at'] is int
          ? record['updated_at'] as int
          : DateTime.now().millisecondsSinceEpoch;
      await customStatement(
        '''INSERT INTO memory_claims (
          id, state_key, subject, predicate, value_json, cardinality, category,
          assertion_kind, claim_state, source_turn_ids_json, transcript_status,
          transcript_quality, stt_confidence, provider_metadata_json,
          extraction_version, confirmation_state, supersedes_claim_id,
          created_at, updated_at, confirmed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          stateKey,
          'user',
          label,
          jsonEncode({'text': value, 'migrated': true}),
          'single',
          label == 'preferred_name' ? 'profile' : 'preference',
          'legacy_migration',
          'current',
          record['source_turn_ids_json'] ?? '[]',
          record['transcript_status'] ?? 'final',
          record['stt_confidence'] == null ? 'unknown' : 'high',
          record['stt_confidence'],
          '{}',
          'legacy_migration_v1',
          'confirmed',
          null,
          record['created_at'] ?? now,
          now,
          now,
        ],
      );
      await customStatement(
        'INSERT OR REPLACE INTO companion_state '
        '(state_key, active_claim_id, value_json, category, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          stateKey,
          id,
          jsonEncode({'text': value, 'migrated': true}),
          label == 'preferred_name' ? 'profile' : 'preference',
          now,
        ],
      );
    }
  }
}

Map<String, Object?> _decodeValue(Object? raw) {
  if (raw is! String) return const {};
  try {
    final value = jsonDecode(raw);
    return value is Map ? Map<String, Object?>.from(value) : const {};
  } catch (_) {
    return const {};
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! String) return const [];
  try {
    final value = jsonDecode(raw);
    return value is List ? value.whereType<String>().toList() : const [];
  } catch (_) {
    return const [];
  }
}

String? _legacyValue(String label, String content) {
  const namePrefix = 'User prefers to be called ';
  if (label == 'preferred_name' && content.startsWith(namePrefix)) {
    return content.substring(namePrefix.length).replaceAll('.', '').trim();
  }
  const languagePrefix = 'User prefers ';
  const languageSuffix = ' replies.';
  if (label == 'language_style' &&
      content.startsWith(languagePrefix) &&
      content.endsWith(languageSuffix)) {
    return content
        .substring(
          languagePrefix.length,
          content.length - languageSuffix.length,
        )
        .trim();
  }
  return null;
}

String _entityToken(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z\u0900-\u097f]+'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
