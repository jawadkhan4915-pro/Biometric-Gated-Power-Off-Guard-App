import 'package:flutter/material';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../providers/biometrics_provider.dart';
import 'settings_screen.dart';
import 'incident_detail_screen.dart';
import 'face_enrollment_screen.dart';
import 'onboarding_carousel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Pull latest device and logs data
    Future.microtask(() {
      ref.read(deviceProvider.notifier).fetchStatus();
      ref.read(deviceProvider.notifier).fetchAttempts();
    });
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingCarousel()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final deviceState = ref.watch(deviceProvider);
    final bioState = ref.watch(biometricsProvider);

    final isProtected = deviceState.status == 'Protected';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      appBar: AppBar(
        title: Text(
          'SECURESHUTDOWN',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(deviceProvider.notifier).fetchStatus();
            await ref.read(deviceProvider.notifier).fetchAttempts();
          },
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Hero Status Card
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isProtected
                        ? [const Color(0xFF1F3E3D), const Color(0xFF132525)]
                        : [const Color(0xFF3E2D1F), const Color(0xFF251A13)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isProtected
                        ? const Color(0xFF3DDC97).withOpacity(0.2)
                        : const Color(0xFFFF9F43).withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHIELD STATUS',
                              style: GoogleFonts.inter(
                                color: isProtected ? const Color(0xFF3DDC97) : const Color(0xFFFF9F43),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isProtected ? 'Active Protection' : 'Guard Disabled',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        // Protected Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isProtected
                                ? const Color(0xFF3DDC97).withOpacity(0.15)
                                : const Color(0xFFFF9F43).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isProtected ? 'PROTECTED' : 'WARNING',
                            style: GoogleFonts.inter(
                              color: isProtected ? const Color(0xFF3DDC97) : const Color(0xFFFF9F43),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Quick Action Toggle button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isProtected ? const Color(0xFF3DDC97) : const Color(0xFFFF9F43),
                          foregroundColor: const Color(0xFF0F1420),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: deviceState.isLoading
                            ? null
                            : () => ref.read(deviceProvider.notifier).toggleProtection(!isProtected),
                        child: deviceState.isLoading
                            ? const CircularProgressIndicator(color: Color(0xFF0F1420))
                            : Text(
                                isProtected ? 'Disable Shield Protection' : 'Activate Shield Protection',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Biometric enrollment shortcuts
              if (!bioState.isFaceEnrolled)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C8DFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4C8DFF).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.face_retouching_natural, color: Color(0xFF4C8DFF), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Face Recognition is Pending',
                              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Complete biometric details to enable facial auth.',
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C8DFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                          );
                        },
                        child: Text('Setup', style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              // Quick Stats Row
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.shield_outlined,
                    label: 'Security Protocol',
                    val: bioState.requireFace && bioState.requireFingerprint
                        ? 'Dual Biometric'
                        : (bioState.requireFace ? 'Face ID' : 'Fingerprint'),
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    icon: Icons.history_toggle_off,
                    label: 'Grace Period',
                    val: bioState.gracePeriodSeconds == 0 ? 'None' : '${bioState.gracePeriodSeconds}s Delay',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Timeline Activity Log Section
              Text(
                'RECENT LOG DETAILS',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              if (deviceState.recentAttempts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.playlist_add_check, size: 48, color: Colors.white12),
                        const SizedBox(height: 12),
                        Text(
                          'No security events logged.',
                          style: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...deviceState.recentAttempts.map((attempt) => _buildActivityTile(attempt)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String val}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161C2C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              val,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(dynamic attempt) {
    final String method = attempt['method'] ?? 'unknown';
    final String result = attempt['result'] ?? 'unknown';
    final String timestampStr = attempt['timestamp'] ?? '';
    final String signature = attempt['signature'] ?? '';
    final String alertPhoto = attempt['photoUrl'] ?? '';

    final DateTime dateTime = DateTime.tryParse(timestampStr) ?? DateTime.now();
    final String formattedTime = '${dateTime.month}/${dateTime.day} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    final bool isSuccess = result == 'success';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(attempt: attempt),
            ),
          );
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSuccess ? const Color(0xFF3DDC97).withOpacity(0.1) : const Color(0xFFFF4D4D).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuccess ? Icons.verified_user_outlined : Icons.report_problem_outlined,
            color: isSuccess ? const Color(0xFF3DDC97) : const Color(0xFFFF4D4D),
            size: 20,
          ),
        ),
        title: Text(
          isSuccess ? 'Authorized Shutdown' : 'Intrusion Alert Locked',
          style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$formattedTime via ${method.toUpperCase()}',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white30),
      ),
    );
  }
}
