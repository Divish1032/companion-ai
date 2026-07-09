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
  HttpSessionApiClient({
    required this.baseUrl,
    required this.database,
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final AppDatabase database;
  final http.Client? _client;

  @override
  Future<LiveKitSessionInfo> createSession({required String deviceId}) async {
    final context = await database.readRecentTranscriptContext(limit: 12);
    final memories = await database.readSessionStartMemoryContext(limit: 3);
    final response = await _postJson('/v1/session', {
      'device_id': deviceId,
      'recent_transcript_context': _recentTranscriptPayload(context),
      'memory_context': _memoryPayload(memories),
    });
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
    final response = await _postJson('/v1/livekit/token', {
      'device_id': deviceId,
      'session_id': sessionId,
    });
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
    await _postJson('/v1/session/end', {
      'device_id': deviceId,
      'session_id': sessionId,
    });
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final client = _client ?? http.Client();
    final shouldCloseClient = _client == null;
    try {
      return await client.post(
        Uri.parse('$baseUrl$path'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }
}

List<Map<String, Object?>> _recentTranscriptPayload(List<ChatMessage> context) {
  return [
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
  ];
}

List<Map<String, Object?>> _memoryPayload(List<MemoryRecord> memories) {
  return [
    for (final memory in memories)
      {
        'memory_id': memory.id,
        'kind': memory.kind,
        'label': memory.label,
        'content': memory.content,
        'original_text': memory.originalText,
        'canonical_text': memory.canonicalText,
        'language': memory.language,
        'script': memory.script,
        'source_turn_ids': jsonDecode(memory.sourceTurnIdsJson),
        'source_role': memory.sourceRole,
        'transcript_status': memory.transcriptStatus,
        'stt_confidence': memory.sttConfidence,
        'created_at_ms': memory.createdAt,
        'updated_at_ms': memory.updatedAt,
        'last_used_at_ms': memory.lastUsedAt,
        'confidence_score': memory.confidenceScore,
        'importance_score': memory.importanceScore,
        'recurrence_count': memory.recurrenceCount,
        'sensitivity': memory.sensitivity,
        'temporal_status': memory.temporalStatus,
        'receipt_state': memory.receiptState,
        'evidence_summary': memory.evidenceSummary,
      },
  ];
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
