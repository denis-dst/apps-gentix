import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../providers/gate_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants.dart';

class GateScanScreen extends StatefulWidget {
  final String type; // IN or OUT
  final int? gateId;
  final String gateName;
  final int eventId;
  final int tenantId;
  final List<int> allowedCategoryIds;
  const GateScanScreen({
    super.key, 
    required this.type,
    required this.gateId,
    required this.gateName,
    required this.eventId,
    required this.tenantId,
    required this.allowedCategoryIds,
  });

  @override
  State<GateScanScreen> createState() => _GateScanScreenState();
}

class _GateScanScreenState extends State<GateScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode();
  bool _isProcessing = false;
  bool _useCamera = true;
  late String _scanType;
  final List<_ScanHistoryItem> _scanHistory = [];
  // Bertambah setiap ada hasil scan baru; dipakai agar timer auto-reset dari
  // scan lama tidak mereset hasil scan yang lebih baru.
  int _resultToken = 0;
  final Set<int> _selectedTicketIds = {};

  @override
  void initState() {
    super.initState();
    _scanType = widget.type;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  void _handleCodeDetected(String code) async {
    if (_isProcessing || code.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    await context.read<GateProvider>().scanWristband(
      qrCode: code,
      type: _scanType,
      gateId: widget.gateId,
      gateName: widget.gateName,
      deviceId: 'Android-Dev-01',
      eventId: widget.eventId,
      tenantId: widget.tenantId,
      allowedCategoryIds: widget.allowedCategoryIds,
    );

    if (!mounted) return;

    final provider = context.read<GateProvider>();
    _addHistoryItem(
      code: code.trim(),
      type: _scanType,
      isSuccess: provider.isSuccess ?? false,
      message: provider.message ?? '',
    );
    _manualController.clear();

    final isGroup = provider.isSuccess == true && provider.scanResult?['is_group'] == true;

    if (isGroup) {
      final attendeesList = provider.scanResult?['attendees'] as List? ?? [];
      final scannedTicketId = provider.scanResult?['scanned_ticket_id'];

      _selectedTicketIds.clear();
      for (final a in attendeesList) {
        if (a is Map) {
          final ticketId = a['ticket_id'] as int?;
          final isCheckedIn = a['is_checked_in'] as bool? ?? false;
          if (ticketId != null) {
            if (_scanType == 'IN') {
              if (!isCheckedIn || ticketId == scannedTicketId) {
                _selectedTicketIds.add(ticketId);
              }
            } else {
              if (isCheckedIn || ticketId == scannedTicketId) {
                _selectedTicketIds.add(ticketId);
              }
            }
          }
        }
      }
      setState(() {});
      // Do not trigger auto timer reset for group checklist screen
    } else {
      final token = ++_resultToken;
      final autoTimer = context.read<SettingsProvider>().gateAutoTimer;
      final bool failed = provider.isSuccess != true;

      if (failed) {
        // Mode gagal: tampilkan selama 5 detik agar operator bisa membaca alasan ditolak
        Future.delayed(const Duration(seconds: 5), () => _resetScan(token));
      } else if (autoTimer) {
        // Mode sukses + timer otomatis: kembali ke ready-to-scan setelah 3 detik.
        Future.delayed(const Duration(seconds: 3), () => _resetScan(token));
      }
    }
  }

  void _resetScan(int token) {
    // Abaikan bila sudah ada hasil scan yang lebih baru atau sudah di-reset manual.
    if (!mounted || token != _resultToken) return;
    context.read<GateProvider>().clearStatus();
    setState(() => _isProcessing = false);
    if (!_useCamera) _manualFocusNode.requestFocus();
  }

  void _setScanInputMode(bool useCamera) {
    setState(() => _useCamera = useCamera);
    if (!useCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _manualFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateProvider = context.watch<GateProvider>();
    final event = context.read<EventProvider>().selectedEvent;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF8FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(settings),
            _buildEventBar(event?.name ?? 'Gate Control'),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _useCamera ? _buildCameraScanner() : _buildReadyToScan(),
                  ),
                  if (gateProvider.isSuccess != null)
                    Positioned.fill(
                      child: gateProvider.isSuccess == true && gateProvider.scanResult?['is_group'] == true
                          ? _buildGroupChecklistOverlay(gateProvider)
                          : _buildResultOverlay(gateProvider),
                    ),
                ],
              ),
            ),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  void _submitGroupCheck(GateProvider provider) async {
    if (_selectedTicketIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih minimal 1 peserta.'),
          backgroundColor: Color(0xFFD95164),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    await provider.bulkCheckin(
      ticketIds: _selectedTicketIds.toList(),
      type: _scanType,
      gateId: widget.gateId,
      gateName: widget.gateName,
      deviceId: 'Android-Dev-01',
    );

    if (!mounted) return;

    _selectedTicketIds.clear();
    setState(() {
      _isProcessing = false;
    });
  }

  Widget _buildGroupChecklistOverlay(GateProvider provider) {
    final result = provider.scanResult ?? const <String, dynamic>{};
    final String customerName = result['visitor']?.toString() ?? '-';
    final String refNo = result['reference_no']?.toString() ?? '-';
    final String category = result['category']?.toString() ?? '-';
    final List attendees = result['attendees'] as List? ?? [];
    final bool isOut = _scanType == 'OUT';
    
    final Color themeColor = isOut ? const Color(0xFFD95164) : const Color(0xFF16A085);
    final String actionText = isOut ? 'Check-out' : 'Check-in';

    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xFF070B19).withValues(alpha: 0.8),
            ),
          ),
        ),
        
        // Centered Card
        Center(
          child: FadeInDown(
            duration: const Duration(milliseconds: 250),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Slate-900
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B), // Slate-800
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.people_alt_rounded, color: themeColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DETAIL GRUP - $actionText',
                                    style: TextStyle(
                                      color: themeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    customerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ref: $refNo',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Kategori: $category',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Selection Controller Bar (Select All / Unselect All)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PILIH PESERTA (${_selectedTicketIds.length}/${attendees.length})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_selectedTicketIds.length == attendees.length) {
                                _selectedTicketIds.clear();
                              } else {
                                for (final a in attendees) {
                                  if (a is Map && a['ticket_id'] != null) {
                                    _selectedTicketIds.add(a['ticket_id'] as int);
                                  }
                                }
                              }
                            });
                          },
                          icon: Icon(
                            _selectedTicketIds.length == attendees.length
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 16,
                            color: themeColor,
                          ),
                          label: Text(
                            _selectedTicketIds.length == attendees.length
                                ? 'Batal Semua'
                                : 'Pilih Semua',
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Attendees list
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shrinkWrap: true,
                      itemCount: attendees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final a = attendees[index] as Map<String, dynamic>;
                        final int ticketId = a['ticket_id'] as int;
                        final String name = a['name']?.toString() ?? '-';
                        final String cat = a['category']?.toString() ?? '-';
                        final bool isCheckedIn = a['is_checked_in'] as bool? ?? false;
                        final String? checkedInAt = a['checked_in_at']?.toString();
                        final String? checkedInBy = a['checked_in_by']?.toString();
                        final String? customLabel = a['custom_question_label']?.toString();
                        final String? customAnswer = a['custom_question_answer']?.toString();
                        final bool hasCustom = customLabel != null && 
                            customLabel != '-' && 
                            customAnswer != null && 
                            customAnswer != '-';

                        final bool isSelected = _selectedTicketIds.contains(ticketId);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedTicketIds.remove(ticketId);
                              } else {
                                _selectedTicketIds.add(ticketId);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? themeColor.withValues(alpha: 0.08)
                                  : const Color(0xFF1E293B).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? themeColor.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.04),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Custom Checkbox icon
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected ? themeColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected ? themeColor : Colors.white38,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cat,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (hasCustom) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '$customLabel: $customAnswer',
                                          style: const TextStyle(
                                            color: Color(0xFFF39C12),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      if (isCheckedIn) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Masuk pada: ${checkedInAt ?? "-"} (${checkedInBy ?? "-"})',
                                          style: const TextStyle(
                                            color: Color(0xFF4D9D96),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCheckedIn
                                        ? const Color(0xFF16A085).withValues(alpha: 0.15)
                                        : const Color(0xFF64748B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isCheckedIn ? 'DI DALAM' : 'DI LUAR',
                                    style: TextStyle(
                                      color: isCheckedIn ? const Color(0xFF16C7B7) : const Color(0xFF94A3B8),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer actions
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              _selectedTicketIds.clear();
                              provider.clearStatus();
                              setState(() => _isProcessing = false);
                              if (!_useCamera) _manualFocusNode.requestFocus();
                            },
                            child: const Text(
                              'Batal',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: provider.isLoading ? null : () => _submitGroupCheck(provider),
                            child: provider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Proses $actionText (${_selectedTicketIds.length})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addHistoryItem({
    required String code,
    required String type,
    required bool isSuccess,
    required String message,
  }) {
    setState(() {
      _scanHistory.insert(
        0,
        _ScanHistoryItem(
          code: code,
          type: type,
          isSuccess: isSuccess,
          message: message.isEmpty ? (isSuccess ? 'Success' : 'Failed') : message,
          scannedAt: DateTime.now(),
        ),
      );
      if (_scanHistory.length > 50) {
        _scanHistory.removeRange(50, _scanHistory.length);
      }
    });
  }

  Widget _buildTopBar(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 12),
      color: const Color(0xFF0D2444),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gate Scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.gateName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBFD5EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildModeChip(settings),
          const SizedBox(width: 6),
          _buildIconAction(
            tooltip: _scanType == 'IN' ? 'Switch checkout' : 'Switch checkin',
            icon: _scanType == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
            onTap: () => setState(() => _scanType = _scanType == 'IN' ? 'OUT' : 'IN'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(SettingsProvider settings) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await settings.setMode(!settings.isOnline);
        await settings.saveSettings();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: settings.isOnline ? const Color(0xFF16C7B7) : const Color(0xFF64748B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          settings.isOnline ? 'ONLINE' : 'LOCAL',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }

  Widget _buildIconAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          width: 36,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildEventBar(String eventName) {
    final bool isOut = _scanType == 'OUT';

    return Container(
      width: double.infinity,
      color: const Color(0xFF12345D),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.gateName} - $eventName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBFD5EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                _buildInputModeButton(
                  label: 'CAM',
                  icon: Icons.camera_alt_outlined,
                  isActive: _useCamera,
                  onTap: () => _setScanInputMode(true),
                ),
                const SizedBox(width: 4),
                _buildInputModeButton(
                  label: 'IR/MANUAL',
                  icon: Icons.keyboard_command_key_rounded,
                  isActive: !_useCamera,
                  onTap: () => _setScanInputMode(false),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isOut ? const Color(0xFFD95164) : const Color(0xFF16A085),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOut ? 'OUT' : 'IN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? const Color(0xFF12345D) : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF12345D) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyToScan() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEAF8FF),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF49769B), size: 74),
          const SizedBox(height: 26),
          const Text(
            'Infrared / Manual Ready',
            style: TextStyle(
              color: Color(0xFF122E4F),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Mode ini untuk scanner infrared atau input manual.\nScan atau ketik kode lalu tekan enter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF49769B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: _manualController,
              focusNode: _manualFocusNode,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(border: InputBorder.none),
              onSubmitted: _handleCodeDetected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null) _handleCodeDetected(code);
            }
          },
        ),
        Center(
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Container(
                width: 180,
                height: 2,
                color: const Color(0xFF16C7B7),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Text(
            _isProcessing ? 'Processing...' : 'Align QR Code within the frame',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Container(
      height: 238,
      color: const Color(0xFFDFF4FF),
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(
              color: Color(0xFFE9FAFF),
              border: Border(bottom: BorderSide(color: Color(0xFF94C9D7))),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'RECENT SCANS',
                    style: TextStyle(
                      color: Color(0xFF24435E),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: .4,
                    ),
                  ),
                ),
                Text(
                  'Last 50',
                  style: TextStyle(
                    color: Color(0xFF526A7E),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _scanHistory.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada scan',
                      style: TextStyle(
                        color: Color(0xFF6B8498),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _scanHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFC7E7F2)),
                    itemBuilder: (context, index) => _buildHistoryRow(_scanHistory[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(_ScanHistoryItem item) {
    final Color statusColor = item.isSuccess ? const Color(0xFF16A085) : AppConstants.errorColor;
    final String date = DateFormat('dd MMM').format(item.scannedAt);
    final String time = '${DateFormat('HH:mm:ss').format(item.scannedAt)} WIB';

    return Container(
      color: const Color(0xFFEAF8FF),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF173552),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.isSuccess ? 'Success' : item.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.isSuccess ? const Color(0xFF4D9D96) : AppConstants.errorColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              item.type == 'OUT' ? 'CHECK OUT' : 'CHECK IN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF5C748A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF5C748A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(GateProvider provider) {
    final bool success = provider.isSuccess ?? false;
    final Color bgColor = success ? AppConstants.successColor : AppConstants.errorColor;
    final bool autoTimer = context.watch<SettingsProvider>().gateAutoTimer;
    final result = provider.scanResult ?? const <String, dynamic>{};
    final customQuestionLabel = result['custom_question_label']?.toString() ?? '-';
    final customQuestionAnswer = result['custom_question_answer']?.toString() ?? '-';
    final hasCustomQuestion = customQuestionLabel.trim().isNotEmpty &&
        customQuestionLabel != '-' &&
        customQuestionAnswer.trim().isNotEmpty &&
        customQuestionAnswer != '-';

    return FadeIn(
      duration: const Duration(milliseconds: 200),
      child: Container(
        color: bgColor.withValues(alpha: 0.92),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Skala mengikuti ukuran layar agar area hijau/putih tidak melebar
              // di layar besar dan tidak meluber (menutup tombol OK) di layar kecil.
              final bool compact = constraints.maxHeight < 560;
              final double iconSize = compact ? 62 : 84;
              final double cardWidth =
                  constraints.maxWidth - 40 > 380 ? 380 : constraints.maxWidth - 40;

              return Column(
                children: [
                  // Konten hasil scan — scrollable agar tidak pernah menutupi tombol OK.
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: compact ? 12 : 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 100),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ZoomIn(
                              child: Icon(
                                success
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.error_outline_rounded,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 18),
                            FadeInUp(
                              child: Text(
                                success ? 'ACCESS GRANTED' : 'ACCESS DENIED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FadeInUp(
                              delay: const Duration(milliseconds: 100),
                              child: Column(
                                children: [
                                  Text(
                                    provider.message ?? '',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                  SizedBox(height: compact ? 12 : 18),
                                  Container(
                                    width: cardWidth,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildOverlayInfoRow('Kode Tiket',
                                            result['ticket_code']?.toString() ?? '-'),
                                        _buildOverlayInfoRow(
                                            'Nama Customer',
                                            result['visitor']?.toString() ??
                                                result['customer_name']?.toString() ??
                                                '-'),
                                        if (hasCustomQuestion)
                                          _buildOverlayInfoRow(
                                              customQuestionLabel, customQuestionAnswer),
                                        _buildOverlayInfoRow('Kategori',
                                            result['category']?.toString() ?? '-'),
                                        _buildOverlayInfoRow(
                                            'Email', result['email']?.toString() ?? '-'),
                                        _buildOverlayInfoRow('No. Transaksi',
                                            result['reference_no']?.toString() ?? '-'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tombol OK selalu menempel di bawah overlay, tidak pernah tertutup.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: bgColor,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.25),
                        ),
                        onPressed: () {
                          // Batalkan timer auto-reset yang tertunda lalu reset segera.
                          _resultToken++;
                          context.read<GateProvider>().clearStatus();
                          setState(() => _isProcessing = false);
                          if (!_useCamera) _manualFocusNode.requestFocus();
                        },
                        child: Text(
                          autoTimer ? 'OK (otomatis 3 detik)' : 'OK',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHistoryItem {
  final String code;
  final String type;
  final bool isSuccess;
  final String message;
  final DateTime scannedAt;

  const _ScanHistoryItem({
    required this.code,
    required this.type,
    required this.isSuccess,
    required this.message,
    required this.scannedAt,
  });
}
