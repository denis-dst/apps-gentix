import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/gate_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late TextEditingController _ipController;
  bool _isTesting = false;
  bool _isDownloading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlController = TextEditingController(text: settings.apiUrl);
    _ipController = TextEditingController(text: settings.localIp);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan Koneksi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode Selection ──
            _sectionLabel('Mode Koneksi'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeCard(
                    title: 'Online',
                    subtitle: 'Internet / Cloud',
                    icon: Icons.cloud_done_rounded,
                    isActive: settings.isOnline,
                    onTap: () => settings.setMode(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeCard(
                    title: 'Local',
                    subtitle: 'Jaringan LAN',
                    icon: Icons.lan_rounded,
                    isActive: !settings.isOnline,
                    onTap: () => settings.setMode(false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── URL / IP Input ──
            if (settings.isOnline) ...[
              _sectionLabel('URL Server API'),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _urlController,
                hint: 'https://example.com/api',
                icon: Icons.link_rounded,
                onChanged: (val) => settings.setApiUrl(val),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _buildPresetChip(
                    label: 'Online Preset',
                    onTap: () {
                      _urlController.text = AppConstants.onlineApiUrl;
                      settings.setApiUrl(AppConstants.onlineApiUrl);
                    },
                  ),
                  _buildPresetChip(
                    label: 'Local Preset',
                    onTap: () {
                      _urlController.text = AppConstants.localApiUrl;
                      settings.setApiUrl(AppConstants.localApiUrl);
                    },
                  ),
                ],
              ),
            ] else ...[
              _sectionLabel('IP Server Lokal'),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _ipController,
                hint: '192.168.1.100',
                icon: Icons.computer_rounded,
                onChanged: (val) => settings.setLocalIp(val),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 6),
              Text(
                'URL yang akan dipakai: http://${settings.localIp}/gentix-apps/api',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .45),
                  fontSize: 11,
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Data Sync Section (hanya Local) ──
            if (!settings.isOnline) ...[
              _buildDataSyncCard(),
              const SizedBox(height: 28),
            ],

            // ── Connection Status ──
            _buildConnectionStatus(settings),

            const SizedBox(height: 16),

            // ── Test Connection ──
            _buildActionButton(
              label: _isTesting ? 'Menguji...' : 'Test Koneksi',
              icon: Icons.wifi_find_rounded,
              color: AppConstants.primaryColor,
              isLoading: _isTesting,
              onPressed: _isTesting ? null : _testConnection,
            ),

            if (settings.isConnected) ...[
              const SizedBox(height: 12),
              _buildActionButton(
                label: 'Simpan Pengaturan',
                icon: Icons.save_rounded,
                color: const Color(0xFF22C55E),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  await settings.saveSettings();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Pengaturan berhasil disimpan!'),
                        ],
                      ),
                      backgroundColor: const Color(0xFF22C55E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  navigator.pop();
                },
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Data Sync Card ──
  Widget _buildDataSyncCard() {
    final selectedEvent = context.watch<EventProvider>().selectedEvent;
    final gateProvider = context.watch<GateProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.primaryColor.withValues(alpha: .25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sinkronisasi Data Wristband',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Untuk mode offline di lapangan',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Event info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  color: selectedEvent != null ? AppConstants.primaryColor : Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedEvent == null
                        ? 'Belum ada event dipilih'
                        : selectedEvent.name,
                    style: TextStyle(
                      color: selectedEvent != null ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: selectedEvent != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Sync message
          if (gateProvider.syncMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: .30)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF22C55E), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      gateProvider.syncMessage!,
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              // Download
              Expanded(
                child: _buildSyncButton(
                  label: 'Download Data',
                  icon: Icons.download_rounded,
                  isLoading: _isDownloading,
                  isPrimary: false,
                  onPressed: selectedEvent == null || _isDownloading ? null : _downloadData,
                ),
              ),
              const SizedBox(width: 10),
              // Upload
              Expanded(
                child: _buildSyncButton(
                  label: 'Upload Data',
                  icon: Icons.upload_rounded,
                  isLoading: _isUploading,
                  isPrimary: true,
                  onPressed: _isUploading ? null : _uploadData,
                ),
              ),
            ],
          ),

          // Info hint
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white30, size: 13),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Download: unduh data wristband ke perangkat sebelum berangkat ke lapangan.\nUpload: kirim hasil scan kembali ke server setelah event selesai.',
                  style: TextStyle(color: Colors.white30, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required bool isPrimary,
    VoidCallback? onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppConstants.primaryColor.withValues(alpha: onPressed == null ? .4 : 1.0)
            : Colors.transparent,
        border: isPrimary
            ? null
            : Border.all(
                color: onPressed == null
                    ? Colors.white12
                    : AppConstants.primaryColor.withValues(alpha: .60),
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(
                    icon,
                    size: 16,
                    color: onPressed == null ? Colors.white30 : Colors.white,
                  ),
                const SizedBox(width: 6),
                Text(
                  isLoading ? (isPrimary ? 'Upload...' : 'Download...') : label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: onPressed == null ? Colors.white30 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
          prefixIcon: Icon(icon, color: AppConstants.primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPresetChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppConstants.primaryColor.withValues(alpha: .30)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppConstants.primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppConstants.primaryColor.withValues(alpha: .15)
              : AppConstants.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppConstants.primaryColor : Colors.white12,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? AppConstants.primaryColor : Colors.white38,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isActive ? AppConstants.primaryColor : Colors.white30,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(SettingsProvider settings) {
    final connected = settings.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFF22C55E).withValues(alpha: .10)
            : Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? const Color(0xFF22C55E).withValues(alpha: .30)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: connected ? const Color(0xFF22C55E) : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            connected ? 'Terhubung ke Server' : 'Belum Terhubung',
            style: TextStyle(
              color: connected ? const Color(0xFF22C55E) : Colors.white38,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: .4),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _testConnection() async {
    final settingsProvider = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isTesting = true);
    final success = await settingsProvider.checkConnection();
    if (!mounted) return;
    setState(() => _isTesting = false);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(success ? 'Koneksi berhasil!' : 'Koneksi gagal! Periksa URL/IP'),
          ],
        ),
        backgroundColor: success ? const Color(0xFF22C55E) : AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _downloadData() async {
    final gateProvider = context.read<GateProvider>();
    final eventProvider = context.read<EventProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final event = eventProvider.selectedEvent;
    if (event == null) return;

    setState(() => _isDownloading = true);
    try {
      final isConnected = settingsProvider.isConnected || await settingsProvider.checkConnection();
      if (!isConnected) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Server belum terhubung. Cek koneksi lalu coba lagi.'),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final total = await gateProvider.downloadGateData(eventId: event.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('$total tiket wristband berhasil diunduh!'),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal download data: $e'),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _uploadData() async {
    final gateProvider = context.read<GateProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isUploading = true);
    try {
      // Pastikan ada koneksi sebelum upload
      final isConnected = settingsProvider.isConnected || await settingsProvider.checkConnection();
      if (!isConnected) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Server belum terhubung. Cek koneksi lalu coba lagi.'),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final total = await gateProvider.uploadPendingGateLogs();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.upload_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(total == 0
                  ? 'Tidak ada data scan untuk di-upload.'
                  : '$total data scan berhasil di-upload ke server!'),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal upload data: $e'),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
