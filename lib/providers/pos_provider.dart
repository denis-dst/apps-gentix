import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';

import '../providers/settings_provider.dart';

class POSProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;

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
      final response = await _apiClient.dio.get('/pos/check-ticket/$code');
      _ticketInfo = response.data['ticket'];
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isLoading = false;
      _message = e.response?.data['message'] ?? 'Ticket not found';
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
    required String wristbandQr,
    String? photoBase64,
  }) async {
    _isLoading = true;
    _message = null;
    _isSuccess = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/pos/redeem', data: {
        'ticket_code': ticketCode,
        'wristband_qr': wristbandQr,
        'photo': photoBase64,
      });

      _isSuccess = true;
      _message = response.data['message'] ?? 'Redemption Successful';
    } on DioException catch (e) {
      _isSuccess = false;
      _message = e.response?.data['message'] ?? 'Redemption Failed';
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
