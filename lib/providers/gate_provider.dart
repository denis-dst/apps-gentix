import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/local_gate_data_service.dart';

import '../providers/settings_provider.dart';

import '../models/gate_model.dart';

class GateProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final LocalGateDataService _localGateDataService = LocalGateDataService();

  GateProvider(this.settings) {
    _apiClient = ApiClient(settings.baseUrl);
  }

  bool _isLoading = false;
  String? _message;
  bool? _isSuccess;
  Map<String, dynamic>? _scanResult;
  List<GateModel> _gates = [];
  int _totalScans = 0;
  int _totalValidScans = 0;
  int _totalInvalidScans = 0;
  String? _syncMessage;

  bool get isLoading => _isLoading;
  String? get message => _message;
  bool? get isSuccess => _isSuccess;
  Map<String, dynamic>? get scanResult => _scanResult;
  List<GateModel> get gates => _gates;
  int get totalScans => _totalScans;
  int get totalValidScans => _totalValidScans;
  int get totalInvalidScans => _totalInvalidScans;
  String? get syncMessage => _syncMessage;

  Future<void> fetchGates(int eventId) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      final response = await _apiClient.dio.get('/gate/list', queryParameters: {'event_id': eventId});
      final List data = response.data['data'] ?? [];
      _gates = data.map((json) => GateModel.fromJson(json)).toList();
    } on DioException catch (e) {
      _message = e.response?.data['message'] ?? 'Failed to load gates';
      _gates = [];
    } catch (e) {
      _message = 'Failed to parse gate data: $e';
      _gates = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> scanWristband({
    required String qrCode,
    required String type, // IN or OUT
    required int? gateId,
    required String gateName,
    required String deviceId,
    required int eventId,
    required int tenantId,
    required List<int> allowedCategoryIds,
  }) async {
    _isLoading = true;
    _message = null;
    _isSuccess = null;
    notifyListeners();

    try {
      final scannedCode = qrCode.trim();
      final Map<String, dynamic> result = settings.isOnline
          ? await _scanOnline(
              scannedCode: scannedCode,
              type: type,
              gateId: gateId,
              gateName: gateName,
              deviceId: deviceId,
            )
          : await _scanLocal(
              scannedCode: scannedCode,
              type: type,
              gateId: gateId,
              gateName: gateName,
              deviceId: deviceId,
              eventId: eventId,
              tenantId: tenantId,
              allowedCategoryIds: allowedCategoryIds,
            );

      _isSuccess = true;
      _message = result['message']?.toString() ?? 'Access Granted';
      _scanResult = result;
      _totalScans++;
      _totalValidScans++;

      // Sound feedback
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));

      // Haptic feedback
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 100);
      }
    } on DioException catch (e) {
      _isSuccess = false;
      _message = e.response?.data['message'] ?? 'Access Denied';
      final data = e.response?.data;
      _scanResult = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : {
              'ticket_code': qrCode.trim(),
              'category': '-',
              'email': '-',
              'reference_no': '-',
            };
      _totalScans++;
      _totalInvalidScans++;
      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 200, 100, 200]);
      }
    } catch (e) {
      _isSuccess = false;
      _message = e.toString().replaceFirst('Exception: ', '');
      _scanResult = {
        'ticket_code': qrCode.trim(),
        'category': '-',
        'email': '-',
        'reference_no': '-',
      };
      _totalScans++;
      _totalInvalidScans++;

      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      if (await Vibration.hasVibrator()) {
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
    _scanResult = null;
    notifyListeners();
  }

  Future<int> downloadGateData({required int eventId}) async {
    _apiClient.updateBaseUrl(settings.baseUrl);
    final response = await _apiClient.dio.get('/gate/download-data', queryParameters: {
      'event_id': eventId,
    });

    final List tickets = response.data['tickets'] ?? [];
    final List gates = response.data['gates'] ?? [];

    await _localGateDataService.replaceEventData(
      eventId: eventId,
      tickets: tickets.map((ticket) {
        final map = Map<String, dynamic>.from(ticket as Map);
        return {
          'ticket_id': map['ticket_id'],
          'event_id': map['event_id'],
          'tenant_id': map['tenant_id'],
          'ticket_category_id': map['ticket_category_id'],
          'ticket_code': map['ticket_code'],
          'wristband_qr': map['wristband_qr'],
          'category_name': map['category_name'],
          'customer_email': map['customer_email'],
          'reference_no': map['reference_no'],
        };
      }).toList(),
      gates: gates.map((gate) {
        final map = Map<String, dynamic>.from(gate as Map);
        final List allowedIds = map['allowed_category_ids'] ?? const [];
        return {
          'gate_id': map['gate_id'],
          'event_id': map['event_id'],
          'gate_name': map['gate_name'],
          'allowed_category_ids': allowedIds.join(','),
        };
      }).toList(),
    );

    return _localGateDataService.getLocalTicketCount(eventId);
  }

  Future<int> uploadPendingGateLogs() async {
    _apiClient.updateBaseUrl(settings.baseUrl);
    final pendingLogs = await _localGateDataService.getPendingScanLogs();
    if (pendingLogs.isEmpty) {
      _syncMessage = 'Tidak ada data scan yang perlu di-upload.';
      notifyListeners();
      return 0;
    }

    final payload = pendingLogs.map((log) {
      return {
        'offline_id': log['offline_id'],
        'ticket_id': log['ticket_id'],
        'event_id': log['event_id'],
        'tenant_id': log['tenant_id'],
        'gate_name': log['gate_name'],
        'type': log['type'],
        'scanned_at': log['scanned_at'],
        'device_id': log['device_id'],
      };
    }).toList();

    await _apiClient.dio.post('/gate/sync', data: {'logs': payload});
    await _localGateDataService.markLogsSynced(
      pendingLogs.map((log) => log['offline_id'].toString()).toList(),
    );

    _syncMessage = '${payload.length} data scan berhasil di-upload.';
    notifyListeners();
    return payload.length;
  }

  Future<Map<String, dynamic>> _scanOnline({
    required String scannedCode,
    required String type,
    required int? gateId,
    required String gateName,
    required String deviceId,
  }) async {
    _apiClient.updateBaseUrl(settings.baseUrl);
    final response = await _apiClient.dio.post('/gate/scan', data: {
      'wristband_qr': scannedCode,
      'ticket_code': scannedCode,
      'type': type,
      'gate_id': gateId,
      'gate_name': gateName,
      'device_id': deviceId,
    });

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> _scanLocal({
    required String scannedCode,
    required String type,
    required int? gateId,
    required String gateName,
    required String deviceId,
    required int eventId,
    required int tenantId,
    required List<int> allowedCategoryIds,
  }) async {
    final ticket = await _localGateDataService.findTicket(scannedCode, eventId);
    if (ticket == null) {
      throw Exception('Invalid Wristband / Ticket Code');
    }

    if (gateId != null && allowedCategoryIds.isNotEmpty) {
      final categoryId = ticket['ticket_category_id'] as int;
      if (!allowedCategoryIds.contains(categoryId)) {
        throw Exception('Wrong Gate! Access Denied for ${ticket['category_name']}');
      }
    }

    final lastLog = await _localGateDataService.getLastScanLog(ticket['ticket_id'] as int);
    final lastType = lastLog?['type']?.toString();

    if (type == 'IN' && lastType == 'IN') {
      throw Exception('Tiket sudah berada di dalam area!');
    }

    if (type == 'OUT' && lastType != 'IN') {
      throw Exception(lastType == 'OUT'
          ? 'Tiket sudah berada di luar area!'
          : 'Tiket belum pernah Check-in!');
    }

    final offlineId = '${ticket['ticket_id']}_${DateTime.now().millisecondsSinceEpoch}';
    final scannedAt = DateTime.now().toIso8601String();

    await _localGateDataService.addScanLog({
      'offline_id': offlineId,
      'ticket_id': ticket['ticket_id'],
      'event_id': eventId,
      'tenant_id': tenantId,
      'gate_name': gateName,
      'type': type,
      'scanned_at': scannedAt,
      'device_id': deviceId,
      'synced': 0,
    });

    return {
      'message': 'Access Granted: $type',
      'ticket_code': ticket['ticket_code'] ?? scannedCode,
      'category': ticket['category_name'] ?? '-',
      'email': ticket['customer_email'] ?? '-',
      'reference_no': ticket['reference_no'] ?? '-',
    };
  }
}
