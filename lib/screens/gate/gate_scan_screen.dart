import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final int gateId;
  final String gateName;
  const GateScanScreen({
    super.key, 
    required this.type,
    required this.gateId,
    required this.gateName,
  });

  @override
  State<GateScanScreen> createState() => _GateScanScreenState();
}

class _GateScanScreenState extends State<GateScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode();
  bool _isProcessing = false;
  bool _useCamera = false;
  late String _scanType;
  final List<_ScanHistoryItem> _scanHistory = [];

  @override
  void initState() {
    super.initState();
    _scanType = widget.type;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_useCamera) {
        _manualFocusNode.requestFocus();
      }
    });
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

    // Wait a bit to show result then reset
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<GateProvider>().clearStatus();
        setState(() => _isProcessing = false);
        if (!_useCamera) _manualFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gateProvider = context.watch<GateProvider>();
    final event = context.read<EventProvider>().selectedEvent;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF8FF),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(settings),
                _buildEventBar(event?.name ?? 'Gate Control'),
                Expanded(
                  child: _useCamera ? _buildCameraScanner() : _buildReadyToScan(),
                ),
                _buildHistorySection(),
              ],
            ),
          ),
          if (gateProvider.isSuccess != null)
            _buildResultOverlay(gateProvider),
        ],
      ),
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
            tooltip: _useCamera ? 'Insert kode manual' : 'Switch to camera',
            icon: _useCamera ? Icons.keyboard_alt_outlined : Icons.camera_alt_outlined,
            onTap: () {
              setState(() => _useCamera = !_useCamera);
              if (!_useCamera) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _manualFocusNode.requestFocus();
                });
              }
            },
          ),
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
          settings.isOnline ? 'ONLINE' : 'OFFLINE',
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
            'Ready to Scan',
            style: TextStyle(
              color: Color(0xFF122E4F),
              fontSize: 34,
              fontWeight: FontWeight.w900,
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

    return Positioned.fill(
      child: FadeIn(
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: bgColor.withValues(alpha: 0.9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ZoomIn(
                child: Icon(
                  success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 120,
                ),
              ),
              const SizedBox(height: 24),
              FadeInUp(
                child: Text(
                  success ? 'ACCESS GRANTED' : 'ACCESS DENIED',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 8),
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    provider.message ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
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
