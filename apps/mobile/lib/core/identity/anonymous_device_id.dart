import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _deviceIdKey = 'anonymous_device_id_v1';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final anonymousDeviceIdStoreProvider = Provider<AnonymousDeviceIdStore>(
  (ref) => AnonymousDeviceIdStore(ref.watch(secureStorageProvider)),
);

final anonymousDeviceIdProvider = FutureProvider<String>((ref) {
  return ref.watch(anonymousDeviceIdStoreProvider).getOrCreate();
});

class AnonymousDeviceIdStore {
  AnonymousDeviceIdStore(this._storage, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = 'anon_${_uuid.v4()}';
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }
}
