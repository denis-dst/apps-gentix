import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../core/constants.dart';
import '../gate/gate_control_screen.dart';
import '../pos/redemption_screen.dart';
import '../pos/sell_ticket_screen.dart';

class ActionSelectionScreen extends StatefulWidget {
  const ActionSelectionScreen({super.key});

  @override
  State<ActionSelectionScreen> createState() => _ActionSelectionScreenState();
}

class _ActionSelectionScreenState extends State<ActionSelectionScreen> {
  bool _isVerified = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final event = context.read<EventProvider>().selectedEvent;
    if (event?.securityCode == null || event!.securityCode!.isEmpty) {
      _isVerified = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVerified) {
      return _buildSecurityVerification();
    }

    final auth = context.read<AuthProvider>();
    final event = context.read<EventProvider>().selectedEvent;
    final role = auth.user?.role;

    final bool isLoket = role == 'Petugas Loket' || role == 'Penyedia Event' || role == 'Superadmin';
    final bool isGate = role == 'Petugas Gate' || role == 'Penyedia Event' || role == 'Superadmin';

    return Scaffold(
      appBar: AppBar(
        title: Text(event?.name ?? 'Actions'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInLeft(
              child: const Text(
                'Choose Operation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            FadeInLeft(
              delay: const Duration(milliseconds: 100),
              child: Text(
                'Select the feature you want to use for this event',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            const SizedBox(height: 32),
            
            if (isLoket) ...[
              _buildSectionTitle('Ticketing (POS)'),
              const SizedBox(height: 16),
              _buildActionCard(
                context,
                title: 'Redeem Voucher',
                subtitle: 'Scan E-Voucher & Link Wristband',
                icon: Icons.qr_code_scanner_rounded,
                color: AppConstants.primaryColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RedemptionScreen())),
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context,
                title: 'Sell Tickets',
                subtitle: 'On-the-spot ticket sales',
                icon: Icons.confirmation_number_rounded,
                color: Colors.cyan,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SellTicketScreen())),
              ),
              const SizedBox(height: 32),
            ],

            if (isGate) ...[
              _buildSectionTitle('Access Control (Gate)'),
              const SizedBox(height: 16),
              _buildActionCard(
                context,
                title: 'Access Control',
                subtitle: 'Manage entry and exit points',
                icon: Icons.door_sliding_rounded,
                color: AppConstants.successColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateControlScreen())),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityVerification() {
    final event = context.read<EventProvider>().selectedEvent;
    return Scaffold(
      appBar: AppBar(title: const Text('Security Verification')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_rounded, size: 80, color: AppConstants.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Enter Security Code',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This event requires a security code to access operational features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'Enter 6-digit code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_codeController.text == event?.securityCode) {
                  setState(() => _isVerified = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Security Code')),
                  );
                }
              },
              child: const Text('Verify Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeInLeft(
      delay: const Duration(milliseconds: 200),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryColor, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FadeInUp(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
