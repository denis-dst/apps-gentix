import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool _isOnline = true;
  String _apiUrl = 'https://sekelik-news.com/gentix-apps/api';
  String _localIp = '192.168.1.1';
  bool _isConnected = false;

  bool get isOnline => _isOnline;
  String get apiUrl => _apiUrl;
  String get localIp => _localIp;
  bool get isConnected => _isConnected;

  String get baseUrl {
    if (_isOnline) {
      return _apiUrl;
    } else {
      return 'http://$_localIp/api';
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isOnline = _prefs.getBool('isOnline') ?? true;
    _apiUrl = _prefs.getString('apiUrl') ?? 'https://sekelik-news.com/gentix-apps/api';
    _localIp = _prefs.getString('localIp') ?? '192.168.1.1';
    notifyListeners();
  }

  Future<void> setMode(bool online) async {
    _isOnline = online;
    await _prefs.setBool('isOnline', online);
    _isConnected = false;
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    await _prefs.setString('apiUrl', url);
    _isConnected = false;
    notifyListeners();
  }

  Future<void> setLocalIp(String ip) async {
    _localIp = ip;
    await _prefs.setString('localIp', ip);
    _isConnected = false;
    notifyListeners();
  }

  Future<bool> checkConnection() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
      ));

      // Simple health check or just ping the base url
      final response = await dio.get('/health-check').catchError((e) {
        // If 404, the server is there but endpoint doesn't exist, still "connected"
        if (e is DioException && e.response?.statusCode != null) {
          return e.response!;
        }
        throw e;
      });

      _isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }
}
