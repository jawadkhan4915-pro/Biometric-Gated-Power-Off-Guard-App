import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'auth_provider.dart';
import 'device_provider.dart';

class BiometricsState {
  final bool hasFingerprint;
  final bool hasFace;
  final bool isFaceEnrolled;
  final String? fallbackPin;
  final int failureCount;
  final bool isLockedOut;
  final bool requireFace;
  final bool requireFingerprint;
  final int gracePeriodSeconds; // 0, 10, 30, 60
  final bool isLoading;
  final String? errorMessage;

  BiometricsState({
    this.hasFingerprint = false,
    this.hasFace = false,
    this.isFaceEnrolled = false,
    this.fallbackPin,
    this.failureCount = 0,
    this.isLockedOut = false,
    this.requireFace = false,
    this.requireFingerprint = true, // Default to fingerprint protection
    this.gracePeriodSeconds = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  BiometricsState copyWith({
    bool? hasFingerprint,
    bool? hasFace,
    bool? isFaceEnrolled,
    String? fallbackPin,
    int? failureCount,
    bool? isLockedOut,
    bool? requireFace,
    bool? requireFingerprint,
    int? gracePeriodSeconds,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BiometricsState(
      hasFingerprint: hasFingerprint ?? this.hasFingerprint,
      hasFace: hasFace ?? this.hasFace,
      isFaceEnrolled: isFaceEnrolled ?? this.isFaceEnrolled,
      fallbackPin: fallbackPin ?? this.fallbackPin,
      failureCount: failureCount ?? this.failureCount,
      isLockedOut: isLockedOut ?? this.isLockedOut,
      requireFace: requireFace ?? this.requireFace,
      requireFingerprint: requireFingerprint ?? this.requireFingerprint,
      gracePeriodSeconds: gracePeriodSeconds ?? this.gracePeriodSeconds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BiometricsNotifier extends StateNotifier<BiometricsState> {
  final Ref _ref;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 5)));

  BiometricsNotifier(this._ref) : super(BiometricsState()) {
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final types = await _localAuth.getAvailableBiometrics();
      
      final hasFingerprint = types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong);
      final hasFace = types.contains(BiometricType.face);

      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString('fallback_pin');
      final faceEnrolled = prefs.getBool('face_enrolled') ?? false;
      final reqFace = prefs.getBool('require_face') ?? false;
      final reqFinger = prefs.getBool('require_fingerprint') ?? true;
      final grace = prefs.getInt('grace_period_seconds') ?? 0;

      state = BiometricsState(
        hasFingerprint: hasFingerprint || isAvailable, // Fallback to basic bio check
        hasFace: hasFace,
        isFaceEnrolled: faceEnrolled,
        fallbackPin: pin,
        requireFace: reqFace,
        requireFingerprint: reqFinger,
        gracePeriodSeconds: grace,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Biometrics hardware initialization failed');
    }
  }

  // Local Biometric Authentication
  Future<bool> authenticateLocally(String reason) async {
    if (state.isLockedOut) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        resetFailureCount();
        return true;
      } else {
        _incrementFailures();
      }
    } catch (e) {
      _incrementFailures();
    }
    return false;
  }

  // Enroll Fallback PIN
  Future<void> enrollPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fallback_pin', pin);
    state = state.copyWith(fallbackPin: pin);
  }

  // Verify PIN fallback
  bool verifyPin(String pin) {
    if (state.isLockedOut || state.fallbackPin == null) return false;
    
    if (state.fallbackPin == pin) {
      resetFailureCount();
      return true;
    } else {
      _incrementFailures();
      return false;
    }
  }

  // Set auth settings preferences
  Future<void> updateRequirements({bool? reqFace, bool? reqFingerprint, int? gracePeriod}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reqFace != null) {
      await prefs.setBool('require_face', reqFace);
    }
    if (reqFingerprint != null) {
      await prefs.setBool('require_fingerprint', reqFingerprint);
    }
    if (gracePeriod != null) {
      await prefs.setInt('grace_period_seconds', gracePeriod);
    }

    state = state.copyWith(
      requireFace: reqFace ?? state.requireFace,
      requireFingerprint: reqFingerprint ?? state.requireFingerprint,
      gracePeriodSeconds: gracePeriod ?? state.gracePeriodSeconds,
    );
  }

  // Simulate Face Embedding and register embedding hash on server
  Future<bool> enrollFaceEmbedding(List<List<double>> rawAngleKeypoints) async {
    final auth = _ref.read(authProvider);
    final device = _ref.read(deviceProvider);
    
    if (!auth.isAuthenticated || auth.accessToken == null || device.deviceId == null) {
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Generate local simulated face embedding representation
      // We compute a SHA-256 hash of the keypoint arrays for the embedding model profile backup
      final jsonString = json.encode(rawAngleKeypoints);
      final bytes = utf8.encode(jsonString);
      final embeddingHash = sha256.convert(bytes).toString();

      // 2. Upload hashed embedding backup to server
      final res = await _dio.post(
        '/biometrics/enroll',
        data: {
          'deviceId': device.deviceId,
          'faceEmbeddingHash': embeddingHash
        },
        options: Options(headers: {'Authorization': 'Bearer ${auth.accessToken}'}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('face_enrolled', true);
        state = state.copyWith(isFaceEnrolled: true, isLoading: false);
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to enroll face embeddings';
      state = state.copyWith(isLoading: false, errorMessage: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Network connection failed');
    }
    return false;
  }

  void _incrementFailures() {
    final nextFailures = state.failureCount + 1;
    final isLocked = nextFailures >= 3;
    state = state.copyWith(
      failureCount: nextFailures,
      isLockedOut: isLocked,
    );

    // If locked, we report failure event cryptographically
    if (isLocked) {
      _ref.read(deviceProvider.notifier).reportShutdownAttempt(
        method: state.requireFace ? 'face' : 'fingerprint',
        result: 'failure',
      );
    }
  }

  void resetFailureCount() {
    state = state.copyWith(failureCount: 0, isLockedOut: false);
  }
}

final biometricsProvider = StateNotifierProvider<BiometricsNotifier, BiometricsState>((ref) {
  return BiometricsNotifier(ref);
});
