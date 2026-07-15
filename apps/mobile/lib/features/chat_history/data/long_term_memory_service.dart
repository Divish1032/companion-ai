import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'app_database.dart';
import 'memory_candidate_model.dart';
import 'memory_embedding_service.dart';

const memoryExtractionVersion = 'v1';

final memoryCandidateClientProvider = Provider<MemoryCandidateClient>((ref) {
  return HttpMemoryCandidateClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
  );
});

final longTermMemoryCoordinatorProvider = Provider<LongTermMemoryCoordinator>((
  ref,
) {
  final coordinator = LongTermMemoryCoordinator(
    database: ref.watch(appDatabaseProvider),
    client: ref.watch(memoryCandidateClientProvider),
    enabled: ref.watch(appConfigProvider).enableMemoryExtraction,
    syncTurnMemories: ref.watch(memoryEmbeddingSyncProvider).syncTurnMemories,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

abstract interface class MemoryCandidateClient {
  Future<List<ExtractedMemoryCandidate>> extract({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  });
}

class HttpMemoryCandidateClient implements MemoryCandidateClient {
  const HttpMemoryCandidateClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client;

  final String baseUrl;
  final http.Client? _client;
  final Duration timeout;

  @override
  Future<List<ExtractedMemoryCandidate>> extract({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  }) async {
    final client = _client ?? http.Client();
    final closeClient = _client == null;
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/v1/memory-candidates'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'job_id': jobId,
              'extraction_version': memoryExtractionVersion,
              'language': language,
              'turns': [
                for (final turn in turns)
                  {
                    'turn_id': turn.turnId,
                    'role': turn.role == 'ai' ? 'assistant' : turn.role,
                    'text': turn.messageText,
                    'created_at_ms': turn.createdAt,
                    'status': turn.status,
                    'confidence': turn.sttConfidence,
                  },
              ],
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw MemoryCandidateException(response.statusCode);
      }
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      if (decoded['job_id'] != jobId ||
          decoded['extraction_version'] != memoryExtractionVersion ||
          decoded['candidates'] is! List) {
        throw const FormatException('Invalid memory candidate envelope.');
      }
      final rawCandidates = decoded['candidates']! as List<Object?>;
      if (rawCandidates.any((item) => item is! Map<String, Object?>)) {
        throw const FormatException('Invalid memory candidate item.');
      }
      return rawCandidates
          .cast<Map<String, Object?>>()
          .map(ExtractedMemoryCandidate.fromJson)
          .toList(growable: false);
    } finally {
      if (closeClient) client.close();
    }
  }
}

class LongTermMemoryCoordinator {
  LongTermMemoryCoordinator({
    required this.database,
    required this.client,
    required this.enabled,
    this.syncTurnMemories,
    this.maxJobsPerDrain = 4,
    this.continuationDelay = const Duration(seconds: 1),
  }) : assert(maxJobsPerDrain > 0);

  final AppDatabase database;
  final MemoryCandidateClient client;
  final bool enabled;
  final Future<void> Function(String turnId)? syncTurnMemories;
  final int maxJobsPerDrain;
  final Duration continuationDelay;
  Timer? _idleTimer;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  Future<void> enqueueCompletedTurn({
    required String sessionId,
    required String turnId,
  }) async {
    if (!enabled || _disposed) return;
    await database.enqueueMemoryExtractionJob(
      sessionId: sessionId,
      turnId: turnId,
      extractionVersion: memoryExtractionVersion,
    );
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 15), () {
      unawaited(processPending());
    });
  }

  Future<void> processPending() {
    if (!enabled || _disposed) return Future<void>.value();
    _queue = _queue.catchError((_) {}).then((_) => _drain());
    return _queue;
  }

  Future<void> _drain() async {
    for (var processed = 0; processed < maxJobsPerDrain; processed += 1) {
      final job = await database.claimNextMemoryExtractionJob();
      if (job == null) return;
      try {
        final turns = await database.readExtractionWindow(job);
        if (turns.isEmpty) {
          await database.failMemoryExtractionJob(
            job,
            errorCode: 'missing_completed_turns',
            retryable: false,
          );
          continue;
        }
        final candidates = await client.extract(
          jobId: job.id,
          language: turns.last.language,
          turns: turns,
        );
        await database.validateAndApplyMemoryCandidates(
          job: job,
          candidates: candidates,
        );
        if (syncTurnMemories != null) {
          final sourceTurnIds = {
            for (final candidate in candidates) ...candidate.sourceTurnIds,
          };
          for (final turnId in sourceTurnIds) {
            try {
              await syncTurnMemories!(turnId);
            } catch (error) {
              developer.log(
                'memory_embedding_sync_failed '
                '{job_id: ${job.id}, error_type: ${error.runtimeType}}',
                name: 'companion.memory',
              );
            }
          }
        }
      } catch (error) {
        await database.failMemoryExtractionJob(
          job,
          errorCode: error is MemoryCandidateException
              ? 'http_${error.statusCode}'
              : error.runtimeType.toString(),
          retryable: error is! MemoryCandidateException || error.retryable,
        );
        developer.log(
          'memory_extraction_retry {job_id: ${job.id}, error_type: ${error.runtimeType}}',
          name: 'companion.memory',
        );
      }
    }
    if (!_disposed) {
      _idleTimer?.cancel();
      _idleTimer = Timer(continuationDelay, () {
        unawaited(processPending());
      });
    }
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
  }
}

class MemoryCandidateException implements Exception {
  const MemoryCandidateException(this.statusCode);
  final int statusCode;

  bool get retryable =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;
}
