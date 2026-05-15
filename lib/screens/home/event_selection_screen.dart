import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/event_model.dart';
import '../../models/gate_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/gate_provider.dart';
import '../gate/gate_scan_screen.dart';
import '../settings/settings_screen.dart';

class EventSelectionScreen extends StatefulWidget {
  const EventSelectionScreen({super.key});

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  final TextEditingController _codeController = TextEditingController();
  GateModel? _selectedGate;
  bool _isGateLoading = false;
  bool _isCodeVerified = false;
  String? _codeError;

  GateModel get _allGateOption => GateModel(
        id: 0,
        name: 'All Gate',
        allowedCategories: const [],
        allowedCategoryIds: const [],
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.fetchEvents();
    if (!mounted || eventProvider.events.isEmpty) return;

    final initialEvent = eventProvider.selectedEvent ?? eventProvider.events.first;
    await _selectEvent(initialEvent);
  }

  Future<void> _selectEvent(EventModel event) async {
    final eventProvider = context.read<EventProvider>();
    final gateProvider = context.read<GateProvider>();

    eventProvider.selectEvent(event);
    _codeController.clear();
    _codeError = null;
    _isCodeVerified = !event.requiresSecurityCode;

    setState(() {
      _isGateLoading = true;
      _selectedGate = null;
    });

    await gateProvider.fetchGates(event.id);
    if (!mounted) return;

    setState(() {
      _selectedGate = _allGateOption;
      _isGateLoading = false;
    });
  }

  void _verifyEventCode() {
    final event = context.read<EventProvider>().selectedEvent;
    if (event == null) {
      _showSnackBar('Pilih event terlebih dahulu.');
      return;
    }

    if (!event.requiresSecurityCode) {
      setState(() {
        _isCodeVerified = true;
        _codeError = null;
      });
      return;
    }

    if (_codeController.text.trim() == event.securityCode) {
      setState(() {
        _isCodeVerified = true;
        _codeError = null;
      });
      return;
    }

    setState(() {
      _isCodeVerified = false;
      _codeError = 'Kode event tidak sesuai.';
    });
  }

