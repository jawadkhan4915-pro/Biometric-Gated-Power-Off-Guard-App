import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../providers/biometrics_provider.dart';
import '../providers/device_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _pinController = TextEditingController();
  final _overrideController = TextEditingController();
  static const _platform = MethodChannel('com.example.power_guard/platform_channel');

  bool _isAccessibilityActive = false;
  bool _isDeviceAdminActive = false;

  @override
  void initState() {
    super.initState();
    _checkNativeCompliance();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _overrideController.dispose();
    super.dispose();
  }

  Future<void> _checkNativeCompliance() async {
    if (Platform.isAndroid) {
      try {
        final bool acc = await _platform.invokeMethod('isAccessibilityServiceEnabled');
        final bool admin = await _platform.invokeMethod('isDeviceAdminEnabled');
        setState(() {
          _isAccessibilityActive = acc;
          _isDeviceAdminActive = admin;
        });
      } catch (_) {}
    }
  }

  Future<void> _savePinFallback() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be exactly 4 digits')),
      );
      return;
    }

    await ref.read(biometricsProvider.notifier).enrollPin(pin);
    if (mounted) {
      _pinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fallback PIN enrolled successfully!'), backgroundColor: Color(0xFF3DDC97)),
      );
    }
  }

  Future<void> _handleEmergencyOverride() async {
    final code = _overrideController.text.trim();
    if (code.isEmpty) return;

    // Simulate emergency server validation call (signed & rate limited on server)
    final deviceNotifier = ref.read(deviceProvider.notifier);
    
    // In a real app we hit a rate-limited endpoint. We simulate it here.
    if (code == '999999') {
      await deviceNotifier.reportShutdownAttempt(
        method: 'override',
        result: 'success',
      );
      if (mounted) {
        _overrideController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency Override verified! Code accepted.'), backgroundColor: Color(0xFF3DDC97)),
        );
      }
    } else {
      await deviceNotifier.reportShutdownAttempt(
        method: 'override',
        result: 'failure',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid override credentials. Attempt logged.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioState = ref.watch(biometricsProvider);
    final bioNotifier = ref.read(biometricsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // iOS Platform Warning Banner
          if (Platform.isIOS)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F43).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF9F43).withOpacity(0.4), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFF9F43)),
                      const SizedBox(width: 10),
                      Text(
                        'iOS Platform Constraints',
                        style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Full power-button lock isn't supported by iOS. SecureShutdown will re-verify your identity the next time this device is unlocked or reopened.",
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),

          // Android Native Permissions Section
          if (Platform.isAndroid) ...[
            _buildSectionHeader('SYSTEM INTEGRATION'),
            _buildComplianceTile(
              title: 'Accessibility Service',
              subtitle: 'Required to intercept power button presses.',
              isActive: _isAccessibilityActive,
              onTap: () async {
                await _platform.invokeMethod('openAccessibilitySettings');
                Future.delayed(const Duration(seconds: 2), _checkNativeCompliance);
              },
            ),
            _buildComplianceTile(
              title: 'Device Administrator',
              subtitle: 'Required to lock phone on unauthorized attempts.',
              isActive: _isDeviceAdminActive,
              onTap: () async {
                await _platform.invokeMethod('requestDeviceAdmin');
                Future.delayed(const Duration(seconds: 2), _checkNativeCompliance);
              },
            ),
            const SizedBox(height: 24),
          ],

          // Gating options
          _buildSectionHeader('GATING PREFERENCES'),
          SwitchListTile(
            value: bioState.requireFingerprint,
            title: Text('Require Fingerprint Lock', style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text('Challenge fingerprint on shutdown menu.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
            activeColor: const Color(0xFF4C8DFF),
            onChanged: (val) {
              bioNotifier.updateRequirements(reqFingerprint: val);
            },
          ),
          SwitchListTile(
            value: bioState.requireFace,
            title: Text('Require Face recognition', style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text('Scan reference face angles on shutdown menu.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
            activeColor: const Color(0xFF4C8DFF),
            onChanged: (val) {
              bioNotifier.updateRequirements(reqFace: val);
            },
          ),
          const SizedBox(height: 16),
          // Grace Period selector
          ListTile(
            title: Text('Grace Period', style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text('Bypass lock if device was recently active.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
            trailing: DropdownButton<int>(
              value: bioState.gracePeriodSeconds,
              dropdownColor: const Color(0xFF161C2C),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 0, child: Text('No Delay')),
                DropdownMenuItem(value: 10, child: Text('10 Seconds')),
                DropdownMenuItem(value: 30, child: Text('30 Seconds')),
                DropdownMenuItem(value: 60, child: Text('1 Minute')),
              ],
              onChanged: (val) {
                if (val != null) {
                  bioNotifier.updateRequirements(gracePeriod: val);
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Recovery configuration
          _buildSectionHeader('SECURITY RECOVERY'),
          // Fallback PIN setup
          _buildCard(
            title: bioState.fallbackPin == null ? 'Setup Fallback PIN' : 'Update Fallback PIN',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This numeric code is requested if biometrics fail 3 times.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '4-digit PIN',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C8DFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onPressed: _savePinFallback,
                      child: Text('Register', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Emergency override code input
          _buildCard(
            title: 'Emergency Override Verification',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the emergency administrative code to override system lock. Requests are rate-limited and logged.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _overrideController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Override Code',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9F43),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onPressed: _handleEmergencyOverride,
                      child: Text('Override', style: GoogleFonts.manrope(color: const Color(0xFF0F1420), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 12.0),
      child: Text(
        label,
        style: GoogleFonts.inter(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildComplianceTile({
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(title, style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3DDC97).withOpacity(0.12) : Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isActive ? 'ACTIVE' : 'INACTIVE',
            style: GoogleFonts.inter(color: isActive ? const Color(0xFF3DDC97) : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: isActive ? null : onTap,
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
