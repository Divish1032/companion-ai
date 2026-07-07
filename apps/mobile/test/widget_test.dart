import 'package:companion_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('voice shell toggles placeholder session', (tester) async {
    await tester.pumpWidget(const CompanionApp());

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Session placeholder active'), findsNothing);

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    expect(find.text('Ready'), findsNothing);
    expect(find.text('Session placeholder active'), findsOneWidget);
  });
}
