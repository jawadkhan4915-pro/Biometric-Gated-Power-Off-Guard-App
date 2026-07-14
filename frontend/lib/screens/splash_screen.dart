import 'package:flutter/material';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import 'onboarding_carousel.dart';
import 'dashboard_screen.dart';
import 'verification_challenge_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  static const _platform = MethodChannel('com.example.power_guard/platform_channel');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.initState();
  }

  Future<void> _initializeApp() async {
    // 1. Minimum animation delay
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // 2. Check if launched due to power button intercept
    try {
      final bool triggerChallenge = await _platform.invokeMethod('checkTriggerIntent');
      if (triggerChallenge) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerificationChallengeScreen()),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error checking trigger intent: $e');
    }

    // 3. Check authentication status
    final auth = ref.read(authProvider);
    final device = ref.read(deviceProvider);

    if (auth.isAuthenticated) {
      if (device.isEnrolled) {
        // Enrolled and authenticated -> Go to Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // Authenticated but device not enrolled -> Go to Onboarding Carousel to set permissions
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingCarousel()),
        );
      }
    } else {
      // Direct login onboarding flow
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingCarousel()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0Color.fromARGB(255, 15, 20, 32).value),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Symbol
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF4C8DFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4C8DFF).withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: Color(0xFF4C8DFF),
                ),
              ),
              const SizedBox(height: 24),
              // App Title
              Text(
                'SECURE SHUTDOWN',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Biometric Power Guard',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
