import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../providers/biometrics_provider.dart';
import '../providers/device_provider.dart';

class VerificationChallengeScreen extends ConsumerStatefulWidget {
  const VerificationChallengeScreen({super.key});

  @override
  ConsumerState<VerificationChallengeScreen> createState() => _VerificationChallengeScreenState();
}

class _VerificationChallengeScreenState extends ConsumerState<VerificationChallengeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _usePinFallback = false;
  final List<String> _pinDigits = [];

  static const _platform = MethodChannel('com.example.power_guard/platform_channel');

  @override
  void initState() {
    super.initState();
    // Configure immersive mode to hide status & navigation bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-trigger biometric prompt on page load (sub-300ms budget)
    Future.microtask(() {
      _triggerBiometricAuth();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Restore system overlays on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _triggerBiometricAuth() async {
    final bioNotifier = ref.read(biometricsProvider.notifier);
    final bioState = ref.read(biometricsProvider);

    final String reason = bioState.requireFace 
        ? 'Scan face to authorize device shutdown' 
        : 'Verify fingerprint to authorize device shutdown';

    final success = await bioNotifier.authenticateLocally(reason);

    if (success && mounted) {
      _handleAuthSuccess();
    } else {
      _checkLockoutState();
    }
  }

  Future<void> _handleAuthSuccess() async {
    // 1. Log cryptographic success to backend
    final deviceNotifier = ref.read(deviceProvider.notifier);
    final bioState = ref.read(biometricsProvider);

    await deviceNotifier.reportShutdownAttempt(
      method: bioState.requireFace ? 'face' : 'fingerprint',
      result: 'success',
    );

    // 2. Exit screen and allow shut down
    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification success. Releasing power block.'),
          backgroundColor: Color(0xFF3DDC97),
        ),
      );
      // Wait for snackbar, then quit
      await Future.delayed(const Duration(seconds: 1));
      SystemNavigator.pop(); // Standard exit call
    }
  }

  Future<void> _checkLockoutState() async {
    final bioState = ref.read(biometricsProvider);

    if (bioState.isLockedOut) {
      // 1. Capture intruder photo (Simulated base64 camera image)
      const String simulatedIntruderPhoto = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
      
      final deviceNotifier = ref.read(deviceProvider.notifier);
      await deviceNotifier.reportShutdownAttempt(
        method: bioState.requireFace ? 'face' : 'fingerprint',
        result: 'failure',
        photoUrl: simulatedIntruderPhoto,
        geolocation: {'latitude': 37.7749, 'longitude': -122.4194}, // Mock location
      );

      // 2. Lock screen using device admin receiver
      try {
        await _platform.invokeMethod('lockDevice');
      } catch (e) {
        debugPrint('Device Lock Failure: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device locked due to multiple verification failures.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handlePinPress(String value) {
    if (value == 'delete') {
      if (_pinDigits.isNotEmpty) {
        setState(() {
          _pinDigits.removeLast();
        });
      }
    } else {
      if (_pinDigits.length < 4) {
        setState(() {
          _pinDigits.add(value);
        });
      }

      if (_pinDigits.length == 4) {
        _verifyPinCode();
      }
    }
  }

  Future<void> _verifyPinCode() async {
    final enteredPin = _pinDigits.join();
    final bioNotifier = ref.read(biometricsProvider.notifier);
    
    final success = bioNotifier.verifyPin(enteredPin);

    if (success) {
      _handleAuthSuccess();
    } else {
      setState(() {
        _pinDigits.clear();
      });
      _checkLockoutState();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect PIN code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioState = ref.watch(biometricsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      body: WillPopScope(
        onWillPop: () async => false, // Intercept Android back button
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                if (!_usePinFallback) ...[
                  // Pulse Biometric Visuals
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D4D).withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.15), width: 2),
                      ),
                      child: Icon(
                        bioState.requireFace ? Icons.face : Icons.fingerprint,
                        size: 54,
                        color: const Color(0xFFFF4D4D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Verification Required',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verify identity to authorize device power-off',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Attempt ${bioState.failureCount + 1} of 3',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF4D4D),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Fallback options
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _usePinFallback = true;
                      });
                    },
                    child: Text(
                      'Use PIN fallback',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF4C8DFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else ...[
                  // PIN Numeric pad
                  Text(
                    'Enter Fallback PIN',
                    style: GoogleFonts.manrope(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your mandatory recovery code',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _pinDigits.length > index ? const Color(0xFF4C8DFF) : Colors.white12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Keyboard layout
                  _buildKeyboard(),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _usePinFallback = false;
                        _pinDigits.clear();
                      });
                    },
                    child: Text(
                      'Back to Biometrics',
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    final List<List<String>> keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'delete']
    ];

    return Table(
      children: keys.map((row) {
        return TableRow(
          children: row.map((key) {
            if (key == '') {
              return const SizedBox.shrink();
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: IconButton(
                  iconSize: 48,
                  onPressed: () => _handlePinPress(key),
                  icon: Container(
                    alignment: Alignment.center,
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      shape: BoxShape.circle,
                    ),
                    child: key == 'delete'
                        ? const Icon(Icons.backspace_outlined, color: Colors.white70, size: 20)
                        : Text(
                            key,
                            style: GoogleFonts.manrope(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
