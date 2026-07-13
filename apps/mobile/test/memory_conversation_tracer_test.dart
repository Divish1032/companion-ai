import 'dart:convert';
import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scriptPath = Platform.environment['AUDIT_SCRIPT'];
  final dbPath = Platform.environment['AUDIT_DB_PATH'];

  if (scriptPath == null || scriptPath.isEmpty) {
    stderr.writeln('SKIP: AUDIT_SCRIPT not set');
    return;
  }
  if (dbPath == null || dbPath.isEmpty) {
    stderr.writeln('SKIP: AUDIT_DB_PATH not set');
    return;
  }

  final scriptJson = File(scriptPath).readAsStringSync();
  final script = jsonDecode(scriptJson) as Map<String, dynamic>;
  final conversationId = script['id'] as String? ?? 'unknown';
  final turns = script['turns'] as List<dynamic>? ?? [];

  if (turns.isEmpty) {
    stderr.writeln('Conversation script has no turns');
    exitCode = 1;
    return;
  }

  test('conversation trace: $conversationId', () async {
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    final database = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async {
      await database.close();
      try { dbFile.deleteSync(); } catch (_) {}
    });

    final trace = <Map<String, dynamic>>[];
    String? lastAssistantText;
    int sessionCount = 0;

    for (int turnIdx = 0; turnIdx < turns.length; turnIdx++) {
      final turn = turns[turnIdx] as Map<String, dynamic>;
      final text = turn['text'] as String? ?? '';
      final confidence = (turn['stt_confidence'] as num?)?.toDouble() ?? 0.95;
      final turnId = turn['turn_id'] as String? ?? 'conv_turn_$turnIdx';

      final sessionKey = 'audit_session_$sessionCount';

      final beforeRecords = await database.select(database.memoryRecords).get();
      final beforeLabels = beforeRecords.map((r) => r.label).toSet();

      await database.upsertUserMessageAndExtractMemory(
        ChatMessagesCompanion.insert(
          id: 'audit_user_$turnIdx',
          sessionId: sessionKey,
          turnId: turnId,
          role: 'user',
          messageText: text,
          status: 'final',
          language: 'hi-IN',
          createdAt: turnIdx * 1000,
          sttConfidence: Value(confidence),
        ),
      );

      final afterRecords = await database.select(database.memoryRecords).get();
      final newLabels = afterRecords
          .where((r) => !beforeLabels.contains(r.label))
          .map((r) => r.label)
          .toSet();

      final memories = await database.readMemoryContext(
        latestUserText: text,
        limit: 6,
      );

      final retrievedLabels = memories.map((m) => m.label).toList();
      final retrievedIds = memories.map((m) => m.id).toList();
      final memoryBlocks = memories.map(_toBlock).toList();
      final packetCount = memories.length;

      final mockResponse = _generateMockResponse(text, retrievedLabels, afterRecords);
      lastAssistantText = mockResponse;

      await database.upsertAssistantMessageAndSummarizeTurn(
        ChatMessagesCompanion.insert(
          id: 'audit_assistant_$turnIdx',
          sessionId: sessionKey,
          turnId: turnId,
          role: 'assistant',
          messageText: mockResponse,
          status: 'final',
          language: 'hi-IN',
          createdAt: turnIdx * 1000 + 100,
        ),
      );

      final finalRecords = await database.select(database.memoryRecords).get();
      final finalLabels = finalRecords.map((r) => r.label).toSet();
      final finalByLabel = <String, int>{};
      for (final r in finalRecords) {
        finalByLabel[r.label] = (finalByLabel[r.label] ?? 0) + 1;
      }
      final finalByTemporal = <String, int>{};
      for (final r in finalRecords) {
        finalByTemporal[r.temporalStatus] = (finalByTemporal[r.temporalStatus] ?? 0) + 1;
      }
      final finalByReceipt = <String, int>{};
      for (final r in finalRecords) {
        finalByReceipt[r.receiptState] = (finalByReceipt[r.receiptState] ?? 0) + 1;
      }

      final pendingReceipts = await database.readPendingMemoryReceipts(limit: 4);

      trace.add({
        'turn_index': turnIdx,
        'user_text_hash': _hashText(text),
        'admission': {
          'before_labels': beforeLabels.toList()..sort(),
          'after_labels': finalLabels.toList()..sort(),
          'new_labels_this_turn': newLabels.toList()..sort(),
        },
        'retrieval': {
          'returned_labels': retrievedLabels,
          'returned_ids': retrievedIds,
          'packet_count': packetCount,
          'memory_blocks': memoryBlocks,
        },
        'assistant': {
          'response_hash': _hashText(mockResponse),
          'response_length': mockResponse.length,
        },
        'db_snapshot': {
          'total_records': finalRecords.length,
          'by_label': finalByLabel,
          'by_temporal_status': finalByTemporal,
          'by_receipt_state': finalByReceipt,
          'pending_receipts': pendingReceipts.length,
        },
      });

      if (lastAssistantText != null && _shouldStartNewSession(text)) {
        sessionCount++;
      }
    }

    final output = {
      'conversation_id': conversationId,
      'total_turns': turns.length,
      'turns': trace,
      'final_db_state': {
        'total_records': (await database.select(database.memoryRecords).get()).length,
      },
    };

    stdout.writeln(jsonEncode(output));
  });
}

