import 'dart:async';
import 'dart:convert';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/chat_history/data/long_term_memory_service.dart';
import 'package:companion_mobile/features/chat_history/data/memory_candidate_model.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('completed turn creates an idempotent extraction job', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    await database.enqueueMemoryExtractionJob(
      sessionId: 's1',
      turnId: 't1',
      extractionVersion: 'v1',
    );
    await database.enqueueMemoryExtractionJob(
      sessionId: 's1',
      turnId: 't1',
      extractionVersion: 'v1',
    );
    await _completedTurn(database, sessionId: 's1', turnId: 't2');
    await database.enqueueMemoryExtractionJob(
      sessionId: 's1',
      turnId: 't2',
      extractionVersion: 'v1',
    );

    final jobs = await database.select(database.memoryExtractionJobs).get();
    expect(jobs, hasLength(1));
    expect(jobs.single.startTurnId, 't1');
    expect(jobs.single.endTurnId, 't2');
    final window = await database.readExtractionWindow(jobs.single);
    expect(window, hasLength(4));
    expect(window.map((row) => row.turnId).toSet(), {'t1', 't2'});
  });

  test(
    'background coordinator drains a completed exchange without blocking the turn',
    () async {
      await _completedTurn(database, sessionId: 's1', turnId: 't1');
      final syncedTurns = <String>[];
      final coordinator = LongTermMemoryCoordinator(
        database: database,
        client: _FakeCandidateClient(),
        enabled: true,
        syncTurnMemories: (turnId) async => syncedTurns.add(turnId),
      );
      addTearDown(coordinator.dispose);

      await coordinator.enqueueCompletedTurn(sessionId: 's1', turnId: 't1');
      await coordinator.processPending();

      final job = await database
          .select(database.memoryExtractionJobs)
          .getSingle();
      expect(job.status, 'succeeded');
      final memories = await database.select(database.memoryRecords).get();
      expect(memories.single.kind, 'episodic');
      expect(memories.single.sourceTurnIdsJson, '["t1"]');
      expect(syncedTurns, ['t1']);
    },
  );

  test(
    'embedding sync failure does not retry an admitted extraction job',
    () async {
      await _completedTurn(database, sessionId: 's1', turnId: 't1');
      final coordinator = LongTermMemoryCoordinator(
        database: database,
        client: _FakeCandidateClient(),
        enabled: true,
        syncTurnMemories: (_) async => throw StateError('derived index failed'),
      );
      addTearDown(coordinator.dispose);

      await coordinator.enqueueCompletedTurn(sessionId: 's1', turnId: 't1');
      await coordinator.processPending();

      final job = await database
          .select(database.memoryExtractionJobs)
          .getSingle();
      expect(job.status, 'succeeded');
      expect(await database.select(database.memoryRecords).get(), hasLength(1));
    },
  );

  test('non-retryable extractor response makes the job terminal', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    final coordinator = LongTermMemoryCoordinator(
      database: database,
      client: const _FailingCandidateClient(400),
      enabled: true,
    );
    addTearDown(coordinator.dispose);

    await coordinator.enqueueCompletedTurn(sessionId: 's1', turnId: 't1');
    await coordinator.processPending();

    final job = await database
        .select(database.memoryExtractionJobs)
        .getSingle();
    expect(job.status, 'dead');
    expect(job.attempts, 1);
  });

  test('retryable jobs back off, cap attempts, and become terminal', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    await database.enqueueMemoryExtractionJob(
      sessionId: 's1',
      turnId: 't1',
      extractionVersion: memoryExtractionVersion,
    );
    MemoryExtractionJob? claimed;
    for (var attempt = 1; attempt <= 5; attempt += 1) {
      claimed = await database.claimNextMemoryExtractionJob();
      expect(claimed, isA<MemoryExtractionJob>());
      expect(claimed!.attempts, attempt);
      await database.failMemoryExtractionJob(
        claimed,
        errorCode: 'http_503',
        retryable: true,
      );
      final failed = await database
          .select(database.memoryExtractionJobs)
          .getSingle();
      expect(failed.status, attempt == 5 ? 'dead' : 'retry');
      if (attempt < 5) {
        await (database.update(
          database.memoryExtractionJobs,
        )..where((row) => row.id.equals(failed.id))).write(
          const MemoryExtractionJobsCompanion(nextAttemptAt: Value(0)),
        );
      }
    }
    expect(await database.claimNextMemoryExtractionJob(), equals(null));
  });

  test(
    'stale processing lease is reclaimed after an interrupted worker',
    () async {
      await _completedTurn(database, sessionId: 's1', turnId: 't1');
      await database.enqueueMemoryExtractionJob(
        sessionId: 's1',
        turnId: 't1',
        extractionVersion: memoryExtractionVersion,
      );
      final queued = await database
          .select(database.memoryExtractionJobs)
          .getSingle();
      await (database.update(
        database.memoryExtractionJobs,
      )..where((row) => row.id.equals(queued.id))).write(
        const MemoryExtractionJobsCompanion(
          status: Value('processing'),
          attempts: Value(1),
          updatedAt: Value(0),
        ),
      );

      final reclaimed = await database.claimNextMemoryExtractionJob();

      expect(reclaimed, isA<MemoryExtractionJob>());
      expect(reclaimed!.status, 'processing');
      expect(reclaimed.attempts, 2);
    },
  );

  test('HTTP candidate client times out and rejects malformed items', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    final turns = await database.select(database.chatMessages).get();
    final timeoutClient = HttpMemoryCandidateClient(
      baseUrl: 'http://api.test',
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      timeoutClient.extract(jobId: 'job', language: 'hi-IN', turns: turns),
      throwsA(isA<TimeoutException>()),
    );

    final validClient = HttpMemoryCandidateClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'job_id': 'job',
            'extraction_version': memoryExtractionVersion,
            'judge_contract_version': memoryJudgeContractVersion,
            'outcome': 'accepted',
            'cost_source': 'unknown',
            'candidates': [
              {
                'candidate_kind': 'episode',
                'subject': 'user',
                'predicate': 'attended_interview',
                'object_text': 'design interview',
                'event_start_at_ms': null,
                'event_end_at_ms': null,
                'temporal_status': 'past',
                'explicitness': 'explicit',
                'confidence': 0.9,
                'future_utility': 0.8,
                'sensitivity': 'normal',
                'source_turn_ids': ['t1'],
                'evidence_role': 'user',
                'suggested_action': 'ADD',
                'follow_up_allowed': false,
                'proactive_allowed': false,
              },
            ],
          }),
          200,
        ),
      ),
    );
    final parsed = await validClient.extract(
      jobId: 'job',
      language: 'hi-IN',
      turns: turns,
    );
    expect(parsed.single.kind, 'episode');

    final malformedClient = HttpMemoryCandidateClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'job_id': 'job',
            'extraction_version': memoryExtractionVersion,
            'judge_contract_version': memoryJudgeContractVersion,
            'outcome': 'rejected',
            'cost_source': 'unknown',
            'candidates': [42],
          }),
          200,
        ),
      ),
    );
    await expectLater(
      malformedClient.extract(jobId: 'job', language: 'hi-IN', turns: turns),
      throwsA(isA<FormatException>()),
    );
  });

  test('long sessions are split into bounded four-exchange jobs', () async {
    for (var index = 1; index <= 5; index += 1) {
      final turnId = 't$index';
      await _completedTurn(database, sessionId: 's1', turnId: turnId);
      await database.enqueueMemoryExtractionJob(
        sessionId: 's1',
        turnId: turnId,
        extractionVersion: 'v1',
      );
    }

    final jobs = await database.select(database.memoryExtractionJobs).get()
      ..sort((left, right) => left.startTurnId.compareTo(right.startTurnId));
    expect(jobs, hasLength(2));
    expect(jobs.first.startTurnId, 't1');
    expect(jobs.first.endTurnId, 't4');
    expect(jobs.last.startTurnId, 't5');
    expect(await database.readExtractionWindow(jobs.first), hasLength(8));
    expect(await database.readExtractionWindow(jobs.last), hasLength(2));
  });

  test(
    'coordinator schedules continuation when more than one drain batch exists',
    () async {
      for (var index = 1; index <= 20; index += 1) {
        final turnId = 't$index';
        await _completedTurn(database, sessionId: 's1', turnId: turnId);
        await database.enqueueMemoryExtractionJob(
          sessionId: 's1',
          turnId: turnId,
          extractionVersion: memoryExtractionVersion,
        );
      }
      expect(
        await database.select(database.memoryExtractionJobs).get(),
        hasLength(5),
      );
      final coordinator = LongTermMemoryCoordinator(
        database: database,
        client: const _EmptyCandidateClient(),
        enabled: true,
        maxJobsPerDrain: 4,
        continuationDelay: const Duration(milliseconds: 1),
      );
      addTearDown(coordinator.dispose);

      await coordinator.processPending();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final jobs = await database.select(database.memoryExtractionJobs).get();
      expect(jobs.map((job) => job.status), everyElement('succeeded'));
    },
  );

  test(
    'validated episode keeps provenance and expands source turn window',
    () async {
      await _completedTurn(database, sessionId: 's1', turnId: 't1');
      final job = await _claimJob(database, 's1', 't1');

      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'episode',
            subject: 'user',
            predicate: 'attended_interview',
            objectText: 'Had an important design interview',
            temporalStatus: 'past',
            explicitness: 'explicit',
            confidence: 0.94,
            futureUtility: 0.82,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );

      final episodes = await database.select(database.memoryEpisodes).get();
      expect(episodes, hasLength(1));
      expect(episodes.single.sourceTurnIdsJson, '["t1"]');
      final memories = await database.readMemoryContext(
        latestUserText: 'design interview kaisa raha',
        limit: 3,
        route: 'episodic',
      );
      expect(memories, hasLength(1));
      expect(memories.single.content, contains('Context:'));
      expect(
        memories.single.content,
        contains('user: Friday ko mera design interview tha'),
      );
    },
  );

  test(
    'grounded Hindi interview episode is admitted for durable recall',
    () async {
      const transcript =
          'मेरा डिजाइन इंटरव्यू हुआ था सिस्टम डिजाइन राउंड मुझे अच्छा नहीं लगता';
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: transcript,
        runDeterministicMemory: false,
      );
      final job = await _claimJob(database, 's1', 't1');

      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'episode',
            subject: 'Design interview',
            predicate: 'had_difficult_system_design_round',
            objectText: transcript,
            temporalStatus: 'past',
            explicitness: 'explicit',
            confidence: 0.9,
            futureUtility: 0.8,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );

      final episodes = await database.select(database.memoryEpisodes).get();
      expect(episodes, hasLength(1));
      expect(episodes.single.summary, transcript);
    },
  );

  test('assistant-only text cannot become a user fact', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    final job = await _claimJob(database, 's1', 't1');
    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'goal',
          subject: 'user',
          predicate: 'wants_promotion',
          objectText: 'Wants a promotion',
          temporalStatus: 'current',
          explicitness: 'assistant_only',
          confidence: 0.9,
          futureUtility: 0.8,
          sensitivity: 'normal',
          sourceTurnIds: ['t1'],
          evidenceRole: 'assistant',
          suggestedAction: 'ADD',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    final audit = await database.select(database.memoryCandidates).getSingle();
    expect(audit.decisionState, 'rejected');
    expect(audit.decisionReason, 'assistant_cannot_prove_user_fact');
  });

  test(
    'open thread is found from a vague follow-up and can be forgotten',
    () async {
      await _completedTurn(database, sessionId: 's1', turnId: 't1');
      final job = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'open_thread',
            subject: 'user',
            predicate: 'has_interview',
            objectText: 'Interview on Friday',
            temporalStatus: 'future',
            explicitness: 'explicit',
            confidence: 0.95,
            futureUtility: 0.9,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: true,
            proactiveAllowed: false,
          ),
        ],
      );

      final memories = await database.readMemoryContext(
        latestUserText: 'Woh kaisa raha?',
        limit: 3,
        route: 'episodic',
      );
      expect(memories.single.content, contains('Interview on Friday'));
      await database.forgetMemory(memories.single.id);
      expect(await database.select(database.memoryOpenThreads).get(), isEmpty);
      expect(await database.select(database.memoryRecords).get(), isEmpty);
      expect(await database.select(database.memoryCandidates).get(), isEmpty);
    },
  );

  test(
    'grounded personal LLM candidate is implicitly admitted without a prompt',
    () async {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: 'Asha meri close friend hai',
      );
      final job = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'relationship',
            subject: 'user',
            predicate: 'has_close_friend',
            objectText: 'Asha is a close friend',
            temporalStatus: 'current',
            explicitness: 'explicit',
            confidence: 0.9,
            futureUtility: 0.75,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );
      final record = await database.select(database.memoryRecords).getSingle();
      expect(record.receiptState, 'implicit');
      expect(
        await database.readMemoryContext(latestUserText: 'Asha', limit: 3),
        isNotEmpty,
      );
      // Relationship memories are recalled only for a relevant turn, not
      // injected into generic session-start context.
      expect(await database.readSessionStartMemoryContext(limit: 3), isEmpty);
      final audit = await database
          .select(database.memoryCandidates)
          .getSingle();
      expect(audit.decisionState, 'admitted');
    },
  );

  test('voice rejection forgets the most recent implicit LLM memory', () async {
    await _completedTurn(
      database,
      sessionId: 's1',
      turnId: 't1',
      userText: 'Asha meri close friend hai',
    );
    final job = await _claimJob(database, 's1', 't1');
    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'relationship',
          subject: 'user',
          predicate: 'has_close_friend',
          objectText: 'Asha is a close friend',
          temporalStatus: 'current',
          explicitness: 'explicit',
          confidence: 0.9,
          futureUtility: 0.75,
          sensitivity: 'normal',
          sourceTurnIds: ['t1'],
          evidenceRole: 'user',
          suggestedAction: 'ADD',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    await database.upsertUserMessageAndExtractMemory(
      ChatMessagesCompanion.insert(
        id: 't2_user',
        sessionId: 's1',
        turnId: 't2',
        role: 'user',
        messageText: 'nahi yaad mat rakhna',
        status: 'final',
        language: 'hi-IN',
        createdAt: 100,
        sttConfidence: const Value(0.98),
      ),
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    expect(await database.select(database.memoryCandidates).get(), isEmpty);
  });

  test(
    'explicit goal replacement supersedes only its prior semantic target',
    () async {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: 'I want to learn guitar',
        runDeterministicMemory: false,
      );
      final firstJob = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: firstJob,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'goal',
            subject: 'user',
            predicate: 'learning_goal',
            objectText: 'learn guitar',
            temporalStatus: 'current',
            explicitness: 'explicit',
            confidence: 0.94,
            futureUtility: 0.82,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );

      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't2',
        userText: 'I now want to learn piano instead of guitar',
        runDeterministicMemory: false,
      );
      final secondJob = await _claimJob(database, 's1', 't2');
      await database.validateAndApplyMemoryCandidates(
        job: secondJob,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'goal',
            subject: 'user',
            predicate: 'learning_goal',
            objectText: 'learn piano instead of guitar',
            temporalStatus: 'current',
            explicitness: 'explicit',
            confidence: 0.95,
            futureUtility: 0.85,
            sensitivity: 'normal',
            sourceTurnIds: ['t2'],
            evidenceRole: 'user',
            suggestedAction: 'SUPERSEDE',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );

      final records = await database.select(database.memoryRecords).get();
      expect(records, hasLength(2));
      final oldRecord = records.singleWhere(
        (row) => row.content.contains('piano') == false,
      );
      final newRecord = records.singleWhere(
        (row) => row.content.contains('piano'),
      );
      expect(oldRecord.supersededBy, newRecord.id);
      expect(oldRecord.temporalStatus, 'past');
      final contradiction = await database
          .select(database.memoryContradictions)
          .getSingle();
      expect(contradiction.oldMemoryId, oldRecord.id);
      expect(contradiction.newMemoryId, newRecord.id);

      final retrieved = await database.readMemoryContext(
        latestUserText: 'what is my learning goal piano guitar',
        limit: 5,
      );
      expect(retrieved.map((row) => row.id), [newRecord.id]);

      await database.forgetMemory(newRecord.id);
      expect(
        await database.select(database.memoryContradictions).get(),
        isEmpty,
      );
    },
  );

  test('sensitive candidate fails closed', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    final job = await _claimJob(database, 's1', 't1');
    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'episode',
          subject: 'user',
          predicate: 'medical_fact',
          objectText: 'Private medical detail',
          temporalStatus: 'current',
          explicitness: 'explicit',
          confidence: 0.99,
          futureUtility: 0.9,
          sensitivity: 'sensitive',
          sourceTurnIds: ['t1'],
          evidenceRole: 'user',
          suggestedAction: 'ADD',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
  });

  test(
    'locally detected sensitive evidence fails closed when mislabeled',
    () async {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: 'My doctor said I have diabetes',
        runDeterministicMemory: false,
      );
      final job = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'goal',
            subject: 'user',
            predicate: 'manage_diabetes',
            objectText: 'manage diabetes after doctor diagnosis',
            temporalStatus: 'current',
            explicitness: 'explicit',
            confidence: 0.99,
            futureUtility: 0.9,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );

      expect(await database.select(database.memoryRecords).get(), isEmpty);
      expect(
        (await database.select(database.memoryCandidates).getSingle())
            .decisionReason,
        'sensitive_memory_requires_explicit_opt_in',
      );
    },
  );

  test('candidate provenance is limited to the claimed job window', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    final job = await _claimJob(database, 's1', 't1');
    await _completedTurn(
      database,
      sessionId: 's1',
      turnId: 't2',
      userText: 'I want to learn piano',
      runDeterministicMemory: false,
    );

    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'goal',
          subject: 'user',
          predicate: 'learning_goal',
          objectText: 'learn piano',
          temporalStatus: 'current',
          explicitness: 'explicit',
          confidence: 0.95,
          futureUtility: 0.8,
          sensitivity: 'normal',
          sourceTurnIds: ['t2'],
          evidenceRole: 'user',
          suggestedAction: 'ADD',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    expect(
      (await database.select(database.memoryCandidates).getSingle())
          .decisionReason,
      'invalid_or_unverifiable_schema',
    );
  });

  test('a rejected hypothesis cannot bootstrap implied recurrence', () async {
    for (final turnId in ['t1', 't2']) {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: turnId,
        userText: 'I sometimes practice guitar',
        runDeterministicMemory: false,
      );
      final job = await _claimJob(database, 's1', turnId);
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: [
          ExtractedMemoryCandidate(
            kind: 'routine',
            subject: 'user',
            predicate: 'practice_routine',
            objectText: 'sometimes practice guitar',
            temporalStatus: 'current',
            explicitness: 'implied',
            confidence: 0.8,
            futureUtility: 0.7,
            sensitivity: 'normal',
            sourceTurnIds: [turnId],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );
    }

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    final audits = await database.select(database.memoryCandidates).get();
    expect(audits.map((row) => row.decisionState), everyElement('rejected'));
  });

  test('high-confidence but ungrounded LLM proposal is rejected', () async {
    await _completedTurn(database, sessionId: 's1', turnId: 't1');
    final job = await _claimJob(database, 's1', 't1');
    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'goal',
          subject: 'user',
          predicate: 'plans_marathon',
          objectText: 'Will run a marathon in Mumbai',
          temporalStatus: 'future',
          explicitness: 'explicit',
          confidence: 0.99,
          futureUtility: 0.95,
          sensitivity: 'normal',
          sourceTurnIds: ['t1'],
          evidenceRole: 'user',
          suggestedAction: 'ADD',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    final audit = await database.select(database.memoryCandidates).getSingle();
    expect(audit.decisionReason, 'candidate_not_lexically_grounded');
  });

  test(
    'implicitly admitted personal memory does not expand into unrelated recall',
    () async {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: 'Asha is my close friend and manager at office',
      );
      final job = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'relationship',
            subject: 'user',
            predicate: 'has_close_friend',
            objectText: 'Asha close friend manager office',
            temporalStatus: 'current',
            explicitness: 'explicit',
            confidence: 0.92,
            futureUtility: 0.75,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );
      final audit = await database
          .select(database.memoryCandidates)
          .getSingle();
      expect(audit.decisionState, 'admitted');

      final retrieved = await database.readMemoryContext(
        latestUserText: 'aaj office mein manager ki wajah se bad day tha',
        limit: 6,
        route: 'semantic',
      );
      expect(
        retrieved.map((row) => row.id),
        isNot(contains(audit.targetMemoryId)),
      );
    },
  );

  test('expiration without an existing exact target is rejected', () async {
    await _completedTurn(
      database,
      sessionId: 's1',
      turnId: 't1',
      userText: 'Please forget that I want to learn guitar',
      runDeterministicMemory: false,
    );
    final job = await _claimJob(database, 's1', 't1');
    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'goal',
          subject: 'user',
          predicate: 'learning_goal',
          objectText: 'learn guitar',
          temporalStatus: 'current',
          explicitness: 'explicit',
          confidence: 0.95,
          futureUtility: 0.8,
          sensitivity: 'normal',
          sourceTurnIds: ['t1'],
          evidenceRole: 'user',
          suggestedAction: 'EXPIRE',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    expect(
      (await database.select(database.memoryCandidates).getSingle())
          .decisionReason,
      'expiration_requires_existing_target',
    );
  });

  test(
    'explicit expiration updates an existing exact semantic target',
    () async {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: 'I want to learn guitar',
        runDeterministicMemory: false,
      );
      final firstJob = await _claimJob(database, 's1', 't1');
      const baseCandidate = ExtractedMemoryCandidate(
        kind: 'goal',
        subject: 'user',
        predicate: 'learning_goal',
        objectText: 'learn guitar',
        temporalStatus: 'current',
        explicitness: 'explicit',
        confidence: 0.95,
        futureUtility: 0.8,
        sensitivity: 'normal',
        sourceTurnIds: ['t1'],
        evidenceRole: 'user',
        suggestedAction: 'ADD',
        followUpAllowed: false,
        proactiveAllowed: false,
      );
      await database.validateAndApplyMemoryCandidates(
        job: firstJob,
        candidates: const [baseCandidate],
      );
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't2',
        userText: 'I no longer want to learn guitar',
        runDeterministicMemory: false,
      );
      final secondJob = await _claimJob(database, 's1', 't2');
      await database.validateAndApplyMemoryCandidates(
        job: secondJob,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'goal',
            subject: 'user',
            predicate: 'learning_goal',
            objectText: 'learn guitar',
            temporalStatus: 'current',
            explicitness: 'explicit',
            confidence: 0.95,
            futureUtility: 0.8,
            sensitivity: 'normal',
            sourceTurnIds: ['t2'],
            evidenceRole: 'user',
            suggestedAction: 'EXPIRE',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );

      final record = await database.select(database.memoryRecords).getSingle();
      expect(record.temporalStatus, 'expired');
      expect(record.replacementReason, 'explicit_user_expiration');
    },
  );

  test('out-of-range local candidate schema is rejected', () async {
    await _completedTurn(
      database,
      sessionId: 's1',
      turnId: 't1',
      userText: 'I want to learn guitar',
      runDeterministicMemory: false,
    );
    final job = await _claimJob(database, 's1', 't1');
    await database.validateAndApplyMemoryCandidates(
      job: job,
      candidates: const [
        ExtractedMemoryCandidate(
          kind: 'goal',
          subject: 'user',
          predicate: 'learning_goal',
          objectText: 'learn guitar',
          temporalStatus: 'current',
          explicitness: 'explicit',
          confidence: 1.2,
          futureUtility: 0.8,
          sensitivity: 'normal',
          sourceTurnIds: ['t1'],
          evidenceRole: 'user',
          suggestedAction: 'ADD',
          followUpAllowed: false,
          proactiveAllowed: false,
        ),
      ],
    );

    expect(await database.select(database.memoryRecords).get(), isEmpty);
    expect(
      (await database.select(database.memoryCandidates).getSingle())
          .decisionReason,
      'invalid_or_unverifiable_schema',
    );
  });

  test('separate source events do not collapse into one episode', () async {
    for (final turnId in ['t1', 't2']) {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: turnId,
        userText: 'I attended a design interview',
        runDeterministicMemory: false,
      );
      final job = await _claimJob(database, 's1', turnId);
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: [
          ExtractedMemoryCandidate(
            kind: 'episode',
            subject: 'user',
            predicate: 'attended_interview',
            objectText: 'attended a design interview',
            temporalStatus: 'past',
            explicitness: 'explicit',
            confidence: 0.92,
            futureUtility: 0.72,
            sensitivity: 'normal',
            sourceTurnIds: [turnId],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: false,
            proactiveAllowed: false,
          ),
        ],
      );
    }

    expect(await database.select(database.memoryEpisodes).get(), hasLength(2));
    expect(await database.select(database.memoryRecords).get(), hasLength(2));
  });

  test(
    'undated open threads become stale instead of remaining open forever',
    () async {
      await _completedTurn(
        database,
        sessionId: 's1',
        turnId: 't1',
        userText: 'I have a design interview coming up',
        runDeterministicMemory: false,
      );
      final job = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'open_thread',
            subject: 'user',
            predicate: 'has_interview',
            objectText: 'design interview coming up',
            temporalStatus: 'future',
            explicitness: 'explicit',
            confidence: 0.92,
            futureUtility: 0.8,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: true,
            proactiveAllowed: false,
          ),
        ],
      );
      final record = await database.select(database.memoryRecords).getSingle();

      await database.consolidateLocalMemory(
        nowMs: record.createdAt + const Duration(days: 31).inMilliseconds,
      );

      expect(
        (await database.select(database.memoryOpenThreads).getSingle()).status,
        'closed',
      );
      expect(
        (await database.select(database.memoryRecords).getSingle())
            .temporalStatus,
        'stale',
      );
    },
  );

  test(
    'LLM event timestamp must agree with the cited temporal phrase',
    () async {
      await _completedTurn(database, sessionId: 's1', turnId: 't1');
      final job = await _claimJob(database, 's1', 't1');
      await database.validateAndApplyMemoryCandidates(
        job: job,
        candidates: const [
          ExtractedMemoryCandidate(
            kind: 'open_thread',
            subject: 'user',
            predicate: 'has_interview',
            objectText: 'Friday design interview',
            eventStartAt: 172800000,
            temporalStatus: 'future',
            explicitness: 'explicit',
            confidence: 0.95,
            futureUtility: 0.9,
            sensitivity: 'normal',
            sourceTurnIds: ['t1'],
            evidenceRole: 'user',
            suggestedAction: 'ADD',
            followUpAllowed: true,
            proactiveAllowed: false,
          ),
        ],
      );

      expect(await database.select(database.memoryRecords).get(), isEmpty);
      final audit = await database
          .select(database.memoryCandidates)
          .getSingle();
      expect(audit.decisionReason, 'event_time_not_grounded');
    },
  );
}

