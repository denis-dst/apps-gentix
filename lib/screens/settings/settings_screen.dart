import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                    title: 'Offline',
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
                ],
              ),
            ),
          ],
        ),
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
          color: isActive ? AppConstants.primaryColor.withOpacity(0.1) : AppConstants.cardBg,
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
    setState(() => _isTesting = true);
    final success = await context.read<SettingsProvider>().checkConnection();
    setState(() => _isTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Connection Successful!' : 'Connection Failed! Check your URL/IP'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
