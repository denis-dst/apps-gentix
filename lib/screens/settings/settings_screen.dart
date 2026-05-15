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
      appBar: AppBar(
        title: const Text('Connection Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModeCard(
                    title: 'Online',
                    icon: Icons.cloud_outlined,
                    isActive: settings.isOnline,
                    onTap: () => settings.setMode(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeCard(
                    title: 'Local',
                    icon: Icons.lan_outlined,
                    isActive: !settings.isOnline,
                    onTap: () => settings.setMode(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (settings.isOnline) ...[
              const Text('API Server URL'),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://example.com/api',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => settings.setApiUrl(val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ActionChip(
                    label: const Text('Online Preset'),
                    onPressed: () {
                      _urlController.text = AppConstants.onlineApiUrl;
                      settings.setApiUrl(AppConstants.onlineApiUrl);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Local Preset'),
                    onPressed: () {
                      _urlController.text = AppConstants.localApiUrl;
                      settings.setApiUrl(AppConstants.localApiUrl);
                    },
                  ),
                ],
              ),
            ] else ...[
                  const Text('Local Server IP'),
              const SizedBox(height: 8),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  hintText: '192.168.1.100',
                  prefixIcon: const Icon(Icons.computer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => settings.setLocalIp(val),
              ),
            ],
            const SizedBox(height: 40),
            _buildDataSyncSection(),
            const SizedBox(height: 28),
            Center(
              child: Column(
                children: [
                  if (settings.isConnected)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Connected to Server', style: TextStyle(color: Colors.green)),
                      ],
                    )
                  else
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Not Connected', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    child: _isTesting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Test Connection'),
                  ),
                  if (settings.isConnected) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        await settings.saveSettings();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Settings Saved Successfully!')),
                        );
                        navigator.pop();
                      },
                      child: const Text('Save Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSyncSection() {
    final selectedEvent = context.watch<EventProvider>().selectedEvent;
    final gateProvider = context.watch<GateProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gate Data Sync',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            selectedEvent == null
                ? 'Pilih event terlebih dahulu dari dashboard.'
                : 'Event aktif: ${selectedEvent.name}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (gateProvider.syncMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              gateProvider.syncMessage!,
              style: const TextStyle(
                color: Color(0xFF0F766E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: selectedEvent == null ? null : _downloadData,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Data'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploadData,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Upload Data'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? AppConstants.primaryColor.withValues(alpha: .10) : AppConstants.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppConstants.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? AppConstants.primaryColor : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? AppConstants.primaryColor : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
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
        content: Text(success ? 'Connection Successful!' : 'Connection Failed! Check your URL/IP'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _downloadData() async {
    final gateProvider = context.read<GateProvider>();
    final eventProvider = context.read<EventProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final event = eventProvider.selectedEvent;
    if (event == null) return;

    try {
      final total = await gateProvider.downloadGateData(eventId: event.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('$total tiket berhasil diunduh untuk mode Local.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal download data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadData() async {
    final gateProvider = context.read<GateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final total = await gateProvider.uploadPendingGateLogs();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(total == 0 ? 'Tidak ada data untuk di-upload.' : '$total data scan berhasil di-upload.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal upload data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
