import 'dart:async';
import 'dart:convert';

import 'package:companion_mobile/app.dart';
import 'package:companion_mobile/core/audio/audio_session_service.dart';
import 'package:companion_mobile/core/config/app_config.dart';
import 'package:companion_mobile/core/identity/anonymous_device_id.dart';
import 'package:companion_mobile/core/permissions/microphone_permission_service.dart';
import 'package:companion_mobile/core/privacy/consent_store.dart';
import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/chat_history/data/memory_embedding_service.dart';
import 'package:companion_mobile/features/chat_history/data/memory_model_config.dart';
import 'package:companion_mobile/features/chat_history/data/memory_vector_index.dart';
import 'package:companion_mobile/features/chat_history/data/objectbox_memory_vector_index.dart';
import 'package:companion_mobile/features/livekit_session/data/livekit_connection_service.dart';
import 'package:companion_mobile/features/livekit_session/data/session_api_client.dart';
import 'package:companion_mobile/features/livekit_session/domain/livekit_data_event.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'voice session connects, persists simulated turns, and clears history',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vectorIndex = InMemoryMemoryVectorIndex();
      addTearDown(database.close);
      await vectorIndex.upsert(
        memoryId: 'memory_to_clear',
        embedding: _testEmbedding(),
      );

      await tester.pumpWidget(_testApp(database, vectorIndex: vectorIndex));

      expect(find.text('Ready'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Start voice session'));
      await tester.pumpAndSettle();
      expect(find.text('Microphone and AI processing'), findsOneWidget);

      await tester.tap(find.text('Agree'));
      await tester.pumpAndSettle();
      expect(find.text('Listening'), findsOneWidget);

      await tester.tap(find.text('Dev: simulate transcript turn'));
      await tester.pumpAndSettle();
      expect(find.text('Aaj mood thoda off hai.'), findsOneWidget);
      expect(find.text('Bad transcript? Re-speak'), findsOneWidget);

      await tester.tap(find.text('Bad transcript? Re-speak'));
      await tester.pumpAndSettle();
      expect(find.textContaining('re-spoken clearly'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_testApp(database, vectorIndex: vectorIndex));
      await tester.pumpAndSettle();
      expect(find.textContaining('re-spoken clearly'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.textContaining('re-spoken clearly'), findsNothing);
      expect(
        find.text('Start a voice session to see local transcript history.'),
        findsOneWidget,
      );
      final vectorHits = await vectorIndex.search(
        queryEmbedding: _testEmbedding(),
        limit: 4,
      );
      expect(vectorHits, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('voice session surfaces reconnect and error states', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final liveKit = _FakeLiveKitConnectionService();
    addTearDown(database.close);

    await tester.pumpWidget(_testApp(database, liveKit: liveKit));

    await tester.tap(find.text('Start voice session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();
    expect(find.text('Listening'), findsOneWidget);

    liveKit.emitStatus(LiveKitConnectionStatus.reconnecting);
    await tester.pumpAndSettle();
    expect(find.text('Reconnecting'), findsOneWidget);

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'session_state',
        sequence: 1,
        sessionId: 'session_test',
        timestampMs: 1,
        turnId: 'session_test:turn:0001',
        payload: {'state': 'thinking'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thinking'), findsOneWidget);

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'speech_start',
        sequence: 2,
        sessionId: 'session_test',
        timestampMs: 2,
        turnId: 'session_test:turn:0001',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You are speaking'), findsOneWidget);

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'speech_end',
        sequence: 3,
        sessionId: 'session_test',
        timestampMs: 3,
        turnId: 'session_test:turn:0001',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Listening'), findsOneWidget);

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'session_state',
        sequence: 4,
        sessionId: 'session_test',
        timestampMs: 4,
        turnId: 'session_test:turn:0001',
        payload: {'state': 'speaking'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Speaking'), findsOneWidget);

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'assistant_transcript_final',
        sequence: 5,
        sessionId: 'session_test',
        timestampMs: 5,
        turnId: 'session_test:turn:0001',
        payload: {
          'text': 'Haan, main sun raha hoon.',
          'status': 'final',
          'language': 'hi-IN',
          'provider': 'persona_local',
          'model': 'hindi_companion_rules_v1',
          'latency_ms': 7,
          'billed_units': 0,
          'cost_units': 0,
          'clipped': false,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Haan, main sun raha hoon.'), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'error',
        sequence: 6,
        sessionId: 'session_test',
        timestampMs: 6,
        payload: {'message': 'Simulated LiveKit error.'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connection problem'), findsOneWidget);
    expect(find.text('Simulated LiveKit error.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('memory lookup response never includes confirmation candidates', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final liveKit = _FakeLiveKitConnectionService();
    addTearDown(database.close);

    await database.upsertUserMessageAndExtractMemory(
      ChatMessagesCompanion.insert(
        id: 'u_memory_seed',
        sessionId: 'session_test',
        turnId: 'turn_memory_seed',
        role: 'user',
        messageText: 'office mein manager bahut pressure deta hai',
        status: 'final',
        language: 'hi-IN',
        createdAt: 1,
        sttConfidence: const Value(0.96),
      ),
    );

    await tester.pumpWidget(_testApp(database, liveKit: liveKit));
    await tester.tap(find.text('Start voice session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();

    liveKit.emitEvent(
      const LiveKitDataEvent(
        type: 'memory_lookup_request',
        sequence: 10,
        sessionId: 'session_test',
        timestampMs: 10,
        turnId: 'session_test:turn:0002',
        payload: {'query_text': 'aaj office bad day tha', 'max_blocks': 6},
      ),
    );
    await tester.pumpAndSettle();

    final response = liveKit.sentReliable.lastWhere(
      (event) => event.type == 'memory_lookup_response',
    );
    final pendingReceipts =
        response.payload['pending_receipts'] as List<Object?>;
    expect(pendingReceipts, isEmpty);
    final memory = (await database.select(database.memoryRecords).get())
        .singleWhere(
          (record) => record.id == 'memory_semantic_work_stress_manager',
        );
    expect(memory.receiptState, 'implicit');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'live final-turn events run deterministic admission and enqueue background extraction',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final liveKit = _FakeLiveKitConnectionService();
      addTearDown(database.close);
      await tester.pumpWidget(
        _testApp(database, liveKit: liveKit, memoryExtractionEnabled: true),
      );
      await tester.tap(find.text('Start voice session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree'));
      await tester.pumpAndSettle();

      liveKit.emitEvent(
        const LiveKitDataEvent(
          type: 'transcript_final',
          sequence: 20,
          sessionId: 'session_test',
          timestampMs: 20,
          turnId: 'turn_live_memory',
          payload: {
            'text': 'mera naam Rahul hai',
            'status': 'final',
            'language': 'hi-IN',
            'confidence': 0.96,
          },
        ),
      );
      liveKit.emitEvent(
        const LiveKitDataEvent(
          type: 'assistant_transcript_final',
          sequence: 21,
          sessionId: 'session_test',
          timestampMs: 21,
          turnId: 'turn_live_memory',
          payload: {
            'text': 'Namaste Rahul, tumse milkar accha laga.',
            'status': 'final',
            'language': 'hi-IN',
          },
        ),
      );
      await tester.pumpAndSettle();

      final records = await database.select(database.memoryRecords).get();
      expect(records.any((record) => record.label == 'preferred_name'), isTrue);
      final jobs = await database.select(database.memoryExtractionJobs).get();
      expect(jobs, hasLength(1));
      expect(jobs.single.status, 'pending');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('memory controls confirm, embed, and forget one memory', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final vectorIndex = InMemoryMemoryVectorIndex();
    addTearDown(database.close);
    await database.upsertMessage(
      ChatMessagesCompanion.insert(
        id: 'u_control',
        sessionId: 'session_test',
        turnId: 'turn_control',
        role: 'user',
        messageText: 'Asha meri close friend hai',
        status: 'final',
        language: 'hi-IN',
        createdAt: 1,
        sttConfidence: const Value(0.96),
      ),
    );
    await database
        .into(database.memoryRecords)
        .insert(
          MemoryRecordsCompanion.insert(
            id: 'memory_control',
            kind: 'semantic',
            label: 'relationship',
            content: 'Asha is a close friend.',
            canonicalText: const Value('asha close friend'),
            sourceTurnIdsJson: jsonEncode(['turn_control']),
            sourceRole: 'user',
            transcriptStatus: 'validated_completed_turn',
            createdAt: 1,
            updatedAt: 1,
            confidenceScore: 0.9,
            importanceScore: 0.8,
            receiptState: const Value('unconfirmed'),
          ),
        );

    await tester.pumpWidget(_testApp(database, vectorIndex: vectorIndex));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.psychology_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Asha is a close friend.'), findsOneWidget);
    expect(find.text('needs confirmation'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(
      (await database.select(database.memoryRecords).getSingle()).receiptState,
      'confirmed',
    );
    expect(await vectorIndex.count(), 1);

    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Forget'));
    await tester.pumpAndSettle();
    expect(await database.select(database.memoryRecords).get(), isEmpty);
    expect(await vectorIndex.count(), 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Widget _testApp(
  AppDatabase database, {
  _FakeLiveKitConnectionService? liveKit,
  InMemoryMemoryVectorIndex? vectorIndex,
  bool memoryExtractionEnabled = false,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        (ref) => AppConfig(enableMemoryExtraction: memoryExtractionEnabled),
      ),
      appDatabaseProvider.overrideWith((ref) => database),
      memoryVectorIndexProvider.overrideWith(
        (ref) async => vectorIndex ?? InMemoryMemoryVectorIndex(),
      ),
      memoryEmbeddingClientProvider.overrideWith(
        (ref) => _FakeMemoryEmbeddingClient(),
      ),
      memoryRerankClientProvider.overrideWith(
        (ref) => _FakeMemoryRerankClient(),
      ),
      anonymousDeviceIdProvider.overrideWith((ref) async => 'anon_test_device'),
      consentStoreProvider.overrideWith((ref) => _FakeConsentStore()),
      microphonePermissionServiceProvider.overrideWith(
        (ref) => _GrantedMicrophonePermissionService(),
      ),
      audioSessionServiceProvider.overrideWith(
        (ref) => _NoopAudioSessionService(),
      ),
      sessionApiClientProvider.overrideWith((ref) => _FakeSessionApiClient()),
      liveKitConnectionServiceProvider.overrideWith(
        (ref) => liveKit ?? _FakeLiveKitConnectionService(),
      ),
    ],
    child: const CompanionApp(),
  );
}

List<double> _testEmbedding() {
  return <double>[1, for (var i = 1; i < memoryEmbeddingDimensions; i += 1) 0];
}

class _FakeConsentStore implements ConsentStore {
  bool _accepted = false;

  @override
  Future<void> acceptCurrentCopy(DateTime acceptedAt) async {
    _accepted = true;
  }

  @override
  Future<bool> hasAcceptedCurrentCopy() async => _accepted;
}

class _GrantedMicrophonePermissionService
    implements MicrophonePermissionService {
  @override
  Future<MicrophonePermissionResult> request() async {
    return MicrophonePermissionResult.granted;
  }
}

class _NoopAudioSessionService extends AudioSessionService {
  @override
  Future<void> configureForVoiceCompanion() async {}
}

class _FakeSessionApiClient implements SessionApiClient {
  @override
  Future<LiveKitSessionInfo> createSession({required String deviceId}) async {
    return const LiveKitSessionInfo(
      sessionId: 'session_test',
      roomName: 'companion_session_test',
      liveKitUrl: 'ws://localhost:7880',
      expiresAtMs: 1,
    );
  }

  @override
  Future<void> endSession({
    required String deviceId,
    required String sessionId,
  }) async {}

  @override
  Future<LiveKitTokenInfo> mintToken({
    required String deviceId,
    required String sessionId,
  }) async {
    return const LiveKitTokenInfo(
      token: 'token',
      liveKitUrl: 'ws://localhost:7880',
      roomName: 'companion_session_test',
      expiresInSeconds: 600,
    );
  }
}

class _FakeMemoryEmbeddingClient implements MemoryEmbeddingClient {
  @override
  Future<List<List<double>>> embedTexts(
    List<String> texts, {
    String inputType = 'document',
  }) async {
    return [
      for (var i = 0; i < texts.length; i += 1)
        [1.0, for (var j = 1; j < memoryEmbeddingDimensions; j += 1) 0.0],
    ];
  }
}

class _FakeMemoryRerankClient implements MemoryRerankClient {
  @override
  Future<List<String>> rerank({
    required String query,
    required List<MemoryRecord> candidates,
  }) async {
    return [for (final candidate in candidates) candidate.id];
  }
}

class _FakeLiveKitConnectionService extends LiveKitConnectionService {
  final _connections = StreamController<LiveKitConnectionStatus>.broadcast();
  final _events = StreamController<LiveKitDataEvent>.broadcast();
  final sentReliable = <LiveKitDataEvent>[];
  final sentLossy = <LiveKitDataEvent>[];

  @override
  Stream<LiveKitConnectionStatus> get connectionUpdates => _connections.stream;

  @override
  Stream<LiveKitDataEvent> get events => _events.stream;

  @override
  Future<LiveKitSessionHandle> connect({
    required LiveKitSessionInfo session,
    required LiveKitTokenInfo token,
  }) async {
    _connections.add(LiveKitConnectionStatus.connected);
    return LiveKitSessionHandle(
      session: session,
      connectionUpdates: connectionUpdates,
      events: events,
    );
  }

  @override
  Future<void> sendReliable(LiveKitDataEvent event) async {
    sentReliable.add(event);
  }

  @override
  Future<void> sendLossy(LiveKitDataEvent event) async {
    sentLossy.add(event);
  }

  @override
  Future<void> disconnect() async {
    _connections.add(LiveKitConnectionStatus.disconnected);
  }

  void emitStatus(LiveKitConnectionStatus status) {
    _connections.add(status);
  }

  void emitEvent(LiveKitDataEvent event) {
    _events.add(event);
  }
}
