import 'dart:convert';
import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/chat_history/data/companion_memory_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogPath = Platform.environment['MEMORY_V3_FIXTURE_CATALOG'];
  final outputPath = Platform.environment['MEMORY_V3_V2_PROBE_OUTPUT'];

  if (catalogPath == null ||
      catalogPath.isEmpty ||
      outputPath == null ||
      outputPath.isEmpty) {
    stderr.writeln(
      'SKIP: MEMORY_V3_FIXTURE_CATALOG and '
      'MEMORY_V3_V2_PROBE_OUTPUT are required',
    );
    return;
  }

  test('capture unchanged V2 retrieval for Memory V3 Task 1', () async {
    final catalogFile = File(catalogPath);
    expect(catalogFile.existsSync(), isTrue, reason: 'fixture catalog missing');
    final catalog =
        jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
    final scenarios = catalog['scenarios'] as List<dynamic>? ?? const [];
    final scenarioResults = <Map<String, dynamic>>[];

    for (final rawScenario in scenarios) {
      final scenario = rawScenario as Map<String, dynamic>;
      final scenarioId = scenario['id'] as String? ?? 'unknown';
      final queries = scenario['queries'] as List<dynamic>? ?? const [];
      final queryResults = <Map<String, dynamic>>[];
      String? scenarioError;

      for (final rawQuery in queries) {
        final query = rawQuery as Map<String, dynamic>;
        final queryId = query['query_id'] as String? ?? 'unknown';
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          await _replayUntil(
            database: database,
            scenarioId: scenarioId,
            sessions: scenario['sessions'] as List<dynamic>? ?? const [],
            afterSessionId: query['after_session_id'] as String? ?? '',
          );

          final storedRecords = await database
              .select(database.memoryRecords)
              .get();
          final stateRows = await database
              .customSelect(
                'SELECT state_key, value_json, category FROM companion_state '
                'ORDER BY state_key ASC',
              )
              .get();

          final queryTurnId = '${scenarioId}_$queryId';
          final queryText = query['text'] as String? ?? '';
          final queryCreatedAt = query['created_at_ms'] as int? ?? 0;
          await database.upsertUserMessageAndExtractMemory(
            ChatMessagesCompanion.insert(
              id: '${queryTurnId}_message',
              sessionId: '${scenarioId}_baseline_query',
              turnId: queryTurnId,
              role: 'user',
              messageText: queryText,
              status: 'final',
              language: query['language'] as String? ?? 'hi-IN',
              createdAt: queryCreatedAt,
              sttConfidence: const Value(0.99),
            ),
          );
          final stopwatch = Stopwatch()..start();
          final resolution = await database.resolveMemoryTurn(
            turnId: queryTurnId,
            text: queryText,
            language: query['language'] as String? ?? 'hi-IN',
            transcriptStatus: 'final',
            sttConfidence: 0.99,
            sttProvider: 'synthetic',
            sttModel: 'fixture',
          );
          final memories = resolution.queryScope == null
              ? <MemoryRecord>[]
              : await database.readMemoryContext(
                  latestUserText: queryText,
                  limit: 8,
                  route: resolution.queryScope,
                );
          stopwatch.stop();
          queryResults.add({
            'query_id': queryId,
            'status': 'completed',
            'latency_ms': stopwatch.elapsedMilliseconds,
            'memory_blocks': memories.map(_toMemoryBlock).toList(),
            'stored_memory_blocks': storedRecords.map(_toMemoryBlock).toList(),
            'state_snapshot': [
              for (final row in stateRows)
                {
                  'state_key': row.read<String>('state_key'),
                  'value': _decodeValue(row.read<String>('value_json')),
                  'category': row.read<String>('category'),
                },
            ],
            'response_directive': resolution.directive,
            'state_facts': resolution.stateFacts,
            'policy_card': resolution.policyCard,
            'semantic_resolved': resolution.queryScope != null,
            'error': null,
          });
        } catch (error) {
          scenarioError ??= error.toString();
          queryResults.add({
            'query_id': queryId,
            'status': 'failed',
            'latency_ms': 0,
            'memory_blocks': <Map<String, dynamic>>[],
            'stored_memory_blocks': <Map<String, dynamic>>[],
            'state_snapshot': <Map<String, dynamic>>[],
            'response_directive': null,
            'state_facts': <Map<String, dynamic>>[],
            'policy_card': <String, dynamic>{},
            'semantic_resolved': false,
            'error': error.toString(),
          });
        } finally {
          await database.close();
        }
      }

      scenarioResults.add({
        'scenario_id': scenarioId,
        'error': scenarioError,
        'queries': queryResults,
      });
    }

    final output = {
      'schema_version': 1,
      'source': 'unchanged_v2_phone_replay',
      'scenario_count': scenarioResults.length,
      'scenarios': scenarioResults,
    };
    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(output),
    );
    stdout.writeln('MEMORY_V3_V2_PROBE=${outputFile.absolute.path}');
  });
}

Future<void> _replayUntil({
  required AppDatabase database,
  required String scenarioId,
  required List<dynamic> sessions,
  required String afterSessionId,
}) async {
  var foundCheckpoint = false;
  String? currentUserTurnId;
  for (final rawSession in sessions) {
    final session = rawSession as Map<String, dynamic>;
    final sessionId = session['session_id'] as String? ?? 'session_unknown';
    final turns = session['turns'] as List<dynamic>? ?? const [];

    for (final rawTurn in turns) {
      final turn = rawTurn as Map<String, dynamic>;
      final turnId = turn['turn_id'] as String? ?? 'turn_unknown';
      final role = turn['role'] as String? ?? 'user';
      final status = turn['status'] as String? ?? 'final';
      final confidence = (turn['stt_confidence'] as num?)?.toDouble();
      if (role == 'user') {
        currentUserTurnId = turnId;
      }
      final databaseTurnId = role == 'assistant'
          ? (currentUserTurnId ?? turnId)
          : turnId;
      final message = ChatMessagesCompanion.insert(
        id: '${scenarioId}_$turnId',
        sessionId: '${scenarioId}_$sessionId',
        turnId: databaseTurnId,
        role: role,
        messageText: turn['text'] as String? ?? '',
        status: status,
        language: turn['language'] as String? ?? 'hi-IN',
        createdAt: turn['created_at_ms'] as int? ?? 0,
        sttConfidence: Value(confidence),
      );

      if (role == 'assistant') {
        await database.upsertAssistantMessageAndSummarizeTurn(message);
      } else {
        await database.upsertUserMessageAndExtractMemory(message);
        await database.resolveMemoryTurn(
          turnId: turnId,
          text: turn['text'] as String? ?? '',
          language: turn['language'] as String? ?? 'hi-IN',
          transcriptStatus: status,
          sttConfidence: confidence,
          sttProvider: turn['stt_provider'] as String?,
          sttModel: turn['stt_model'] as String?,
        );
      }
    }

    if (sessionId == afterSessionId) {
      foundCheckpoint = true;
      break;
    }
  }

  if (!foundCheckpoint) {
    throw StateError('unknown replay checkpoint: $afterSessionId');
  }
}

Map<String, dynamic> _toMemoryBlock(MemoryRecord record) {
  List<String> sourceTurnIds;
  try {
    sourceTurnIds = (jsonDecode(record.sourceTurnIdsJson) as List<dynamic>)
        .map((value) => value.toString())
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

Object? _decodeValue(String value) {
  try {
    return jsonDecode(value);
  } catch (_) {
    return value;
  }
}
