import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/gate_provider.dart';
import '../../core/constants.dart';
import 'gate_scan_screen.dart';
import 'package:intl/intl.dart';
import '../../providers/settings_provider.dart';
import '../../core/api_client.dart';
import '../../models/gate_model.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final gateProvider = context.watch<GateProvider>();
    final event = eventProvider.selectedEvent;

    if (_selectedGate == null && gateProvider.gates.isNotEmpty) {
      _selectedGate = gateProvider.gates.first;
    }

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
                
                // Event Dropdown
                _buildDropdown<String>(
                  label: 'Event',
                  value: event?.name ?? 'No Event Selected',
                  items: [event?.name ?? 'No Event Selected'],
                  displayBuilder: (val) => Text(val),
                  onChanged: (v) {},
                ),
                
                const SizedBox(height: 16),
                
                // Event Info (Venue & Date)
                _buildReadOnlyField(
                  label: 'Information',
                  value: event != null 
                    ? '${event.venue} | ${DateFormat('dd MMM yyyy, HH:mm').format(event.eventStartDate)}'
                    : 'N/A',
                ),
                
                const SizedBox(height: 16),
                
                // Gate Dropdown
                _buildDropdown<GateModel>(
                  label: 'Gate',
                  value: _selectedGate,
                  items: gateProvider.gates,
                  displayBuilder: (gate) => Text(gate.name),
                  onChanged: (v) => setState(() => _selectedGate = v),
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
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black54,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Scan Barcode',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Widget Function(T) displayBuilder,
    required Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: displayBuilder(item),
                );
              }).toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.unfold_more_rounded, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50]!,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(color: Colors.grey[400]),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: isActive ? AppConstants.primaryColor : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? AppConstants.primaryColor : Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? AppConstants.primaryColor : Colors.grey[400],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
