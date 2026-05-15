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

  GateModel get _allGateOption => GateModel(
        id: 0,
        name: 'All Gate',
        allowedCategories: const [],
        allowedCategoryIds: const [],
      );

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
      setState(() {
        _selectedGate = _allGateOption;
        if (gates.isNotEmpty) {
          _selectedGate = _allGateOption;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final gateProvider = context.watch<GateProvider>();
    final event = eventProvider.selectedEvent;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ACCESS CONTROL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppConstants.darkBg,
        elevation: 0,
      ),
      body: gateProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppConstants.primaryColor),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Event Card ──
                  _buildEventCard(event),

                  const SizedBox(height: 24),

                  // ── Gate Selection Label ──
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pilih Gate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Gate Dropdown (dark-theme-safe) ──
                  _buildGateDropdown(gateProvider),

                  const SizedBox(height: 24),

                  // ── Check In / Check Out Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildToggleButton(
                          title: 'Check In',
                          icon: Icons.login_rounded,
                          isActive: _scanType == 'IN',
                          activeColor: const Color(0xFF22C55E),
                          onTap: () => setState(() => _scanType = 'IN'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToggleButton(
                          title: 'Check Out',
                          icon: Icons.logout_rounded,
                          isActive: _scanType == 'OUT',
                          activeColor: AppConstants.secondaryColor,
                          onTap: () => setState(() => _scanType = 'OUT'),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Scan Button ──
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AppConstants.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.primaryColor.withValues(alpha: .45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _selectedGate == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GateScanScreen(
                                      type: _scanType,
                                      gateId: _selectedGate!.id == 0 ? null : _selectedGate!.id,
                                      gateName: _selectedGate!.name,
                                      eventId: event!.id,
                                      tenantId: event.tenantId,
                                      allowedCategoryIds: _selectedGate!.allowedCategoryIds,
                                    ),
                                  ),
                                );
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Scan Wristband',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _buildGateDropdown(GateProvider gateProvider) {
    final allGates = [_allGateOption, ...gateProvider.gates];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppConstants.primaryColor.withValues(alpha: .35),
          width: 1.4,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GateModel>(
          isExpanded: true,
          value: _selectedGate,
          dropdownColor: const Color(0xFF1E293B),
          iconEnabledColor: AppConstants.primaryColor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          hint: const Text(
            'Pilih Gate',
            style: TextStyle(color: Colors.white54),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: allGates.map((gate) {
            final isAll = gate.id == 0;
            return DropdownMenuItem<GateModel>(
              value: gate,
              child: Row(
                children: [
                  Icon(
                    isAll ? Icons.grid_view_rounded : Icons.door_sliding_outlined,
                    color: isAll ? AppConstants.primaryColor : Colors.white60,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gate.name,
                      style: TextStyle(
                        color: isAll ? AppConstants.primaryColor : Colors.white,
                        fontWeight: isAll ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isAll && gate.allowedCategoryIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${gate.allowedCategoryIds.length} kategori',
                        style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedGate = v),
          selectedItemBuilder: (context) {
            return allGates.map((gate) {
              final isAll = gate.id == 0;
              return Row(
                children: [
                  Icon(
                    isAll ? Icons.grid_view_rounded : Icons.door_sliding_outlined,
                    color: AppConstants.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    gate.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isAll ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildEventCard(EventModel? event) {
    if (event == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppConstants.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy_rounded, color: Colors.white30),
            SizedBox(width: 12),
            Text('Belum ada event dipilih', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppConstants.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withValues(alpha: .30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'Event Terpilih',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white60, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.venue,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white60, size: 14),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd MMMM yyyy, HH:mm').format(event.eventStartDate),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: .12) : AppConstants.cardBg,
          border: Border.all(
            color: isActive ? activeColor : Colors.white12,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white38,
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
