import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';

import '../providers/settings_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class POSProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;
  final AudioPlayer _audioPlayer = AudioPlayer();

  POSProvider(this.settings) {
    _apiClient = ApiClient(settings.baseUrl);
  }
  
  bool _isLoading = false;
  String? _message;
  bool? _isSuccess;
  Map<String, dynamic>? _ticketInfo;

  bool get isLoading => _isLoading;
  String? get message => _message;
  bool? get isSuccess => _isSuccess;
  Map<String, dynamic>? get ticketInfo => _ticketInfo;

  Future<bool> checkTicket(String code) async {
    _isLoading = true;
    _message = null;
    _ticketInfo = null;
    notifyListeners();

    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      final response = await _apiClient.dio.get('/pos/check-ticket/$code');
      
      if (response.data['status'] == 'error' && response.data['is_redeemable'] == false) {
        _ticketInfo = response.data['details'];
        _message = response.data['message'];
        _isSuccess = false;
        await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _ticketInfo = response.data['ticket'];
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isLoading = false;
      _message = e.response?.data['message'] ?? 'Ticket not found';
      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _message = 'An error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<void> redeemTicket({
    required String ticketCode,
    String? wristbandQr,
    String? photoBase64,
  }) async {
    _isLoading = true;
    _message = null;
    _isSuccess = null;
    notifyListeners();

    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      final response = await _apiClient.dio.post('/pos/redeem', data: {
        'ticket_code': ticketCode,
        'photo': photoBase64,
      });

      if (response.data['status'] == 'error') {
        _isSuccess = false;
        _message = response.data['message'];
        _ticketInfo = response.data['details'];
        await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      } else {
        _isSuccess = true;
        _message = response.data['message'] ?? 'Redemption Successful';
        await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      }
    } on DioException catch (e) {
      _isSuccess = false;
      _message = e.response?.data['message'] ?? 'Redemption Failed';
      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sellTicket({
    required int eventId,
    required int categoryId,
    required String name,
    required String email,
    required String phone,
    required String nik,
  }) async {
    _isLoading = true;
    _message = null;
    _isSuccess = null;
    notifyListeners();

    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      final response = await _apiClient.dio.post('/pos/events/$eventId/sell', data: {
        'ticket_category_id': categoryId,
        'customer_name': name,
        'customer_email': email,
        'customer_phone': phone,
        'customer_nik': nik,
      });

      _isSuccess = true;
      _message = 'Ticket Sold Successfully';
    } on DioException catch (e) {
      _isSuccess = false;
      _message = e.response?.data['message'] ?? 'Sale Failed';
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
