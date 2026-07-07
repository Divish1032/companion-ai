import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../identity/anonymous_device_id.dart';

const privacyConsentCopyVersion = 'voice_mic_ai_processing_v1';

const firstSessionPrivacyCopy =
    'Your voice and transcript are sent to our server and AI providers to '
    'understand and respond.\n\n'
    'We do not store raw audio in this MVP. Chat history is saved on this '
    'device.\n\n'
    'You can clear chat history anytime.\n\n'
    'Tap Agree to continue.';

const _consentAcceptedAtKey = 'privacy_consent_accepted_at_v1';
const _consentCopyVersionKey = 'privacy_consent_copy_version_v1';

final consentStoreProvider = Provider<ConsentStore>(
  (ref) => ConsentStore(ref.watch(secureStorageProvider)),
);

final hasAcceptedConsentProvider = FutureProvider<bool>((ref) {
  return ref.watch(consentStoreProvider).hasAcceptedCurrentCopy();
});

class ConsentStore {
  ConsentStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<bool> hasAcceptedCurrentCopy() async {
    final acceptedAt = await _storage.read(key: _consentAcceptedAtKey);
    final copyVersion = await _storage.read(key: _consentCopyVersionKey);
    return acceptedAt != null && copyVersion == privacyConsentCopyVersion;
  }

  Future<void> acceptCurrentCopy(DateTime acceptedAt) async {
    await _storage.write(
      key: _consentAcceptedAtKey,
      value: acceptedAt.toUtc().toIso8601String(),
    );
    await _storage.write(
      key: _consentCopyVersionKey,
      value: privacyConsentCopyVersion,
    );
  }
}
