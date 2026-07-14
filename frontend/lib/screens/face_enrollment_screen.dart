import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../providers/biometrics_provider.dart';

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _hasCameraError = false;

  int _currentStep = 1; // 1: Front, 2: Left, 3: Right
  bool _isCapturing = false;
  double _scanProgress = 0.0;

  // Local keypoints array mock
  final List<List<double>> _capturedKeypoints = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _hasCameraError = true;
        });
        return;
      }

      // Pick front camera
      final frontCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      setState(() {
        _hasCameraError = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _simulateScanning() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _scanProgress = 0.0;
    });

    // Simulate progress bar scan animation
    for (int i = 0; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _scanProgress = i / 20.0;
      });
    }

    // Trigger haptic success feedback
    HapticFeedback.lightImpact();

    // Record mock keypoints coordinates for this angle
    _capturedKeypoints.add([12.3 * _currentStep, 45.6 * _currentStep, 78.9 * _currentStep]);

    setState(() {
      _isCapturing = false;
    });

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Completed all 3 angles! Register embedding hash on server
      final notifier = ref.read(biometricsProvider.notifier);
      final success = await notifier.enrollFaceEmbedding(_capturedKeypoints);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face enrollment completed and secured successfully!'),
            backgroundColor: Color(0xFF3DDC97),
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(biometricsProvider).errorMessage ?? 'Enrollment failed. Try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _getStepInstruction() {
    switch (_currentStep) {
      case 1:
        return 'Look directly at the front camera';
      case 2:
        return 'Turn your head slowly to the left';
      case 3:
        return 'Turn your head slowly to the right';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioState = ref.watch(biometricsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      appBar: AppBar(
        title: Text('Face Enrollment', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ANGLE RECORDING',
                          style: GoogleFonts.inter(color: const Color(0xFF4C8DFF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Profile Capture ${_currentStep}/3',
                          style: GoogleFonts.manrope(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentStep > index
                              ? const Color(0xFF3DDC97)
                              : (_currentStep == index + 1 ? const Color(0xFF4C8DFF) : Colors.white12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Live Preview Frame with Oval
            Expanded(
              child: Center(
                child: Container(
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(140),
                    border: Border.all(
                      color: _isCapturing ? const Color(0xFF4C8DFF) : const Color(0xFF4C8DFF).withOpacity(0.3),
                      width: 3.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(140),
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        // Live Stream vs Simulator Mock
                        _isCameraInitialized && !_hasCameraError
                            ? CameraPreview(_cameraController!)
                            : _buildMockCameraPreview(),
                        // Progress Sweep animation on capture
                        if (_isCapturing)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: 0.15,
                              duration: const Duration(milliseconds: 100),
                              child: Container(color: const Color(0xFF4C8DFF)),
                            ),
                          ),
                        // Instruction guidance overlay
                        Positioned(
                          bottom: 30,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStepInstruction(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        // Loading state overlay
                        if (bioState.isLoading)
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            child: const Center(child: CircularProgressIndicator(color: Color(0xFF4C8DFF))),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Capture Action button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_isCapturing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _scanProgress,
                            backgroundColor: Colors.white10,
                            color: const Color(0xFF4C8DFF),
                            minHeight: 4,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Analyzing points... ${( _scanProgress * 100).toInt()}%',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C8DFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isCapturing || bioState.isLoading ? null : _simulateScanning,
                      child: Text(
                        _isCapturing ? 'Scanning Face...' : 'Scan Angle',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockCameraPreview() {
    return Container(
      color: const Color(0xFF161C2C),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.face, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Live Face Simulator',
            style: GoogleFonts.manrope(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Hardware Camera Simulator Active',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
