import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_session_service.dart';
import '../../../core/audio/playback_telemetry_bridge.dart';
import '../../../core/identity/anonymous_device_id.dart';
import '../../../core/permissions/microphone_permission_service.dart';
import '../../../core/privacy/consent_store.dart';
import '../../chat_history/data/app_database.dart';
import '../../chat_history/data/companion_memory_store.dart';
import '../../chat_history/data/long_term_memory_service.dart';
import '../../chat_history/data/memory_embedding_service.dart';
import '../../chat_history/data/memory_v3_compiler_service.dart';
import '../../chat_history/data/objectbox_memory_vector_index.dart';
import '../../livekit_session/data/livekit_connection_service.dart';
import '../../livekit_session/data/session_api_client.dart';
import '../../livekit_session/domain/livekit_data_event.dart';
import '../data/mock_conversation_service.dart';
import '../data/voice_preference_store.dart';
import '../data/voice_preview_player.dart';
import '../domain/voice_session_state.dart';

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return ref.watch(appDatabaseProvider).watchMessages();
});

final mockConversationServiceProvider = Provider<MockConversationService>(
  (ref) => MockConversationService(ref.watch(appDatabaseProvider)),
);

final voiceChatControllerProvider =
    NotifierProvider<VoiceChatController, VoiceChatState>(
      VoiceChatController.new,
    );

class VoiceChatController extends Notifier<VoiceChatState> {
  StreamSubscription<LiveKitConnectionStatus>? _connectionSubscription;
  StreamSubscription<LiveKitDataEvent>? _eventSubscription;
  StreamSubscription<PlaybackObservation>? _playbackSubscription;
  StreamSubscription<MemoryJudgeOutcome>? _memoryJudgeSubscription;
  String? _activeDeviceId;
  final _sequencer = LiveKitEventSequencer();
  final _seenMemoryNoticeIds = <String>{};
  Future<void> _criticalEventQueue = Future<void>.value();

  @override
  VoiceChatState build() {
    final liveKitService = ref.read(liveKitConnectionServiceProvider);
    unawaited(ref.read(longTermMemoryCoordinatorProvider).processPending());
    unawaited(ref.read(memoryV3CompilerCoordinatorProvider).processPending());
    _memoryJudgeSubscription ??= ref
        .read(longTermMemoryCoordinatorProvider)
        .outcomes
        .listen((outcome) => unawaited(_sendMemoryJudgeNotice(outcome)));
    unawaited(ref.read(appDatabaseProvider).consolidateLocalMemory());
    _playbackSubscription ??= PlaybackTelemetryBridge.instance.observations
        .listen((observation) {
          unawaited(_reportPlaybackObservation(observation));
        });
    ref.onDispose(() {
      _connectionSubscription?.cancel();
      _eventSubscription?.cancel();
      _playbackSubscription?.cancel();
      _memoryJudgeSubscription?.cancel();
      liveKitService.disconnect();
    });
    return const VoiceChatState.initial();
  }

  Future<void> _sendMemoryJudgeNotice(MemoryJudgeOutcome outcome) async {
    if (state.activeSessionId != outcome.sessionId) {
      return;
    }
    // Emitted only after the local decision-operation transaction committed.
    // The notice ID is deterministic per job and outcome so reconnect/replay
    // delivery collapses to at most one visible notice.
    final notice = switch (outcome.outcome) {
      MemoryJudgeOutcomeKind.accepted => 'I saved that memory.',
      MemoryJudgeOutcomeKind.superseded =>
        'I updated that memory with your correction.',
      MemoryJudgeOutcomeKind.rejected =>
        'I could not safely update that memory.',
      _ => 'I could not safely update that memory right now.',
    };
    await ref
        .read(liveKitConnectionServiceProvider)
        .sendReliable(
          _sequencer.next(
            type: 'memory_judge_notice',
            schemaVersion: 2,
            sessionId: outcome.sessionId,
            turnId: outcome.turnId,
            payload: {
              'notice': notice,
              'notice_id': '${outcome.jobId}:${outcome.outcome.name}',
              'outcome': outcome.outcome.name,
              'accepted_count': outcome.acceptedCount,
              'window_turn_count': outcome.windowTurnCount,
              'attempt_count': outcome.attemptCount,
              'request_started_at_ms': outcome.requestStartedAtMs,
              'completed_at_ms': outcome.completedAtMs,
              'cost_source': outcome.costSource,
              'input_tokens': outcome.inputTokens,
              'output_tokens': outcome.outputTokens,
              'estimated_micro_inr': outcome.estimatedMicroInr,
            },
          ),
        );
  }

