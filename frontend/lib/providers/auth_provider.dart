import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

// Local Mock server endpoint for testing purposes
const String baseUrl = 'http://10.0.2.2:5000'; // Standard Android emulator alias for host localhost

class AuthState {
  final bool isAuthenticated;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    this.isAuthenticated = false,
    this.email,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    String? accessToken,
    String? refreshToken,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 5)));

  AuthNotifier() : super(AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final refresh = prefs.getString('refresh_token');
      final email = prefs.getString('user_email');

      if (token != null && refresh != null && email != null) {
        state = AuthState(
          isAuthenticated: true,
          email: email,
          accessToken: token,
          refreshToken: refresh,
        );
      } else {
        state = AuthState(isAuthenticated: false);
      }
    } catch (e) {
      state = AuthState(isAuthenticated: false, errorMessage: 'Failed to load session');
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userEmail = data['user']['email'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('user_email', userEmail);

        state = AuthState(
          isAuthenticated: true,
          email: userEmail,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        return true;
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Login failed. Try again.';
      state = state.copyWith(isLoading: false, errorMessage: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Network error occurred');
    }
    return false;
  }

  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 201) {
        final data = response.data;
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userEmail = data['user']['email'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('user_email', userEmail);

        state = AuthState(
          isAuthenticated: true,
          email: userEmail,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        return true;
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Registration failed. Try again.';
      state = state.copyWith(isLoading: false, errorMessage: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Network error occurred');
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_email');
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
