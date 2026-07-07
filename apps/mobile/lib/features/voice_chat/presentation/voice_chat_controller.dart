import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_session_service.dart';
import '../../../core/identity/anonymous_device_id.dart';
import '../../../core/permissions/microphone_permission_service.dart';
import '../../../core/privacy/consent_store.dart';
import '../../chat_history/data/app_database.dart';
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
  @override
  VoiceChatState build() => const VoiceChatState.initial();

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

      await ref.read(anonymousDeviceIdProvider.future);
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
      final sessionId = await ref
          .read(mockConversationServiceProvider)
          .startSession();
      state = state.copyWith(
        isBusy: false,
        phase: VoiceSessionPhase.listening,
        activeSessionId: sessionId,
      );
      return StartSessionResult.started;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        phase: VoiceSessionPhase.idle,
        errorMessage: 'Could not start mock voice session.',
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
}

enum StartSessionResult { started, needsConsent, permissionDenied, failed }