Map<String, dynamic> _toBlock(MemoryRecord record) {
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

String _generateMockResponse(
  String userText,
  List<String> retrievedLabels,
  List<MemoryRecord> allRecords,
) {
  final normalized = userText.toLowerCase();

  if (_containsAny(normalized, ['namaste', 'hi', 'hello', 'hey'])) {
    return 'Namaste! Kaise ho aap?';
  }
  if (_containsAny(normalized, ['naam kya hai', 'naam yaad hai', 'mere baare mein'])) {
    final name = allRecords
        .where((r) => r.label == 'preferred_name')
        .map((r) => r.content)
        .firstOrNull;
    if (name != null && name.contains('called ')) {
      final extracted = name.split('called ').last.replaceAll('.', '').trim();
      return 'Haan, aapka naam $extracted hai na?';
    }
    return 'Haan, mujhe yaad hai aapke baare mein.';
  }
  if (_containsAny(normalized, ['naam']) || retrievedLabels.contains('preferred_name')) {
    final name = allRecords
        .where((r) => r.label == 'preferred_name')
        .map((r) => r.content)
        .firstOrNull;
    if (name != null && name.contains('called ')) {
      final extracted = name.split('called ').last.replaceAll('.', '').trim();
      return 'Achha $extracted, yaad rakhoonga.';
    }
  }
  if (_containsAny(normalized, ['office', 'manager', 'boss', 'kaam', 'pressure'])) {
    return 'Main samajh raha hoon, office ka pressure tough hota hai. Aap apna dhyaan rakhiye.';
  }
  if (_containsAny(normalized, ['walk', 'exercise', 'subah', 'routine'])) {
    return 'Walk karna bahut achi aadat hai, keep it up!';
  }
  if (_containsAny(normalized, ['hindi', 'english', 'language', 'भाषा'])) {
    return 'Theek hai, Hindi mein jawab doonga.';
  }
  if (_containsAny(normalized, ['sunna', 'advice', 'suno'])) {
    return 'Samjha, main pehle sununga, phir advice doonga.';
  }
  if (_containsAny(normalized, ['mat karna', 'mat kar', 'boundary', 'call'])) {
    return 'Theek hai, avoid karoonga.';
  }
  if (_containsAny(normalized, ['behen', 'bhai', 'sister', 'brother', 'family'])) {
    return 'Achha, yaad rakhoonga aapki family ke baare mein.';
  }
  if (_containsAny(normalized, ['yaad rakhna', 'yaad rakho'])) {
    return 'Haan, zaroor yaad rakhoonga.';
  }
  if (_containsAny(normalized, ['yaad mat rakhna', 'yaad mat karo', 'nahi yaad'])) {
    return 'Theek hai, nahi rakhoonga yaad.';
  }
  return 'Haan, main sun raha hoon. Aap batao na.';
}

bool _containsAny(String text, List<String> markers) {
  return markers.any((m) => text.contains(m));
}

bool _shouldStartNewSession(String text) {
  return text.contains('bye') || text.contains('alvida');
}

String _hashText(String text) {
  final bytes = utf8.encode(text);
  var hash = 0;
  for (final b in bytes) {
    hash = ((hash << 5) - hash + b) & 0x3FFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
