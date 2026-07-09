import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../chat_history/data/app_database.dart';

final sessionApiClientProvider = Provider<SessionApiClient>((ref) {
  return HttpSessionApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    database: ref.watch(appDatabaseProvider),
  );
});

abstract interface class SessionApiClient {
  Future<LiveKitSessionInfo> createSession({required String deviceId});
  Future<LiveKitTokenInfo> mintToken({
    required String deviceId,
    required String sessionId,
  });
  Future<void> endSession({
    required String deviceId,
    required String sessionId,
  });
}

class HttpSessionApiClient implements SessionApiClient {
  HttpSessionApiClient({required this.baseUrl, required this.database});

  final String baseUrl;
  final AppDatabase database;

  @override
  Future<LiveKitSessionInfo> createSession({required String deviceId}) async {
    final context = await database.readRecentTranscriptContext(limit: 12);
    String? latestUserText;
    for (final message in context) {
      if (message.role == 'user') {
        latestUserText = message.messageText;
      }
    }
    final memories = await database.readMemoryContext(
      latestUserText: latestUserText ?? '',
      limit: 6,
    );
    final response = await http.post(
      Uri.parse('$baseUrl/v1/session'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId,
        'recent_transcript_context': [
          for (final message in context)
            {
              'turn_id': message.turnId,
              'role': message.role == 'assistant' || message.role == 'ai'
                  ? 'assistant'
                  : 'user',
              'text': message.messageText,
              'status': message.status,
              'confidence': message.sttConfidence,
              'source': 'recent_turns',
              'created_at_ms': message.createdAt,
            },
        ],
        'memory_context': [
          for (final memory in memories)
            {
              'memory_id': memory.id,
              'kind': memory.kind,
              'label': memory.label,
              'content': memory.content,
              'source_turn_ids': jsonDecode(memory.sourceTurnIdsJson),
              'source_role': memory.sourceRole,
              'transcript_status': memory.transcriptStatus,
              'stt_confidence': memory.sttConfidence,
              'created_at_ms': memory.createdAt,
              'updated_at_ms': memory.updatedAt,
              'last_used_at_ms': memory.lastUsedAt,
              'confidence_score': memory.confidenceScore,
              'importance_score': memory.importanceScore,
            },
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw SessionApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    return LiveKitSessionInfo(
      sessionId: body['session_id'] as String,
      roomName: body['room_name'] as String,
      liveKitUrl: body['livekit_url'] as String,
      expiresAtMs: body['expires_at_ms'] as int,
    );
  }

  @override
  Future<LiveKitTokenInfo> mintToken({
    required String deviceId,
    required String sessionId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/livekit/token'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, 'session_id': sessionId}),
    );
    if (response.statusCode != 200) {
      throw SessionApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    return LiveKitTokenInfo(
      token: body['token'] as String,
      liveKitUrl: body['livekit_url'] as String,
      roomName: body['room_name'] as String,
      expiresInSeconds: body['expires_in_seconds'] as int,
    );
  }

  @override
  Future<void> endSession({
    required String deviceId,
    required String sessionId,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/v1/session/end'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, 'session_id': sessionId}),
    );
  }
}

class LiveKitSessionInfo {
  const LiveKitSessionInfo({
    required this.sessionId,
    required this.roomName,
    required this.liveKitUrl,
    required this.expiresAtMs,
  });

  final String sessionId;
  final String roomName;
  final String liveKitUrl;
  final int expiresAtMs;
}

class LiveKitTokenInfo {
  const LiveKitTokenInfo({
    required this.token,
    required this.liveKitUrl,
    required this.roomName,
    required this.expiresInSeconds,
  });

  final String token;
  final String liveKitUrl;
  final String roomName;
  final int expiresInSeconds;
}

class SessionApiException implements Exception {
  const SessionApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'SessionApiException($statusCode): $body';
}