class _FakeCandidateClient implements MemoryCandidateClient {
  @override
  Future<List<ExtractedMemoryCandidate>> extract({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  }) async {
    return const [
      ExtractedMemoryCandidate(
        kind: 'episode',
        subject: 'user',
        predicate: 'attended_interview',
        objectText: 'design interview',
        temporalStatus: 'past',
        explicitness: 'explicit',
        confidence: 0.9,
        futureUtility: 0.8,
        sensitivity: 'normal',
        sourceTurnIds: ['t1'],
        evidenceRole: 'user',
        suggestedAction: 'ADD',
        followUpAllowed: false,
        proactiveAllowed: false,
      ),
    ];
  }
}

class _FailingCandidateClient implements MemoryCandidateClient {
  const _FailingCandidateClient(this.statusCode);

  final int statusCode;

  @override
  Future<List<ExtractedMemoryCandidate>> extract({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  }) async {
    throw MemoryCandidateException(statusCode);
  }
}

class _EmptyCandidateClient implements MemoryCandidateClient {
  const _EmptyCandidateClient();

  @override
  Future<List<ExtractedMemoryCandidate>> extract({
    required String jobId,
    required String language,
    required List<ChatMessage> turns,
  }) async {
    return const [];
  }
}

Future<MemoryExtractionJob> _claimJob(
  AppDatabase database,
  String sessionId,
  String turnId,
) async {
  await database.enqueueMemoryExtractionJob(
    sessionId: sessionId,
    turnId: turnId,
    extractionVersion: 'v1',
  );
  return (await database.claimNextMemoryExtractionJob())!;
}

