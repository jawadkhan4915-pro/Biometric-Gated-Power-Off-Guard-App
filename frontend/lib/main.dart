import 'package:flutter/material';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'screens/splash_screen.dart';
import 'screens/verification_challenge_screen.dart';
import 'providers/device_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SecureGuardApp(),
    ),
  );
}

class SecureGuardApp extends ConsumerStatefulWidget {
  const SecureGuardApp({super.key});

  @override
  ConsumerState<SecureGuardApp> createState() => _SecureGuardAppState();
}

class _SecureGuardAppState extends ConsumerState<SecureGuardApp> with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.example.power_guard/platform_channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannelListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-verify identity on iOS foreground resumption
      final device = ref.read(deviceProvider);
      if (Platform.isIOS && device.status == 'Protected') {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerificationChallengeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _setupMethodChannelListener() {
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onPowerOffIntercepted') {
        // Accessibility service intercepted a shutdown trigger - display overlay instantly!
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerificationChallengeScreen()),
          (route) => false, // Clears navigation history to prevent backing out
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureShutdown Guard',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      // Curated security dark theme (#0F1420 Navy background, confident #4C8DFF blue accents)
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1420),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4C8DFF),
          secondary: Color(0xFF3DDC97),
          surface: Color(0xFF161C2C),
          background: Color(0xFF0F1420),
          error: Color(0xFFFF4D4D),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
