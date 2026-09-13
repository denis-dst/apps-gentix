import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:camera/camera.dart';
import '../../providers/pos_provider.dart';
import '../../providers/event_provider.dart';
import '../../core/constants.dart';

class RedemptionScreen extends StatefulWidget {
  const RedemptionScreen({super.key});

  @override
  State<RedemptionScreen> createState() => _RedemptionScreenState();
}

class _RedemptionScreenState extends State<RedemptionScreen> {
  String? _ticketCode;
  String? _wristbandQr;
  XFile? _personPhoto;

  bool _isScanningTicket = true;
  bool _showTicketInfo = false;
  bool _isTakingPhoto = false;
  bool _showPhotoPreview = false;
  int _photoCountdown = 3;
  Timer? _photoTimer;
  bool _useCameraScanner = true;

  CameraController? _cameraController;
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initCamera() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    _cameraController?.dispose();
    _scannerController.dispose();
    _manualController.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  void _handleCodeInput(String code) async {
    if (code.trim().isEmpty) return;
    HapticFeedback.lightImpact();

    if (_isScanningTicket) {
      final success = await context.read<POSProvider>().checkTicket(code);
      final provider = context.read<POSProvider>();
      
      if (success || provider.ticketInfo != null) {
        setState(() {
          _ticketCode = code;
          _isScanningTicket = false;
          _showTicketInfo = true;
          _manualController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.message ?? 'Invalid Ticket')),
        );
      }
    }
  }

  Future<void> _startPhotoFlow() async {
    setState(() {
      _showTicketInfo = false;
      _isTakingPhoto = true;
    });
    await _initCamera();
    _startPhotoTimer();
  }

  void _startPhotoTimer() {
    setState(() => _photoCountdown = 3);
    _photoTimer?.cancel();
    _photoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_photoCountdown > 1) {
          _photoCountdown--;
        } else {
          _photoTimer?.cancel();
          _takePicture();
        }
      });
    });
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final file = await _cameraController!.takePicture();
      setState(() {
        _personPhoto = file;
        _isTakingPhoto = false;
        _showPhotoPreview = true;
      });
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<POSProvider>();

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        title: const Text('Ticket Redemption'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_isScanningTicket)
            IconButton(
              icon: Icon(_useCameraScanner ? Icons.keyboard : Icons.camera_alt),
              onPressed: () => setState(() => _useCameraScanner = !_useCameraScanner),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressStepper(),
          Expanded(
            child: Stack(
              children: [
                if (_isScanningTicket)
                  _useCameraScanner
                    ? MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final String? code = barcodes.first.rawValue;
                            if (code != null) _handleCodeInput(code);
                          }
                        },
                      )
                    : _buildManualInput()
                else if (_showTicketInfo)
                  _buildTicketInfo(posProvider.ticketInfo)
                else if (_isTakingPhoto)
                  _buildCameraPreview()
                else if (_showPhotoPreview)
                  _buildPhotoPreview(posProvider),

                if (posProvider.isLoading)
                  const Center(child: CircularProgressIndicator()),
                  
                if (posProvider.isSuccess != null)
                  _buildResultOverlay(posProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIcon(1, 'Ticket', _isScanningTicket || _showTicketInfo),
          _buildStepDivider(),
          _buildStepIcon(2, 'Photo & Redeem', _isTakingPhoto || _showPhotoPreview),
        ],
      ),
    );
  }

  Widget _buildStepIcon(int step, String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive ? AppConstants.primaryColor : Colors.white10,
          child: Text('$step', style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.white : Colors.white38)),
      ],
    );
  }

  Widget _buildStepDivider() => const Expanded(child: Divider(color: Colors.white10, indent: 8, endIndent: 8));

  Widget _buildManualInput() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: TextField(
          controller: _manualController,
          focusNode: _manualFocusNode,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter code or scan with infrared',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppConstants.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: _handleCodeInput,
        ),
      ),
    );
  }

  Widget _buildTicketInfo(Map<String, dynamic>? info) {
    if (info == null) return const Center(child: Text('No Info Available'));
    final bool isAlreadyRedeemed = info['redeemed_at'] != null;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          FadeInDown(
            child: Card(
              color: AppConstants.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    if (isAlreadyRedeemed && info['photo'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(info['photo'], height: 160, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      const Icon(Icons.confirmation_number_rounded, color: AppConstants.primaryColor, size: 48),
                      const SizedBox(height: 12),
                    ],
                    Text(info['name'] ?? 'Unknown Customer', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppConstants.primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(info['category'] ?? 'General Admission', style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const Divider(height: 28, color: Colors.white10),
                    _buildInfoRow('Email', info['email'] ?? '-'),
                    _buildInfoRow('Phone', info['phone'] ?? '-'),
                    if (isAlreadyRedeemed) ...[
                      const Divider(height: 24, color: Colors.white10),
                      const Text('ALREADY REDEEMED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 6),
                      _buildInfoRow('At', info['redeemed_at']),
                      _buildInfoRow('By', info['redeemed_by'] ?? 'System'),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isAlreadyRedeemed ? _reset : _startPhotoFlow,
            child: Text(isAlreadyRedeemed ? 'BACK TO SCAN' : 'CONTINUE TO PHOTO'),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(24),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
                child: _cameraController != null && _cameraController!.value.isInitialized
                    ? CameraPreview(_cameraController!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: FloatingActionButton.large(
                backgroundColor: Colors.white,
                onPressed: () {
                  _photoTimer?.cancel();
                  _takePicture();
                },
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 32),
              ),
            ),
          ],
        ),
        Center(
          child: Text(
            '$_photoCountdown',
            style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview(POSProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppConstants.primaryColor, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(File(_personPhoto!.path), width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _startPhotoFlow,
                  child: const Text('FOTO ULANG'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _processRedemption,
                  child: const Text('CONFIRM REDEEM'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  void _processRedemption() async {
    final bytes = await File(_personPhoto!.path).readAsBytes();
    final photoBase64 = base64Encode(bytes);

    await context.read<POSProvider>().redeemTicket(
      ticketCode: _ticketCode!,
      photoBase64: photoBase64,
    );
  }

  Widget _buildResultOverlay(POSProvider provider) {
    final bool success = provider.isSuccess ?? false;

    if (success) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && provider.isSuccess != null) {
          _reset();
          provider.clearStatus();
        }
      });
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.95),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: success ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 72),
            const SizedBox(height: 12),
            Text(provider.message ?? '', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            
            if (success && _personPhoto != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(_personPhoto!.path), fit: BoxFit.cover),
                ),
              ),
            ],

            if (!success && provider.ticketInfo != null) ...[
              const SizedBox(height: 18),
              if (provider.ticketInfo!['photo'] != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(provider.ticketInfo!['photo'], height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _buildInfoRow('Time', provider.ticketInfo!['redeemed_at'] ?? '-'),
                    _buildInfoRow('By', provider.ticketInfo!['redeemed_by'] ?? 'System'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!success)
              ElevatedButton(
                onPressed: () {
                  _reset();
                  provider.clearStatus();
                }, 
                child: const Text('CLOSE'),
              ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _ticketCode = null;
      _wristbandQr = null;
      _personPhoto = null;
      _isScanningTicket = true;
      _showTicketInfo = false;
      _isTakingPhoto = false;
      _showPhotoPreview = false;
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
