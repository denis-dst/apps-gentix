import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/gate_provider.dart';
import '../../core/constants.dart';
import 'gate_scan_screen.dart';
import 'package:intl/intl.dart';
import '../../models/gate_model.dart';
import '../../models/event_model.dart';

class GateControlScreen extends StatefulWidget {
  const GateControlScreen({super.key});

  @override
  State<GateControlScreen> createState() => _GateControlScreenState();
}

class _GateControlScreenState extends State<GateControlScreen> {
  String _scanType = 'IN'; // IN or OUT
  GateModel? _selectedGate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGates();
    });
  }

  Future<void> _fetchGates() async {
    final event = context.read<EventProvider>().selectedEvent;
    if (event == null) return;
    await context.read<GateProvider>().fetchGates(event.id);
    if (mounted) {
      final gates = context.read<GateProvider>().gates;
      if (gates.isNotEmpty) {
        setState(() {
          _selectedGate = gates.first;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final gateProvider = context.watch<GateProvider>();
    final event = eventProvider.selectedEvent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ACCESS CONTROL',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, letterSpacing: 1.1),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: gateProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Event Information Card
                _buildEventCard(event),
                
                const SizedBox(height: 24),
                
                // Gate Selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Pilih Gate",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildDropdown<GateModel>(
                  label: 'Gate',
                  value: _selectedGate,
                  items: gateProvider.gates,
                  displayBuilder: (gate) => Text(gate.name),
                  onChanged: (v) => setState(() => _selectedGate = v),
                  icon: Icons.door_sliding_outlined,
                ),
                
                const SizedBox(height: 32),
                
                // Check In / Check Out Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleButton(
                        title: 'Check In',
                        icon: Icons.login_rounded,
                        isActive: _scanType == 'IN',
                        onTap: () => setState(() => _scanType = 'IN'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildToggleButton(
                        title: 'Check Out',
                        icon: Icons.logout_rounded,
                        isActive: _scanType == 'OUT',
                        onTap: () => setState(() => _scanType = 'OUT'),
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Scan Barcode Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedGate == null ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GateScanScreen(
                            type: _scanType,
                            gateId: _selectedGate!.id,
                            gateName: _selectedGate!.name,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppConstants.primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded),
                        SizedBox(width: 12),
                        Text(
                          'Scan Barcode',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildEventCard(EventModel? event) {
    if (event == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppConstants.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                "Event Terpilih",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.name,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.venue,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd MMMM yyyy, HH:mm').format(event.eventStartDate),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Widget Function(T) displayBuilder,
    required Function(T?) onChanged,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppConstants.primaryColor, size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                hint: Text("Pilih $label", style: TextStyle(color: Colors.grey[400])),
                items: items.map((T item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: displayBuilder(item),
                  );
                }).toList(),
                onChanged: onChanged,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppConstants.primaryColor),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? AppConstants.primaryColor.withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isActive ? AppConstants.primaryColor : Colors.grey[200]!,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? AppConstants.primaryColor : Colors.grey[400],
              size: 20
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? AppConstants.primaryColor : Colors.grey[400],
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