  Future<void> _openScanner() async {
    final event = context.read<EventProvider>().selectedEvent;
    final gateProvider = context.read<GateProvider>();

    if (event == null) {
      _showSnackBar('Pilih event terlebih dahulu.');
      return;
    }

    if (!_isCodeVerified) {
      _showSnackBar('Masukkan dan verifikasi kode event terlebih dahulu.');
      return;
    }

    if (_selectedGate == null) {
      _showSnackBar('Pilih gate terlebih dahulu.');
      return;
    }

    if (gateProvider.gates.isEmpty && _selectedGate?.id != 0) {
      _showSnackBar('Gate belum tersedia untuk event ini.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GateScanScreen(
          type: 'IN',
          gateId: _selectedGate!.id == 0 ? null : _selectedGate!.id,
          gateName: _selectedGate!.name,
          eventId: event.id,
          tenantId: event.tenantId,
          allowedCategoryIds: _selectedGate!.allowedCategoryIds,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final eventProvider = context.watch<EventProvider>();
    final gateProvider = context.watch<GateProvider>();
    final selectedEvent = eventProvider.selectedEvent;
    final gates = [_allGateOption, ...gateProvider.gates];

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFF),
      appBar: AppBar(
        title: const Text(
          'Pilih Event',
          style: TextStyle(color: Color(0xFF172033), fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF3FAFF),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF172033)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF172033)),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: eventProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : eventProvider.events.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                    children: [
                      _buildHeaderCard(selectedEvent),
                      const SizedBox(height: 24),
                      _buildSectionTitle('1. Pilih Event'),
                      const SizedBox(height: 12),
                      ...eventProvider.events.map(_buildEventTile),
                      const SizedBox(height: 24),
                      _buildSectionTitle('2. Masukkan Kode Event'),
                      const SizedBox(height: 12),
                      _buildCodeSection(selectedEvent),
                      const SizedBox(height: 24),
                      _buildSectionTitle('3. Pilih Gate'),
                      const SizedBox(height: 12),
                      _buildGateSection(gates),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: _canStandby(selectedEvent) ? _openScanner : null,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text(
                            'Standby Ready to Scan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F8E7C),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFB7C7D5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  bool _canStandby(EventModel? selectedEvent) {
    return selectedEvent != null && _selectedGate != null && _isCodeVerified && !_isGateLoading;
  }

  Widget _buildHeaderCard(EventModel? event) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12345D), Color(0xFF1F5D91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF12345D).withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational Setup',
            style: TextStyle(
              color: Color(0xFFD9E8F6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            event?.name ?? 'Pilih event untuk mulai',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _buildHeaderMeta(
            Icons.location_on_outlined,
            event?.venue ?? 'Belum ada event terpilih',
          ),
          const SizedBox(height: 8),
          _buildHeaderMeta(
            Icons.calendar_today_outlined,
            event == null
                ? '-'
                : DateFormat('dd MMM yyyy, HH:mm').format(event.eventStartDate),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMeta(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD9E8F6), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF2F8FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF24435E),
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildEventTile(EventModel event) {
    final selectedEvent = context.watch<EventProvider>().selectedEvent;
    final isSelected = selectedEvent?.id == event.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppConstants.primaryColor : const Color(0xFFD8E6F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _selectEvent(event),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isSelected ? AppConstants.primaryColor : const Color(0xFF7BA7C7)).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isSelected ? Icons.check_circle_rounded : Icons.event_note_rounded,
            color: isSelected ? AppConstants.primaryColor : const Color(0xFF54728D),
          ),
        ),
        title: Text(
          event.name,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            event.venue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7788),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: Text(
          DateFormat('dd MMM').format(event.eventStartDate),
          style: const TextStyle(
            color: Color(0xFF4C6A84),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeSection(EventModel? selectedEvent) {
    final requiresCode = selectedEvent?.requiresSecurityCode ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiresCode
                ? 'Event ini membutuhkan kode akses sebelum scan dimulai.'
                : 'Event ini tidak memiliki kode akses. Lanjut pilih gate.',
            style: const TextStyle(
              color: Color(0xFF60758A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeController,
            enabled: selectedEvent != null && requiresCode,
            obscureText: requiresCode,
            decoration: InputDecoration(
              hintText: requiresCode ? 'Masukkan kode event' : 'Kode event tidak diperlukan',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: _codeError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (_) {
              if (_codeError != null || _isCodeVerified) {
                setState(() {
                  _codeError = null;
                  _isCodeVerified = false;
                });
              }
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: selectedEvent == null ? null : _verifyEventCode,
              icon: Icon(_isCodeVerified ? Icons.verified_rounded : Icons.key_rounded),
              label: Text(_isCodeVerified ? 'Kode Event Terverifikasi' : 'Verifikasi Kode Event'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _isCodeVerified ? const Color(0xFF0F8E7C) : AppConstants.primaryColor,
                side: BorderSide(
                  color: _isCodeVerified ? const Color(0xFF0F8E7C) : AppConstants.primaryColor,
                ),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGateSection(List<GateModel> gates) {
    final gateProvider = context.watch<GateProvider>();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7AB8D4).withValues(alpha: .10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _isGateLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih gate aktif untuk mode standby scan.',
                  style: TextStyle(
                    color: Color(0xFF60758A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9ED8E8), width: 1.4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<GateModel>(
                      isExpanded: true,
                      value: _selectedGate,
                      hint: const Text('Pilih gate'),
                      items: gates.map((gate) {
                        return DropdownMenuItem<GateModel>(
                          value: gate,
                          child: Text(
                            gate.name,
                            style: TextStyle(
                              color: gate.id == 0 ? const Color(0xFF0D5C63) : const Color(0xFF172033),
                              fontWeight: gate.id == 0 ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: gates.isEmpty
                          ? null
                          : (gate) {
                              setState(() => _selectedGate = gate);
                            },
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppConstants.primaryColor),
                    ),
                  ),
                ),
                if (gateProvider.message != null && gateProvider.gates.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    gateProvider.message!,
                    style: const TextStyle(
                      color: AppConstants.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Belum ada event aktif',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tarik ke bawah untuk memuat ulang daftar event.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7788),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _loadInitialData,
              child: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}