Future<void> _completedTurn(
  AppDatabase database, {
  required String sessionId,
  required String turnId,
  String userText = 'Friday ko mera design interview tha',
  bool runDeterministicMemory = true,
}) async {
  final turnOffset =
      (int.tryParse(turnId.replaceFirst(RegExp(r'\D+'), '')) ?? 0) * 10;
  await database.upsertSession(
    ChatSessionsCompanion.insert(
      id: sessionId,
      startedAt: 1,
      language: 'hi-IN',
    ),
  );
  final userMessage = ChatMessagesCompanion.insert(
    id: '${turnId}_user',
    sessionId: sessionId,
    turnId: turnId,
    role: 'user',
    messageText: userText,
    status: 'final',
    language: 'hi-IN',
    createdAt: 10 + turnOffset,
    sttConfidence: const Value(0.96),
  );
  if (runDeterministicMemory) {
    await database.upsertUserMessageAndExtractMemory(userMessage);
  } else {
    await database.upsertMessage(userMessage);
  }
  await database.upsertMessage(
    ChatMessagesCompanion.insert(
      id: '${turnId}_assistant',
      sessionId: sessionId,
      turnId: turnId,
      role: 'assistant',
      messageText: 'I hope it went well. Tell me how it felt.',
      status: 'final',
      language: 'hi-IN',
      createdAt: 11 + turnOffset,
    ),
  );
}
