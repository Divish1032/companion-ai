import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/anonymous_device_id.dart';
import '../../../core/privacy/consent_store.dart';
import '../../chat_history/data/app_database.dart';
import '../domain/voice_session_state.dart';
import 'voice_chat_controller.dart';

class VoiceChatHomeScreen extends ConsumerWidget {
  const VoiceChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceChatControllerProvider);
    final messages = ref.watch(chatMessagesProvider);
    final deviceId = ref.watch(anonymousDeviceIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Companion AI'),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            onPressed: messages.maybeWhen(
              data: (items) => items.isEmpty
                  ? null
                  : () => _confirmClearHistory(context, ref),
              orElse: () => null,
            ),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _SessionStatusCard(
                state: state,
                deviceLabel: deviceId.maybeWhen(
                  data: (id) => 'Device ${id.substring(0, 10)}',
                  orElse: () => 'Device preparing',
                ),
              ),
            ),
            Expanded(
              child: messages.when(
                data: (items) => _ChatHistoryList(messages: items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Could not load local history.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _VoiceControls(state: state),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
          'This removes local transcripts and memory stored on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(voiceChatControllerProvider.notifier).clearHistory();
    }
  }
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({required this.state, required this.deviceLabel});

  final VoiceChatState state;
  final String deviceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              state.phase == VoiceSessionPhase.permissionDenied ||
                      state.phase == VoiceSessionPhase.error
                  ? Icons.mic_off_outlined
                  : Icons.graphic_eq,
              color:
                  state.phase == VoiceSessionPhase.permissionDenied ||
                      state.phase == VoiceSessionPhase.error
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.phase.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    state.errorMessage ??
                        (state.partialTranscript == null
                            ? 'Listening for Hindi/Hinglish voice.'
                            : 'Heard: ${state.partialTranscript}'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(deviceLabel, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _WaveformPlaceholder(active: state.isSessionActive),
          ],
        ),
      ),
    );
  }
}

class _ChatHistoryList extends StatelessWidget {
  const _ChatHistoryList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Start a voice session to see local transcript history.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _TranscriptBubble(message: message);
      },
    );
  }
}

class _TranscriptBubble extends ConsumerWidget {
  const _TranscriptBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'You' : 'AI',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(message.messageText),
                  if (isUser && message.status.startsWith('final')) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(voiceChatControllerProvider.notifier)
                          .replaceLatestUserTurn(),
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text('Bad transcript? Re-speak'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceControls extends ConsumerWidget {
  const _VoiceControls({required this.state});

  final VoiceChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(voiceChatControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isSessionActive && state.mockModeEnabled)
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : controller.addMockExchange,
            icon: const Icon(Icons.hearing),
            label: const Text('Dev: simulate transcript turn'),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: state.isBusy
              ? null
              : () async {
                  if (state.isSessionActive) {
                    await controller.endSession();
                    return;
                  }
                  final result = await controller.startSession();
                  if (context.mounted &&
                      result == StartSessionResult.needsConsent) {
                    await _showConsentDialog(context, ref);
                  }
                },
          icon: Icon(state.isSessionActive ? Icons.stop : Icons.mic),
          label: Text(
            state.isSessionActive ? 'End session' : 'Start voice session',
          ),
        ),
      ],
    );
  }

  Future<void> _showConsentDialog(BuildContext context, WidgetRef ref) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Microphone and AI processing'),
        content: const Text(firstSessionPrivacyCopy),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Agree'),
          ),
        ],
      ),
    );

    if (agreed == true) {
      await ref
          .read(voiceChatControllerProvider.notifier)
          .acceptConsentAndStart();
    }
  }
}

class _WaveformPlaceholder extends StatelessWidget {
  const _WaveformPlaceholder({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    final heights = active
        ? const [10.0, 18.0, 28.0, 18.0, 10.0]
        : const [8.0, 8.0, 8.0, 8.0, 8.0];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final height in heights)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
