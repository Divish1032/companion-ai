import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final microphonePermissionServiceProvider =
    Provider<MicrophonePermissionService>(
      (ref) => PermissionHandlerMicrophonePermissionService(),
    );

abstract interface class MicrophonePermissionService {
  Future<MicrophonePermissionResult> request();
}

enum MicrophonePermissionResult { granted, denied, permanentlyDenied }

class PermissionHandlerMicrophonePermissionService
    implements MicrophonePermissionService {
  @override
  Future<MicrophonePermissionResult> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return MicrophonePermissionResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return MicrophonePermissionResult.permanentlyDenied;
    }
    return MicrophonePermissionResult.denied;
  }
}
