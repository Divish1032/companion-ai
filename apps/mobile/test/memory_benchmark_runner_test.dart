import 'dart:convert';
import 'dart:io';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final benchmarkPath = Platform.environment['BENCHMARK_JSON'];
  if (benchmarkPath == null || benchmarkPath.isEmpty) {
    stderr.writeln('SKIP: BENCHMARK_JSON environment variable not set');
    return;
  }

  final benchmarkJson = File(benchmarkPath).readAsStringSync();
  final benchmark = jsonDecode(benchmarkJson) as Map<String, dynamic>;
  final categories = benchmark['categories'] as Map<String, dynamic>? ?? {};
  final seedSessions = benchmark['seed_sessions'] as List<dynamic>? ?? [];
  final queries = benchmark['queries'] as List<dynamic>? ?? [];

  if (queries.isEmpty) {
    stderr.writeln('Benchmark has no queries');
    exitCode = 1;
    return;
  }

  test('benchmark: retrieval metrics', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await _seedData(database, seedSessions);

    final queryResults = <Map<String, dynamic>>[];
    for (final q in queries) {
      final queryData = q as Map<String, dynamic>;
      final text = queryData['text'] as String? ?? '';
      final relevantLabels =
          (queryData['relevant_labels'] as List<dynamic>?)?.cast<String>() ??
          [];
      final irrelevantLabels =
          (queryData['irrelevant_labels'] as List<dynamic>?)?.cast<String>() ??
          [];
      final category = queryData['category'] as String? ?? 'general';

      final memories = await database.readMemoryContext(
        latestUserText: text,
        limit: 6,
      );

      final returnedLabels = memories.map((m) => m.label).toList();
      final returnedIds = memories.map((m) => m.id).toList();

      final result = _evaluateQuery(
        text: text,
        category: category,
        returnedLabels: returnedLabels,
        returnedIds: returnedIds,
        relevantLabels: relevantLabels,
        irrelevantLabels: irrelevantLabels,
      );
      queryResults.add(result);
    }

    final byCategory = _aggregateByCategory(queryResults);
    final overall = _computeOverall(queryResults, categories);

    final output = {
      'query_results': queryResults,
      'by_category': byCategory,
      'overall': overall,
      'total_queries': queries.length,
      'seed_memory_count':
          (await database.select(database.memoryRecords).get()).length,
    };

    stdout.writeln(jsonEncode(output));
  });
}

Future<void> _seedData(AppDatabase database, List<dynamic> sessions) async {
  int baseOffset = 0;
  for (final session in sessions) {
    final sessionData = session as Map<String, dynamic>;
    final sessionKey = sessionData['session_key'] as String? ?? 's';
    final turns = sessionData['turns'] as List<dynamic>? ?? [];

    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i] as Map<String, dynamic>;
      final role = turn['role'] as String? ?? 'user';
      final text = turn['text'] as String? ?? '';
      final status = turn['transcript_status'] as String? ?? 'final';
      final confidence = (turn['stt_confidence'] as num?)?.toDouble();

      final msgId = 'seed_${sessionKey}_$i';
      final turnId = '${sessionKey}_t$i';
      final createdAt = baseOffset + (i * 100);

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
}

Map<String, dynamic> _evaluateQuery({
  required String text,
  required String category,
  required List<String> returnedLabels,
  required List<String> returnedIds,
  required List<String> relevantLabels,
  required List<String> irrelevantLabels,
}) {
  final returnedSet = returnedLabels.toSet();
  final relevantSet = relevantLabels.toSet();

  double precision;
  double recall;

  if (relevantLabels.isEmpty) {
    recall = 1.0;
    precision = returnedLabels.isEmpty ? 1.0 : 0.0;
  } else {
    final truePositives = returnedSet.intersection(relevantSet).length;
    precision = returnedLabels.isEmpty
        ? 1.0
        : truePositives / returnedLabels.length;
    recall = truePositives / relevantLabels.length;
  }

  double mrr = 0.0;
  if (relevantLabels.isNotEmpty) {
    for (int i = 0; i < returnedLabels.length; i++) {
      if (relevantSet.contains(returnedLabels[i])) {
        mrr = 1.0 / (i + 1);
        break;
      }
    }
  }

  double f1 = 0.0;
  if (precision + recall > 0) {
    f1 = 2 * (precision * recall) / (precision + recall);
  }

  final irrelevantReturned = returnedSet
      .intersection(irrelevantLabels.toSet())
      .length;

  return {
    'query_text_hash': _hashText(text),
    'category': category,
    'returned_labels': returnedLabels,
    'returned_count': returnedLabels.length,
    'relevant_labels': relevantLabels,
    'precision': precision,
    'recall': recall,
    'f1': f1,
    'mrr': mrr,
    'irrelevant_intrusions': irrelevantReturned,
    'passed':
        irrelevantReturned == 0 && (relevantLabels.isEmpty || recall >= 0.5),
  };
}

Map<String, dynamic> _aggregateByCategory(List<Map<String, dynamic>> results) {
  final byCategory = <String, List<Map<String, dynamic>>>{};
  for (final r in results) {
    final cat = r['category'] as String;
    byCategory.putIfAbsent(cat, () => []).add(r);
  }

  final aggregated = <String, Map<String, dynamic>>{};
  for (final entry in byCategory.entries) {
    final cat = entry.key;
    final items = entry.value;
    final n = items.length;

    aggregated[cat] = {
      'query_count': n,
      'avg_precision': _avg(items, 'precision'),
      'avg_recall': _avg(items, 'recall'),
      'avg_f1': _avg(items, 'f1'),
      'avg_mrr': _avg(items, 'mrr'),
      'total_irrelevant_intrusions': items.fold<int>(
        0,
        (sum, r) => sum + (r['irrelevant_intrusions'] as int),
      ),
      'pass_count': items.where((r) => r['passed'] as bool).length,
      'fail_count': items.where((r) => !(r['passed'] as bool)).length,
    };
  }
  return aggregated;
}

Map<String, dynamic> _computeOverall(
  List<Map<String, dynamic>> results,
  Map<String, dynamic> categories,
) {
  final n = results.length;
  final relevantResults = results
      .where((r) => (r['relevant_labels'] as List).isNotEmpty)
      .toList();
  final generalResults = results
      .where((r) => (r['relevant_labels'] as List).isEmpty)
      .toList();

  return {
    'total_queries': n,
    'relevant_queries': relevantResults.length,
    'general_queries': generalResults.length,
    'avg_precision': _avg(results, 'precision'),
    'avg_recall': _avg(relevantResults, 'recall'),
    'avg_f1': _avg(relevantResults, 'f1'),
    'avg_mrr': _avg(relevantResults, 'mrr'),
    'total_irrelevant_intrusions': results.fold<int>(
      0,
      (sum, r) => sum + (r['irrelevant_intrusions'] as int),
    ),
    'pass_count': results.where((r) => r['passed'] as bool).length,
    'fail_count': results.where((r) => !(r['passed'] as bool)).length,
  };
}

double _avg(List<Map<String, dynamic>> items, String key) {
  if (items.isEmpty) return 0.0;
  return items.fold<double>(0, (s, r) => s + (r[key] as double)) / items.length;
}

String _hashText(String text) {
  final bytes = utf8.encode(text);
  var hash = 0;
  for (final b in bytes) {
    hash = ((hash << 5) - hash + b) & 0x3FFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
