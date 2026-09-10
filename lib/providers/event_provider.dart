import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/event_model.dart';
import 'package:dio/dio.dart';

import '../providers/settings_provider.dart';

import '../services/local_gate_data_service.dart';

class EventProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;
  final LocalGateDataService _localGateDataService = LocalGateDataService();

  EventProvider(this.settings) {
    _apiClient = ApiClient(settings.baseUrl);
  }
  
  List<EventModel> _events = [];
  EventModel? _selectedEvent;
  bool _isLoading = false;
  String? _error;

  List<EventModel> get events => _events;
  EventModel? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _apiClient.updateBaseUrl(settings.baseUrl);
      final response = await _apiClient.dio.get('/events');
      final List data = response.data;
      _events = data.map((json) => EventModel.fromJson(json)).toList();
      if (_selectedEvent != null) {
        final match = _events.where((e) => e.id == _selectedEvent!.id).toList();
        if (match.isNotEmpty) {
          _selectedEvent = match.first;
        }
      }
    } on DioException catch (e) {
      // Offline fallback: load events previously saved in local SQLite
      final localEvents = await _localGateDataService.getLocalEvents();
      if (localEvents.isNotEmpty) {
        _events = localEvents.map((row) => EventModel(
          id: row['event_id'] as int,
          tenantId: row['tenant_id'] as int,
          name: row['name'] as String,
          venue: (row['venue'] as String?) ?? '-',
          eventStartDate: DateTime.tryParse(row['event_start_date']?.toString() ?? '') ?? DateTime.now(),
          securityCode: row['security_code'] as String?,
        )).toList();
        _error = null;
      } else {
        _error = e.response?.data['message'] ?? 'Gagal memuat event. Tidak ada data offline.';
        _events = [];
      }
    } catch (e) {
      final localEvents = await _localGateDataService.getLocalEvents();
      if (localEvents.isNotEmpty) {
        _events = localEvents.map((row) => EventModel(
          id: row['event_id'] as int,
          tenantId: row['tenant_id'] as int,
          name: row['name'] as String,
          venue: (row['venue'] as String?) ?? '-',
          eventStartDate: DateTime.tryParse(row['event_start_date']?.toString() ?? '') ?? DateTime.now(),
          securityCode: row['security_code'] as String?,
        )).toList();
        _error = null;
      } else {
        _error = 'Failed to parse event data: $e';
        _events = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectEvent(EventModel event) {
    _selectedEvent = event;
    notifyListeners();
  }
}
