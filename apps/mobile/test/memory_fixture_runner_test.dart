import 'dart:convert';
import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixturePath = Platform.environment['FIXTURE_JSON'];
  if (fixturePath == null || fixturePath.isEmpty) {
    stderr.writeln('SKIP: FIXTURE_JSON environment variable not set');
    return;
  }

  final fixtureFile = File(fixturePath);
  if (!fixtureFile.existsSync()) {
    stderr.writeln('ERROR: fixture JSON file not found: $fixturePath');
    exitCode = 1;
    return;
  }

  final fixtureJson = fixtureFile.readAsStringSync();
  final fixture = jsonDecode(fixtureJson) as Map<String, dynamic>;
  final fixtureId = fixture['id'] as String? ?? 'unknown';

  test('fixture: $fixtureId', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final sessions = fixture['sessions'] as List<dynamic>?;
    if (sessions == null || sessions.isEmpty) {
      fail('Fixture "$fixtureId" has no sessions');
    }

    int baseOffset = 0;
    for (final session in sessions) {
      final sessionData = session as Map<String, dynamic>;
      final sessionKey = sessionData['session_key'] as String? ?? 's_default';
      final turns = sessionData['turns'] as List<dynamic>? ?? [];

      for (int i = 0; i < turns.length; i++) {
        final turn = turns[i] as Map<String, dynamic>;
        final turnKey = turn['turn_key'] as String? ?? 't_$i';
        final role = turn['role'] as String? ?? 'user';
        final text = turn['text'] as String? ?? '';
        final status = turn['transcript_status'] as String? ?? 'final';
        final confidence = (turn['stt_confidence'] as num?)?.toDouble();
        final offsetMs = (turn['offset_ms'] as int?) ?? 0;

        final msgId = '${fixtureId}_$turnKey';
        final turnId = '${sessionKey}_$turnKey';
        final createdAt = baseOffset + offsetMs;

        if (role == 'user') {
          await database.upsertUserMessageAndExtractMemory(
            ChatMessagesCompanion.insert(
              id: msgId,
              sessionId: sessionKey,
              turnId: turnId,
              role: 'user',
              messageText: text,
              status: status,
              language: 'hi-IN',
              createdAt: createdAt,
              sttConfidence: Value(confidence),
            ),
          );
        } else {
          await database.upsertAssistantMessageAndSummarizeTurn(
            ChatMessagesCompanion.insert(
              id: msgId,
              sessionId: sessionKey,
              turnId: turnId,
              role: 'assistant',
              messageText: text,
              status: status,
              language: 'hi-IN',
              createdAt: createdAt,
            ),
          );
        }
      }
      baseOffset += 10000;
    }

    final allRecords = await database.select(database.memoryRecords).get();
    final allMemoryIds = allRecords.map((r) => r.id).toSet();
    final allLabels = allRecords.map((r) => r.label).toSet();

    final results = <String, dynamic>{
      'fixture_id': fixtureId,
      'storage': {
        'memory_ids': allMemoryIds.toList()..sort(),
        'labels': allLabels.toList()..sort(),
        'total_records': allRecords.length,
      },
    };

    final query = fixture['query'] as Map<String, dynamic>?;
    if (query != null) {
      final queryText = query['text'] as String? ?? '';
      final memories = await database.readMemoryContext(
        latestUserText: queryText,
        limit: 6,
      );

      final queryMemoryIds = memories.map((m) => m.id).toList();
      final queryLabels = memories.map((m) => m.label).toList();

      results['query_result'] = {
        'text_hash': _hashText(queryText),
        'memory_ids': queryMemoryIds,
        'labels': queryLabels,
        'packet_count': memories.length,
      };

      results['memory_blocks'] = memories.map(_toMemoryBlock).toList();

      final pendingReceipts = await database.readPendingMemoryReceipts(
        limit: 4,
      );
      results['pending_receipts'] = pendingReceipts
          .map(_toReceiptBlock)
          .toList();
    }

    final storageExpect = fixture['storage_expect'] as Map<String, dynamic>?;
    if (storageExpect != null) {
      results['storage_expect'] = storageExpect;

      final mustExistLabels =
          (storageExpect['must_exist_labels'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final mustNotLabels =
          (storageExpect['must_not_exist_labels'] as List<dynamic>?)
              ?.cast<String>() ??
          [];

      for (final label in mustExistLabels) {
        expect(
          allLabels,
          contains(label),
          reason: 'storage must_exist_labels expects label "$label"',
        );
      }
      for (final label in mustNotLabels) {
        expect(
          allLabels,
          isNot(contains(label)),
          reason: 'storage must_not_exist_labels forbids label "$label"',
        );
      }
    }

    final queryExpect = query?['expect'] as Map<String, dynamic>?;
    if (queryExpect != null) {
      final mustIncludeLabels =
          (queryExpect['must_include_labels'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final mustNotIncludeLabels =
          (queryExpect['must_not_include_labels'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final maxPackets = queryExpect['max_packets'] as int?;

      final queryLabelsActual =
          results['query_result']['labels'] as List<dynamic>;

      for (final label in mustIncludeLabels) {
        expect(
          queryLabelsActual,
          contains(label),
          reason: 'query expect must_include_labels expects label "$label"',
        );
      }
      for (final label in mustNotIncludeLabels) {
        expect(
          queryLabelsActual,
          isNot(contains(label)),
          reason: 'query expect must_not_include_labels forbids label "$label"',
        );
      }
      if (maxPackets != null) {
        final packetCount = results['query_result']['packet_count'] as int;
        expect(
          packetCount,
          lessThanOrEqualTo(maxPackets),
          reason: 'packet_count $packetCount exceeds max_packets $maxPackets',
        );
      }
    }

    final output = jsonEncode(results);
    stdout.writeln(output);
  });
}

Map<String, dynamic> _toMemoryBlock(MemoryRecord record) {
  List<String> sourceTurnIds;
  try {
    sourceTurnIds = (jsonDecode(record.sourceTurnIdsJson) as List<dynamic>)
        .map((e) => e.toString())
        .toList();
  } catch (_) {
    sourceTurnIds = [];
  }

  return {
    'memory_id': record.id,
    'kind': record.kind,
    'label': record.label,
    'content': record.content,
    'canonical_text': record.canonicalText,
    'source_turn_ids': sourceTurnIds,
    'source_role': record.sourceRole,
    'transcript_status': record.transcriptStatus,
    'stt_confidence': record.sttConfidence,
    'created_at_ms': record.createdAt,
    'updated_at_ms': record.updatedAt,
    'last_used_at_ms': record.lastUsedAt,
    'confidence_score': record.confidenceScore,
    'importance_score': record.importanceScore,
    'recurrence_count': record.recurrenceCount,
    'sensitivity': record.sensitivity,
    'temporal_status': record.temporalStatus,
    'receipt_state': record.receiptState,
    'evidence_summary': record.evidenceSummary,
  };
}

Map<String, dynamic> _toReceiptBlock(MemoryRecord record) {
  return {
    'memory_id': record.id,
    'kind': record.kind,
    'label': record.label,
    'content': record.content,
    'confidence_score': record.confidenceScore,
    'importance_score': record.importanceScore,
    'evidence_summary': record.evidenceSummary,
  };
}

String _hashText(String text) {
  final bytes = utf8.encode(text);
  var hash = 0;
  for (final b in bytes) {
    hash = ((hash << 5) - hash + b) & 0x3FFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
