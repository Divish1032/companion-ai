import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/identity/anonymous_device_id.dart';
import '../../livekit_session/data/session_api_client.dart';

const _voicePreferenceKey = 'preferred_tts_voice_id_v1';

final voicePreferenceStoreProvider = Provider<VoicePreferenceStore>(
  (ref) => VoicePreferenceStore(ref.watch(secureStorageProvider)),
);

final selectedVoiceIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(voicePreferenceStoreProvider).read();
});

final ttsVoiceCatalogProvider = FutureProvider<TtsVoiceCatalog>((ref) {
  return ref.watch(sessionApiClientProvider).fetchTtsVoiceCatalog();
});

class VoicePreferenceStore {
  VoicePreferenceStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _voicePreferenceKey);

  Future<void> write(String voiceId) {
    return _storage.write(key: _voicePreferenceKey, value: voiceId);
  }
}
