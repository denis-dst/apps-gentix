import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/event_model.dart';
import '../../models/gate_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/gate_provider.dart';
import '../../providers/settings_provider.dart';
import '../gate/gate_scan_screen.dart';
import '../settings/settings_screen.dart';
import 'event_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isDownloading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final eventProvider = context.read<EventProvider>();
    final gateProvider = context.read<GateProvider>();

    await eventProvider.fetchEvents();
    if (!mounted || eventProvider.events.isEmpty) return;

    final event = eventProvider.selectedEvent ?? eventProvider.events.first;
    eventProvider.selectEvent(event);
    await gateProvider.fetchGates(event.id);
    await gateProvider.refreshLocalStats(event.id);
  }

  Future<void> _downloadOfflineData() async {
    final event = context.read<EventProvider>().selectedEvent;
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih event terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isDownloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final gateProvider = context.read<GateProvider>();
      final count = await gateProvider.downloadGateData(eventId: event.id, event: event);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$count data tiket e-voucher berhasil diunduh ke lokal!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal unduh data: $e'),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _uploadOfflineLogs() async {
    final event = context.read<EventProvider>().selectedEvent;
    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final gateProvider = context.read<GateProvider>();
      final count = await gateProvider.uploadPendingGateLogs(event?.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(count == 0
                    ? 'Tidak ada data scan offline untuk di-upload.'
                    : '$count data scan berhasil di-upload ke server!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal upload data: $e'),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _openSelectionFlow({required bool launchScannerOnApply}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventSelectionScreen(
          launchScannerOnApply: launchScannerOnApply,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openScanner() async {
    final event = context.read<EventProvider>().selectedEvent;
    final gate = context.read<GateProvider>().selectedGate;

    if (event == null || gate == null) {
      await _openSelectionFlow(launchScannerOnApply: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GateScanScreen(
          type: 'IN',
          gateId: gate.id == 0 ? null : gate.id,
          gateName: gate.name,
          eventId: event.id,
          tenantId: event.tenantId,
          allowedCategoryIds: gate.allowedCategoryIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final gateProvider = context.watch<GateProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    final selectedEvent = eventProvider.selectedEvent;
    final selectedGate = gateProvider.selectedGate;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFF),
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Color(0xFF172033), fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF3FAFF),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF172033)),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: eventProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                children: [
                  _buildEventCard(selectedEvent, selectedGate),
                  const SizedBox(height: 18),
                  _buildOfflineSyncCard(selectedEvent, gateProvider, settings),
                  const SizedBox(height: 28),
                  const Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      color: Color(0xFF344155),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: .95,
                    children: [
                      _buildQuickAction(
                        title: 'Scanner',
                        subtitle: 'Check In/Out',
                        icon: Icons.qr_code_scanner_rounded,
                        iconColor: const Color(0xFF1BA9E8),
                        onTap: _openScanner,
                      ),
                      _buildQuickAction(
                        title: 'Settings',
                        subtitle: 'Sync & Device Settings',
                        icon: Icons.settings_rounded,
                        iconColor: const Color(0xFF0097A7),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                      _buildQuickAction(
                        title: 'History',
                        subtitle: 'View Logs',
                        icon: Icons.history_rounded,
                        iconColor: const Color(0xFF7E57C2),
                        onTap: _showHistorySummary,
                      ),
                      _buildQuickAction(
                        title: 'Change Event',
                        subtitle: 'Switch Event & Gate',
                        icon: Icons.swap_horiz_rounded,
                        iconColor: const Color(0xFF2B7EBF),
                        onTap: () => _openSelectionFlow(launchScannerOnApply: false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEventCard(EventModel? event, GateModel? gate) {
    final schedule = event == null ? '-' : DateFormat('dd MMM yyyy, HH:mm').format(event.eventStartDate);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF132A55),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132A55).withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded, color: Color(0xFFD6E8FF), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event?.name ?? 'Belum ada event terpilih',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(height: 1, color: Colors.white.withValues(alpha: .18)),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _buildEventMeta('GATE', gate?.name ?? 'Belum Dipilih'),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildEventMeta('SCHEDULE', schedule),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openSelectionFlow(launchScannerOnApply: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6EA7D6).withValues(alpha: .28),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'UBAH GATE',
                style: TextStyle(
                  color: Color(0xFFE7F5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCFDDF2),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFEAF7FF),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconColor.withValues(alpha: .10),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7B899A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistorySummary() {
    final gateProvider = context.read<GateProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF3FAFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History Summary',
              style: TextStyle(color: Color(0xFF172033), fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            _buildSummaryRow('Total Scan', gateProvider.totalScans, AppConstants.primaryColor),
            _buildSummaryRow('Total Valid', gateProvider.totalValidScans, AppConstants.successColor),
            _buildSummaryRow('Total Invalid', gateProvider.totalInvalidScans, AppConstants.errorColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF172033), fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(color: Color(0xFF172033), fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineSyncCard(
    EventModel? event,
    GateProvider gateProvider,
    SettingsProvider settings,
  ) {
    final hasPending = gateProvider.pendingSyncCount > 0;
    final isOnlineMode = settings.isOnline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132A55).withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isOnlineMode ? const Color(0xFF16C7B7) : const Color(0xFF6366F1))
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOnlineMode ? Icons.cloud_done_rounded : Icons.offline_pin_rounded,
                  color: isOnlineMode ? const Color(0xFF0D9488) : const Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mode & Sinkronisasi Offline',
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnlineMode
                          ? 'Scan Online (Server Cloud)'
                          : 'Scan Offline (Data Lokal HP)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await settings.setMode(!settings.isOnline);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnlineMode
                        ? const Color(0xFFE6FFFA)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnlineMode
                          ? const Color(0xFF16C7B7).withValues(alpha: .5)
                          : const Color(0xFF6366F1).withValues(alpha: .5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: isOnlineMode ? const Color(0xFF0D9488) : const Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnlineMode ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: isOnlineMode ? const Color(0xFF0D9488) : const Color(0xFF4F46E5),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${gateProvider.localTicketCount}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF172033),
                              ),
                            ),
                            const Text(
                              'E-Voucher Lokal',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions_rounded,
                        size: 20,
                        color: hasPending ? const Color(0xFFEA580C) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${gateProvider.pendingSyncCount}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: hasPending ? const Color(0xFFEA580C) : const Color(0xFF172033),
                              ),
                            ),
                            const Text(
                              'Menunggu Upload',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isDownloading || event == null) ? null : _downloadOfflineData,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _isDownloading ? 'Mengunduh...' : 'Unduh E-Voucher',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadOfflineLogs,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    _isUploading ? 'Mengupload...' : 'Upload Laporan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasPending ? const Color(0xFFF97316) : const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
