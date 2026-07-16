import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'memory_language_policy.dart';
import 'memory_candidate_model.dart';
import 'database_encryption.dart';

import 'memory_vector_index.dart';

part 'app_database.g.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

const _telemetryForbiddenKeys = {
  'text',
  'content',
  'message',
  'query',
  'prompt',
  'transcript',
  'memory',
  'vector',
  'audio',
  'device_id',
  'authorization',
  'api_key',
};

void _validateTelemetryEnvelope(Map<String, Object?> envelope) {
  if (envelope['schema'] != 'telemetry_envelope_v1' ||
      envelope['session_id'] is! String ||
      envelope['turn_id'] is! String) {
    throw const FormatException('Invalid telemetry envelope.');
  }
  void visit(Object? value, [String? key]) {
    if (key != null && _telemetryForbiddenKeys.contains(key.toLowerCase())) {
      throw FormatException('Telemetry cannot contain $key.');
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException('Telemetry key must be text.');
        }
        visit(entry.value, entry.key as String);
      }
    } else if (value is List) {
      for (final item in value) {
        visit(item);
      }
    } else if (value != null &&
        value is! String &&
        value is! num &&
        value is! bool) {
      throw const FormatException('Invalid telemetry value.');
    }
  }

  visit(envelope);
}

