import 'dart:convert';

import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:companion_mobile/features/livekit_session/data/session_api_client.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'createSession excludes exact companion state from startup context',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_name',
              kind: 'core_profile',
              label: 'preferred_name',
              content: 'User prefers to be called Rahul.',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_summary',
              kind: 'session_summary',
              label: 'previous_session',
              content: 'A bounded episodic session summary.',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_language',
              kind: 'procedural',
              label: 'language_style',
              content: 'User prefers Hinglish replies.',
            ),
          );
      await database
          .into(database.memoryRecords)
          .insert(
            _memory(
              id: 'memory_semantic',
              kind: 'semantic',
              label: 'work',
              content: 'This should wait for query-time lookup.',
            ),
          );

      late Map<String, Object?> requestBody;
      final client = HttpSessionApiClient(
        baseUrl: 'http://api.test',
        database: database,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/session');
          requestBody = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'session_id': 'session_test',
              'room_name': 'room_test',
              'livekit_url': 'ws://livekit.test',
              'expires_at_ms': 123,
            }),
            200,
          );
        }),
      );

      await client.createSession(deviceId: 'device_test');

      final memoryContext = requestBody['memory_context'] as List<Object?>;
      final ids = [
        for (final item in memoryContext)
          (item as Map<String, Object?>)['memory_id'],
      ];

      expect(ids, isNot(contains('memory_name')));
      expect(ids, isNot(contains('memory_language')));
      expect(ids, isNot(contains('memory_semantic')));
      expect(ids, isEmpty);
    },
  );

  test('catalog and selected voice are sent with a new session', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final client = HttpSessionApiClient(
      baseUrl: 'http://api.test',
      database: database,
      client: MockClient((request) async {
        if (request.url.path == '/v1/config') {
          return http.Response(
            jsonEncode({
              'tts': {
                'language': 'hi-IN',
                'default_voice_id': 'hi_aarohi',
                'voices': [
                  {
                    'id': 'hi_aarohi',
                    'display_name': 'Aarohi',
                    'voice_presentation': 'female',
                    'traits': [],
                    'preview_url': '/v1/tts-previews/hi_aarohi.opus',
                  },
                ],
              },
            }),
            200,
          );
        }
        expect(request.url.path, '/v1/session');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['language'], 'hi-IN');
        expect(body['voice_id'], 'hi_aarohi');
        return http.Response(
          jsonEncode({
            'session_id': 'session_test',
            'room_name': 'room_test',
            'livekit_url': 'ws://livekit.test',
            'expires_at_ms': 123,
            'language': 'hi-IN',
            'voice_id': 'hi_aarohi',
          }),
          200,
        );
      }),
    );

    final catalog = await client.fetchTtsVoiceCatalog();
    expect(catalog.resolve('removed_voice'), 'hi_aarohi');
    final session = await client.createSession(
      deviceId: 'device_test',
      language: catalog.language,
      voiceId: catalog.defaultVoiceId,
    );
    expect(session.voiceId, 'hi_aarohi');
    expect(
      catalog.voices.single.previewUri.toString(),
      'http://api.test/v1/tts-previews/hi_aarohi.opus',
    );
  });
}

MemoryRecordsCompanion _memory({
  required String id,
  required String kind,
  required String label,
  required String content,
}) {
  return MemoryRecordsCompanion.insert(
    id: id,
    kind: kind,
    label: label,
    content: content,
    originalText: Value(content),
    canonicalText: Value(content.toLowerCase()),
    language: const Value('hi-IN'),
    script: const Value('mixed'),
    sourceTurnIdsJson: jsonEncode(['turn_old']),
    sourceRole: 'user',
    transcriptStatus: 'final',
    sttConfidence: const Value(0.96),
    createdAt: 1,
    updatedAt: 1,
    confidenceScore: 0.8,
    importanceScore: 0.7,
    recurrenceCount: const Value(1),
    sensitivity: const Value('normal'),
    temporalStatus: const Value('current'),
    receiptState: const Value('implicit'),
    evidenceSummary: const Value('test memory'),
  );
}
