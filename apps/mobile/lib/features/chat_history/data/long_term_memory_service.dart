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
const memoryJudgeContractVersion = 'memory_judge_v1';

final memoryJudgeClientProvider = Provider<MemoryJudgeClient>((ref) {
  return HttpMemoryJudgeClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
  );
});

final longTermMemoryCoordinatorProvider = Provider<LongTermMemoryCoordinator>((
  ref,
) {
  final coordinator = LongTermMemoryCoordinator(
    database: ref.watch(appDatabaseProvider),
    client: ref.watch(memoryJudgeClientProvider),
    enabled: ref.watch(appConfigProvider).enableMemoryExtraction,
    syncTurnMemories: ref.watch(memoryEmbeddingSyncProvider).syncTurnMemories,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

abstract interface class MemoryJudgeClient {
  Future<MemoryJudgeEnvelope> judge({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  });
}

class HttpMemoryJudgeClient implements MemoryJudgeClient {
  const HttpMemoryJudgeClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client;

  final String baseUrl;
  final http.Client? _client;
  final Duration timeout;

  @override
  Future<MemoryJudgeEnvelope> judge({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  }) async {
    final client = _client ?? http.Client();
    final closeClient = _client == null;
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/v1/memory-judge'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'job_id': jobId,
              'extraction_version': memoryExtractionVersion,
              'judge_contract_version': memoryJudgeContractVersion,
              'language': language,
              'turns': [
                for (final turn in turns.take(8))
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
        throw MemoryJudgeException(response.statusCode);
      }
      return _parseEnvelope(jobId, response.body);
    } finally {
      if (closeClient) client.close();
    }
  }

  MemoryJudgeEnvelope _parseEnvelope(String jobId, String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const FormatException('Memory judge response is not JSON.');
    }
    if (decoded is! Map<String, Object?> ||
        decoded['job_id'] != jobId ||
        decoded['contract_version'] != memoryJudgeContractVersion ||
        decoded['cost'] is! Map<String, Object?> ||
        decoded['decisions'] is! List) {
      throw const FormatException('Invalid memory judge envelope.');
    }
    final rawDecisions = decoded['decisions']! as List<Object?>;
    if (rawDecisions.length > 16 ||
        rawDecisions.any((item) => item is! Map<String, Object?>)) {
      throw const FormatException('Invalid memory judge decision list.');
    }
    return MemoryJudgeEnvelope(
      jobId: jobId,
      cost: MemoryJudgeCost.fromJson(decoded['cost']! as Map<String, Object?>),
      decisions: rawDecisions
          .cast<Map<String, Object?>>()
          .map(MemoryJudgeDecision.fromJson)
          .toList(growable: false),
    );
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
  final MemoryJudgeClient client;
  final bool enabled;
  final Future<void> Function(String turnId)? syncTurnMemories;
  final _outcomes = StreamController<MemoryJudgeOutcome>.broadcast();
  Stream<MemoryJudgeOutcome> get outcomes => _outcomes.stream;
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
      final requestStartedAtMs = DateTime.now().millisecondsSinceEpoch;
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
        final envelope = await client.judge(
          jobId: job.id,
          language: turns.last.language,
          turns: turns,
        );
        // The DB layer validates, resolves local targets, applies mutations,
        // and records the decision-operation ledger in one transaction. The
        // notice below is emitted only after that commit returns.
        final applied = await database.applyMemoryJudgeDecisions(
          job: job,
          decisions: envelope.decisions,
          cost: envelope.cost,
          windowTurnCount: turns.length,
        );
        if (applied.noticeEligible) {
          _outcomes.add(
            MemoryJudgeOutcome(
              jobId: job.id,
              sessionId: job.sessionId,
              turnId: job.endTurnId,
              outcome: applied.supersededCount > 0
                  ? MemoryJudgeOutcomeKind.superseded
                  : applied.appliedCount > 0
                  ? MemoryJudgeOutcomeKind.accepted
                  : MemoryJudgeOutcomeKind.rejected,
              acceptedCount: applied.appliedCount,
              windowTurnCount: turns.length,
              attemptCount: job.attempts,
              requestStartedAtMs: requestStartedAtMs,
              completedAtMs: DateTime.now().millisecondsSinceEpoch,
              costSource: envelope.cost.source,
              inputTokens: envelope.cost.inputTokens,
              outputTokens: envelope.cost.outputTokens,
              estimatedMicroInr: envelope.cost.estimatedMicroInr,
            ),
          );
        }
        if (syncTurnMemories != null) {
          for (final turnId in applied.appliedSourceTurnIds) {
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
          errorCode: switch (error) {
            MemoryJudgeException(:final statusCode) => 'http_$statusCode',
            FormatException() => 'invalid_judge_response',
            _ => error.runtimeType.toString(),
          },
          retryable: error is! MemoryJudgeException || error.retryable,
        );
        developer.log(
          'memory_judge_retry {job_id: ${job.id}, error_type: ${error.runtimeType}}',
          name: 'companion.memory',
        );
        _outcomes.add(
          MemoryJudgeOutcome(
            jobId: job.id,
            sessionId: job.sessionId,
            turnId: job.endTurnId,
            outcome: switch (error) {
              TimeoutException() => MemoryJudgeOutcomeKind.timeout,
              FormatException() => MemoryJudgeOutcomeKind.invalid,
              _ => MemoryJudgeOutcomeKind.unavailable,
            },
            acceptedCount: 0,
            windowTurnCount: 0,
            attemptCount: job.attempts,
            requestStartedAtMs: requestStartedAtMs,
            completedAtMs: DateTime.now().millisecondsSinceEpoch,
            costSource: 'unknown',
            inputTokens: 0,
            outputTokens: 0,
            estimatedMicroInr: 0,
          ),
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
    _outcomes.close();
  }
}

enum MemoryJudgeOutcomeKind {
  accepted,
  superseded,
  rejected,
  unavailable,
  timeout,
  invalid,
}

class MemoryJudgeOutcome {
  const MemoryJudgeOutcome({
    required this.jobId,
    required this.sessionId,
    required this.turnId,
    required this.outcome,
    required this.acceptedCount,
    required this.windowTurnCount,
    required this.attemptCount,
    required this.requestStartedAtMs,
    required this.completedAtMs,
    required this.costSource,
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedMicroInr,
  });
  final String jobId;
  final String sessionId;
  final String turnId;
  final MemoryJudgeOutcomeKind outcome;
  final int acceptedCount;
  final int windowTurnCount;
  final int attemptCount;
  final int requestStartedAtMs;
  final int completedAtMs;
  final String costSource;
  final int inputTokens;
  final int outputTokens;
  final int estimatedMicroInr;
}

class MemoryJudgeException implements Exception {
  const MemoryJudgeException(this.statusCode);
  final int statusCode;

  bool get retryable =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;
}