class ChatSessions extends Table {
  TextColumn get id => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get language => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get turnId => text()();
  TextColumn get role => text()();
  TextColumn get messageText => text().named('text')();
  TextColumn get status => text()();
  TextColumn get language => text()();
  IntColumn get createdAt => integer()();
  TextColumn get latencyJson => text().nullable()();
  RealColumn get sttConfidence => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryRecords extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get label => text()();
  TextColumn get content => text()();
  TextColumn get originalText => text().withDefault(const Constant(''))();
  TextColumn get canonicalText => text().withDefault(const Constant(''))();
  TextColumn get language => text().withDefault(const Constant('hi-IN'))();
  TextColumn get script => text().withDefault(const Constant('mixed'))();
  TextColumn get sourceTurnIdsJson => text()();
  TextColumn get sourceRole => text()();
  TextColumn get transcriptStatus => text()();
  RealColumn get sttConfidence => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get lastUsedAt => integer().nullable()();
  IntColumn get receiptPromptedAt => integer().nullable()();
  RealColumn get confidenceScore => real()();
  RealColumn get importanceScore => real()();
  IntColumn get recurrenceCount => integer().withDefault(const Constant(1))();
  TextColumn get sensitivity => text().withDefault(const Constant('normal'))();
  TextColumn get temporalStatus =>
      text().withDefault(const Constant('current'))();
  TextColumn get receiptState =>
      text().withDefault(const Constant('implicit'))();
  TextColumn get supersededBy => text().nullable()();
  TextColumn get replacementReason => text().nullable()();
  TextColumn get evidenceSummary => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryEntities extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get canonicalName => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get language => text().withDefault(const Constant('hi-IN'))();
  TextColumn get sensitivity => text().withDefault(const Constant('normal'))();
  IntColumn get firstSeenAt => integer()();
  IntColumn get lastSeenAt => integer()();
  RealColumn get confidenceScore => real().withDefault(const Constant(0.7))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryEdges extends Table {
  TextColumn get id => text()();
  TextColumn get sourceEntityId => text()();
  TextColumn get relation => text()();
  TextColumn get targetEntityId => text()();
  TextColumn get evidenceTurnIdsJson =>
      text().withDefault(const Constant('[]'))();
  RealColumn get confidenceScore => real().withDefault(const Constant(0.7))();
  IntColumn get frequency => integer().withDefault(const Constant(1))();
  TextColumn get polarity => text().withDefault(const Constant('neutral'))();
  TextColumn get sensitivity => text().withDefault(const Constant('normal'))();
  TextColumn get temporalStatus =>
      text().withDefault(const Constant('current'))();
  IntColumn get firstSeenAt => integer()();
  IntColumn get lastSeenAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryContradictions extends Table {
  TextColumn get id => text()();
  TextColumn get oldMemoryId => text()();
  TextColumn get newMemoryId => text()();
  TextColumn get reason => text()();
  TextColumn get evidenceTurnIdsJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryEpisodes extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get title => text()();
  TextColumn get summary => text()();
  TextColumn get retrievalText => text()();
  TextColumn get sourceTurnIdsJson => text()();
  TextColumn get entityIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get topicKeysJson => text().withDefault(const Constant('[]'))();
  IntColumn get eventStartAt => integer().nullable()();
  IntColumn get eventEndAt => integer().nullable()();
  TextColumn get temporalStatus => text().withDefault(const Constant('past'))();
  TextColumn get explicitness =>
      text().withDefault(const Constant('explicit'))();
  RealColumn get confidenceScore => real()();
  RealColumn get importanceScore => real()();
  TextColumn get sensitivity => text().withDefault(const Constant('normal'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryOpenThreads extends Table {
  TextColumn get id => text()();
  TextColumn get episodeId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get subject => text()();
  TextColumn get predicate => text()();
  TextColumn get objectText => text()();
  IntColumn get dueStartAt => integer().nullable()();
  IntColumn get dueEndAt => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  BoolColumn get followUpAllowed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get proactiveAllowed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get sourceTurnIdsJson => text()();
  RealColumn get confidenceScore => real()();
  TextColumn get sensitivity => text().withDefault(const Constant('normal'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get closedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryExtractionJobs extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get startTurnId => text()();
  TextColumn get endTurnId => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get extractionVersion => text()();
  TextColumn get requestHash => text()();
  TextColumn get lastErrorCode => text().nullable()();
  IntColumn get nextAttemptAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MemoryCandidates extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  TextColumn get candidateKind => text()();
  TextColumn get subject => text()();
  TextColumn get predicate => text()();
  TextColumn get objectText => text()();
  IntColumn get eventStartAt => integer().nullable()();
  IntColumn get eventEndAt => integer().nullable()();
  TextColumn get temporalStatus => text()();
  TextColumn get explicitness => text()();
  RealColumn get confidenceScore => real()();
  RealColumn get futureUtility => real()();
  TextColumn get sensitivity => text()();
  TextColumn get sourceTurnIdsJson => text()();
  TextColumn get evidenceRole => text()();
  TextColumn get suggestedAction => text()();
  BoolColumn get followUpAllowed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get proactiveAllowed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get decisionState => text()();
  TextColumn get decisionReason => text()();
  TextColumn get targetMemoryId => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ChatSessions,
    ChatMessages,
    MemoryRecords,
    MemoryEntities,
    MemoryEdges,
    MemoryContradictions,
    MemoryEpisodes,
    MemoryOpenThreads,
    MemoryExtractionJobs,
    MemoryCandidates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _ensureMemoryFtsSchema();
      await _ensureTelemetrySchema();
      await _ensureJudgeOperationsSchema();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(chatMessages, chatMessages.sttConfidence);
        // Drift creates the current table definition here. For a v1 database,
        // do not subsequently add v3/v4 columns a second time.
        await m.createTable(memoryRecords);
        await m.createTable(memoryEntities);
        await m.createTable(memoryEdges);
        await m.createTable(memoryContradictions);
      } else if (from < 3) {
        await m.addColumn(memoryRecords, memoryRecords.originalText);
        await m.addColumn(memoryRecords, memoryRecords.canonicalText);
        await m.addColumn(memoryRecords, memoryRecords.language);
        await m.addColumn(memoryRecords, memoryRecords.script);
        await m.addColumn(memoryRecords, memoryRecords.recurrenceCount);
        await m.addColumn(memoryRecords, memoryRecords.sensitivity);
        await m.addColumn(memoryRecords, memoryRecords.temporalStatus);
        await m.addColumn(memoryRecords, memoryRecords.receiptState);
        await m.addColumn(memoryRecords, memoryRecords.replacementReason);
        await m.addColumn(memoryRecords, memoryRecords.evidenceSummary);
        await m.createTable(memoryEntities);
        await m.createTable(memoryEdges);
        await m.createTable(memoryContradictions);
      }
      if (from >= 2 && from < 4) {
        await m.addColumn(memoryRecords, memoryRecords.receiptPromptedAt);
      }
      if (from < 5) {
        await m.createTable(memoryEpisodes);
        await m.createTable(memoryOpenThreads);
        await m.createTable(memoryExtractionJobs);
        await m.createTable(memoryCandidates);
      }
      if (from < 6) {
        await _ensureTelemetrySchema();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureMemoryFtsSchema();
      await _ensureTelemetrySchema();
      await _ensureJudgeOperationsSchema();
    },
  );

  Future<void> _ensureMemoryFtsSchema() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS memory_records_fts USING fts5(
        memory_id UNINDEXED,
        label,
        content,
        canonical_text,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS memory_records_fts_insert
      AFTER INSERT ON memory_records BEGIN
        INSERT INTO memory_records_fts(memory_id, label, content, canonical_text)
        VALUES (new.id, new.label, new.content, new.canonical_text);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS memory_records_fts_update
      AFTER UPDATE ON memory_records BEGIN
        DELETE FROM memory_records_fts WHERE memory_id = old.id;
        INSERT INTO memory_records_fts(memory_id, label, content, canonical_text)
        VALUES (new.id, new.label, new.content, new.canonical_text);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS memory_records_fts_delete
      AFTER DELETE ON memory_records BEGIN
        DELETE FROM memory_records_fts WHERE memory_id = old.id;
      END
    ''');
    await customStatement('''
      INSERT INTO memory_records_fts(memory_id, label, content, canonical_text)
      SELECT id, label, content, canonical_text FROM memory_records
      WHERE id NOT IN (SELECT memory_id FROM memory_records_fts)
    ''');
  }

  Future<void> _ensureTelemetrySchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS telemetry_events (
        id TEXT PRIMARY KEY NOT NULL,
        session_id TEXT NOT NULL,
        turn_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS telemetry_events_session_idx
      ON telemetry_events(session_id, created_at)
    ''');
  }

  /// Append-only, content-free decision-operation ledger. It stores decision
  /// and job IDs, timestamps, redacted counters/cost metadata, and resulting
  /// local claim IDs; never transcript or memory text.
  Future<void> _ensureJudgeOperationsSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_judge_operations (
        decision_id TEXT PRIMARY KEY NOT NULL,
        job_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        turn_id TEXT NOT NULL,
        action TEXT NOT NULL,
        outcome TEXT NOT NULL,
        reason TEXT NOT NULL,
        result_claim_id TEXT,
        window_turn_count INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL,
        cost_source TEXT NOT NULL,
        input_tokens INTEGER NOT NULL,
        output_tokens INTEGER NOT NULL,
        estimated_micro_inr INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> markTurnDeterministicallyHandled(String turnId) async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS memory_judge_skips (turn_id TEXT PRIMARY KEY)',
    );
    await customStatement(
      'INSERT OR IGNORE INTO memory_judge_skips(turn_id) VALUES (?)',
      [turnId],
    );
  }

  Future<void> appendTelemetryEnvelope(Map<String, Object?> envelope) async {
    _validateTelemetryEnvelope(envelope);
    final sessionId = envelope['session_id']! as String;
    final turnId = envelope['turn_id']! as String;
    final recordedAt = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT INTO telemetry_events(id, session_id, turn_id, created_at, payload_json) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        'telemetry_${sessionId}_${turnId}_$recordedAt',
        sessionId,
        turnId,
        recordedAt,
        jsonEncode(envelope),
      ],
    );
  }

  Future<List<Map<String, Object?>>> readTelemetryForSession(
    String sessionId,
  ) async {
    final rows = await customSelect(
      'SELECT payload_json FROM telemetry_events WHERE session_id = ? ORDER BY created_at ASC',
      variables: [Variable<String>(sessionId)],
    ).get();
    return [
      for (final row in rows)
        Map<String, Object?>.from(
          jsonDecode(row.read<String>('payload_json')) as Map,
        ),
    ];
  }

  Stream<List<ChatMessage>> watchMessages() {
    return (select(
      chatMessages,
    )..orderBy([(message) => OrderingTerm.asc(message.createdAt)])).watch();
  }

  Future<List<ChatMessage>> readMessages() {
    return (select(
      chatMessages,
    )..orderBy([(message) => OrderingTerm.asc(message.createdAt)])).get();
  }

  Future<List<ChatMessage>> readRecentTranscriptContext({required int limit}) {
    return (select(chatMessages)
          ..where(
            (message) =>
                message.status.equals('final') |
                message.status.equals('final_corrected'),
          )
          ..orderBy([(message) => OrderingTerm.desc(message.createdAt)])
          ..limit(limit))
        .get()
        .then((messages) => messages.reversed.toList());
  }

  Future<void> upsertSession(ChatSessionsCompanion session) {
    return into(chatSessions).insertOnConflictUpdate(session);
  }

  Future<void> addMessage(ChatMessagesCompanion message) {
    return into(chatMessages).insert(message);
  }

  Future<void> upsertMessage(ChatMessagesCompanion message) {
    return into(chatMessages).insertOnConflictUpdate(message);
  }

  Future<void> upsertUserMessageAndExtractMemory(
    ChatMessagesCompanion message,
  ) async {
    await transaction(() async {
      await into(chatMessages).insertOnConflictUpdate(message);
      final inserted = await (select(
        chatMessages,
      )..where((row) => row.id.equals(message.id.value))).getSingle();
      await _admitStableFacts(inserted);
    });
  }

  Future<void> upsertAssistantMessageAndSummarizeTurn(
    ChatMessagesCompanion message,
  ) async {
    int? consolidationNow;
    await transaction(() async {
      await into(chatMessages).insertOnConflictUpdate(message);
      final assistant = await (select(
        chatMessages,
      )..where((row) => row.id.equals(message.id.value))).getSingle();
      if (assistant.status != 'final' &&
          assistant.status != 'safety_override') {
        return;
      }
      final user =
          await (select(chatMessages)
                ..where(
                  (row) =>
                      row.turnId.equals(assistant.turnId) &
                      row.role.equals('user') &
                      (row.status.equals('final') |
                          row.status.equals('final_corrected')),
                )
                ..limit(1))
              .getSingleOrNull();
      if (user != null &&
          _eligibleForMemory(user) &&
          _classifyMemoryReceiptReply(user.messageText) ==
              _MemoryReceiptDecision.none) {
        await _upsertSessionSummary(user, assistant);
        consolidationNow = assistant.createdAt;
      }
    });
    if (consolidationNow != null) {
      await consolidateLocalMemory(nowMs: consolidationNow);
    }
  }

  Future<void> replaceMessageText({
    required String messageId,
    required String text,
    required int createdAt,
  }) async {
    await transaction(() async {
      await (update(
        chatMessages,
      )..where((message) => message.id.equals(messageId))).write(
        ChatMessagesCompanion(
          messageText: Value(text),
          createdAt: Value(createdAt),
          status: const Value('final_corrected'),
        ),
      );
      final corrected = await (select(
        chatMessages,
      )..where((message) => message.id.equals(messageId))).getSingleOrNull();
      if (corrected != null) {
        await _admitStableFacts(corrected);
      }
    });
  }

  Future<List<MemoryRecord>> readMemoryContext({
    required String latestUserText,
    required int limit,
    List<VectorSearchHit> vectorHits = const [],
    String? route,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final intent = _classifyMemoryQuery(latestUserText);
    final vectorScores = {
      for (final hit in vectorHits) hit.memoryId: hit.score,
    };
    final ftsScores = await _memoryFtsScores(latestUserText);
    final rows =
        await (select(memoryRecords)
              ..where((row) => row.supersededBy.isNull())
              ..orderBy([
                (row) => OrderingTerm.desc(row.importanceScore),
                (row) => OrderingTerm.desc(row.updatedAt),
              ]))
            .get();
    final ranked = [
      for (final row in rows)
        if (_memoryRelevant(row, latestUserText, intent))
          _RankedMemory(row, _memoryRank(row, latestUserText, intent)),
      for (final row in rows)
        if (ftsScores.containsKey(row.id) &&
            _memoryRelevant(row, latestUserText, intent))
          _RankedMemory(
            row,
            _memoryRank(row, latestUserText, intent) + ftsScores[row.id]!,
          ),
      for (final row in rows)
        if (vectorScores.containsKey(row.id) &&
            _memoryAllowedForRetrieval(row, latestUserText) &&
            (intent == _MemoryQueryIntent.general ||
                _intentAllowsMemory(row, intent)))
          _RankedMemory(
            row,
            _memoryRank(row, latestUserText, intent) +
                0.45 +
                vectorScores[row.id]!.clamp(0.0, 1.0),
          ),
      ...await _graphExpandedMemories(latestUserText, intent),
      ...await _openThreadExpandedMemories(latestUserText, intent, route),
    ]..sort((a, b) => b.score.compareTo(a.score));
    final selected = _selectBoundedMemories(
      ranked,
      limit: limit,
      intent: intent,
    );
    for (final row in selected) {
      await (update(memoryRecords)..where((record) => record.id.equals(row.id)))
          .write(MemoryRecordsCompanion(lastUsedAt: Value(now)));
    }
    _logMemoryDiagnostic('memory_lookup_local', {
      'intent': intent.name,
      'route': route ?? 'unspecified',
      'candidate_count': rows.length,
      'vector_hit_count': vectorHits.length,
      'selected_count': selected.length,
      'selected_kinds': [for (final row in selected) row.kind],
    });
    return Future.wait(selected.map(_expandEpisodeWindow));
  }

  Future<Map<String, double>> _memoryFtsScores(String query) async {
    final tokens = _canonicalMemoryText(query)
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .take(8)
        .toList();
    if (tokens.isEmpty) return const {};
    final match = tokens
        .map((token) => '"${token.replaceAll('"', '')}"')
        .join(' OR ');
    try {
      final rows = await customSelect(
        'SELECT memory_id, bm25(memory_records_fts) AS rank '
        'FROM memory_records_fts WHERE memory_records_fts MATCH ? LIMIT 20',
        variables: [Variable<String>(match)],
      ).get();
      return {
        for (final row in rows)
          row.read<String>('memory_id'):
              (1 / (1 + row.read<double>('rank').abs())).clamp(0.0, 1.0),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<MemoryRecord> _expandEpisodeWindow(MemoryRecord memory) async {
    if (memory.kind != 'episodic') return memory;
    final sourceIds = _decodeStringList(memory.sourceTurnIdsJson);
    if (sourceIds.isEmpty) return memory;
    final sources =
        await (select(chatMessages)
              ..where((row) => row.turnId.isIn(sourceIds))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    if (sources.isEmpty) return memory;
    final anchor = sources.first.createdAt;
    final surrounding =
        await (select(chatMessages)
              ..where(
                (row) =>
                    row.sessionId.equals(sources.first.sessionId) &
                    row.createdAt.isBetweenValues(
                      anchor - 120000,
                      anchor + 120000,
                    ) &
                    (row.status.like('final%') |
                        row.status.equals('safety_override')),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
              ..limit(6))
            .get();
    if (surrounding.isEmpty) return memory;
    final window = surrounding
        .map(
          (row) =>
              '${row.role}: ${_cleanMemoryText(row.messageText, maxChars: 140)}',
        )
        .join('\n');
    return memory.copyWith(content: '${memory.content}\nContext:\n$window');
  }

  Future<List<MemoryRecord>> readMemoryRecordsForTurn({
    required String turnId,
  }) async {
    final rows = await (select(
      memoryRecords,
    )..where((row) => row.supersededBy.isNull())).get();
    return [
      for (final row in rows)
        if (_decodeStringList(row.sourceTurnIdsJson).contains(turnId)) row,
    ];
  }

  Future<List<MemoryRecord>> readEmbeddableMemoryRecords() {
    return (select(memoryRecords)
          ..where(
            (row) =>
                row.supersededBy.isNull() &
                row.sensitivity.equals('normal') &
                row.receiptState.isNotIn(['rejected', 'unconfirmed']) &
                row.temporalStatus.isNotIn(['expired', 'stale']) &
                row.content.isNotValue(''),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
        .get();
  }

  Future<List<MemoryRecord>> readSessionStartMemoryContext({
    required int limit,
  }) {
    return (select(memoryRecords)
          ..where(
            (row) =>
                row.supersededBy.isNull() &
                row.sensitivity.equals('normal') &
                row.receiptState.isNotIn(['rejected', 'unconfirmed']) &
                row.temporalStatus.isNotIn(['expired', 'stale']) &
                (row.kind.equals('core_profile') |
                    (row.kind.equals('procedural') &
                        row.label.equals('language_style'))),
          )
          ..orderBy([
            (row) => OrderingTerm.desc(row.importanceScore),
            (row) => OrderingTerm.desc(row.updatedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<ChatMessage?> latestFinalUserMessage() {
    return (select(chatMessages)
          ..where(
            (message) =>
                message.role.equals('user') & message.status.like('final%'),
          )
          ..orderBy([(message) => OrderingTerm.desc(message.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> clearHistory() async {
    await transaction(() async {
      await delete(memoryCandidates).go();
      await delete(memoryExtractionJobs).go();
      await delete(memoryOpenThreads).go();
      await delete(memoryEpisodes).go();
      await delete(memoryContradictions).go();
      await delete(memoryEdges).go();
      await delete(memoryEntities).go();
      await delete(memoryRecords).go();
      await delete(chatMessages).go();
      await delete(chatSessions).go();
    });
  }

  Stream<List<MemoryRecord>> watchManageableMemories() {
    return (select(memoryRecords)
          ..where(
            (row) =>
                row.supersededBy.isNull() &
                row.temporalStatus.isNotIn(['expired']),
          )
          ..orderBy([
            (row) => OrderingTerm.desc(row.importanceScore),
            (row) => OrderingTerm.desc(row.updatedAt),
          ]))
        .watch();
  }

  Future<void> confirmMemory(String memoryId) async {
    await transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(
        memoryRecords,
      )..where((row) => row.id.equals(memoryId))).write(
        MemoryRecordsCompanion(
          receiptState: const Value('confirmed'),
          confidenceScore: const Value(0.95),
          updatedAt: Value(now),
        ),
      );
      await (update(
        memoryCandidates,
      )..where((row) => row.targetMemoryId.equals(memoryId))).write(
        const MemoryCandidatesCompanion(
          decisionState: Value('confirmed'),
          decisionReason: Value('explicit_user_confirmation'),
        ),
      );
    });
  }

  Future<void> forgetMemory(String memoryId) async {
    await transaction(() async {
      await (delete(memoryContradictions)..where(
            (row) =>
                row.oldMemoryId.equals(memoryId) |
                row.newMemoryId.equals(memoryId),
          ))
          .go();
      await (delete(
        memoryCandidates,
      )..where((row) => row.targetMemoryId.equals(memoryId))).go();
      await (delete(
        memoryOpenThreads,
      )..where((row) => row.id.equals(memoryId))).go();
      await (delete(
        memoryEpisodes,
      )..where((row) => row.id.equals(memoryId))).go();
      await (delete(
        memoryRecords,
      )..where((row) => row.id.equals(memoryId))).go();
    });
  }

  Future<void> enqueueMemoryExtractionJob({
    required String sessionId,
    required String turnId,
    required String extractionVersion,
  }) async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS memory_judge_skips (turn_id TEXT PRIMARY KEY)',
    );
    final skip = await customSelect(
      'SELECT turn_id FROM memory_judge_skips WHERE turn_id = ?',
      variables: [Variable.withString(turnId)],
    ).getSingleOrNull();
    if (skip != null) return;
    final messages =
        await (select(chatMessages)..where(
              (row) =>
                  row.sessionId.equals(sessionId) &
                  row.turnId.equals(turnId) &
                  (row.status.like('final%') |
                      row.status.equals('safety_override')),
            ))
            .get();
    if (!messages.any((row) => row.role == 'user') ||
        !messages.any((row) => row.role == 'assistant' || row.role == 'ai')) {
      return;
    }
    final duplicate =
        await (select(memoryExtractionJobs)..where(
              (row) =>
                  row.sessionId.equals(sessionId) &
                  row.endTurnId.equals(turnId) &
                  row.extractionVersion.equals(extractionVersion),
            ))
            .getSingleOrNull();
    if (duplicate != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending =
        await (select(memoryExtractionJobs)
              ..where(
                (row) =>
                    row.sessionId.equals(sessionId) &
                    row.extractionVersion.equals(extractionVersion) &
                    row.status.equals('pending'),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (pending != null) {
      final startMessage =
          await (select(chatMessages)
                ..where(
                  (row) =>
                      row.sessionId.equals(sessionId) &
                      row.turnId.equals(pending.startTurnId) &
                      row.role.equals('user'),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      final endMessage = messages.firstWhere((row) => row.role == 'user');
      final boundedUsers = startMessage == null
          ? const <ChatMessage>[]
          : await (select(chatMessages)..where(
                  (row) =>
                      row.sessionId.equals(sessionId) &
                      row.role.equals('user') &
                      row.createdAt.isBetweenValues(
                        startMessage.createdAt,
                        endMessage.createdAt,
                      ) &
                      row.status.like('final%'),
                ))
                .get();
      if (boundedUsers.map((row) => row.turnId).toSet().length <= 4) {
        await (update(
          memoryExtractionJobs,
        )..where((row) => row.id.equals(pending.id))).write(
          MemoryExtractionJobsCompanion(
            endTurnId: Value(turnId),
            requestHash: Value(
              _stableMemoryHash(
                '$sessionId|${pending.startTurnId}|$turnId|$extractionVersion',
              ),
            ),
            updatedAt: Value(now),
          ),
        );
        return;
      }
      await (update(
        memoryExtractionJobs,
      )..where((row) => row.id.equals(pending.id))).write(
        MemoryExtractionJobsCompanion(
          status: const Value('ready'),
          updatedAt: Value(now),
        ),
      );
    }
    final hash = _stableMemoryHash('$sessionId|$turnId|$extractionVersion');
    final jobId = 'memory_job_$hash';
    await into(memoryExtractionJobs).insert(
      MemoryExtractionJobsCompanion.insert(
        id: jobId,
        sessionId: sessionId,
        startTurnId: turnId,
        endTurnId: turnId,
        extractionVersion: extractionVersion,
        requestHash: hash,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<MemoryExtractionJob?> claimNextMemoryExtractionJob() async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final staleLease = now - const Duration(minutes: 5).inMilliseconds;
      final job =
          await (select(memoryExtractionJobs)
                ..where(
                  (row) =>
                      (((row.status.isIn(['pending', 'ready', 'retry'])) &
                              (row.nextAttemptAt.isNull() |
                                  row.nextAttemptAt.isSmallerOrEqualValue(
                                    now,
                                  ))) |
                          (row.status.equals('processing') &
                              row.updatedAt.isSmallerThanValue(staleLease))) &
                      row.attempts.isSmallerThanValue(5),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      if (job == null) return null;
      await (update(
        memoryExtractionJobs,
      )..where((row) => row.id.equals(job.id))).write(
        MemoryExtractionJobsCompanion(
          status: const Value('processing'),
          attempts: Value(job.attempts + 1),
          updatedAt: Value(now),
          lastErrorCode: const Value(null),
        ),
      );
      return job.copyWith(
        status: 'processing',
        attempts: job.attempts + 1,
        updatedAt: now,
      );
    });
  }

  Future<List<ChatMessage>> readExtractionWindow(
    MemoryExtractionJob job,
  ) async {
    final start =
        await (select(chatMessages)
              ..where(
                (row) =>
                    row.sessionId.equals(job.sessionId) &
                    row.turnId.equals(job.startTurnId),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    final end =
        await (select(chatMessages)
              ..where(
                (row) =>
                    row.sessionId.equals(job.sessionId) &
                    row.turnId.equals(job.endTurnId),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (start == null || end == null) return const [];
    return (select(chatMessages)
          ..where(
            (row) =>
                row.sessionId.equals(job.sessionId) &
                row.createdAt.isBetweenValues(start.createdAt, end.createdAt) &
                (row.status.like('final%') |
                    row.status.equals('safety_override')),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
          ..limit(8))
        .get();
  }

  Future<void> failMemoryExtractionJob(
    MemoryExtractionJob job, {
    required String errorCode,
    required bool retryable,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final terminal = !retryable || job.attempts >= 5;
    final delayMinutes = (1 << job.attempts.clamp(0, 5)).clamp(2, 32);
    await (update(
      memoryExtractionJobs,
    )..where((row) => row.id.equals(job.id))).write(
      MemoryExtractionJobsCompanion(
        status: Value(terminal ? 'dead' : 'retry'),
        lastErrorCode: Value(_truncateMemoryText(errorCode, 100)),
        nextAttemptAt: terminal
            ? const Value(null)
            : Value(now + Duration(minutes: delayMinutes).inMilliseconds),
        updatedAt: Value(now),
      ),
    );
  }

  /// Applies one `memory_judge_v1` decision batch in a single transaction:
  /// validate each decision, resolve the local target, mutate/supersede,
  /// update the active state projection, and append the idempotent
  /// decision-operation ledger row. A replayed decision ID is a no-op and
  /// never re-creates claims or user notices.
  Future<MemoryJudgeApplyResult> applyMemoryJudgeDecisions({
    required MemoryExtractionJob job,
    required List<MemoryJudgeDecision> decisions,
    required MemoryJudgeCost cost,
    required int windowTurnCount,
  }) async {
    var appliedCount = 0;
    var supersededCount = 0;
    var rejectedCount = 0;
    var duplicateCount = 0;
    final appliedSourceTurnIds = <String>{};
    await transaction(() async {
      final evidence = await readExtractionWindow(job);
      final byTurn = <String, List<ChatMessage>>{};
      for (final row in evidence) {
        byTurn.putIfAbsent(row.turnId, () => []).add(row);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final decision in decisions.take(16)) {
        final replayed = await customSelect(
          'SELECT decision_id FROM memory_judge_operations WHERE decision_id = ?',
          variables: [Variable.withString(decision.decisionId)],
        ).getSingleOrNull();
        if (replayed != null) {
          duplicateCount += 1;
          continue;
        }
        final candidate = decision.proposal;
        final fingerprint = _candidateFingerprint(candidate);
        // Targets are always resolved locally from normalized content; a
        // model-supplied database ID is never trusted or even representable.
        final targetId = 'memory_llm_$fingerprint';
        final prior =
            await (select(memoryCandidates)..where(
                  (row) =>
                      row.candidateKind.equals(candidate.kind) &
                      row.subject.equals(candidate.subject) &
                      row.predicate.equals(candidate.predicate) &
                      row.objectText.equals(candidate.objectText) &
                      row.jobId.isNotValue(job.id) &
                      row.decisionState.isIn(['admitted', 'confirmed']),
                ))
                .get();
        final supersessionTargets =
            await (select(memoryCandidates)..where(
                  (row) =>
                      row.candidateKind.equals(candidate.kind) &
                      row.subject.equals(candidate.subject) &
                      row.predicate.equals(candidate.predicate) &
                      row.objectText.isNotValue(candidate.objectText) &
                      row.targetMemoryId.isNotNull() &
                      row.decisionState.isIn(['admitted', 'confirmed']),
                ))
                .get();
        final exactTarget = await (select(
          memoryRecords,
        )..where((row) => row.id.equals(targetId))).getSingleOrNull();
        final verdict = _validateJudgeDecision(
          decision,
          byTurn,
          prior.length,
          hasSupersessionTarget: supersessionTargets.isNotEmpty,
          hasExactTarget: exactTarget != null,
        );
        await into(memoryCandidates).insertOnConflictUpdate(
          MemoryCandidatesCompanion.insert(
            id: decision.decisionId,
            jobId: job.id,
            candidateKind: candidate.kind,
            subject: candidate.subject,
            predicate: candidate.predicate,
            objectText: candidate.objectText,
            eventStartAt: Value(candidate.eventStartAt),
            eventEndAt: Value(candidate.eventEndAt),
            temporalStatus: candidate.temporalStatus,
            explicitness: candidate.explicitness,
            confidenceScore: candidate.confidence,
            futureUtility: candidate.futureUtility,
            sensitivity: candidate.sensitivity,
            sourceTurnIdsJson: jsonEncode(candidate.sourceTurnIds),
            evidenceRole: candidate.evidenceRole,
            suggestedAction: decision.action,
            followUpAllowed: Value(candidate.followUpAllowed),
            proactiveAllowed: Value(candidate.proactiveAllowed),
            decisionState: verdict.state,
            decisionReason: verdict.reason,
            targetMemoryId: verdict.admit ? Value(targetId) : const Value(null),
            createdAt: now,
          ),
        );
        _logMemoryDiagnostic('memory_judge_decision', {
          'job_id': job.id,
          'decision_id': decision.decisionId,
          'action': decision.action,
          'candidate_kind': candidate.kind,
          'decision_state': verdict.state,
          'decision_reason': verdict.reason,
        });
        String? resultClaimId;
        if (verdict.admit) {
          appliedCount += 1;
          if (decision.action == 'supersede') {
            supersededCount += 1;
          }
          appliedSourceTurnIds.addAll(candidate.sourceTurnIds);
          if (candidate.kind == 'profile') {
            resultClaimId = await _applyLlmJudgedProfileClaim(
              candidate: candidate,
              now: now,
            );
            if (resultClaimId != null &&
                await _profileClaimSuperseded(resultClaimId)) {
              supersededCount += 1;
            }
          } else {
            resultClaimId = targetId;
            await _applyValidatedCandidate(
              candidate: candidate,
              action: decision.action,
              job: job,
              memoryId: targetId,
              now: now,
            );
          }
        } else {
          rejectedCount += 1;
        }
        await customStatement(
          'INSERT OR IGNORE INTO memory_judge_operations ('
          'decision_id, job_id, session_id, turn_id, action, outcome, reason, '
          'result_claim_id, window_turn_count, attempt_count, cost_source, '
          'input_tokens, output_tokens, estimated_micro_inr, created_at'
          ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            decision.decisionId,
            job.id,
            job.sessionId,
            job.endTurnId,
            decision.action,
            verdict.admit
                ? (decision.action == 'supersede' ? 'superseded' : 'applied')
                : 'rejected',
            verdict.reason,
            resultClaimId,
            windowTurnCount,
            job.attempts,
            cost.source,
            cost.inputTokens,
            cost.outputTokens,
            cost.estimatedMicroInr,
            now,
          ],
        );
      }
      await (update(
        memoryExtractionJobs,
      )..where((row) => row.id.equals(job.id))).write(
        MemoryExtractionJobsCompanion(
          status: const Value('succeeded'),
          completedAt: Value(now),
          updatedAt: Value(now),
          nextAttemptAt: const Value(null),
        ),
      );
    });
    return MemoryJudgeApplyResult(
      appliedCount: appliedCount,
      supersededCount: supersededCount,
      rejectedCount: rejectedCount,
      duplicateCount: duplicateCount,
      appliedSourceTurnIds: appliedSourceTurnIds,
    );
  }

  Future<bool> _profileClaimSuperseded(String claimId) async {
    final row = await customSelect(
      'SELECT supersedes_claim_id FROM memory_claims WHERE id = ?',
      variables: [Variable.withString(claimId)],
    ).getSingleOrNull();
    return row?.data['supersedes_claim_id'] is String;
  }

  Future<String?> _applyLlmJudgedProfileClaim({
    required ExtractedMemoryCandidate candidate,
    required int now,
  }) async {
    const stateKey = 'user.profile.preferred_name';
    final previous = await customSelect(
      'SELECT id FROM memory_claims WHERE state_key = ? AND claim_state = ? '
      'ORDER BY updated_at DESC LIMIT 1',
      variables: [
        Variable.withString(stateKey),
        Variable.withString('current'),
      ],
    ).getSingleOrNull();
    final claimId = 'llm_claim_${_candidateFingerprint(candidate)}';
    if (previous?.data['id'] == claimId) return claimId;
    if (previous?.data['id'] is String) {
      await customStatement(
        'UPDATE memory_claims SET claim_state = ?, updated_at = ? WHERE id = ?',
        ['superseded', now, previous!.data['id']],
      );
    }
    await customStatement(
      '''INSERT OR REPLACE INTO memory_claims (
        id, state_key, subject, predicate, value_json, cardinality, category,
        assertion_kind, claim_state, source_turn_ids_json, transcript_status,
        transcript_quality, stt_confidence, provider_metadata_json,
        extraction_version, confirmation_state, supersedes_claim_id,
        created_at, updated_at, confirmed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        claimId,
        stateKey,
        'user',
        'preferred_name',
        jsonEncode({'text': candidate.objectText}),
        'single',
        'profile',
        'llm_judged',
        'current',
        jsonEncode(candidate.sourceTurnIds),
        'validated_completed_turn',
        'llm_judged',
        null,
        '{}',
        'llm_judge_v1',
        'implicit',
        previous?.data['id'],
        now,
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
        claimId,
        jsonEncode({'text': candidate.objectText}),
        'profile',
        now,
      ],
    );
    return claimId;
  }

  Future<void> _applyValidatedCandidate({
    required ExtractedMemoryCandidate candidate,
    required String action,
    required MemoryExtractionJob job,
    required String memoryId,
    required int now,
  }) async {
    if (candidate.suggestedAction == 'EXPIRE') {
      await (update(
        memoryRecords,
      )..where((row) => row.id.equals(memoryId))).write(
        MemoryRecordsCompanion(
          temporalStatus: const Value('expired'),
          updatedAt: Value(now),
          replacementReason: const Value('explicit_user_expiration'),
        ),
      );
      await (update(
        memoryOpenThreads,
      )..where((row) => row.id.equals(memoryId))).write(
        MemoryOpenThreadsCompanion(
          status: const Value('cancelled'),
          closedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    final existing = await (select(
      memoryRecords,
    )..where((row) => row.id.equals(memoryId))).getSingleOrNull();
    final sources = <String>{
      if (existing != null) ..._decodeStringList(existing.sourceTurnIdsJson),
      ...candidate.sourceTurnIds,
    }.toList();
    final content = _candidateContent(candidate);
    await into(memoryRecords).insertOnConflictUpdate(
      MemoryRecordsCompanion.insert(
        id: memoryId,
        kind: candidate.kind == 'episode'
            ? 'episodic'
            : candidate.kind == 'open_thread' ||
                  candidate.kind == 'assistant_commitment'
            ? 'episodic'
            : 'semantic',
        label: 'llm_${candidate.kind}_${_safeMemoryToken(candidate.predicate)}',
        content: content,
        originalText: const Value(''),
        canonicalText: Value(
          _canonicalMemoryText('${candidate.predicate} $content'),
        ),
        language: const Value('und'),
        script: const Value('mixed'),
        sourceTurnIdsJson: jsonEncode(sources),
        sourceRole: candidate.evidenceRole,
        transcriptStatus: 'validated_completed_turn',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        confidenceScore: existing == null
            ? candidate.confidence
            : (existing.confidenceScore + 0.05).clamp(0.0, 0.98),
        importanceScore: (0.35 + candidate.futureUtility * 0.55).clamp(
          0.0,
          0.9,
        ),
        recurrenceCount: Value((existing?.recurrenceCount ?? 0) + 1),
        sensitivity: const Value('normal'),
        temporalStatus: Value(candidate.temporalStatus),
        receiptState: const Value('implicit'),
        supersededBy: const Value(null),
        evidenceSummary: Value(
          candidate.kind == 'assistant_commitment'
              ? 'Remembered from the assistant’s explicit commitment.'
              : 'Remembered from your ${candidate.explicitness} statement.',
        ),
      ),
    );
    if (action == 'supersede') {
      await _supersedePriorLlmSemanticMemories(
        candidate: candidate,
        newMemoryId: memoryId,
        now: now,
      );
    }
    if (candidate.kind == 'episode') {
      await into(memoryEpisodes).insertOnConflictUpdate(
        MemoryEpisodesCompanion.insert(
          id: memoryId,
          sessionId: job.sessionId,
          title: _truncateMemoryText(candidate.objectText, 80),
          summary: candidate.objectText,
          retrievalText: content,
          sourceTurnIdsJson: jsonEncode(candidate.sourceTurnIds),
          eventStartAt: Value(candidate.eventStartAt),
          eventEndAt: Value(candidate.eventEndAt),
          temporalStatus: Value(candidate.temporalStatus),
          explicitness: Value(candidate.explicitness),
          confidenceScore: candidate.confidence,
          importanceScore: candidate.futureUtility,
          sensitivity: const Value('normal'),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
    if (candidate.kind == 'open_thread' ||
        candidate.kind == 'assistant_commitment') {
      await into(memoryOpenThreads).insertOnConflictUpdate(
        MemoryOpenThreadsCompanion.insert(
          id: memoryId,
          kind: candidate.kind,
          subject: candidate.subject,
          predicate: candidate.predicate,
          objectText: candidate.objectText,
          dueStartAt: Value(candidate.eventStartAt),
          dueEndAt: Value(candidate.eventEndAt),
          followUpAllowed: Value(candidate.followUpAllowed),
          proactiveAllowed: Value(
            candidate.proactiveAllowed && candidate.followUpAllowed,
          ),
          sourceTurnIdsJson: jsonEncode(candidate.sourceTurnIds),
          confidenceScore: candidate.confidence,
          sensitivity: const Value('normal'),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> _supersedePriorLlmSemanticMemories({
    required ExtractedMemoryCandidate candidate,
    required String newMemoryId,
    required int now,
  }) async {
    final priorCandidates =
        await (select(memoryCandidates)..where(
              (row) =>
                  row.candidateKind.equals(candidate.kind) &
                  row.subject.equals(candidate.subject) &
                  row.predicate.equals(candidate.predicate) &
                  row.objectText.isNotValue(candidate.objectText) &
                  row.targetMemoryId.isNotNull() &
                  row.decisionState.isIn(['admitted', 'confirmed']),
            ))
            .get();
    final priorIds = priorCandidates
        .map((row) => row.targetMemoryId)
        .whereType<String>()
        .where((id) => id != newMemoryId)
        .toSet();
    for (final oldMemoryId in priorIds) {
      final oldMemory = await (select(
        memoryRecords,
      )..where((row) => row.id.equals(oldMemoryId))).getSingleOrNull();
      if (oldMemory == null || oldMemory.supersededBy != null) continue;
      await (update(
        memoryRecords,
      )..where((row) => row.id.equals(oldMemoryId))).write(
        MemoryRecordsCompanion(
          temporalStatus: const Value('past'),
          supersededBy: Value(newMemoryId),
          replacementReason: const Value('explicit_llm_semantic_supersession'),
          updatedAt: Value(now),
        ),
      );
      await into(memoryContradictions).insertOnConflictUpdate(
        MemoryContradictionsCompanion.insert(
          id: 'contradiction_${_stableMemoryHash('$oldMemoryId|$newMemoryId')}',
          oldMemoryId: oldMemoryId,
          newMemoryId: newMemoryId,
          reason: 'explicit_llm_semantic_supersession',
          evidenceTurnIdsJson: Value(jsonEncode(candidate.sourceTurnIds)),
          createdAt: now,
        ),
      );
    }
  }

  Future<void> consolidateLocalMemory({int? nowMs}) async {
    await transaction(() async {
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      await _applyMemoryDecay(now);
      await _consolidateOpenThreads(now);
      await _pruneExtractionAudit(now);
    });
  }

  Future<void> _consolidateOpenThreads(int now) async {
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    final threads = await (select(
      memoryOpenThreads,
    )..where((row) => row.status.equals('open'))).get();
    for (final thread in threads) {
      final due = thread.dueEndAt ?? thread.dueStartAt;
      if (due == null) {
        if (now - thread.createdAt <= thirtyDaysMs) continue;
        await (update(
          memoryOpenThreads,
        )..where((row) => row.id.equals(thread.id))).write(
          MemoryOpenThreadsCompanion(
            status: const Value('closed'),
            closedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await (update(
          memoryRecords,
        )..where((row) => row.id.equals(thread.id))).write(
          MemoryRecordsCompanion(
            temporalStatus: const Value('stale'),
            updatedAt: Value(now),
          ),
        );
        continue;
      }
      if (due >= now) continue;
      if (now - due <= thirtyDaysMs) {
        await (update(
          memoryRecords,
        )..where((row) => row.id.equals(thread.id))).write(
          MemoryRecordsCompanion(
            temporalStatus: const Value('past'),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (update(
          memoryOpenThreads,
        )..where((row) => row.id.equals(thread.id))).write(
          MemoryOpenThreadsCompanion(
            status: const Value('closed'),
            closedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await (update(
          memoryRecords,
        )..where((row) => row.id.equals(thread.id))).write(
          MemoryRecordsCompanion(
            temporalStatus: const Value('stale'),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  Future<void> _pruneExtractionAudit(int now) async {
    const ninetyDaysMs = 90 * 24 * 60 * 60 * 1000;
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    await (delete(memoryCandidates)..where(
          (row) =>
              row.decisionState.equals('rejected') &
              row.createdAt.isSmallerThanValue(now - ninetyDaysMs),
        ))
        .go();
    await (delete(memoryExtractionJobs)..where(
          (row) =>
              row.status.equals('succeeded') &
              row.updatedAt.isSmallerThanValue(now - thirtyDaysMs),
        ))
        .go();
  }

  Future<List<MemoryRecord>> readPendingMemoryReceipts({required int limit}) {
    final minPromptSpacingMs =
        DateTime.now().millisecondsSinceEpoch -
        const Duration(minutes: 15).inMilliseconds;
    return (select(memoryRecords)
          ..where(
            (row) =>
                row.supersededBy.isNull() &
                row.sensitivity.equals('normal') &
                row.receiptState.equals('unconfirmed') &
                row.temporalStatus.isNotIn(['expired', 'stale']) &
                (row.receiptPromptedAt.isNull() |
                    row.receiptPromptedAt.isSmallerThanValue(
                      minPromptSpacingMs,
                    )) &
                row.importanceScore.isBiggerOrEqualValue(0.6),
          )
          ..orderBy([
            (row) => OrderingTerm.desc(row.importanceScore),
            (row) => OrderingTerm.desc(row.updatedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> markMemoryReceiptPrompted({
    required String memoryId,
    required int promptedAt,
  }) {
    _logMemoryDiagnostic('memory_receipt_prompted', {'memory_id': memoryId});
    return (update(memoryRecords)..where((row) => row.id.equals(memoryId)))
        .write(MemoryRecordsCompanion(receiptPromptedAt: Value(promptedAt)));
  }

  Future<Map<String, Object?>> readMemoryDiagnosticsSnapshot() async {
    final memories = await select(memoryRecords).get();
    final entities = await select(memoryEntities).get();
    final edges = await select(memoryEdges).get();
    final contradictions = await select(memoryContradictions).get();
    final byKind = <String, int>{};
    final byLabel = <String, int>{};
    final byReceipt = <String, int>{};
    final byTemporal = <String, int>{};
    for (final memory in memories) {
      byKind.update(memory.kind, (count) => count + 1, ifAbsent: () => 1);
      byLabel.update(memory.label, (count) => count + 1, ifAbsent: () => 1);
      byReceipt.update(
        memory.receiptState,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      byTemporal.update(
        memory.temporalStatus,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final snapshot = {
      'memory_count': memories.length,
      'entity_count': entities.length,
      'edge_count': edges.length,
      'contradiction_count': contradictions.length,
      'by_kind': byKind,
      'by_label': byLabel,
      'by_receipt': byReceipt,
      'by_temporal': byTemporal,
      'memory_ids': [for (final memory in memories) memory.id],
    };
    _logMemoryDiagnostic('memory_diagnostics_snapshot', snapshot);
    return snapshot;
  }

  Future<void> _admitStableFacts(ChatMessage message) async {
    if (!_eligibleForMemory(message) || message.role != 'user') {
      return;
    }
    final receiptDecision = _classifyMemoryReceiptReply(message.messageText);
    if (receiptDecision != _MemoryReceiptDecision.none) {
      await _applyMemoryReceiptReply(message);
      return;
    }
    await _upsertGraphSignals(message);
    for (final candidate in _extractStableFactCandidates(message.messageText)) {
      final id = _memoryRecordId(candidate);
      final existing = await (select(
        memoryRecords,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      final now = message.createdAt;
      final sourceTurnIds = existing == null
          ? [message.turnId]
          : {
              ..._decodeStringList(existing.sourceTurnIdsJson),
              message.turnId,
            }.toList();
      if (existing != null &&
          !_shouldReplaceStableFact(
            existing: existing,
            candidate: candidate,
            message: message,
          )) {
        continue;
      }
      final replacementReason = existing != null
          ? _replacementReason(existing: existing, candidate: candidate)
          : null;
      if (existing != null && replacementReason != null) {
        await into(memoryContradictions).insertOnConflictUpdate(
          MemoryContradictionsCompanion.insert(
            id: 'contradiction_${existing.id}_${message.turnId}',
            oldMemoryId: existing.id,
            newMemoryId: id,
            reason: replacementReason,
            evidenceTurnIdsJson: Value(jsonEncode(sourceTurnIds)),
            createdAt: now,
          ),
        );
      }
      await into(memoryRecords).insertOnConflictUpdate(
        MemoryRecordsCompanion.insert(
          id: id,
          kind: candidate.memoryType,
          label: candidate.label,
          content: candidate.content,
          originalText: Value(message.messageText),
          canonicalText: Value(_canonicalMemoryText(candidate.content)),
          language: Value(message.language),
          script: Value(_detectScript(message.messageText)),
          sourceTurnIdsJson: jsonEncode(sourceTurnIds),
          sourceRole: 'user',
          transcriptStatus: message.status,
          sttConfidence: Value(message.sttConfidence),
          createdAt: existing == null ? now : existing.createdAt,
          updatedAt: now,
          confidenceScore: existing == null
              ? candidate.confidence
              : (existing.confidenceScore + 0.08).clamp(0.0, 0.98),
          importanceScore: existing == null
              ? candidate.importance
              : (existing.importanceScore + 0.05).clamp(0.0, 0.95),
          recurrenceCount: Value((existing?.recurrenceCount ?? 0) + 1),
          sensitivity: const Value('normal'),
          temporalStatus: const Value('current'),
          receiptState: const Value('implicit'),
          supersededBy: const Value(null),
          replacementReason: Value(replacementReason),
          evidenceSummary: Value(candidate.evidenceSummary),
        ),
      );
      _logMemoryDiagnostic('memory_admitted', {
        'memory_id': id,
        'kind': candidate.memoryType,
        'label': candidate.label,
        'receipt_state': 'implicit',
        'replacement': replacementReason != null,
      });
    }
    await _admitCompanionContextMemories(message);
  }

  Future<void> _upsertSessionSummary(
    ChatMessage user,
    ChatMessage assistant,
  ) async {
    final userText = _cleanMemoryText(user.messageText, maxChars: 160);
    final assistantText = _cleanMemoryText(
      assistant.messageText,
      maxChars: 160,
    );
    if (userText.isEmpty ||
        assistantText.isEmpty ||
        _containsSensitiveMemoryBlocker(userText.toLowerCase()) ||
        _containsSensitiveMemoryBlocker(assistantText.toLowerCase())) {
      return;
    }
    final now = assistant.createdAt;
    await into(memoryRecords).insertOnConflictUpdate(
      MemoryRecordsCompanion.insert(
        id: 'summary_${user.sessionId}_${user.turnId}',
        kind: 'session_summary',
        label: 'previous_session',
        content: 'User: $userText\nAssistant: $assistantText',
        originalText: Value(
          'User: ${user.messageText}\nAssistant: ${assistant.messageText}',
        ),
        canonicalText: Value(_canonicalMemoryText('$userText $assistantText')),
        language: Value(user.language),
        script: Value(
          _detectScript('${user.messageText} ${assistant.messageText}'),
        ),
        sourceTurnIdsJson: jsonEncode([user.turnId]),
        sourceRole: 'mixed',
        transcriptStatus: '${user.status}+${assistant.status}',
        sttConfidence: Value(user.sttConfidence),
        createdAt: user.createdAt,
        updatedAt: now,
        confidenceScore: 0.62,
        importanceScore: 0.35,
        recurrenceCount: const Value(1),
        sensitivity: const Value('normal'),
        temporalStatus: const Value('past'),
        receiptState: const Value('implicit'),
        supersededBy: const Value(null),
        evidenceSummary: Value('Completed local session turn ${user.turnId}.'),
      ),
    );
    await _pruneSessionSummaries(keep: 4);
  }

  Future<void> _pruneSessionSummaries({required int keep}) async {
    final summaries =
        await (select(memoryRecords)
              ..where((row) => row.kind.equals('session_summary'))
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();
    for (final summary in summaries.skip(keep)) {
      await (delete(
        memoryRecords,
      )..where((row) => row.id.equals(summary.id))).go();
    }
  }

  Future<List<_RankedMemory>> _graphExpandedMemories(
    String latestUserText,
    _MemoryQueryIntent intent,
  ) async {
    final queryEntities = _extractMemoryEntities(latestUserText);
    if (queryEntities.isEmpty || _isGreetingOnly(latestUserText)) {
      return const [];
    }
    final entityIds = queryEntities.map((entity) => entity.id).toSet();
    final edges =
        await (select(memoryEdges)..where(
              (edge) =>
                  edge.sourceEntityId.isIn(entityIds) |
                  edge.targetEntityId.isIn(entityIds),
            ))
            .get();
    if (edges.isEmpty) {
      return const [];
    }
    final relatedEntityIds = <String>{
      for (final edge in edges) edge.sourceEntityId,
      for (final edge in edges) edge.targetEntityId,
    };
    final relatedTerms = relatedEntityIds
        .map((id) => id.replaceFirst('entity_', '').replaceAll('_', ' '))
        .toSet();
    final rows =
        await (select(memoryRecords)..where(
              (row) =>
                  row.supersededBy.isNull() &
                  (row.temporalStatus.equals('current') |
                      row.temporalStatus.equals('past') |
                      row.temporalStatus.equals('uncertain')) &
                  row.sensitivity.equals('normal'),
            ))
            .get();
    return [
      for (final row in rows)
        if (_memoryAllowedForRetrieval(row, latestUserText) &&
            (intent == _MemoryQueryIntent.general ||
                _intentAllowsMemory(row, intent)) &&
            relatedTerms.any(
              (term) =>
                  row.canonicalText.contains(term) ||
                  row.content.toLowerCase().contains(term),
            ))
          _RankedMemory(row, _memoryRank(row, latestUserText, intent) + 0.65),
    ];
  }

  Future<List<_RankedMemory>> _openThreadExpandedMemories(
    String latestUserText,
    _MemoryQueryIntent intent,
    String? route,
  ) async {
    final normalized = _normalizeForMemory(latestUserText);
    final vagueFollowUp =
        route == 'episodic' ||
        _containsAny(normalized, [
          'kaisa raha',
          'kaisi rahi',
          'how did it go',
          'what happened',
          'uska kya hua',
          'उसका क्या हुआ',
          'कैसा रहा',
          'कैसी रही',
        ]);
    if (!vagueFollowUp) return const [];
    final threads =
        await (select(memoryOpenThreads)
              ..where(
                (row) =>
                    row.status.equals('open') &
                    row.sensitivity.equals('normal'),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.dueStartAt),
                (row) => OrderingTerm.desc(row.updatedAt),
              ])
              ..limit(4))
            .get();
    if (threads.isEmpty) return const [];
    final ids = threads.map((thread) => thread.id).toList();
    final rows =
        await (select(memoryRecords)..where(
              (row) =>
                  row.id.isIn(ids) &
                  row.supersededBy.isNull() &
                  row.temporalStatus.isNotIn(['expired', 'stale']),
            ))
            .get();
    return [
      for (final row in rows)
        if (_memoryAllowedForRetrieval(row, latestUserText))
          _RankedMemory(row, _memoryRank(row, latestUserText, intent) + 1.1),
    ];
  }

  Future<void> _admitCompanionContextMemories(ChatMessage message) async {
    final normalized = _normalizeForMemory(message.messageText);
    if (!_looksWorkStressRelated(normalized)) {
      return;
    }
    final now = message.createdAt;
    const id = 'memory_semantic_work_stress_manager';
    final existing = await (select(
      memoryRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing?.receiptState == 'rejected') {
      return;
    }
    final sourceTurnIds = existing == null
        ? [message.turnId]
        : {
            ..._decodeStringList(existing.sourceTurnIdsJson),
            message.turnId,
          }.toList();
    await into(memoryRecords).insertOnConflictUpdate(
      MemoryRecordsCompanion.insert(
        id: id,
        kind: 'semantic',
        label: 'recurring_work_stressor',
        content:
            'User has previously mentioned work stress related to office or manager pressure.',
        originalText: Value(message.messageText),
        canonicalText: const Value('work stress office manager pressure'),
        language: Value(message.language),
        script: Value(_detectScript(message.messageText)),
        sourceTurnIdsJson: jsonEncode(sourceTurnIds),
        sourceRole: 'user',
        transcriptStatus: message.status,
        sttConfidence: Value(message.sttConfidence),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        confidenceScore: existing == null
            ? 0.68
            : (existing.confidenceScore + 0.06).clamp(0.0, 0.95),
        importanceScore: existing == null
            ? 0.72
            : (existing.importanceScore + 0.04).clamp(0.0, 0.95),
        recurrenceCount: Value((existing?.recurrenceCount ?? 0) + 1),
        sensitivity: const Value('normal'),
        temporalStatus: const Value('current'),
        // This deterministic, locally-grounded signal is usable immediately.
        // The voice flow never asks the user to confirm a memory.
        receiptState: const Value('implicit'),
        supersededBy: const Value(null),
        evidenceSummary: const Value(
          'Recurring work/office stress signal from local turns.',
        ),
      ),
    );
  }

  Future<void> _upsertGraphSignals(ChatMessage message) async {
    final entities = _extractMemoryEntities(message.messageText);
    for (final entity in entities) {
      await _upsertEntity(entity, message);
    }
    final entityIds = entities.map((entity) => entity.id).toSet();
    Future<void> edge(String source, String relation, String target) async {
      if (!entityIds.contains(source) || !entityIds.contains(target)) {
        return;
      }
      await _upsertEdge(
        sourceEntityId: source,
        relation: relation,
        targetEntityId: target,
        message: message,
        polarity: relation == 'causes_stress' ? 'negative' : 'neutral',
      );
    }

    await edge('entity_office', 'related_to', 'entity_work');
    await edge('entity_manager', 'works_at_context', 'entity_office');
    await edge('entity_manager', 'causes_stress', 'entity_work_stress');
    await edge('entity_office', 'recurs_with', 'entity_work_stress');
    await edge('entity_family', 'related_to', 'entity_relationships');
    await edge('entity_relationships', 'related_to', 'entity_comfort_style');
    await edge('entity_routine', 'recurs_with', 'entity_ritual');
    await edge('entity_goal', 'related_to', 'entity_routine');
    await edge('entity_boundary', 'has_boundary', 'entity_taboo_topic');
    await edge('entity_comfort_style', 'prefers', 'entity_boundary');
    await edge('entity_recurring_stressor', 'causes_stress', 'entity_stress');
  }

  Future<void> _applyMemoryDecay(int nowMs) async {
    const dayMs = 24 * 60 * 60 * 1000;
    final rows =
        await (select(memoryRecords)..where(
              (row) =>
                  row.supersededBy.isNull() &
                  row.temporalStatus.isNotIn(['expired']),
            ))
            .get();
    var decayed = 0;
    var expired = 0;
    var agedEpisodic = 0;
    for (final row in rows) {
      final ageDays = ((nowMs - row.updatedAt) / dayMs).floor();
      if (ageDays < 14) {
        continue;
      }
      if (row.kind == 'core_profile' &&
          row.confidenceScore >= 0.85 &&
          row.receiptState == 'confirmed') {
        continue;
      }
      if (row.kind == 'episodic' && ageDays >= 30) {
        await (update(
          memoryRecords,
        )..where((record) => record.id.equals(row.id))).write(
          MemoryRecordsCompanion(
            kind: const Value('session_summary'),
            label: const Value('past_episodic_summary'),
            temporalStatus: const Value('past'),
            importanceScore: Value(
              (row.importanceScore - 0.08).clamp(0.25, 0.8),
            ),
            evidenceSummary: Value(
              row.evidenceSummary.isEmpty
                  ? 'Aged local episodic memory into a past summary.'
                  : '${row.evidenceSummary} Aged into a past summary.',
            ),
          ),
        );
        agedEpisodic += 1;
        continue;
      }
      if (row.importanceScore <= 0.45 || row.temporalStatus == 'stale') {
        final nextImportance = (row.importanceScore - 0.12).clamp(0.0, 1.0);
        final nextStatus = nextImportance < 0.25 || ageDays >= 90
            ? 'expired'
            : ageDays >= 30
            ? 'stale'
            : row.temporalStatus;
        await (update(
          memoryRecords,
        )..where((record) => record.id.equals(row.id))).write(
          MemoryRecordsCompanion(
            importanceScore: Value(nextImportance),
            temporalStatus: Value(nextStatus),
            evidenceSummary: Value(
              row.evidenceSummary.isEmpty
                  ? 'Decayed by local consolidation policy.'
                  : '${row.evidenceSummary} Decayed by local consolidation policy.',
            ),
          ),
        );
        decayed += 1;
        if (nextStatus == 'expired') {
          expired += 1;
        }
      }
    }
    _logMemoryDiagnostic('memory_consolidation_decay', {
      'record_count': rows.length,
      'decayed_count': decayed,
      'expired_count': expired,
      'aged_episodic_count': agedEpisodic,
    });
  }

  Future<bool> _applyMemoryReceiptReply(ChatMessage message) async {
    final decision = _classifyMemoryReceiptReply(message.messageText);
    // Positive acknowledgements must not be treated as permission to persist
    // an earlier ambiguous statement. An explicit negative remains a local
    // privacy control for the immediately preceding auto-admitted memory.
    if (decision != _MemoryReceiptDecision.reject) {
      return false;
    }
    final pending =
        await (select(memoryRecords)
              ..where(
                (row) =>
                    row.supersededBy.isNull() &
                    row.sensitivity.equals('normal') &
                    row.receiptState.isIn(['implicit', 'unconfirmed']) &
                    row.temporalStatus.isNotIn(['expired', 'stale']),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.importanceScore),
                (row) => OrderingTerm.desc(row.updatedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (pending == null ||
        _decodeStringList(pending.sourceTurnIdsJson).contains(message.turnId)) {
      return false;
    }
    final now = message.createdAt;
    final sourceTurnIds = {
      ..._decodeStringList(pending.sourceTurnIdsJson),
      message.turnId,
    }.toList();
    if (pending.id.startsWith('memory_llm_')) {
      await (delete(memoryContradictions)..where(
            (row) =>
                row.oldMemoryId.equals(pending.id) |
                row.newMemoryId.equals(pending.id),
          ))
          .go();
      await (delete(
        memoryCandidates,
      )..where((row) => row.targetMemoryId.equals(pending.id))).go();
      await (delete(
        memoryOpenThreads,
      )..where((row) => row.id.equals(pending.id))).go();
      await (delete(
        memoryEpisodes,
      )..where((row) => row.id.equals(pending.id))).go();
      await (delete(
        memoryRecords,
      )..where((row) => row.id.equals(pending.id))).go();
      _logMemoryDiagnostic('memory_receipt_result', {
        'memory_id': pending.id,
        'result': 'forgotten',
      });
      return true;
    }
    await (update(
      memoryRecords,
    )..where((row) => row.id.equals(pending.id))).write(
      MemoryRecordsCompanion(
        sourceTurnIdsJson: Value(jsonEncode(sourceTurnIds)),
        updatedAt: Value(now),
        confidenceScore: const Value(0.0),
        importanceScore: const Value(0.0),
        receiptState: const Value('rejected'),
        temporalStatus: const Value('expired'),
        replacementReason: const Value('explicit_memory_receipt_rejection'),
        evidenceSummary: Value(
          pending.evidenceSummary.isEmpty
              ? 'Rejected by explicit local voice receipt.'
              : '${pending.evidenceSummary} Rejected by explicit local voice receipt.',
        ),
      ),
    );
    _logMemoryDiagnostic('memory_receipt_result', {
      'memory_id': pending.id,
      'result': 'rejected',
    });
    return true;
  }

  Future<void> _upsertEntity(
    _MemoryEntityCandidate entity,
    ChatMessage message,
  ) async {
    final existing = await (select(
      memoryEntities,
    )..where((row) => row.id.equals(entity.id))).getSingleOrNull();
    await into(memoryEntities).insertOnConflictUpdate(
      MemoryEntitiesCompanion.insert(
        id: entity.id,
        kind: entity.kind,
        canonicalName: entity.canonicalName,
        aliasesJson: Value(jsonEncode(entity.aliases)),
        language: Value(message.language),
        sensitivity: const Value('normal'),
        firstSeenAt: existing?.firstSeenAt ?? message.createdAt,
        lastSeenAt: message.createdAt,
        confidenceScore: Value(
          existing == null
              ? entity.confidence
              : (existing.confidenceScore + 0.03).clamp(0.0, 0.95),
        ),
      ),
    );
  }

  Future<void> _upsertEdge({
    required String sourceEntityId,
    required String relation,
    required String targetEntityId,
    required ChatMessage message,
    required String polarity,
  }) async {
    final id = 'edge_${sourceEntityId}_${relation}_$targetEntityId';
    final existing = await (select(
      memoryEdges,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final evidenceTurnIds = existing == null
        ? [message.turnId]
        : {
            ..._decodeStringList(existing.evidenceTurnIdsJson),
            message.turnId,
          }.toList();
    await into(memoryEdges).insertOnConflictUpdate(
      MemoryEdgesCompanion.insert(
        id: id,
        sourceEntityId: sourceEntityId,
        relation: relation,
        targetEntityId: targetEntityId,
        evidenceTurnIdsJson: Value(jsonEncode(evidenceTurnIds)),
        confidenceScore: Value(
          existing == null
              ? 0.68
              : (existing.confidenceScore + 0.04).clamp(0.0, 0.96),
        ),
        frequency: Value((existing?.frequency ?? 0) + 1),
        polarity: Value(polarity),
        sensitivity: const Value('normal'),
        temporalStatus: const Value('current'),
        firstSeenAt: existing?.firstSeenAt ?? message.createdAt,
        lastSeenAt: message.createdAt,
      ),
    );
  }
}

class _MemoryEntityCandidate {
  const _MemoryEntityCandidate({
    required this.id,
    required this.kind,
    required this.canonicalName,
    required this.aliases,
    required this.confidence,
  });

  final String id;
  final String kind;
  final String canonicalName;
  final List<String> aliases;
  final double confidence;
}

class _StableFactCandidate {
  const _StableFactCandidate({
    required this.memoryType,
    required this.label,
    required this.content,
    required this.value,
    required this.confidence,
    required this.importance,
    this.idQualifier,
    this.evidenceSummary = '',
  });

  final String memoryType;
  final String label;
  final String content;
  final String value;
  final double confidence;
  final double importance;
  final String? idQualifier;
  final String evidenceSummary;
}

class _RankedMemory {
  const _RankedMemory(this.record, this.score);

  final MemoryRecord record;
  final double score;
}

enum _UtteranceType { statement, question, correction, unsafe }

enum _MemoryReceiptDecision { none, confirm, reject }

enum _MemoryQueryIntent {
  identityRecall,
  languageRecall,
  preferenceRecall,
  boundaryRecall,
  workStressRecall,
  general,
}

bool _eligibleForMemory(ChatMessage message) {
  final text = message.messageText.trim();
  if (text.length < 4 || text.length > 500) {
    return false;
  }
  if (message.status != 'final' && message.status != 'final_corrected') {
    return false;
  }
  final confidence = message.sttConfidence;
  if (confidence != null && confidence < 0.55) {
    return false;
  }
  final utteranceType = _classifyUtterance(text);
  if (utteranceType == _UtteranceType.unsafe) {
    return false;
  }
  final compactWords = _normalizeForMemory(text).split(RegExp(r'\s+'));
  return compactWords.toSet().length >= 3 || compactWords.length <= 5;
}

List<_StableFactCandidate> _extractStableFactCandidates(String text) {
  final cleaned = _cleanMemoryText(text, maxChars: 220);
  if (cleaned.isEmpty ||
      _containsSensitiveMemoryBlocker(cleaned.toLowerCase())) {
    return const [];
  }
  final candidates = <_StableFactCandidate>[];
  if (_isDeclarativeIdentityStatement(cleaned)) {
    final preferredName = _extractPreferredName(cleaned);
    if (preferredName != null) {
      candidates.add(
        _StableFactCandidate(
          memoryType: 'core_profile',
          label: 'preferred_name',
          content:
              'User prefers to be called ${_cleanMemoryText(preferredName, maxChars: 40)}.',
          value: preferredName,
          confidence: 0.8,
          importance: 0.9,
          evidenceSummary: 'Explicit preferred-name statement.',
        ),
      );
    }
  }
  if (_isDeclarativePreferenceStatement(cleaned)) {
    final preferenceValue = _extractPreferenceValue(cleaned);
    if (preferenceValue != null) {
      candidates.add(
        _StableFactCandidate(
          memoryType: 'semantic',
          label: 'safe_preference',
          content:
              'User explicitly said: ${_cleanMemoryText(preferenceValue, maxChars: 120)}',
          value: preferenceValue,
          confidence: 0.72,
          importance: 0.65,
          evidenceSummary: 'Explicit safe preference statement.',
        ),
      );
    }
    final languageStyle = _extractLanguageStyle(cleaned);
    if (languageStyle != null) {
      candidates.add(
        _StableFactCandidate(
          memoryType: 'procedural',
          label: 'language_style',
          content: 'User prefers $languageStyle replies.',
          value: languageStyle,
          confidence: 0.78,
          importance: 0.75,
          evidenceSummary: 'Explicit language-style preference.',
        ),
      );
    }
  }
  candidates.addAll(_extractRelationshipCandidates(cleaned));
  candidates.addAll(_extractRoutineCandidates(cleaned));
  candidates.addAll(_extractGoalCandidates(cleaned));
  candidates.addAll(_extractBoundaryCandidates(cleaned));
  candidates.addAll(_extractComfortStyleCandidates(cleaned));
  candidates.addAll(_extractRitualCandidates(cleaned));
  candidates.addAll(_extractTabooTopicCandidates(cleaned));
  candidates.addAll(_extractRecurringStressorCandidates(cleaned));
  return candidates;
}

bool _shouldReplaceStableFact({
  required MemoryRecord existing,
  required _StableFactCandidate candidate,
  required ChatMessage message,
}) {
  if (existing.label != candidate.label) {
    return true;
  }
  final utteranceType = _classifyUtterance(message.messageText);
  if (utteranceType == _UtteranceType.question ||
      utteranceType == _UtteranceType.unsafe) {
    return false;
  }
  final existingValue = _stableFactValue(existing);
  final candidateValue = candidate.value.toLowerCase();
  if (candidateValue == existingValue) {
    return true;
  }
  final confidence = message.sttConfidence ?? 0.0;
  return switch (existing.label) {
    'preferred_name' =>
      utteranceType == _UtteranceType.statement &&
          confidence >= 0.8 &&
          candidate.confidence >= existing.confidenceScore,
    'language_style' =>
      utteranceType != _UtteranceType.question &&
          confidence >= 0.7 &&
          candidate.confidence >= existing.confidenceScore - 0.05,
    'family_relationship' ||
    'routine' ||
    'goal' ||
    'boundary' ||
    'comfort_style' ||
    'ritual' ||
    'taboo_topic' ||
    'recurring_stressor' =>
      utteranceType != _UtteranceType.question &&
          confidence >= 0.72 &&
          (candidate.confidence >= existing.confidenceScore - 0.08 ||
              _looksLikeCorrection(_normalizeForMemory(message.messageText))),
    'safe_preference' =>
      (utteranceType == _UtteranceType.correction ||
              _isStrongPreferenceStatement(message.messageText)) &&
          confidence >= 0.75,
    _ => confidence >= 0.8 && candidate.confidence >= existing.confidenceScore,
  };
}

String _stableFactValue(MemoryRecord record) {
  if (record.label == 'preferred_name') {
    const prefix = 'User prefers to be called ';
    if (record.content.startsWith(prefix)) {
      return record.content
          .substring(prefix.length)
          .replaceAll('.', '')
          .trim()
          .toLowerCase();
    }
  }
  if (record.label == 'language_style') {
    const prefix = 'User prefers ';
    const suffix = ' replies.';
    if (record.content.startsWith(prefix) && record.content.endsWith(suffix)) {
      return record.content
          .substring(prefix.length, record.content.length - suffix.length)
          .trim()
          .toLowerCase();
    }
  }
  return record.content.trim().toLowerCase();
}

String _memoryRecordId(_StableFactCandidate candidate) {
  final qualifier = candidate.idQualifier;
  if (qualifier == null || qualifier.isEmpty) {
    return 'memory_${candidate.memoryType}_${candidate.label}';
  }
  return 'memory_${candidate.memoryType}_${candidate.label}_$qualifier';
}

String? _memoryIdToken(String value) {
  final canonical = _canonicalMemoryText(value)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (canonical.isEmpty || canonical.length > 48) {
    return null;
  }
  return canonical;
}

String? _topicQualifier(String normalized, List<String> tokens) {
  for (final token in tokens) {
    if (normalized.contains(token)) {
      return _memoryIdToken(token);
    }
  }
  return null;
}

String? _extractPreferredName(String text) {
  final patterns = <RegExp>[
    RegExp(
      r'(?:^|\b)(?:mera naam|my name is)\s+([A-Za-z\u0900-\u097F]{2,32})(?:(?:\s+(?:hai|hu|hoon))|\b)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|\b)(?:मेरा नाम|मेरा नाम है)\s+([A-Za-z\u0900-\u097F]{2,32})(?:(?:\s+(?:है|हूं|हूँ))|\b)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|\b)(?:mujhe|call me)\s+([A-Za-z\u0900-\u097F]{2,32})\s+(?:bulao|bolna|call karo)(?:\b|[.!?]|$)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|\b)(?:मुझे)\s+([A-Za-z\u0900-\u097F]{2,32})\s+(?:बुलाओ|कहना)(?:\b|[.!?]|$)',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final value = pattern.firstMatch(text)?.group(1)?.trim();
    if (value == null || value.isEmpty || _isQuestionToken(value)) {
      continue;
    }
    return value;
  }
  return null;
}

String? _extractPreferenceValue(String text) {
  final patterns = <RegExp>[
    RegExp(
      r'(?:\b(?:mujhe|i like|i prefer)\s+|(?:मुझे)\s+)(.{2,80}?)(?:pasand hai|achha lagta hai|पसंद है)',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final value = pattern.firstMatch(text)?.group(1)?.trim();
    if (value != null &&
        value.isNotEmpty &&
        !_isQuestionLikeMemoryTurn(value)) {
      return value;
    }
  }
  return null;
}

String? _extractLanguageStyle(String text) {
  final normalized = text.toLowerCase();
  if (normalized.contains('hinglish')) {
    return 'Hinglish';
  }
  if (normalized.contains('english') || normalized.contains('इंग्लिश')) {
    return 'English';
  }
  if (normalized.contains('hindi') || normalized.contains('हिंदी')) {
    return 'Hindi';
  }
  return null;
}

List<_StableFactCandidate> _extractRelationshipCandidates(String text) {
  final patterns = [
    RegExp(
      r'(?:meri|mera|my)\s+(behen|bahan|bhai|sister|brother|wife|husband|partner|maa|mummy|papa)\s+(?:ka naam\s+)?(?:is\s+)?([A-Za-z\u0900-\u097F]{2,32})(?:\s+(?:hai|है))?',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:मेरी|मेरा)\s+(माँ|मां|मम्मी|पापा|भाई|बहन|पत्नी|पति|साथी)\s+(?:का नाम\s+)?([A-Za-z\u0900-\u097F]{2,32})(?:\s+है)?',
      caseSensitive: false,
    ),
  ];
  RegExpMatch? match;
  for (final pattern in patterns) {
    match = pattern.firstMatch(text);
    if (match != null) {
      break;
    }
  }
  final relation = match?.group(1);
  final name = match?.group(2);
  if (relation == null || name == null || _isQuestionToken(name)) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'family_relationship',
      content:
          'User mentioned $relation named ${_cleanMemoryText(name, maxChars: 40)}.',
      value: '$relation:$name',
      confidence: 0.7,
      importance: 0.62,
      idQualifier: _memoryIdToken(relation),
      evidenceSummary: 'Explicit family or relationship statement.',
    ),
  ];
}

List<_StableFactCandidate> _extractRoutineCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (!_containsAny(normalized, [
    'roz',
    'daily',
    'har din',
    'every day',
    'subah',
    'shaam',
    'morning',
    'evening',
    'रोज',
    'हर दिन',
    'सुबह',
    'शाम',
  ])) {
    return const [];
  }
  if (!_containsAny(normalized, [
    'walk',
    'gym',
    'chai',
    'study',
    'meditation',
    'journal',
    'padhna',
    'पढ़',
    'चाय',
    'टहल',
    'ध्यान',
  ])) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'routine',
      content:
          'User described a routine: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.68,
      importance: 0.58,
      idQualifier: _topicQualifier(normalized, [
        'walk',
        'gym',
        'chai',
        'study',
        'meditation',
        'journal',
        'padhna',
        'पढ़',
        'चाय',
        'टहल',
        'ध्यान',
      ]),
      evidenceSummary: 'Explicit routine statement.',
    ),
  ];
}

List<_StableFactCandidate> _extractGoalCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (_isQuestionLikeMemoryTurn(normalized) ||
      _containsAny(normalized, ['shayad', 'maybe', 'sochne chahiye'])) {
    return const [];
  }
  if (!_containsAny(normalized, [
    'goal',
    'target',
    'chahta hoon',
    'chahti hoon',
    'karna hai',
    'seekhna hai',
    'banana hai',
    'improve karna',
    'लक्ष्य',
    'करना है',
    'सीखना है',
    'बनना है',
  ])) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'goal',
      content: 'User stated a goal: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.66,
      importance: 0.68,
      idQualifier: _topicQualifier(normalized, [
        'fitness',
        'health',
        'english',
        'hindi',
        'career',
        'job',
        'study',
        'exam',
        'coding',
        'padhna',
        'स्वास्थ्य',
        'फिटनेस',
        'इंग्लिश',
        'करियर',
        'नौकरी',
        'पढ़',
      ]),
      evidenceSummary: 'Explicit goal statement.',
    ),
  ];
}

List<_StableFactCandidate> _extractBoundaryCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (!_containsAny(normalized, [
    'mat karna',
    'dont',
    "don't",
    'avoid',
    'nahi chahiye',
    'advice nahi',
    'call mat',
    'baat mat',
    'मत करना',
    'नहीं चाहिए',
    'बात मत',
  ])) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'boundary',
      content: 'User set a boundary: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.72,
      importance: 0.74,
      idQualifier: _topicQualifier(normalized, [
        'advice',
        'call',
        'calls',
        'politics',
        'work',
        'office',
        'family',
        'सलाह',
        'कॉल',
        'राजनीति',
        'ऑफिस',
        'परिवार',
      ]),
      evidenceSummary: 'Explicit boundary statement.',
    ),
  ];
}

List<_StableFactCandidate> _extractComfortStyleCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (!_containsAny(normalized, [
    'bas sunna',
    'pehle suno',
    'advice se pehle',
    'just listen',
    'listen first',
    'पहले सुनो',
  ])) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'procedural',
      label: 'comfort_style',
      content:
          'User prefers this comfort style: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.76,
      importance: 0.78,
      idQualifier: _topicQualifier(normalized, [
        'listen',
        'sunna',
        'suno',
        'advice',
        'सलाह',
        'सुनो',
      ]),
      evidenceSummary: 'Explicit comfort-style preference.',
    ),
  ];
}

List<_StableFactCandidate> _extractRitualCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (!_containsAny(normalized, [
    'har sunday',
    'every sunday',
    'sunday',
    'weekend',
    'hafte',
    'रविवार',
    'हफ्ते',
  ])) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'ritual',
      content:
          'User described a ritual: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.67,
      importance: 0.6,
      idQualifier: _topicQualifier(normalized, [
        'har sunday',
        'every sunday',
        'sunday',
        'weekend',
        'hafte',
        'रविवार',
        'हफ्ते',
      ]),
      evidenceSummary: 'Explicit recurring ritual statement.',
    ),
  ];
}

List<_StableFactCandidate> _extractTabooTopicCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (!_containsAny(normalized, [
    'baat mat',
    'topic avoid',
    'avoid topic',
    'ke bare mein mat',
    'ke baare mein baat mat',
    'बारे में बात मत',
  ])) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'taboo_topic',
      content:
          'User asked to avoid a topic: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.72,
      importance: 0.72,
      idQualifier: _topicQualifier(normalized, [
        'politics',
        'family',
        'work',
        'office',
        'health',
        'money',
        'राजनीति',
        'परिवार',
        'ऑफिस',
        'पैसे',
      ]),
      evidenceSummary: 'Explicit taboo-topic boundary.',
    ),
  ];
}

List<_StableFactCandidate> _extractRecurringStressorCandidates(String text) {
  final normalized = _normalizeForMemory(text);
  if (!_containsAny(normalized, [
    'stress hota',
    'pressure hota',
    'tension hoti',
    'chinta hoti',
    'pareshan',
    'तनाव',
    'चिंता',
  ])) {
    return const [];
  }
  if (_looksWorkStressRelated(normalized)) {
    return const [];
  }
  return [
    _StableFactCandidate(
      memoryType: 'semantic',
      label: 'recurring_stressor',
      content:
          'User mentioned a recurring stressor: ${_cleanMemoryText(text, maxChars: 120)}',
      value: _canonicalMemoryText(text),
      confidence: 0.64,
      importance: 0.62,
      idQualifier: _topicQualifier(normalized, [
        'traffic',
        'commute',
        'travel',
        'family',
        'money',
        'exam',
        'stress',
        'pressure',
        'traffic',
        'परिवार',
        'पैसे',
        'एग्जाम',
      ]),
      evidenceSummary: 'Explicit recurring-stressor statement.',
    ),
  ];
}

bool _isDeclarativeIdentityStatement(String text) {
  final normalized = _normalizeForMemory(text);
  if (_isQuestionLikeMemoryTurn(normalized)) {
    return false;
  }
  return normalized.contains('mera naam') ||
      normalized.contains('my name is') ||
      normalized.contains('मेरा नाम') ||
      normalized.contains('call me') ||
      normalized.contains('मुझे ');
}

bool _isDeclarativePreferenceStatement(String text) {
  final normalized = _normalizeForMemory(text);
  if (_isQuestionLikeMemoryTurn(normalized)) {
    return false;
  }
  return normalized.contains('pasand hai') ||
      normalized.contains('achha lagta hai') ||
      normalized.contains('पसंद है') ||
      normalized.contains('i prefer') ||
      normalized.contains('i like');
}

_UtteranceType _classifyUtterance(String text) {
  final normalized = _normalizeForMemory(text);
  if (_containsSensitiveMemoryBlocker(normalized)) {
    return _UtteranceType.unsafe;
  }
  if (_isQuestionLikeMemoryTurn(normalized)) {
    return _UtteranceType.question;
  }
  if (_looksLikeCorrection(normalized)) {
    return _UtteranceType.correction;
  }
  return _UtteranceType.statement;
}

_MemoryQueryIntent _classifyMemoryQuery(String text) {
  final normalized = _normalizeForMemory(text);
  if ((normalized.contains('naam') ||
          normalized.contains('name') ||
          normalized.contains('नाम')) &&
      _isQuestionLikeMemoryTurn(normalized)) {
    return _MemoryQueryIntent.identityRecall;
  }
  if ((normalized.contains('style') ||
          normalized.contains('language') ||
          normalized.contains('reply') ||
          normalized.contains('इंग्लिश') ||
          normalized.contains('हिंदी') ||
          normalized.contains('भाषा') ||
          normalized.contains('जवाब')) &&
      (_isQuestionLikeMemoryTurn(normalized) ||
          normalized.contains('prefer'))) {
    return _MemoryQueryIntent.languageRecall;
  }
  if ((normalized.contains('pasand') || normalized.contains('like')) &&
      (_isQuestionLikeMemoryTurn(normalized) ||
          normalized.contains('prefer'))) {
    return _MemoryQueryIntent.preferenceRecall;
  }
  if (_containsAny(normalized, const ['boundary', 'seema', 'hadd', 'सीमा']) &&
      _isQuestionLikeMemoryTurn(normalized)) {
    return _MemoryQueryIntent.boundaryRecall;
  }
  if (_looksWorkStressRelated(normalized) ||
      (_containsAny(normalized, const [
            'office',
            'work',
            'kaam',
            'ऑफिस',
            'काम',
          ]) &&
          _containsAny(normalized, const [
            'heavy',
            'bad day',
            'pareshan',
            'stress',
            'pressure',
            'परेशान',
            'तनाव',
          ]))) {
    return _MemoryQueryIntent.workStressRecall;
  }
  return _MemoryQueryIntent.general;
}

bool _isQuestionLikeMemoryTurn(String text) {
  final normalized = _normalizeForMemory(text);
  final policy = MemoryLanguagePolicyRegistry.hiIN;
  return policy.isQuestion(normalized) ||
      _containsAny(normalized, const ['what is', 'what was', 'do you know']);
}

bool _isQuestionToken(String value) {
  return !MemoryLanguagePolicyRegistry.hiIN.isValidPersonValue(value) ||
      _normalizeForMemory(value) == 'what';
}

String _normalizeForMemory(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

bool _looksLikeCorrection(String normalized) {
  const markers = [
    'actually',
    'nahi',
    'nahin',
    'instead',
    'correction',
    'galat',
    'sahi',
    'असल में',
    'नहीं',
    'गलत',
    'सही',
  ];
  return markers.any(normalized.contains);
}

bool _isStrongPreferenceStatement(String text) {
  final normalized = _normalizeForMemory(text);
  return normalized.contains('i prefer') ||
      normalized.contains('mujhe') && normalized.contains('pasand') ||
      normalized.contains('मुझे') && normalized.contains('पसंद');
}

_MemoryReceiptDecision _classifyMemoryReceiptReply(String text) {
  final normalized = _normalizeForMemory(text);
  if (_containsSensitiveMemoryBlocker(normalized) ||
      _isQuestionLikeMemoryTurn(normalized)) {
    return _MemoryReceiptDecision.none;
  }
  final mentionsMemoryAction = _containsAny(normalized, [
    'yaad',
    'remember',
    'memory',
    'याद',
  ]);
  if (!mentionsMemoryAction) {
    return _MemoryReceiptDecision.none;
  }
  if (_containsAny(normalized, [
    'mat yaad',
    'yaad mat',
    'dont remember',
    "don't remember",
    'do not remember',
    'forget',
    'bhool jao',
    'भूल जाओ',
    'याद मत',
    'मत याद',
  ])) {
    return _MemoryReceiptDecision.reject;
  }
  if (_containsAny(normalized, [
    'haan yaad',
    'ha yaad',
    'yes remember',
    'remember this',
    'remember it',
    'yaad rakh',
    'yaad rakhna',
    'yaad rakh lo',
    'हाँ याद',
    'हां याद',
    'याद रखना',
    'याद रखो',
  ])) {
    return _MemoryReceiptDecision.confirm;
  }
  return _MemoryReceiptDecision.none;
}

bool _memoryRelevant(
  MemoryRecord row,
  String latestUserText,
  _MemoryQueryIntent intent,
) {
  if (!_memoryAllowedForRetrieval(row, latestUserText)) {
    return false;
  }
  if (intent != _MemoryQueryIntent.general &&
      !_intentAllowsMemory(row, intent)) {
    return false;
  }
  if (intent != _MemoryQueryIntent.general) {
    return true;
  }
  if ({'stable_fact', 'core_profile', 'procedural'}.contains(row.kind)) {
    // Stable personalisation must be explicitly requested. Generic emotional or
    // contextual turns should not be made more personal merely because a profile
    // record exists.
    return false;
  }
  final latest = _canonicalMemoryText(latestUserText);
  final content = '${row.canonicalText} ${row.content}'.toLowerCase();
  final latestWords = latest
      .split(RegExp(r'[^a-zA-Z\u0900-\u097F]+'))
      .where((word) => word.length >= 4)
      .toSet();
  return latestWords.any(content.contains);
}

bool _intentAllowsMemory(MemoryRecord row, _MemoryQueryIntent intent) {
  return switch (intent) {
    _MemoryQueryIntent.identityRecall => row.label == 'preferred_name',
    _MemoryQueryIntent.languageRecall => row.label == 'language_style',
    _MemoryQueryIntent.preferenceRecall => {
      'safe_preference',
      'language_style',
      'comfort_style',
    }.contains(row.label),
    _MemoryQueryIntent.boundaryRecall => {
      'boundary',
      'taboo_topic',
    }.contains(row.label),
    _MemoryQueryIntent.workStressRecall =>
      row.label == 'recurring_work_stressor',
    _MemoryQueryIntent.general => true,
  };
}

bool _memoryAllowedForRetrieval(MemoryRecord row, String latestUserText) {
  if (row.confidenceScore < 0.5 || row.importanceScore < 0.25) {
    return false;
  }
  if (row.sensitivity != 'normal' ||
      {'rejected', 'unconfirmed'}.contains(row.receiptState) ||
      row.temporalStatus == 'expired' ||
      row.temporalStatus == 'stale') {
    return false;
  }
  if (_isGreetingOnly(latestUserText)) {
    return row.kind == 'core_profile' &&
        {'preferred_name', 'language_style'}.contains(row.label);
  }
  return true;
}

double _memoryRank(
  MemoryRecord row,
  String latestUserText,
  _MemoryQueryIntent intent,
) {
  final relevance = _memoryRelevant(row, latestUserText, intent) ? 0.2 : 0.0;
  final recency = row.updatedAt / 10000000000000;
  final typeBoost = switch ((intent, row.label, row.kind)) {
    (_MemoryQueryIntent.identityRecall, 'preferred_name', 'stable_fact') => 1.0,
    (_MemoryQueryIntent.identityRecall, 'preferred_name', 'core_profile') =>
      1.0,
    (_MemoryQueryIntent.languageRecall, 'language_style', 'procedural') => 0.9,
    (_MemoryQueryIntent.preferenceRecall, 'safe_preference', 'semantic') =>
      0.75,
    (_MemoryQueryIntent.boundaryRecall, 'boundary', _) => 0.9,
    (_MemoryQueryIntent.boundaryRecall, 'taboo_topic', _) => 0.85,
    (_MemoryQueryIntent.workStressRecall, 'recurring_work_stressor', _) => 0.9,
    (_, _, 'stable_fact') => 0.35,
    (_, _, 'core_profile') => 0.5,
    (_, _, 'procedural') => 0.42,
    (_, _, 'semantic') => 0.32,
    (_, _, 'episodic') => 0.18,
    (_, _, 'session_summary') => 0.0,
    _ => 0.0,
  };
  final recurrence = (row.recurrenceCount.clamp(1, 12) - 1) * 0.025;
  final temporalBoost = switch (row.temporalStatus) {
    'future' => 0.32,
    'current' => 0.18,
    'uncertain' => -0.08,
    _ => 0.0,
  };
  return row.importanceScore +
      row.confidenceScore +
      relevance +
      typeBoost +
      recurrence +
      temporalBoost +
      recency;
}

List<MemoryRecord> _selectBoundedMemories(
  List<_RankedMemory> ranked, {
  required int limit,
  required _MemoryQueryIntent intent,
}) {
  final selected = <MemoryRecord>[];
  var summaries = 0;
  final summaryLimit = switch (intent) {
    _MemoryQueryIntent.identityRecall => 1,
    _MemoryQueryIntent.languageRecall => 1,
    _MemoryQueryIntent.preferenceRecall => 1,
    _MemoryQueryIntent.boundaryRecall => 1,
    _MemoryQueryIntent.workStressRecall => 1,
    _MemoryQueryIntent.general => 2,
  };
  for (final item in ranked) {
    if (selected.length >= limit) {
      break;
    }
    if (item.record.kind == 'session_summary') {
      if (summaries >= summaryLimit) {
        continue;
      }
      summaries += 1;
    }
    if (selected.any((memory) => memory.id == item.record.id)) {
      continue;
    }
    selected.add(item.record);
  }
  return selected;
}

List<_MemoryEntityCandidate> _extractMemoryEntities(String text) {
  final normalized = _normalizeForMemory(text);
  final entities = <_MemoryEntityCandidate>[];
  void add(
    String id,
    String kind,
    String canonicalName,
    List<String> aliases, {
    double confidence = 0.72,
  }) {
    if (entities.any((entity) => entity.id == id)) {
      return;
    }
    entities.add(
      _MemoryEntityCandidate(
        id: id,
        kind: kind,
        canonicalName: canonicalName,
        aliases: aliases,
        confidence: confidence,
      ),
    );
  }

  if (_containsAny(normalized, [
    'office',
    'work',
    'kaam',
    'काम',
    'ऑफिस',
    'ऑफ़िस',
    'कार्य',
  ])) {
    add('entity_office', 'context', 'office', [
      'office',
      'work',
      'kaam',
      'ऑफिस',
      'ऑफ़िस',
    ]);
    add('entity_work', 'context', 'work', ['work', 'kaam', 'काम', 'कार्य']);
  }
  if (_containsAny(normalized, [
    'manager',
    'boss',
    'sir',
    'मैनेजर',
    'बॉस',
    'सर',
    'sahab',
    'साहब',
  ])) {
    add('entity_manager', 'work_role', 'manager', [
      'manager',
      'boss',
      'sir',
      'मैनेजर',
      'बॉस',
      'सर',
      'sahab',
      'साहब',
    ]);
  }
  if (_containsAny(normalized, [
    'stress',
    'pressure',
    'bad day',
    'bura din',
    'खराब दिन',
    'pareshan',
    'परेशान',
  ])) {
    add('entity_work_stress', 'stressor', 'work stress', [
      'stress',
      'pressure',
      'bad day',
      'pareshan',
    ]);
  }
  if (_containsAny(normalized, [
    'family',
    'relationship',
    'behen',
    'bahan',
    'bhai',
    'maa',
    'mummy',
    'papa',
    'sister',
    'brother',
    'परिवार',
    'बहन',
    'भाई',
    'माँ',
    'मां',
    'मम्मी',
    'पापा',
  ])) {
    add('entity_family', 'people', 'family', ['family', 'parivar', 'परिवार']);
    add('entity_relationships', 'context', 'relationships', [
      'relationship',
      'rishta',
      'रिश्ता',
    ]);
  }
  if (_containsAny(normalized, [
    'routine',
    'roz',
    'daily',
    'har din',
    'subah',
    'shaam',
    'morning',
    'evening',
    'रोज',
    'हर दिन',
    'सुबह',
    'शाम',
  ])) {
    add('entity_routine', 'routine', 'routine', [
      'routine',
      'roz',
      'daily',
      'रोज',
    ]);
  }
  if (_containsAny(normalized, [
    'goal',
    'target',
    'chahta hoon',
    'chahti hoon',
    'seekhna hai',
    'banana hai',
    'लक्ष्य',
    'सीखना है',
    'बनना है',
  ])) {
    add('entity_goal', 'goal', 'goal', ['goal', 'target', 'लक्ष्य']);
  }
  if (_containsAny(normalized, [
    'boundary',
    'mat karna',
    'nahi chahiye',
    'advice nahi',
    'call mat',
    'baat mat',
    'मत करना',
    'नहीं चाहिए',
    'बात मत',
  ])) {
    add('entity_boundary', 'boundary', 'boundary', [
      'boundary',
      'mat karna',
      'मत करना',
    ]);
  }
  if (_containsAny(normalized, [
    'bas sunna',
    'pehle suno',
    'just listen',
    'listen first',
    'पहले सुनो',
  ])) {
    add('entity_comfort_style', 'preference', 'comfort style', [
      'comfort style',
      'bas sunna',
      'just listen',
    ]);
  }
  if (_containsAny(normalized, [
    'ritual',
    'har sunday',
    'every sunday',
    'sunday',
    'weekend',
    'hafte',
    'रविवार',
    'हफ्ते',
  ])) {
    add('entity_ritual', 'routine', 'ritual', [
      'ritual',
      'har sunday',
      'रविवार',
    ]);
  }
  if (_containsAny(normalized, [
    'taboo',
    'baat mat',
    'avoid topic',
    'topic avoid',
    'ke baare mein baat mat',
    'बारे में बात मत',
  ])) {
    add('entity_taboo_topic', 'boundary', 'taboo topic', [
      'taboo',
      'baat mat',
      'avoid topic',
    ]);
  }
  if (_containsAny(normalized, [
    'stress hota',
    'pressure hota',
    'tension hoti',
    'chinta hoti',
    'traffic',
    'pareshan',
    'तनाव',
    'चिंता',
  ])) {
    add('entity_recurring_stressor', 'stressor', 'recurring stressor', [
      'stress hota',
      'pressure hota',
      'traffic',
      'tension',
      'chinta',
      'तनाव',
      'चिंता',
    ]);
    add('entity_stress', 'stressor', 'stress', ['stress', 'pressure']);
  }
  return entities;
}

bool _looksWorkStressRelated(String normalized) {
  return _containsAny(normalized, ['office', 'work', 'kaam', 'ऑफिस', 'काम']) &&
      _containsAny(normalized, [
        'manager',
        'boss',
        'stress',
        'pressure',
        'bad day',
        'pareshan',
        'मैनेजर',
        'परेशान',
      ]);
}

bool _isGreetingOnly(String text) {
  final normalized = _normalizeForMemory(text);
  const greetings = {'hi', 'hello', 'hey', 'namaste', 'नमस्ते', 'haan', 'हाँ'};
  return greetings.contains(normalized);
}

bool _containsAny(String normalized, Iterable<String> tokens) {
  return tokens.any(normalized.contains);
}

String _canonicalMemoryText(String text) {
  var normalized = _normalizeForMemory(text);
  const replacements = {
    'ऑफिस': 'office',
    'ऑफ़िस': 'office',
    'काम': 'work',
    'कार्य': 'work',
    'kaam': 'work',
    'मैनेजर': 'manager',
    'बॉस': 'manager',
    'सर': 'manager',
    'साहब': 'manager',
    'sahab': 'manager',
    'boss': 'manager',
    'sir': 'manager',
    'परेशान': 'stress',
    'pareshan': 'stress',
    'tension': 'stress',
    'चिंता': 'stress',
    'तनाव': 'stress',
    'bura din': 'bad day',
    'खराब दिन': 'bad day',
    'naam': 'name',
    'yaad': 'remember',
    'pasand': 'like',
    'roz': 'routine',
    'रोज': 'routine',
    'हर दिन': 'routine',
    'parivar': 'family',
    'परिवार': 'family',
    'behen': 'sister',
    'bahan': 'sister',
    'बहन': 'sister',
    'bhai': 'brother',
    'भाई': 'brother',
    'maa': 'mother',
    'mummy': 'mother',
    'माँ': 'mother',
    'मां': 'mother',
    'मम्मी': 'mother',
    'papa': 'father',
    'पापा': 'father',
    'रिश्ता': 'relationship',
    'inglish': 'english',
    'इंग्लिश': 'english',
    'लक्ष्य': 'goal',
    'मत करना': 'boundary',
    'नहीं चाहिए': 'boundary',
    'पहले सुनो': 'listen first',
    'रविवार': 'sunday',
    'subah': 'morning',
    'सुबह': 'morning',
    'shaam': 'evening',
    'शाम': 'evening',
    'padhna': 'study',
    'पढ़ना': 'study',
    'पढ़': 'study',
    'ध्यान': 'meditation',
    'टहल': 'walk',
    'सलाह': 'advice',
    'कॉल': 'call',
    'राजनीति': 'politics',
    'पैसे': 'money',
    'फिटनेस': 'fitness',
    'स्वास्थ्य': 'health',
    'करियर': 'career',
    'नौकरी': 'job',
    'एग्जाम': 'exam',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized;
}

String _detectScript(String text) {
  final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(text);
  final hasLatin = RegExp(r'[A-Za-z]').hasMatch(text);
  if (hasDevanagari && hasLatin) {
    return 'mixed';
  }
  if (hasDevanagari) {
    return 'devanagari';
  }
  return 'latin';
}

String? _replacementReason({
  required MemoryRecord existing,
  required _StableFactCandidate candidate,
}) {
  final existingValue = _stableFactValue(existing);
  final candidateValue = candidate.value.toLowerCase();
  if (existingValue == candidateValue) {
    return null;
  }
  return 'new_explicit_${candidate.label}_statement';
}

bool _containsSensitiveMemoryBlocker(String normalized) {
  const blockers = [
    'suicide',
    'mar jaana',
    'mar jana',
    'jaan dena',
    'khud ko maar',
    'khud ko nuksan',
    'मर जाना',
    'जान देना',
    'खुद को मार',
    'खुद को नुकसान',
    'आत्महत्या',
    'doctor',
    'medical',
    'diagnosis',
    'cancer',
    'diabetes',
    'therapy',
    'medicine',
    'medication',
    'dawai',
    'बीमारी',
    'दवाई',
    'इलाज',
    'legal',
    'lawyer',
    'court case',
    'police case',
    'loan',
    'investment',
    'salary',
    'bank account',
    'account number',
    'credit card',
    'debit card',
    'upi pin',
    'aadhaar',
    'aadhar',
    'pan number',
    'password',
    'otp',
    'sexual',
    'religion',
    'caste',
    'political party',
    'address is',
    'phone number',
    'email is',
    'sirf tum',
    'tumhare bina',
  ];
  return blockers.any(normalized.contains);
}

String _cleanMemoryText(String text, {required int maxChars}) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.length <= maxChars) {
    return cleaned;
  }
  return cleaned.substring(0, maxChars).trim();
}

List<String> _decodeStringList(String encoded) {
  final decoded = jsonDecode(encoded);
  if (decoded is! List) {
    return const [];
  }
  return [
    for (final item in decoded)
      if (item is String) item,
  ];
}

void _logMemoryDiagnostic(String event, Map<String, Object?> fields) {
  developer.log(
    jsonEncode({'event': event, ...fields}),
    name: 'companion.memory',
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'companion_chat.sqlite'));
    return openEncryptedCompanionDatabase(file);
  });
}

class _CandidateDecision {
  const _CandidateDecision(this.state, this.reason);

  final String state;
  final String reason;
  bool get admit => state == 'admitted';
}

class MemoryJudgeApplyResult {
  const MemoryJudgeApplyResult({
    required this.appliedCount,
    required this.supersededCount,
    required this.rejectedCount,
    required this.duplicateCount,
    required this.appliedSourceTurnIds,
  });

  final int appliedCount;
  final int supersededCount;
  final int rejectedCount;
  final int duplicateCount;
  final Set<String> appliedSourceTurnIds;

  /// Replays and empty decision batches never produce a user notice.
  bool get noticeEligible => appliedCount + rejectedCount > 0;
}

const _judgeActionForSuggested = {
  'ADD': 'accept',
  'REINFORCE': 'update',
  'SUPERSEDE': 'supersede',
  'EXPIRE': 'update',
  'NOOP': 'reject',
};

_CandidateDecision _validateJudgeDecision(
  MemoryJudgeDecision decision,
  Map<String, List<ChatMessage>> evidence,
  int priorAdmissions, {
  required bool hasSupersessionTarget,
  required bool hasExactTarget,
}) {
  final candidate = decision.proposal;
  const allowedKinds = {
    'profile',
    'preference',
    'relationship',
    'routine',
    'goal',
    'boundary',
    'episode',
    'open_thread',
    'assistant_commitment',
  };
  const allowedTemporalStatuses = {'current', 'past', 'future', 'uncertain'};
  const allowedExplicitness = {'explicit', 'implied', 'assistant_only'};
  const allowedEvidenceRoles = {'user', 'mixed', 'assistant'};
  if (decision.action == 'reject') {
    // A reject decision must cause no mutation regardless of proposal content.
    return const _CandidateDecision('rejected', 'judge_rejected');
  }
  if (!memoryJudgeActions.contains(decision.action) ||
      _judgeActionForSuggested[candidate.suggestedAction] != decision.action) {
    return const _CandidateDecision(
      'rejected',
      'invalid_or_unverifiable_schema',
    );
  }
  if (!allowedKinds.contains(candidate.kind) ||
      candidate.subject.trim().isEmpty ||
      candidate.subject.length > 100 ||
      candidate.predicate.trim().isEmpty ||
      candidate.predicate.length > 100 ||
      candidate.objectText.trim().isEmpty ||
      candidate.objectText.length > 500 ||
      candidate.sourceTurnIds.isEmpty ||
      candidate.sourceTurnIds.length > 8 ||
      candidate.sourceTurnIds.toSet().length !=
          candidate.sourceTurnIds.length ||
      !allowedTemporalStatuses.contains(candidate.temporalStatus) ||
      !allowedExplicitness.contains(candidate.explicitness) ||
      !allowedEvidenceRoles.contains(candidate.evidenceRole) ||
      !candidate.confidence.isFinite ||
      candidate.confidence < 0 ||
      candidate.confidence > 1 ||
      !candidate.futureUtility.isFinite ||
      candidate.futureUtility < 0 ||
      candidate.futureUtility > 1 ||
      (candidate.eventStartAt != null && candidate.eventStartAt! < 0) ||
      (candidate.eventEndAt != null && candidate.eventEndAt! < 0) ||
      (candidate.proactiveAllowed && !candidate.followUpAllowed) ||
      candidate.sourceTurnIds.any((id) => !evidence.containsKey(id))) {
    return const _CandidateDecision(
      'rejected',
      'invalid_or_unverifiable_schema',
    );
  }
  final sourceMessages = [
    for (final id in candidate.sourceTurnIds) ...evidence[id]!,
  ];
  final sensitivityEvidence = _normalizeForMemory(
    '${candidate.subject} ${candidate.predicate} ${candidate.objectText} '
    '${sourceMessages.map((row) => row.messageText).join(' ')}',
  );
  if (candidate.sensitivity != 'normal' ||
      _containsSensitiveMemoryBlocker(sensitivityEvidence)) {
    return const _CandidateDecision(
      'rejected',
      'sensitive_memory_requires_explicit_opt_in',
    );
  }
  if (decision.action == 'supersede' &&
      (!{'routine', 'goal'}.contains(candidate.kind) ||
          candidate.explicitness != 'explicit' ||
          !hasSupersessionTarget)) {
    return const _CandidateDecision(
      'rejected',
      'supersession_requires_prior_explicit_semantic_target',
    );
  }
  final userEvidence = sourceMessages
      .where((row) => row.role == 'user')
      .toList();
  final lowConfidence = userEvidence.any(
    (row) =>
        row.status == 'final_low_confidence' ||
        (row.sttConfidence != null && row.sttConfidence! < 0.55),
  );
  if (lowConfidence) {
    return const _CandidateDecision('rejected', 'low_confidence_transcript');
  }
  // Event timestamps are meaningful only for event-shaped memories. Models
  // sometimes attach spurious timestamps to plain facts; those are ignored
  // rather than used to reject an otherwise grounded proposal.
  const eventKinds = {'episode', 'open_thread', 'assistant_commitment'};
  if (eventKinds.contains(candidate.kind) &&
      !_candidateEventTimeGrounded(candidate, sourceMessages)) {
    return const _CandidateDecision('rejected', 'event_time_not_grounded');
  }
  if (candidate.kind == 'assistant_commitment') {
    if (candidate.evidenceRole != 'assistant' &&
        candidate.evidenceRole != 'mixed') {
      return const _CandidateDecision(
        'rejected',
        'assistant_commitment_role_mismatch',
      );
    }
    final assistantEvidence = sourceMessages
        .where((row) => row.role == 'assistant' || row.role == 'ai')
        .map((row) => row.messageText)
        .join(' ');
    if (!_candidateLexicallyAnchored(candidate, assistantEvidence)) {
      return const _CandidateDecision(
        'rejected',
        'candidate_not_lexically_grounded',
      );
    }
    return candidate.confidence >= 0.75
        ? const _CandidateDecision('admitted', 'bounded_assistant_commitment')
        : const _CandidateDecision('rejected', 'low_confidence_commitment');
  }
  if (userEvidence.isEmpty || candidate.evidenceRole == 'assistant') {
    return const _CandidateDecision(
      'rejected',
      'assistant_cannot_prove_user_fact',
    );
  }
  if (!_candidateLexicallyAnchored(
    candidate,
    userEvidence.map((row) => row.messageText).join(' '),
  )) {
    return const _CandidateDecision(
      'rejected',
      'candidate_not_lexically_grounded',
    );
  }
  if (candidate.kind == 'profile') {
    // Exact profile changes are allowed only as a bounded LLM judgement over
    // explicit, locally grounded user evidence. The application records a
    // committed supersession; it never creates a confirmation-pending state.
    return candidate.explicitness == 'explicit' &&
            candidate.confidence >= 0.85 &&
            candidate.futureUtility >= 0.4 &&
            candidate.subject.toLowerCase() == 'user' &&
            {
              'preferred_name',
              'name',
              'preferred_name_is',
            }.contains(candidate.predicate.toLowerCase())
        ? const _CandidateDecision('admitted', 'llm_judged_exact_profile')
        : const _CandidateDecision(
            'rejected',
            'insufficient_exact_profile_evidence',
          );
  }
  if (candidate.suggestedAction == 'EXPIRE') {
    if (!hasExactTarget) {
      return const _CandidateDecision(
        'rejected',
        'expiration_requires_existing_target',
      );
    }
    return candidate.explicitness == 'explicit' && candidate.confidence >= 0.8
        ? const _CandidateDecision('admitted', 'explicit_expiration')
        : const _CandidateDecision(
            'rejected',
            'expiration_requires_explicit_evidence',
          );
  }
  if (candidate.explicitness == 'explicit') {
    final threshold =
        candidate.kind == 'episode' || candidate.kind == 'open_thread'
        ? 0.68
        : 0.75;
    if (candidate.confidence >= threshold && candidate.futureUtility >= 0.4) {
      if ({'preference', 'boundary', 'relationship'}.contains(candidate.kind)) {
        return const _CandidateDecision(
          'admitted',
          'llm_judged_explicit_personal_fact',
        );
      }
      return const _CandidateDecision(
        'admitted',
        'explicit_low_risk_user_evidence',
      );
    }
  }
  if (candidate.explicitness == 'implied' &&
      priorAdmissions >= 1 &&
      candidate.confidence >= 0.72 &&
      candidate.futureUtility >= 0.55) {
    return const _CandidateDecision(
      'admitted',
      'llm_judged_recurring_cross_window_hypothesis',
    );
  }
  return const _CandidateDecision(
    'rejected',
    'insufficient_explicit_future_value',
  );
}

String _candidateFingerprint(ExtractedMemoryCandidate candidate) {
  final eventIdentity = candidate.kind == 'episode'
      ? '|${candidate.eventStartAt ?? candidate.sourceTurnIds.first}'
      : candidate.kind == 'open_thread' && candidate.eventStartAt != null
      ? '|${candidate.eventStartAt}'
      : '';
  return _stableMemoryHash(
    '${candidate.kind}|${candidate.subject}|${candidate.predicate}|${candidate.objectText}$eventIdentity'
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' '),
  );
}

bool _candidateLexicallyAnchored(
  ExtractedMemoryCandidate candidate,
  String evidenceText,
) {
  const stopWords = {
    'user',
    'has',
    'had',
    'is',
    'was',
    'the',
    'and',
    'with',
    'will',
    'mera',
    'meri',
    'mere',
    'hai',
    'tha',
    'thi',
    'ko',
    'ka',
    'ki',
    'ke',
  };
  Set<String> tokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9\u0900-\u097F]+'))
      .where((token) => token.length >= 3 && !stopWords.contains(token))
      .toSet();
  final candidateTokens = tokens(
    '${candidate.predicate} ${candidate.objectText}',
  );
  if (candidateTokens.isEmpty) return false;
  final evidenceTokens = tokens(evidenceText);
  return candidateTokens.intersection(evidenceTokens).isNotEmpty;
}

bool _candidateEventTimeGrounded(
  ExtractedMemoryCandidate candidate,
  List<ChatMessage> evidence,
) {
  final start = candidate.eventStartAt;
  final end = candidate.eventEndAt;
  if (start == null && end == null) return true;
  if (start == null || (end != null && end < start)) return false;
  final anchorMs = evidence
      .map((row) => row.createdAt)
      .reduce((left, right) => left < right ? left : right);
  const fiveYearsMs = 5 * 366 * 24 * 60 * 60 * 1000;
  if ((start - anchorMs).abs() > fiveYearsMs ||
      (end != null && end - start > const Duration(days: 366).inMilliseconds)) {
    return false;
  }
  final text = evidence.map((row) => row.messageText).join(' ').toLowerCase();
  final proposed = DateTime.fromMillisecondsSinceEpoch(start);
  final absolute = RegExp(
    r'\b(20\d{2})[-/](0?[1-9]|1[0-2])[-/](0?[1-9]|[12]\d|3[01])\b',
  ).firstMatch(text);
  if (absolute != null) {
    return proposed.year == int.parse(absolute.group(1)!) &&
        proposed.month == int.parse(absolute.group(2)!) &&
        proposed.day == int.parse(absolute.group(3)!);
  }
  const weekdays = <String, int>{
    'monday': DateTime.monday,
    'somvaar': DateTime.monday,
    'सोमवार': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'mangalvaar': DateTime.tuesday,
    'मंगलवार': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'budhvaar': DateTime.wednesday,
    'बुधवार': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'guruvaar': DateTime.thursday,
    'गुरुवार': DateTime.thursday,
    'friday': DateTime.friday,
    'shukravaar': DateTime.friday,
    'शुक्रवार': DateTime.friday,
    'saturday': DateTime.saturday,
    'शनिवार': DateTime.saturday,
    'sunday': DateTime.sunday,
    'रविवार': DateTime.sunday,
  };
  for (final entry in weekdays.entries) {
    if (!text.contains(entry.key)) continue;
    if (proposed.weekday != entry.value) return false;
    final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMs);
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    final proposedDay = DateTime(proposed.year, proposed.month, proposed.day);
    final dayDelta = proposedDay.difference(anchorDay).inDays;
    return switch (candidate.temporalStatus) {
      'future' => dayDelta >= 0 && dayDelta <= 7,
      'past' => dayDelta <= 0 && dayDelta >= -7,
      _ => dayDelta.abs() <= 7,
    };
  }
  final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMs);
  if (text.contains('tomorrow') ||
      text.contains('कल') && candidate.temporalStatus == 'future' ||
      text.contains('kal') && candidate.temporalStatus == 'future') {
    return _sameCalendarDay(proposed, anchor.add(const Duration(days: 1)));
  }
  if (text.contains('yesterday') ||
      text.contains('कल') && candidate.temporalStatus == 'past' ||
      text.contains('kal') && candidate.temporalStatus == 'past') {
    return _sameCalendarDay(proposed, anchor.subtract(const Duration(days: 1)));
  }
  if (text.contains('today') || text.contains('आज') || text.contains('aaj')) {
    return _sameCalendarDay(proposed, anchor);
  }
  return false;
}

bool _sameCalendarDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _candidateContent(ExtractedMemoryCandidate candidate) {
  final object = candidate.objectText.trim();
  final punctuated = RegExp(r'[.!?।]$').hasMatch(object) ? object : '$object.';
  const eventKinds = {'episode', 'open_thread', 'assistant_commitment'};
  final time =
      candidate.eventStartAt == null || !eventKinds.contains(candidate.kind)
      ? ''
      : ' Event time: ${DateTime.fromMillisecondsSinceEpoch(candidate.eventStartAt!).toIso8601String()}.';
  return _truncateMemoryText('$punctuated$time', 700);
}

String _safeMemoryToken(String value) {
  final token = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return token.isEmpty ? 'fact' : _truncateMemoryText(token, 48);
}

String _truncateMemoryText(String value, int maxChars) {
  final clean = value.trim();
  return clean.length <= maxChars ? clean : clean.substring(0, maxChars);
}

String _stableMemoryHash(String value) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
