import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_session_service.dart';
import '../../../core/identity/anonymous_device_id.dart';
import '../../../core/permissions/microphone_permission_service.dart';
import '../../../core/privacy/consent_store.dart';
import '../../chat_history/data/app_database.dart';
import '../../livekit_session/data/livekit_connection_service.dart';
import '../../livekit_session/data/session_api_client.dart';
import '../../livekit_session/domain/livekit_data_event.dart';
import '../data/mock_conversation_service.dart';
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
  String? _activeDeviceId;
  final _sequencer = LiveKitEventSequencer();

  @override
  VoiceChatState build() {
    final liveKitService = ref.read(liveKitConnectionServiceProvider);
    ref.onDispose(() {
      _connectionSubscription?.cancel();
      _eventSubscription?.cancel();
      liveKitService.disconnect();
    });
    return const VoiceChatState.initial();
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

      final apiClient = ref.read(sessionApiClientProvider);
      final session = await apiClient.createSession(deviceId: deviceId);
      final token = await apiClient.mintToken(
        deviceId: deviceId,
        sessionId: session.sessionId,
      );
      final liveKitService = ref.read(liveKitConnectionServiceProvider);
      final handle = await liveKitService.connect(
        session: session,
        token: token,
      );

      await _connectionSubscription?.cancel();
      _connectionSubscription = handle.connectionUpdates.listen(
        _applyConnectionStatus,
      );
      await _eventSubscription?.cancel();
      _eventSubscription = handle.events.listen(_applyLiveKitEvent);
      await liveKitService.sendReliable(
        _sequencer.next(
          type: 'client_session_started',
          sessionId: session.sessionId,
          payload: {'room_name': session.roomName},
        ),
      );

      _activeDeviceId = deviceId;
      state = state.copyWith(
        isBusy: false,
        phase: VoiceSessionPhase.listening,
        activeSessionId: session.sessionId,
      );
      return StartSessionResult.started;
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
    _activeDeviceId = null;
    state = state.copyWith(
      phase: VoiceSessionPhase.ended,
      isBusy: false,
      clearSession: true,
    );
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
    await ref.read(appDatabaseProvider).clearHistory();
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

  void _applyLiveKitEvent(LiveKitDataEvent event) {
    if (event.type == 'session_state') {
      final incoming = event.payload['state'];
      if (incoming == 'thinking') {
        state = state.copyWith(phase: VoiceSessionPhase.thinking);
      } else if (incoming == 'speaking') {
        state = state.copyWith(phase: VoiceSessionPhase.speaking);
      } else if (incoming == 'listening') {
        state = state.copyWith(phase: VoiceSessionPhase.listening);
      }
    } else if (event.type == 'error') {
      state = state.copyWith(
        phase: VoiceSessionPhase.error,
        errorMessage:
            (event.payload['message'] as String?) ?? 'Voice session error.',
      );
    }
  }

  String _startErrorMessage(Object error) {
    if (error is SessionApiException && error.statusCode == 409) {
      return 'This device already has an active voice session.';
    }
    return 'Could not start LiveKit voice session.';
  }
}

enum StartSessionResult { started, needsConsent, permissionDenied, failed }
