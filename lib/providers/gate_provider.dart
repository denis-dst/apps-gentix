import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

import '../providers/settings_provider.dart';

import '../models/gate_model.dart';

class GateProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;
  final AudioPlayer _audioPlayer = AudioPlayer();

  GateProvider(this.settings) {
    _apiClient = ApiClient(settings.baseUrl);
  }
  
  bool _isLoading = false;
  String? _message;
  bool? _isSuccess;
  List<GateModel> _gates = [];

  bool get isLoading => _isLoading;
  String? get message => _message;
  bool? get isSuccess => _isSuccess;
  List<GateModel> get gates => _gates;

  Future<void> fetchGates(int eventId) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/gate/list', queryParameters: {'event_id': eventId});
      final List data = response.data['data'] ?? [];
      _gates = data.map((json) => GateModel.fromJson(json)).toList();
      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _isLoading = false;
      _message = e.response?.data['message'] ?? 'Failed to load gates';
      notifyListeners();
    }
  }

  Future<void> scanWristband({
    required String qrCode,
    required String type, // IN or OUT
    required int? gateId,
    required String gateName,
    required String deviceId,
  }) async {
    _isLoading = true;
    _message = null;
    _isSuccess = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/gate/scan', data: {
        'wristband_qr': qrCode,
        'type': type,
        'gate_id': gateId,
        'gate_name': gateName,
        'device_id': deviceId,
      });

      _isSuccess = true;
      _message = response.data['message'] ?? 'Access Granted';
      
      // Sound feedback
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      
      // Haptic feedback
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }
      
    } on DioException catch (e) {
      _isSuccess = false;
      _message = e.response?.data['message'] ?? 'Access Denied';
      
      // Sound feedback
      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      
      // Stronger haptic for error
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 200, 100, 200]);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearStatus() {
    _isSuccess = null;
    _message = null;
    notifyListeners();
  }
}
