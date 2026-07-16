import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final voicePreviewPlayerProvider = Provider<VoicePreviewPlayer>((ref) {
  final player = JustAudioVoicePreviewPlayer();
  ref.onDispose(player.dispose);
  return player;
});

abstract interface class VoicePreviewPlayer {
  Future<void> play(Uri previewUri);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioVoicePreviewPlayer implements VoicePreviewPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(Uri previewUri) async {
    await _player.stop();
    await _player.setUrl(previewUri.toString());
    await _player.play();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
