import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../providers/gate_provider.dart';
import '../../providers/event_provider.dart';
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
  bool _useCamera = true;

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
      type: widget.type,
      gateId: widget.gateId,
      gateName: widget.gateName,
      deviceId: 'Android-Dev-01',
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Gate ${widget.type}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_useCamera ? Icons.keyboard : Icons.camera_alt),
            onPressed: () => setState(() => _useCamera = !_useCamera),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_useCamera)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) _handleCodeDetected(code);
                }
              },
            )
          else
            _buildManualInput(),
          
          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                _buildHeader(event?.name ?? 'Gate Control'),
                const Spacer(),
                if (_useCamera) _buildScannerOverlay(),
                const Spacer(),
                _buildFooter(),
              ],
            ),
          ),

          // Result Feedback Overlay
          if (gateProvider.isSuccess != null)
            _buildResultOverlay(gateProvider),
        ],
      ),
    );
  }

  Widget _buildManualInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppConstants.darkBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          TextField(
            controller: _manualController,
            focusNode: _manualFocusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Scan with infrared or type code',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppConstants.cardBg,
            ),
            onSubmitted: _handleCodeDetected,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GATE ${widget.type}',
            style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Container(
          width: 200,
          height: 2,
          color: AppConstants.primaryColor,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Text(
        _useCamera ? 'Align QR Code within the frame' : 'Waiting for hardware scanner input...',
        style: const TextStyle(color: Colors.white70),
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
          color: bgColor.withOpacity(0.9),
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
