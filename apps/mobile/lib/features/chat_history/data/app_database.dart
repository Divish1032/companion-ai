import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'memory_vector_index.dart';

part 'app_database.g.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

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

@DriftDatabase(
  tables: [
    ChatSessions,
    ChatMessages,
    MemoryRecords,
    MemoryEntities,
    MemoryEdges,
    MemoryContradictions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(chatMessages, chatMessages.sttConfidence);
        await m.createTable(memoryRecords);
      }
      if (from < 3) {
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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
      if (user != null && _eligibleForMemory(user)) {
        await _upsertSessionSummary(user, assistant);
      }
    });
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
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final intent = _classifyMemoryQuery(latestUserText);
    final vectorScores = {
      for (final hit in vectorHits) hit.memoryId: hit.score,
    };
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
        if (_memoryRelevant(row, latestUserText))
          _RankedMemory(row, _memoryRank(row, latestUserText, intent)),
      for (final row in rows)
        if (vectorScores.containsKey(row.id) &&
            _memoryAllowedForRetrieval(row, latestUserText))
          _RankedMemory(
            row,
            _memoryRank(row, latestUserText, intent) +
                0.45 +
                vectorScores[row.id]!.clamp(0.0, 1.0),
          ),
      ...await _graphExpandedMemories(latestUserText, intent),
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
    return selected;
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
                row.temporalStatus.isNotIn(['expired']) &
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
      await delete(memoryContradictions).go();
      await delete(memoryEdges).go();
      await delete(memoryEntities).go();
      await delete(memoryRecords).go();
      await delete(chatMessages).go();
      await delete(chatSessions).go();
    });
  }

  Future<void> _admitStableFacts(ChatMessage message) async {
    if (!_eligibleForMemory(message) || message.role != 'user') {
      return;
    }
    await _upsertGraphSignals(message);
    for (final candidate in _extractStableFactCandidates(message.messageText)) {
      final id = 'memory_${candidate.memoryType}_${candidate.label}';
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
        if (relatedTerms.any(
          (term) =>
              row.canonicalText.contains(term) ||
              row.content.toLowerCase().contains(term),
        ))
          _RankedMemory(row, _memoryRank(row, latestUserText, intent) + 0.65),
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
        receiptState: const Value('unconfirmed'),
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
    this.evidenceSummary = '',
  });

  final String memoryType;
  final String label;
  final String content;
  final String value;
  final double confidence;
  final double importance;
  final String evidenceSummary;
}

class _RankedMemory {
  const _RankedMemory(this.record, this.score);

  final MemoryRecord record;
  final double score;
}

enum _UtteranceType { statement, question, correction, unsafe }

enum _MemoryQueryIntent {
  identityRecall,
  languageRecall,
  preferenceRecall,
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
  if ((normalized.contains('naam') || normalized.contains('name')) &&
      _isQuestionLikeMemoryTurn(normalized)) {
    return _MemoryQueryIntent.identityRecall;
  }
  if ((normalized.contains('style') ||
          normalized.contains('language') ||
          normalized.contains('इंग्लिश') ||
          normalized.contains('हिंदी')) &&
      (_isQuestionLikeMemoryTurn(normalized) ||
          normalized.contains('prefer'))) {
    return _MemoryQueryIntent.languageRecall;
  }
  if ((normalized.contains('pasand') || normalized.contains('like')) &&
      (_isQuestionLikeMemoryTurn(normalized) ||
          normalized.contains('prefer'))) {
    return _MemoryQueryIntent.preferenceRecall;
  }
  return _MemoryQueryIntent.general;
}

bool _isQuestionLikeMemoryTurn(String text) {
  final normalized = _normalizeForMemory(text);
  const markers = [
    '?',
    'kya',
    'kaun',
    'kaise',
    'kis',
    'yaad hai',
    'remember',
    'what is',
    'what was',
    'do you know',
    'क्या',
    'कौन',
    'कैसे',
    'किस',
    'याद है',
  ];
  return markers.any(normalized.contains);
}

bool _isQuestionToken(String value) {
  final normalized = _normalizeForMemory(value);
  const questionTokens = {'kya', 'what', 'क्या'};
  return questionTokens.contains(normalized);
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

bool _memoryRelevant(MemoryRecord row, String latestUserText) {
  if (!_memoryAllowedForRetrieval(row, latestUserText)) {
    return false;
  }
  if ({'stable_fact', 'core_profile', 'procedural'}.contains(row.kind)) {
    return true;
  }
  final latest = _canonicalMemoryText(latestUserText);
  final content = '${row.canonicalText} ${row.content}'.toLowerCase();
  final latestWords = latest
      .split(RegExp(r'[^a-zA-Z\u0900-\u097F]+'))
      .where((word) => word.length >= 4)
      .toSet();
  return latestWords.any(content.contains);
}

bool _memoryAllowedForRetrieval(MemoryRecord row, String latestUserText) {
  if (row.confidenceScore < 0.5 || row.importanceScore < 0.25) {
    return false;
  }
  if (row.sensitivity != 'normal' ||
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
  final relevance = _memoryRelevant(row, latestUserText) ? 0.2 : 0.0;
  final recency = row.updatedAt / 10000000000000;
  final typeBoost = switch ((intent, row.label, row.kind)) {
    (_MemoryQueryIntent.identityRecall, 'preferred_name', 'stable_fact') => 1.0,
    (_MemoryQueryIntent.identityRecall, 'preferred_name', 'core_profile') =>
      1.0,
    (_MemoryQueryIntent.languageRecall, 'language_style', 'procedural') => 0.9,
    (_MemoryQueryIntent.preferenceRecall, 'safe_preference', 'semantic') =>
      0.75,
    (_, _, 'stable_fact') => 0.35,
    (_, _, 'core_profile') => 0.5,
    (_, _, 'procedural') => 0.42,
    (_, _, 'semantic') => 0.32,
    (_, _, 'episodic') => 0.18,
    (_, _, 'session_summary') => 0.0,
    _ => 0.0,
  };
  final recurrence = (row.recurrenceCount.clamp(1, 12) - 1) * 0.025;
  return row.importanceScore +
      row.confidenceScore +
      relevance +
      typeBoost +
      recurrence +
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

  if (_containsAny(normalized, ['office', 'work', 'kaam', 'काम', 'ऑफिस'])) {
    add('entity_office', 'context', 'office', [
      'office',
      'work',
      'kaam',
      'ऑफिस',
    ]);
    add('entity_work', 'context', 'work', ['work', 'kaam', 'काम']);
  }
  if (_containsAny(normalized, ['manager', 'boss', 'sir', 'मैनेजर'])) {
    add('entity_manager', 'work_role', 'manager', ['manager', 'boss', 'sir']);
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
    'काम': 'work',
    'kaam': 'work',
    'मैनेजर': 'manager',
    'परेशान': 'stress',
    'pareshan': 'stress',
    'bura din': 'bad day',
    'खराब दिन': 'bad day',
    'naam': 'name',
    'yaad': 'remember',
    'pasand': 'like',
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
    'dawai',
    'legal',
    'lawyer',
    'loan',
    'investment',
    'sexual',
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'companion_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
