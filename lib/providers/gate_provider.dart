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
  GateModel? _selectedGate;
  int _totalScans = 0;
  int _totalValidScans = 0;
  int _totalInvalidScans = 0;
  String? _syncMessage;

  bool get isLoading => _isLoading;
  String? get message => _message;
  bool? get isSuccess => _isSuccess;
  Map<String, dynamic>? get scanResult => _scanResult;
  List<GateModel> get gates => _gates;
  GateModel? get selectedGate => _selectedGate;
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

      if (_selectedGate == null) {
        _selectedGate = _gates.isNotEmpty ? _gates.first : null;
      } else if (_selectedGate!.id != 0) {
        final selectedGateId = _selectedGate!.id;
        final matchingGates = _gates.where((gate) => gate.id == selectedGateId).toList();
        _selectedGate = matchingGates.isNotEmpty
            ? matchingGates.first
            : (_gates.isNotEmpty ? _gates.first : null);
      }
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

  void selectGate(GateModel? gate) {
    _selectedGate = gate;
    notifyListeners();
  }

  void clearGateSelection() {
    _selectedGate = null;
    notifyListeners();
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

  Future<bool> bulkCheckin({
    required List<int> ticketIds,
    required String type,
    required int? gateId,
    required String gateName,
    required String deviceId,
  }) async {
    _isLoading = true;
    _message = null;
    _isSuccess = null;
    notifyListeners();

    try {
      if (settings.isOnline) {
        _apiClient.updateBaseUrl(settings.baseUrl);
        final response = await _apiClient.dio.post('/gate/bulk-checkin', data: {
          'ticket_ids': ticketIds,
          'type': type,
          'gate_id': gateId,
          'gate_name': gateName,
          'device_id': deviceId,
        });

        _isSuccess = true;
        _message = response.data['message']?.toString() ?? 'Berhasil memproses check-in masal';
        _scanResult = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : null;
      } else {
        final List<String> visitorNames = [];
        final List<String> ticketCodes = [];
        final List<String> customQuestions = [];
        String firstCategory = '-';
        String referenceNo = '-';
        String customerEmail = '-';

        for (final ticketId in ticketIds) {
          final t = await _localGateDataService.findTicketById(ticketId);
          if (t != null) {
            visitorNames.add(t['customer_name'] ?? '-');
            ticketCodes.add(t['ticket_code'] ?? '-');
            if (firstCategory == '-') {
              firstCategory = t['category_name'] ?? '-';
              referenceNo = t['reference_no'] ?? '-';
              customerEmail = t['customer_email'] ?? '-';
            }

            final qLabel = t['custom_question_label']?.toString();
            final qAnswer = t['custom_question_answer']?.toString();
            if (qLabel != null && qLabel != '-' && qAnswer != null && qAnswer != '-') {
              customQuestions.add('$qLabel: $qAnswer');
            }

            // Save log locally
            final offlineId = '${ticketId}_${DateTime.now().millisecondsSinceEpoch}';
            final scannedAt = DateTime.now().toIso8601String();
            await _localGateDataService.addScanLog({
              'offline_id': offlineId,
              'ticket_id': ticketId,
              'event_id': t['event_id'],
              'tenant_id': t['tenant_id'],
              'gate_name': gateName,
              'type': type,
              'scanned_at': scannedAt,
              'device_id': deviceId,
              'synced': 0,
            });
          }
        }

        _isSuccess = true;
        _message = 'Berhasil memproses check-in masal (Offline)';
        _scanResult = {
          'status': 'SUCCESS',
          'message': 'Berhasil memproses check-in masal (Offline)',
          'visitor': visitorNames.join(', '),
          'category': firstCategory,
          'ticket_code': ticketCodes.join(', '),
          'email': customerEmail,
          'reference_no': referenceNo,
          'custom_question_label': customQuestions.isNotEmpty ? 'Pertanyaan Custom' : '-',
          'custom_question_answer': customQuestions.isNotEmpty ? customQuestions.join('; ') : '-',
        };
      }
      _totalScans += ticketIds.length;
      _totalValidScans += ticketIds.length;

      // Sound feedback
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));

      // Haptic feedback
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 100);
      }
      return true;
    } on DioException catch (e) {
      _isSuccess = false;
      _message = e.response?.data['message'] ?? 'Gagal memproses check-in masal';
      _scanResult = e.response?.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(e.response?.data)
          : null;
      _totalScans += ticketIds.length;
      _totalInvalidScans += ticketIds.length;
      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 200, 100, 200]);
      }
      return false;
    } catch (e) {
      _isSuccess = false;
      _message = e.toString().replaceFirst('Exception: ', '');
      _scanResult = null;
      _totalScans += ticketIds.length;
      _totalInvalidScans += ticketIds.length;
      await _audioPlayer.play(AssetSource('sounds/invalid.mp3'));
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 200, 100, 200]);
      }
      return false;
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
    final previousConnectTimeout = _apiClient.dio.options.connectTimeout;
    final previousReceiveTimeout = _apiClient.dio.options.receiveTimeout;
    final previousSendTimeout = _apiClient.dio.options.sendTimeout;

    try {
      _apiClient.dio.options.connectTimeout = const Duration(seconds: 45);
      _apiClient.dio.options.receiveTimeout = const Duration(seconds: 90);
      _apiClient.dio.options.sendTimeout = const Duration(seconds: 45);

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
            'customer_name': map['customer_name'],
            'customer_email': map['customer_email'],
            'custom_question_label': map['custom_question_label'],
            'custom_question_answer': map['custom_question_answer'],
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
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Koneksi ke server terlalu lama. Pastikan server aktif lalu coba lagi.');
      }
      throw Exception(e.response?.data['message'] ?? 'Gagal mengunduh data gate.');
    } finally {
      _apiClient.dio.options.connectTimeout = previousConnectTimeout;
      _apiClient.dio.options.receiveTimeout = previousReceiveTimeout;
      _apiClient.dio.options.sendTimeout = previousSendTimeout;
    }
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

    // Group checking for local/offline mode
    final String? refNo = ticket['reference_no']?.toString();
    List<Map<String, dynamic>> ticketsInGroup = [];
    if (refNo != null && refNo.isNotEmpty && refNo != '-') {
      ticketsInGroup = await _localGateDataService.getTicketsByReference(refNo);
    }

    if (ticketsInGroup.length > 1) {
      final totalGroupCount = ticketsInGroup.length;
      int checkedInCount = 0;
      int checkedOutCount = 0;
      int neverCheckedInCount = 0;

      final attendees = <Map<String, dynamic>>[];

      for (final t in ticketsInGroup) {
        final tLastLog = await _localGateDataService.getLastScanLog(t['ticket_id'] as int);
        final bool isCheckedIn = tLastLog != null && tLastLog['type'] == 'IN';
        if (isCheckedIn) {
          checkedInCount++;
        } else {
          checkedOutCount++;
          if (tLastLog == null) {
            neverCheckedInCount++;
          }
        }

        attendees.add({
          'ticket_id': t['ticket_id'],
          'name': t['customer_name'] ?? '-',
          'category': t['category_name'] ?? '-',
          'is_checked_in': isCheckedIn,
          'checked_in_at': tLastLog != null ? (tLastLog['scanned_at']?.toString() ?? '-') : null,
          'checked_in_by': tLastLog != null ? (tLastLog['gate_name']?.toString() ?? '-') : null,
          'custom_question_label': t['custom_question_label'] ?? '-',
          'custom_question_answer': t['custom_question_answer'] ?? '-',
        });
      }

      if (type == 'IN') {
        if (checkedInCount == totalGroupCount) {
          throw Exception('Seluruh peserta ($totalGroupCount orang) sudah Checkin.');
        }
      } else {
        if (checkedOutCount == totalGroupCount) {
          throw Exception(neverCheckedInCount == totalGroupCount
              ? 'Seluruh peserta ($totalGroupCount orang) belum pernah Check-in!'
              : 'Seluruh peserta ($totalGroupCount orang) sudah berada di luar area!');
        }
      }

      return {
        'status': 'SUCCESS',
        'is_group': true,
        'message': 'Detail grup ditemukan',
        'customer_name': ticket['customer_name'] ?? '-',
        'category': ticket['category_name'] ?? '-',
        'scanned_ticket_id': ticket['ticket_id'],
        'attendees': attendees,
        'reference_no': refNo,
      };
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
      'visitor': ticket['customer_name'] ?? '-',
      'category': ticket['category_name'] ?? '-',
      'email': ticket['customer_email'] ?? '-',
      'custom_question_label': ticket['custom_question_label'] ?? '-',
      'custom_question_answer': ticket['custom_question_answer'] ?? '-',
      'reference_no': ticket['reference_no'] ?? '-',
    };
  }
}
