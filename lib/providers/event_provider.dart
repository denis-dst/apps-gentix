import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/event_model.dart';
import 'package:dio/dio.dart';

import '../providers/settings_provider.dart';

class EventProvider extends ChangeNotifier {
  final SettingsProvider settings;
  late ApiClient _apiClient;

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
      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _isLoading = false;
      _error = e.response?.data['message'] ?? 'Failed to load events';
      notifyListeners();
    }
  }

  void selectEvent(EventModel event) {
    _selectedEvent = event;
    notifyListeners();
  }
}
