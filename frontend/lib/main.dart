import 'package:flutter/material';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/verification_challenge_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SecureGuardApp(),
    ),
  );
}

class SecureGuardApp extends StatefulWidget {
  const SecureGuardApp({super.key});

  @override
  State<SecureGuardApp> createState() => _SecureGuardAppState();
}

class _SecureGuardAppState extends State<SecureGuardApp> {
  static const _platform = MethodChannel('com.example.power_guard/platform_channel');

  @override
  void initState() {
    super.initState();
    _setupMethodChannelListener();
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