  Future<StartSessionResult> startSession() async {
    if (state.isBusy) {
      return StartSessionResult.started;
    }

    state = state.copyWith(
      isBusy: true,
      phase: VoiceSessionPhase.requestingPermission,
      clearError: true,
    );

    try {
      await ref.read(voicePreviewPlayerProvider).stop();
      final hasConsent = await ref
          .read(consentStoreProvider)
          .hasAcceptedCurrentCopy();
      if (!hasConsent) {
        state = state.copyWith(isBusy: false, phase: VoiceSessionPhase.idle);
        return StartSessionResult.needsConsent;
      }

      final deviceId = await ref.read(anonymousDeviceIdProvider.future);
      final permission = await ref
          .read(microphonePermissionServiceProvider)
          .request();
      if (permission != MicrophonePermissionResult.granted) {
        state = state.copyWith(
          isBusy: false,
          phase: VoiceSessionPhase.permissionDenied,
          errorMessage:
              permission == MicrophonePermissionResult.permanentlyDenied
              ? 'Microphone is permanently denied. Open system settings to allow it.'
              : 'Microphone permission is needed to start voice chat.',
        );
        return StartSessionResult.permissionDenied;
      }

      await ref.read(audioSessionServiceProvider).configureForVoiceCompanion();
      state = state.copyWith(phase: VoiceSessionPhase.connecting);

      final liveKitService = ref.read(liveKitConnectionServiceProvider);
      final apiClient = ref.read(sessionApiClientProvider);
      final catalog = await apiClient.fetchTtsVoiceCatalog();
      final preferenceStore = ref.read(voicePreferenceStoreProvider);
      final preferredVoiceId = await preferenceStore.read();
      final voiceId = catalog.resolve(preferredVoiceId);
      if (voiceId != preferredVoiceId) {
        await preferenceStore.write(voiceId);
        ref.invalidate(selectedVoiceIdProvider);
      }
      LiveKitSessionInfo? createdSession;
      try {
        createdSession = await apiClient.createSession(
          deviceId: deviceId,
          language: catalog.language,
          voiceId: voiceId,
        );
        final token = await apiClient.mintToken(
          deviceId: deviceId,
          sessionId: createdSession.sessionId,
        );
        final handle = await liveKitService.connect(
          session: createdSession,
          token: token,
        );

        await _connectionSubscription?.cancel();
        _connectionSubscription = handle.connectionUpdates.listen(
          _applyConnectionStatus,
        );
        await _eventSubscription?.cancel();
        _eventSubscription = handle.events.listen((event) {
          _criticalEventQueue = _criticalEventQueue
              .catchError((_) {})
              .then((_) => _applyLiveKitEvent(event));
        });
        await liveKitService.sendReliable(
          _sequencer.next(
            type: 'client_session_started',
            schemaVersion: 2,
            sessionId: createdSession.sessionId,
            payload: {
              'room_name': createdSession.roomName,
              'memory_protocol_versions': [1, 2],
            },
          ),
        );

        _activeDeviceId = deviceId;
        state = state.copyWith(
          isBusy: false,
          phase: VoiceSessionPhase.listening,
          activeSessionId: createdSession.sessionId,
        );
        return StartSessionResult.started;
      } catch (_) {
        if (createdSession != null) {
          try {
            await apiClient.endSession(
              deviceId: deviceId,
              sessionId: createdSession.sessionId,
            );
          } catch (_) {
            // The API's idempotent session recovery handles a later retry.
          }
        }
        await _connectionSubscription?.cancel();
        await _eventSubscription?.cancel();
        await liveKitService.disconnect();
        rethrow;
      }
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        phase: VoiceSessionPhase.error,
        errorMessage: _startErrorMessage(error),
      );
      return StartSessionResult.failed;
    }
  }

  Future<void> acceptConsentAndStart() async {
    await ref.read(consentStoreProvider).acceptCurrentCopy(DateTime.now());
    ref.invalidate(hasAcceptedConsentProvider);
    await startSession();
  }

  Future<void> endSession() async {
    final sessionId = state.activeSessionId;
    final deviceId = _activeDeviceId;
    if (sessionId != null && deviceId != null) {
      await ref
          .read(sessionApiClientProvider)
          .endSession(deviceId: deviceId, sessionId: sessionId);
    }
    await _connectionSubscription?.cancel();
    await _eventSubscription?.cancel();
    await ref.read(liveKitConnectionServiceProvider).disconnect();
    unawaited(ref.read(longTermMemoryCoordinatorProvider).processPending());
    unawaited(ref.read(memoryV3CompilerCoordinatorProvider).processPending());
    await ref.read(appDatabaseProvider).consolidateLocalMemory();
    _activeDeviceId = null;
    state = state.copyWith(phase: VoiceSessionPhase.ended, isBusy: false);
  }

  Future<void> addMockExchange() async {
    final sessionId = state.activeSessionId;
    if (sessionId == null || state.isBusy) {
      return;
    }

    state = state.copyWith(phase: VoiceSessionPhase.thinking, isBusy: true);
    await ref.read(mockConversationServiceProvider).addMockExchange(sessionId);
    state = state.copyWith(phase: VoiceSessionPhase.speaking, isBusy: false);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (state.activeSessionId == sessionId) {
      state = state.copyWith(phase: VoiceSessionPhase.listening);
    }
  }

  Future<void> replaceLatestUserTurn() async {
    await ref.read(mockConversationServiceProvider).replaceLatestUserTurn();
  }

  Future<void> clearHistory() async {
    final database = ref.read(appDatabaseProvider);
    await database.clearAllHistoryAndCompanionMemory();
    final vectorIndex = await ref.read(memoryVectorIndexProvider.future);
    await vectorIndex.deleteAll();
    state = const VoiceChatState.initial();
  }

  void _applyConnectionStatus(LiveKitConnectionStatus status) {
    if (!state.isSessionActive &&
        status != LiveKitConnectionStatus.failed &&
        status != LiveKitConnectionStatus.connected) {
      return;
    }

    switch (status) {
      case LiveKitConnectionStatus.connected:
        state = state.copyWith(
          phase: VoiceSessionPhase.listening,
          isBusy: false,
          clearError: true,
        );
      case LiveKitConnectionStatus.reconnecting:
      case LiveKitConnectionStatus.connecting:
        state = state.copyWith(phase: VoiceSessionPhase.reconnecting);
      case LiveKitConnectionStatus.failed:
        state = state.copyWith(
          phase: VoiceSessionPhase.error,
          isBusy: false,
          errorMessage: 'LiveKit connection failed. Please try again.',
        );
      case LiveKitConnectionStatus.disconnected:
        if (state.isSessionActive) {
          state = state.copyWith(phase: VoiceSessionPhase.ended);
        }
    }
  }

  Future<void> _applyLiveKitEvent(LiveKitDataEvent event) async {
    if (event.type == 'session_state') {
      final incoming = event.payload['state'];
      if (incoming == 'thinking') {
        state = state.copyWith(
          phase: VoiceSessionPhase.thinking,
          isBusy: false,
          clearPartialTranscript: true,
        );
      } else if (incoming == 'user_speaking') {
        state = state.copyWith(
          phase: VoiceSessionPhase.userSpeaking,
          isBusy: false,
        );
      } else if (incoming == 'speaking') {
        state = state.copyWith(
          phase: VoiceSessionPhase.speaking,
          isBusy: false,
          clearPartialTranscript: true,
        );
      } else if (incoming == 'listening') {
        state = state.copyWith(
          phase: VoiceSessionPhase.listening,
          isBusy: false,
        );
      }
    } else if (event.type == 'speech_start') {
      state = state.copyWith(
        phase: VoiceSessionPhase.userSpeaking,
        isBusy: false,
        clearError: true,
        clearPartialTranscript: true,
      );
    } else if (event.type == 'speech_end') {
      state = state.copyWith(phase: VoiceSessionPhase.listening, isBusy: false);
    } else if (event.type == 'transcript_partial') {
      final text = (event.payload['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) {
        state = state.copyWith(
          phase: VoiceSessionPhase.userSpeaking,
          partialTranscript: text,
          isBusy: false,
        );
      }
    } else if (event.type == 'transcript_final') {
      await _persistFinalTranscript(event);
      state = state.copyWith(
        phase: VoiceSessionPhase.listening,
        isBusy: false,
        clearPartialTranscript: true,
      );
    } else if (event.type == 'assistant_transcript_partial') {
      final text = (event.payload['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) {
        state = state.copyWith(
          phase: VoiceSessionPhase.thinking,
          partialTranscript: text,
          isBusy: false,
        );
      }
    } else if (event.type == 'assistant_transcript_final') {
      await _persistAssistantTranscript(event);
      state = state.copyWith(
        phase: VoiceSessionPhase.listening,
        isBusy: false,
        clearPartialTranscript: true,
      );
    } else if (event.type == 'turn_metrics') {
      final turnId = event.turnId;
      if (turnId != null) {
        await ref.read(appDatabaseProvider).appendTelemetryEnvelope({
          ...event.payload,
          'session_id': event.sessionId,
          'turn_id': turnId,
        });
      }
    } else if (event.type == 'memory_judge_notice') {
      final notice = (event.payload['notice'] as String?)?.trim();
      final noticeId = event.payload['notice_id'] as String?;
      if (notice != null &&
          notice.isNotEmpty &&
          (noticeId == null || _seenMemoryNoticeIds.add(noticeId))) {
        // Reliable, deduplicated UI-only notice. It is deliberately not
        // persisted as a fabricated assistant turn and never enters telemetry.
        state = state.copyWith(errorMessage: notice);
      }
    } else if (event.type == 'tts_playback_marker') {
      // The native bridge owns actual render detection. This marker only creates
      // turn correlation and deliberately does not inspect media frames in Dart.
      _logVoiceMemoryDiagnostic('tts_playback_marker_received', {
        'turn_id': event.turnId,
        'audio_format': event.payload['audio_format'],
      });
      if (event.turnId != null) {
        await PlaybackTelemetryBridge.instance.arm(event.turnId!);
      }
    } else if (event.type == 'memory_context_request_v2') {
      await _replyToMemoryContextV2(event);
    } else if (event.type == 'memory_lookup_request') {
      await _replyToMemoryLookupRequest(event);
    } else if (event.type == 'transcript_repeat_requested') {
      state = state.copyWith(
        phase: VoiceSessionPhase.listening,
        isBusy: false,
        clearPartialTranscript: true,
        errorMessage:
            (event.payload['message'] as String?) ??
            'Please say that again clearly.',
      );
    } else if (event.type == 'stt_error') {
      state = state.copyWith(
        phase: VoiceSessionPhase.listening,
        isBusy: false,
        clearPartialTranscript: true,
        errorMessage: 'Speech recognition failed. Please try again.',
      );
    } else if (event.type == 'llm_error') {
      // An inference outage is operational UI state, not a companion message.
      // It is deliberately neither persisted nor sent to memory processing.
      state = state.copyWith(
        phase: VoiceSessionPhase.listening,
        isBusy: false,
        clearPartialTranscript: true,
        errorMessage:
            (event.payload['message'] as String?) ??
            'AI response is temporarily unavailable. Please try again.',
      );
    } else if (event.type == 'barge_in') {
      state = state.copyWith(
        phase: VoiceSessionPhase.userSpeaking,
        isBusy: false,
      );
    } else if (event.type == 'error') {
      state = state.copyWith(
        phase: VoiceSessionPhase.error,
        errorMessage:
            (event.payload['message'] as String?) ?? 'Voice session error.',
      );
    }
  }

  Future<void> _reportPlaybackObservation(
    PlaybackObservation observation,
  ) async {
    final sessionId = state.activeSessionId;
    if (sessionId == null) return;
    await ref
        .read(liveKitConnectionServiceProvider)
        .sendReliable(
          _sequencer.next(
            type: 'client_playback_started',
            sessionId: sessionId,
            turnId: observation.turnId,
            payload: {
              'playback_timestamp_ms': observation.timestampMs,
              'correlation_status': 'observed',
              'source': observation.source,
            },
          ),
        );
  }

  Future<void> _replyToMemoryLookupRequest(LiveKitDataEvent event) async {
    final query = (event.payload['query_text'] as String?)?.trim();
    if (query == null || query.isEmpty) {
      return;
    }
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final limit = ((event.payload['max_blocks'] as num?)?.toInt() ?? 6).clamp(
      0,
      6,
    );
    final retrievalStrategy =
        (event.payload['memory_retrieval_strategy'] as String?) ??
        'deterministic';
    final rerankerStrategy =
        (event.payload['memory_reranker_strategy'] as String?) ??
        'deterministic';
    final route = event.payload['route'] as String?;
    final memories = await ref
        .read(memoryLookupServiceProvider)
        .lookup(
          latestUserText: query,
          limit: limit,
          retrievalStrategy: retrievalStrategy,
          rerankerStrategy: rerankerStrategy,
          route: route,
        );
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAt;
    _logVoiceMemoryDiagnostic('memory_lookup_response_mobile', {
      'turn_id': event.turnId,
      'request_sequence': event.sequence,
      'elapsed_ms': elapsedMs,
      'memory_packets': memories.length,
      'memory_kinds': [for (final memory in memories) memory.kind],
      'memory_retrieval_strategy': retrievalStrategy,
      'memory_reranker_strategy': rerankerStrategy,
    });
    await ref
        .read(liveKitConnectionServiceProvider)
        .sendReliable(
          _sequencer.next(
            type: 'memory_lookup_response',
            sessionId: event.sessionId,
            turnId: event.turnId,
            payload: {
              'request_sequence': event.sequence,
              'elapsed_ms': elapsedMs,
              'memory_packets': [
                for (final memory in memories)
                  {
                    'memory_id': memory.id,
                    'kind': memory.kind,
                    'label': memory.label,
                    'content': memory.content,
                    'canonical_text': memory.canonicalText,
                    'source_turn_ids': jsonDecode(memory.sourceTurnIdsJson),
                    'confidence_score': memory.confidenceScore,
                    'importance_score': memory.importanceScore,
                    'temporal_status': memory.temporalStatus,
                    'sensitivity': memory.sensitivity,
                    'evidence_summary': memory.evidenceSummary,
                  },
              ],
              'pending_receipts': const [],
            },
          ),
        );
  }

  Future<void> _replyToMemoryContextV2(LiveKitDataEvent event) async {
    final query = (event.payload['query_text'] as String?)?.trim();
    final turnId = event.turnId;
    if (query == null || query.isEmpty || turnId == null) return;
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final database = ref.read(appDatabaseProvider);
    final resolution = await database.resolveMemoryTurn(
      turnId: turnId,
      text: query,
      language: (event.payload['language'] as String?) ?? 'und',
      transcriptStatus:
          (event.payload['transcript_status'] as String?) ?? 'final',
      sttConfidence: (event.payload['stt_confidence'] as num?)?.toDouble(),
      sttProvider: event.payload['stt_provider'] as String?,
      sttModel: event.payload['stt_model'] as String?,
    );
    final limit = ((event.payload['max_blocks'] as num?)?.toInt() ?? 4).clamp(
      0,
      6,
    );
    final semanticPackets = resolution.queryScope == null
        ? const <MemoryRecord>[]
        : await ref
              .read(memoryLookupServiceProvider)
              .lookup(
                latestUserText: query,
                limit: limit,
                retrievalStrategy:
                    (event.payload['memory_retrieval_strategy'] as String?) ??
                    'deterministic',
                rerankerStrategy:
                    (event.payload['memory_reranker_strategy'] as String?) ??
                    'deterministic',
                route: resolution.queryScope,
              );
    if (resolution.directive == 'setting_ack') {
      await database.markTurnDeterministicallyHandled(turnId);
    }
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAt;
    _logVoiceMemoryDiagnostic('memory_context_response_v2_mobile', {
      'turn_id': turnId,
      'request_sequence': event.sequence,
      'elapsed_ms': elapsedMs,
      'directive': resolution.directive,
      'state_fact_count': resolution.stateFacts.length,
      'semantic_packet_count': semanticPackets.length,
      'pending_candidate': resolution.pendingCandidate != null,
    });
    await ref
        .read(liveKitConnectionServiceProvider)
        .sendReliable(
          _sequencer.next(
            type: 'memory_context_response_v2',
            schemaVersion: 2,
            sessionId: event.sessionId,
            turnId: turnId,
            payload: {
              'request_sequence': event.sequence,
              'elapsed_ms': elapsedMs,
              'response_directive': resolution.directive,
              'state_facts': resolution.stateFacts,
              'policy_card': resolution.policyCard,
              'semantic_resolved': resolution.queryScope != null,
              if (resolution.pendingCandidate != null)
                'pending_candidate': resolution.pendingCandidate,
              'memory_packets': [
                for (final memory in semanticPackets)
                  {
                    'memory_id': memory.id,
                    'kind': memory.kind,
                    'label': memory.label,
                    'content': memory.content,
                    'canonical_text': memory.canonicalText,
                    'source_turn_ids': jsonDecode(memory.sourceTurnIdsJson),
                    'confidence_score': memory.confidenceScore,
                    'importance_score': memory.importanceScore,
                    'temporal_status': memory.temporalStatus,
                    'sensitivity': memory.sensitivity,
                    'evidence_summary': memory.evidenceSummary,
                  },
              ],
            },
          ),
        );
  }

  Future<void> _persistFinalTranscript(LiveKitDataEvent event) async {
    final text = (event.payload['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    final status = switch (event.payload['status']) {
      'low_confidence' => 'final_low_confidence',
      _ => 'final',
    };
    final turnId = event.turnId ?? '${event.sessionId}:turn:${event.sequence}';
    final createdAt = event.timestampMs > 0
        ? event.timestampMs
        : DateTime.now().millisecondsSinceEpoch;
    final language = (event.payload['language'] as String?) ?? 'hi-IN';

    await ref
        .read(appDatabaseProvider)
        .upsertUserMessageAndExtractMemory(
          ChatMessagesCompanion.insert(
            id: 'msg_${event.sessionId}_${turnId}_user',
            sessionId: event.sessionId,
            turnId: turnId,
            role: 'user',
            messageText: text,
            status: status,
            language: language,
            createdAt: createdAt,
            sttConfidence: Value(
              (event.payload['confidence'] as num?)?.toDouble(),
            ),
            latencyJson: Value(
              jsonEncode({
                'provider': event.payload['provider'],
                'model': event.payload['model'],
                'latency_ms': event.payload['latency_ms'],
                'audio_seconds': event.payload['audio_seconds'],
                'billed_units': event.payload['billed_units'],
                'cost_units': event.payload['cost_units'],
              }),
            ),
          ),
        );
    await ref.read(memoryEmbeddingSyncProvider).syncTurnMemories(turnId);
  }

  Future<void> _persistAssistantTranscript(LiveKitDataEvent event) async {
    final text = (event.payload['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    final turnId = event.turnId ?? '${event.sessionId}:turn:${event.sequence}';
    final createdAt = event.timestampMs > 0
        ? event.timestampMs
        : DateTime.now().millisecondsSinceEpoch;
    final language = (event.payload['language'] as String?) ?? 'hi-IN';

    await ref
        .read(appDatabaseProvider)
        .upsertAssistantMessageAndSummarizeTurn(
          ChatMessagesCompanion.insert(
            id: 'msg_${event.sessionId}_${turnId}_assistant',
            sessionId: event.sessionId,
            turnId: turnId,
            role: 'assistant',
            messageText: text,
            status: (event.payload['status'] as String?) ?? 'final',
            language: language,
            createdAt: createdAt,
            latencyJson: Value(
              jsonEncode({
                'provider': event.payload['provider'],
                'model': event.payload['model'],
                'latency_ms': event.payload['latency_ms'],
                'billed_units': event.payload['billed_units'],
                'cost_units': event.payload['cost_units'],
                'clipped': event.payload['clipped'],
                'safety_reason': event.payload['safety_reason'],
              }),
            ),
          ),
        );
    await ref.read(memoryEmbeddingSyncProvider).syncTurnMemories(turnId);
    await ref
        .read(longTermMemoryCoordinatorProvider)
        .enqueueCompletedTurn(sessionId: event.sessionId, turnId: turnId);
    await ref
        .read(memoryV3CompilerCoordinatorProvider)
        .enqueueCompletedTurn(sessionId: event.sessionId, turnId: turnId);
  }

  String _startErrorMessage(Object error) {
    if (error is SessionApiException && error.statusCode == 409) {
      return 'This device already has an active voice session.';
    }
    if (error is SessionApiException && error.statusCode == 503) {
      return 'AI voice agent could not start. Please try again.';
    }
    return 'Could not start LiveKit voice session.';
  }
}

enum StartSessionResult { started, needsConsent, permissionDenied, failed }

void _logVoiceMemoryDiagnostic(String event, Map<String, Object?> fields) {
  developer.log(
    jsonEncode({'event': event, ...fields}),
    name: 'companion.voice.memory',
  );
}
