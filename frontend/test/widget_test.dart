import 'package:flutter/material';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:power_guard/main.dart';

void main() {
  testWidgets('Splash Screen renders brand elements successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SecureGuardApp(),
      ),
    );

    // Verify splash branding elements exist
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text('SECURE SHUTDOWN'), findsOneWidget);
    expect(find.text('Biometric Power Guard'), findsOneWidget);
  });
}
