import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import 'dashboard_screen.dart';

class OnboardingCarousel extends ConsumerStatefulWidget {
  const OnboardingCarousel({super.key});

  @override
  ConsumerState<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends ConsumerState<OnboardingCarousel> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  static const _platform = MethodChannel('com.example.power_guard/platform_channel');

  // Local state for checking system settings
  bool _isAccessibilityEnabled = false;
  bool _isDeviceAdminEnabled = false;

  // Login form text fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool accEnabled = await _platform.invokeMethod('isAccessibilityServiceEnabled');
      final bool adminEnabled = await _platform.invokeMethod('isDeviceAdminEnabled');
      setState(() {
        _isAccessibilityEnabled = accEnabled;
        _isDeviceAdminEnabled = adminEnabled;
      });
    } catch (_) {}
  }

  Future<void> _requestAccessibility() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
      // Wait for user to return and re-evaluate
      Future.delayed(const Duration(seconds: 2), _checkPermissions);
    } catch (_) {}
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      await _platform.invokeMethod('requestDeviceAdmin');
      // Wait for user to return and re-evaluate
      Future.delayed(const Duration(seconds: 2), _checkPermissions);
    } catch (_) {}
  }

  Future<void> _handleAuthSubmit() async {
    final authNotifier = ref.read(authProvider.notifier);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    bool success = false;
    if (_isRegistering) {
      success = await authNotifier.register(email, password);
    } else {
      success = await authNotifier.login(email, password);
    }

    if (success && mounted) {
      // Binds device cryptography signature on server
      final enrolled = await deviceNotifier.enrollDevice();
      if (enrolled && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final deviceState = ref.watch(deviceProvider);

    final List<Widget> slides = [
      // Slide 1: Welcome & Accessibility
      _buildSlide(
        icon: Icons.accessibility_new,
        title: 'Accessibility Intercept',
        description: 'SecureShutdown uses Accessibility events to detect when the device is being powered off. This is required to intercept the physical button action.',
        statusWidget: _buildPermissionPill(
          isEnabled: _isAccessibilityEnabled,
          label: _isAccessibilityEnabled ? 'Accessibility Active' : 'Enable Accessibility',
          onTap: _requestAccessibility,
        ),
      ),
      // Slide 2: Device Administrator
      _buildSlide(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Device Administrator',
        description: 'To prevent intruders from bypassing security, Device Admin access allows SecureShutdown to instantly lock the screen when verification fails 3 times.',
        statusWidget: _buildPermissionPill(
          isEnabled: _isDeviceAdminEnabled,
          label: _isDeviceAdminEnabled ? 'Admin Enabled' : 'Enable Device Admin',
          onTap: _requestDeviceAdmin,
        ),
      ),
      // Slide 3: Account & Device Binding
      _buildAuthSlide(authState, deviceState),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      body: SafeArea(
        child: Column(
          children: [
            // Page Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentIndex + 1} of ${slides.length}',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: List.generate(
                      slides.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: _currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? const Color(0xFF4C8DFF) : Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Carousel Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  _checkPermissions();
                },
                children: slides,
              ),
            ),
            // Bottom Action
            if (_currentIndex < slides.length - 1)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C8DFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(
                      'Continue',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required IconData icon,
    required String title,
    required String description,
    required Widget statusWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF4C8DFF).withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4C8DFF).withOpacity(0.2), width: 1.5),
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF4C8DFF)),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          statusWidget,
        ],
      ),
    );
  }

  Widget _buildPermissionPill({
    required bool isEnabled,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFF3DDC97).withOpacity(0.15) : const Color(0xFF4C8DFF),
          borderRadius: BorderRadius.circular(16),
          border: isEnabled ? Border.all(color: const Color(0xFF3DDC97).withOpacity(0.4), width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.check_circle : Icons.arrow_circle_right_outlined,
              color: isEnabled ? const Color(0xFF3DDC97) : Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: isEnabled ? const Color(0xFF3DDC97) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSlide(AuthState authState, DeviceState deviceState) {
    final bool loading = authState.isLoading || deviceState.isLoading;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 16, bottom: 24),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4C8DFF).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_outlined, size: 36, color: Color(0xFF4C8DFF)),
            ),
          ),
          Text(
            _isRegistering ? 'Register Owner Account' : 'Authenticate Credentials',
            style: GoogleFonts.manrope(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enroll this device under your secure account to monitor alerts and log security activities.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (authState.errorMessage != null || deviceState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.3)),
              ),
              child: Text(
                authState.errorMessage ?? deviceState.errorMessage ?? '',
                style: GoogleFonts.inter(color: const Color(0xFFFF4D4D), fontSize: 13),
              ),
            ),
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Email address',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C8DFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: loading ? null : _handleAuthSubmit,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _isRegistering ? 'Register & Enroll' : 'Login & Secure Device',
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isRegistering = !_isRegistering;
                });
              },
              child: Text(
                _isRegistering ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                style: GoogleFonts.inter(color: const Color(0xFF4C8DFF), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
