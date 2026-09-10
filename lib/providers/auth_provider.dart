import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_client.dart';
import '../models/user_model.dart';
import 'package:dio/dio.dart';

import '../providers/settings_provider.dart';

class AuthProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;
  final _storage = const FlutterSecureStorage();

  AuthProvider(this.settings) {
    _apiClient = ApiClient(settings.baseUrl);
    // On fresh app start (e.g. after swipeout), clear any lingering stored token
    _storage.delete(key: 'token');
  }

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      _error = 'Email dan password tidak boleh kosong.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      final response = await _apiClient.dio.post('/login', data: {
        'email': cleanEmail,
        'password': cleanPassword,
        'device_name': 'android_mobile_app',
      });

      final token = response.data['token'];
      _user = UserModel.fromJson(response.data['user']);
      
      await _storage.write(key: 'token', value: token);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isLoading = false;
      _error = e.response?.data['message'] ?? 'Login failed. Please check your credentials.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'An unexpected error occurred: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      await _apiClient.dio.post('/logout');
    } catch (e) {
      // Ignore logout error
    }
    await _storage.delete(key: 'token');
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      try {
        _apiClient.updateBaseUrl(settings.baseUrl);
        final response = await _apiClient.dio.get('/user');
        // Note: Backend /user endpoint returns the user object directly or nested
        // Adjusting based on common Laravel responses
        final userData = response.data;
        _user = UserModel(
          name: userData['name'],
          email: userData['email'],
          role: userData['role'] ?? '', // Might need mapping if roles are in a different field
          tenant: userData['tenant']?['name'] ?? '',
        );
        notifyListeners();
      } catch (e) {
        await _storage.delete(key: 'token');
      }
    }
  }
}
