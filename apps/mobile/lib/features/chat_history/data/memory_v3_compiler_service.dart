import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'app_database.dart';
import 'memory_v3_compiler_store.dart';
import 'memory_v3_models.dart';

final memoryV3CompilerClientProvider = Provider<MemoryV3CompilerClient>((ref) {
  return HttpMemoryV3CompilerClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
  );
});

final memoryV3CompilerCoordinatorProvider =
    Provider<MemoryV3CompilerCoordinator>((ref) {
      final config = ref.watch(appConfigProvider);
      final coordinator = MemoryV3CompilerCoordinator(
        database: ref.watch(appDatabaseProvider),
        client: ref.watch(memoryV3CompilerClientProvider),
        enabled: config.enableMemoryV3Compiler,
        timezone: config.memoryTimezone,
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

abstract interface class MemoryV3CompilerClient {
  String get provider;
  String get model;
  String get promptVersion;

  Future<MemoryV3CompileEnvelope> compile(MemoryV3CompileJobBundle bundle);
}

class HttpMemoryV3CompilerClient implements MemoryV3CompilerClient {
  const HttpMemoryV3CompilerClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client;

  final String baseUrl;
  final http.Client? _client;
  final Duration timeout;

  @override
  String get provider => 'api';

  @override
  String get model => 'server_configured';

  @override
  String get promptVersion => 'memory_semantic_atoms_v3_1';

  @override
  Future<MemoryV3CompileEnvelope> compile(
    MemoryV3CompileJobBundle bundle,
  ) async {
    final client = _client ?? http.Client();
    final shouldClose = _client == null;
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/v1/memory/compile'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(bundle.toRequestJson()),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw MemoryV3CompilerException(response.statusCode);
      }
      return MemoryV3CompileEnvelope.parse(bundle.job.id, response.body);
    } finally {
      if (shouldClose) client.close();
    }
  }
}

class MemoryV3CompilerCoordinator {
  MemoryV3CompilerCoordinator({
    required this.database,
    required this.client,
    required this.enabled,
    required this.timezone,
    this.maxJobsPerDrain = 4,
    this.idleDelay = const Duration(seconds: 15),
    this.continuationDelay = const Duration(seconds: 1),
  }) : assert(maxJobsPerDrain > 0);

  final AppDatabase database;
  final MemoryV3CompilerClient client;
  final bool enabled;
  final String timezone;
  final int maxJobsPerDrain;
  final Duration idleDelay;
  final Duration continuationDelay;
  Timer? _idleTimer;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  Future<void> enqueueCompletedTurn({
    required String sessionId,
    required String turnId,
  }) async {
    if (!enabled || _disposed) return;
    await database.enqueueMemoryV3CompileJob(
      sessionId: sessionId,
      turnId: turnId,
      timezone: timezone,
    );
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDelay, () => unawaited(processPending()));
  }

  Future<void> processPending() {
    if (!enabled || _disposed) return Future<void>.value();
    _queue = _queue.catchError((_) {}).then((_) => _drain());
    return _queue;
  }

  Future<void> _drain() async {
    for (var processed = 0; processed < maxJobsPerDrain; processed += 1) {
      final job = await database.claimNextMemoryV3CompileJob();
      if (job == null) {
        await _scheduleNextReadyJob();
        return;
      }
      final startedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        final bundle = await database.readMemoryV3CompileBundle(job);
        if (bundle.messages.isEmpty) {
          await database.failMemoryV3CompileJob(
            job,
            errorCode: 'missing_request_snapshot',
            retryable: false,
            runStatus: 'rejected',
            startedAtMs: startedAt,
            provider: client.provider,
            model: client.model,
            promptVersion: client.promptVersion,
          );
          continue;
        }
        final envelope = await client.compile(bundle);
        await database.applyMemoryV3CompileEnvelope(
          bundle: bundle,
          envelope: envelope,
          startedAtMs: startedAt,
        );
      } catch (error) {
        final runStatus = switch (error) {
          TimeoutException() => 'timeout',
          FormatException() => 'invalid',
          MemoryV3CompilerException(:final statusCode)
              when statusCode >= 400 && statusCode < 500 && statusCode != 429 =>
            'rejected',
          _ => 'unavailable',
        };
        final retryable = switch (error) {
          MemoryV3CompilerException(:final retryable) => retryable,
          _ => true,
        };
        await database.failMemoryV3CompileJob(
          job,
          errorCode: switch (error) {
            MemoryV3CompilerException(:final statusCode) => 'http_$statusCode',
            TimeoutException() => 'compiler_timeout',
            FormatException() => 'invalid_compiler_response',
            _ => error.runtimeType.toString(),
          },
          retryable: retryable,
          runStatus: runStatus,
          startedAtMs: startedAt,
          provider: client.provider,
          model: client.model,
          promptVersion: client.promptVersion,
        );
        developer.log(
          'memory_v3_compile_failed '
          '{job_id: ${job.id}, attempt: ${job.attempts}, '
          'status: $runStatus, error_type: ${error.runtimeType}}',
          name: 'companion.memory.v3',
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

  Future<void> _scheduleNextReadyJob() async {
    if (_disposed) return;
    final delay = await database.nextMemoryV3CompileDelay();
    if (delay == null) return;
    final boundedDelay = delay < continuationDelay ? continuationDelay : delay;
    _idleTimer?.cancel();
    _idleTimer = Timer(boundedDelay, () => unawaited(processPending()));
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
  }
}

class MemoryV3CompilerException implements Exception {
  const MemoryV3CompilerException(this.statusCode);

  final int statusCode;
  bool get retryable => statusCode == 429 || statusCode >= 500;
}
