enum VoiceSessionPhase {
  idle,
  requestingPermission,
  connecting,
  reconnecting,
  listening,
  userSpeaking,
  thinking,
  speaking,
  permissionDenied,
  error,
  ended,
}

extension VoiceSessionPhaseLabel on VoiceSessionPhase {
  String get label {
    return switch (this) {
      VoiceSessionPhase.idle => 'Ready',
      VoiceSessionPhase.requestingPermission => 'Checking microphone',
      VoiceSessionPhase.connecting => 'Connecting to LiveKit',
      VoiceSessionPhase.reconnecting => 'Reconnecting',
      VoiceSessionPhase.listening => 'Listening',
      VoiceSessionPhase.userSpeaking => 'You are speaking',
      VoiceSessionPhase.thinking => 'Thinking',
      VoiceSessionPhase.speaking => 'Speaking',
      VoiceSessionPhase.permissionDenied => 'Microphone permission needed',
      VoiceSessionPhase.error => 'Connection problem',
      VoiceSessionPhase.ended => 'Session ended',
    };
  }
}

class VoiceChatState {
  const VoiceChatState({
    required this.phase,
    required this.mockModeEnabled,
    this.activeSessionId,
    this.errorMessage,
    this.isBusy = false,
  });

  const VoiceChatState.initial()
    : phase = VoiceSessionPhase.idle,
      mockModeEnabled = true,
      activeSessionId = null,
      errorMessage = null,
      isBusy = false;

  final VoiceSessionPhase phase;
  final bool mockModeEnabled;
  final String? activeSessionId;
  final String? errorMessage;
  final bool isBusy;

  bool get isSessionActive =>
      phase == VoiceSessionPhase.listening ||
      phase == VoiceSessionPhase.userSpeaking ||
      phase == VoiceSessionPhase.thinking ||
      phase == VoiceSessionPhase.speaking ||
      phase == VoiceSessionPhase.reconnecting;

  VoiceChatState copyWith({
    VoiceSessionPhase? phase,
    bool? mockModeEnabled,
    String? activeSessionId,
    String? errorMessage,
    bool? isBusy,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return VoiceChatState(
      phase: phase ?? this.phase,
      mockModeEnabled: mockModeEnabled ?? this.mockModeEnabled,
      activeSessionId: clearSession
          ? null
          : activeSessionId ?? this.activeSessionId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
