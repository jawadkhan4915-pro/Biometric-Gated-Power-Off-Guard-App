import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:power_guard/main.dart';
import 'package:power_guard/providers/device_provider.dart';

// Mock DeviceNotifier to bypass CPU-intensive RSA key generation in widget tests
class MockDeviceNotifier extends DeviceNotifier {
  MockDeviceNotifier(super.ref);

  @override
  Future<void> _initDevice() async {
    state = DeviceState(
      isEnrolled: false,
      deviceId: 'mock_device_123',
      deviceModel: 'Widget Test Mock',
      publicKeyPem: 'mock_public_key',
      status: 'Protected',
      recentAttempts: const [],
      isLoading: false,
    );
  }
}

void main() {
  const channel = MethodChannel('com.example.power_guard/platform_channel');

  setUp(() {
    // Mock SharedPreferences initial values to prevent pending microtasks/timers
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'checkTriggerIntent') {
        return false;
      }
      if (methodCall.method == 'isAccessibilityServiceEnabled') {
        return false;
      }
      if (methodCall.method == 'isDeviceAdminEnabled') {
        return false;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Splash Screen renders brand elements successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame with Riverpod overrides active.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceProvider.overrideWith((ref) => MockDeviceNotifier(ref)),
        ],
        child: const SecureGuardApp(),
      ),
    );

    // Verify splash branding elements exist
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text('SECURE SHUTDOWN'), findsOneWidget);
    expect(find.text('Biometric Power Guard'), findsOneWidget);

    // Advance virtual clock to trigger splash screen timer
    await tester.pump(const Duration(seconds: 3));
    
    // Process all transition navigation frames until the tree settles
    await tester.pumpAndSettle();
  });
}
