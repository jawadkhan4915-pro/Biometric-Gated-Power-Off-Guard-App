import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:pointycastle/asymmetric/api.dart';
import 'auth_provider.dart';
import '../utils/crypto_helper.dart';

class DeviceState {
  final bool isEnrolled;
  final String? deviceId;
  final String? deviceModel;
  final String? publicKeyPem;
  final String status; // Protected, Unprotected
  final List<dynamic> recentAttempts;
  final bool isLoading;
  final String? errorMessage;

  DeviceState({
    this.isEnrolled = false,
    this.deviceId,
    this.deviceModel,
    this.publicKeyPem,
    this.status = 'Protected',
    this.recentAttempts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DeviceState copyWith({
    bool? isEnrolled,
    String? deviceId,
    String? deviceModel,
    String? publicKeyPem,
    String? status,
    List<dynamic>? recentAttempts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DeviceState(
      isEnrolled: isEnrolled ?? this.isEnrolled,
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      publicKeyPem: publicKeyPem ?? this.publicKeyPem,
      status: status ?? this.status,
      recentAttempts: recentAttempts ?? this.recentAttempts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 5)));
  final _secureStorage = const FlutterSecureStorage();

  DeviceNotifier(this._ref) : super(DeviceState()) {
    _initDevice();
  }

  // Load or generate device identity
  Future<void> _initDevice() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('device_id');
      var model = prefs.getString('device_model');

      if (id == null) {
        // Generate persistent UUID for this installation
        id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Platform.operatingSystem}';
        model = Platform.isAndroid ? 'Android Device' : 'iOS Device';
        await prefs.setString('device_id', id);
        await prefs.setString('device_model', model);
      }

      // Check if keys exist in secure storage
      var publicKeyPem = await _secureStorage.read(key: 'device_public_key');
      if (publicKeyPem == null) {
        // Generate new cryptographic key pair
        final pair = CryptoHelper.generateKeyPair();
        publicKeyPem = CryptoHelper.encodePublicKeyToPem(pair.publicKey);
        final privateKeyJson = CryptoHelper.serializePrivateKey(pair.privateKey);

        await _secureStorage.write(key: 'device_public_key', value: publicKeyPem);
        await _secureStorage.write(key: 'device_private_key', value: privateKeyJson);
      }

      final enrolled = prefs.getBool('device_enrolled') ?? false;
      final savedStatus = prefs.getString('device_status') ?? 'Protected';

      state = DeviceState(
        isEnrolled: enrolled,
        deviceId: id,
        deviceModel: model,
        publicKeyPem: publicKeyPem,
        status: savedStatus,
      );

      if (enrolled) {
        fetchStatus();
        fetchAttempts();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to initialize device cryptography');
    }
  }

  // Enroll device to user account on server
  Future<bool> enrollDevice() async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.accessToken == null) {
      state = state.copyWith(errorMessage: 'Authentication required for enrollment');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _dio.post(
        '/devices/enroll',
        data: {
          'deviceId': state.deviceId,
          'deviceModel': state.deviceModel,
          'os': Platform.isAndroid ? 'android' : 'ios',
          'publicKey': state.publicKeyPem
        },
        options: Options(headers: {'Authorization': 'Bearer ${auth.accessToken}'}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('device_enrolled', true);
        state = state.copyWith(isEnrolled: true, isLoading: false);
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Device enrollment failed';
      state = state.copyWith(isLoading: false, errorMessage: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Network connection failed');
    }
    return false;
  }

  // Fetch device protection status from server
  Future<void> fetchStatus() async {
    if (state.deviceId == null) return;
    try {
      final res = await _dio.get('/devices/${state.deviceId}/status');
      if (res.statusCode == 200) {
        final newStatus = res.data['status'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_status', newStatus);
        state = state.copyWith(status: newStatus);
      }
    } catch (_) {
      // Offline fallback: keep current state
    }
  }

  // Toggle status (Protected/Unprotected)
  Future<bool> toggleProtection(bool protect) async {
    final auth = _ref.read(authProvider);
    if (state.deviceId == null || !auth.isAuthenticated) return false;

    final targetStatus = protect ? 'Protected' : 'Unprotected';
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _dio.patch(
        '/devices/${state.deviceId}/status',
        data: {'status': targetStatus},
        options: Options(headers: {'Authorization': 'Bearer ${auth.accessToken}'}),
      );

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_status', targetStatus);
        state = state.copyWith(status: targetStatus, isLoading: false);
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update protection status';
      state = state.copyWith(isLoading: false, errorMessage: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Network connection failure');
    }
    return false;
  }

  // Cryptographically sign and submit shutdown attempt
  Future<bool> reportShutdownAttempt({
    required String method,
    required String result,
    String? photoUrl,
    Map<String, double>? geolocation,
  }) async {
    if (state.deviceId == null) return false;

    try {
      // 1. Fetch private key from Secure Storage
      final privateKeyJson = await _secureStorage.read(key: 'device_private_key');
      if (privateKeyJson == null) return false;
      final privateKey = CryptoHelper.deserializePrivateKey(privateKeyJson);

      // 2. Build signing payload
      final payloadData = {
        'deviceId': state.deviceId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'method': method,
        'result': result,
        'photoUrl': photoUrl,
        'geolocation': geolocation,
      };
      
      final signedPayload = json.encode(payloadData);
      
      // 3. Cryptographically sign JSON payload
      final signature = CryptoHelper.signPayload(privateKey, signedPayload);

      // 4. Post verification request to backend
      final res = await _dio.post('/shutdown-attempts', data: {
        'deviceId': state.deviceId,
        'signature': signature,
        'signedPayload': signedPayload
      });

      if (res.statusCode == 201) {
        fetchAttempts(); // Reload activity log
        return true;
      }
    } catch (e) {
      print('Reporting shutdown failed: $e');
    }
    return false;
  }

  // Fetch recent attempts history (for Dashboard list)
  Future<void> fetchAttempts() async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.accessToken == null) return;

    try {
      final res = await _dio.get(
        '/shutdown-attempts',
        queryParameters: {'deviceId': state.deviceId, 'limit': 10},
        options: Options(headers: {'Authorization': 'Bearer ${auth.accessToken}'}),
      );

      if (res.statusCode == 200) {
        state = state.copyWith(recentAttempts: res.data['attempts']);
      }
    } catch (_) {
      // Offline fallback: keep current log list
    }
  }
}

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier(ref);
});
