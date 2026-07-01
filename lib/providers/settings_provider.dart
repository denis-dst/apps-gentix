import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool _isOnline = true;
  String _apiUrl = 'https://gentix-apps.com/api';
  String _localIp = '192.168.202.253';
  bool _isConnected = false;
  // Mode konfirmasi hasil scan di gate:
  // false = tekan tombol OK (manual), true = timer otomatis 3 detik.
  bool _gateAutoTimer = false;

  bool get isOnline => _isOnline;
  String get apiUrl => _apiUrl;
  String get localIp => _localIp;
  bool get isConnected => _isConnected;
  bool get gateAutoTimer => _gateAutoTimer;

  String get baseUrl {
    if (_isOnline) {
      return _apiUrl;
    } else {
      return 'http://$_localIp/gentix-apps/api';
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isOnline = _prefs.getBool('isOnline') ?? true;
    _apiUrl = _prefs.getString('apiUrl') ?? 'https://gentix-apps.com/api';
    _localIp = _prefs.getString('localIp') ?? '192.168.202.253';
    _gateAutoTimer = _prefs.getBool('gateAutoTimer') ?? false;
    notifyListeners();
  }

  Future<void> setMode(bool online) async {
    _isOnline = online;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> setLocalIp(String ip) async {
    _localIp = ip;
    _isConnected = false;
    notifyListeners();
  }

  // Disimpan langsung agar tidak bergantung pada tombol "Simpan Pengaturan"
  // (yang hanya muncul saat koneksi berhasil).
  Future<void> setGateAutoTimer(bool value) async {
    _gateAutoTimer = value;
    notifyListeners();
    await _prefs.setBool('gateAutoTimer', value);
  }

  Future<void> saveSettings() async {
    await _prefs.setBool('isOnline', _isOnline);
    await _prefs.setString('apiUrl', _apiUrl);
    await _prefs.setString('localIp', _localIp);
    await _prefs.setBool('gateAutoTimer', _gateAutoTimer);
    notifyListeners();
  }

  Future<bool> checkConnection() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
      ));

      // Simple health check or just ping the base url
      await dio.get('/health-check').catchError((e) {
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
