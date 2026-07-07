import 'package:companion_mobile/app.dart';
import 'package:companion_mobile/core/audio/audio_session_service.dart';
import 'package:companion_mobile/core/identity/anonymous_device_id.dart';
import 'package:companion_mobile/core/permissions/microphone_permission_service.dart';
import 'package:companion_mobile/core/privacy/consent_store.dart';
import 'package:companion_mobile/features/chat_history/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mock voice session persists, re-speaks, and clears history', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_testApp(database));

    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Start mock session'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone and AI processing'), findsOneWidget);

    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();
    expect(find.text('Listening in mock mode'), findsOneWidget);
    expect(find.textContaining('Namaste.'), findsOneWidget);

    await tester.tap(find.text('Add mock voice turn'));
    await tester.pumpAndSettle();
    expect(find.text('Aaj mood thoda off hai.'), findsOneWidget);
    expect(find.text('Bad transcript? Re-speak'), findsOneWidget);

    await tester.tap(find.text('Bad transcript? Re-speak'));
    await tester.pumpAndSettle();
    expect(find.textContaining('re-spoken clearly'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_testApp(database));
    await tester.pumpAndSettle();
    expect(find.textContaining('re-spoken clearly'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('re-spoken clearly'), findsNothing);
    expect(
      find.text('Start a mock voice session to see local transcript history.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Widget _testApp(AppDatabase database) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => database),
      anonymousDeviceIdProvider.overrideWith((ref) async => 'anon_test_device'),
      consentStoreProvider.overrideWith((ref) => _FakeConsentStore()),
      microphonePermissionServiceProvider.overrideWith(
        (ref) => _GrantedMicrophonePermissionService(),
      ),
      audioSessionServiceProvider.overrideWith(
        (ref) => _NoopAudioSessionService(),
      ),
    ],
    child: const CompanionApp(),
  );
}

class _FakeConsentStore implements ConsentStore {
  bool _accepted = false;

  @override
  Future<void> acceptCurrentCopy(DateTime acceptedAt) async {
    _accepted = true;
  }

  @override
  Future<bool> hasAcceptedCurrentCopy() async => _accepted;
}

class _GrantedMicrophonePermissionService
    implements MicrophonePermissionService {
  @override
  Future<MicrophonePermissionResult> request() async {
    return MicrophonePermissionResult.granted;
  }
}

class _NoopAudioSessionService extends AudioSessionService {
  @override
  Future<void> configureForVoiceCompanion() async {}
}
