import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../providers/pos_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';

class SellTicketScreen extends StatefulWidget {
  const SellTicketScreen({super.key});

  @override
  State<SellTicketScreen> createState() => _SellTicketScreenState();
}

class _SellTicketScreenState extends State<SellTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nikController = TextEditingController();
  
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final event = context.read<EventProvider>().selectedEvent;
    final settings = context.read<SettingsProvider>();
    if (event == null) return;

    try {
      final response = await ApiClient(settings.baseUrl).dio.get('/events/${event.id}/analytics');
      setState(() {
        _categories = response.data['tickets_stats'];
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<POSProvider>();
    final event = context.read<EventProvider>().selectedEvent;

    return Scaffold(
      appBar: AppBar(title: const Text('Sell Ticket')),
      body: _isLoadingCategories 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Customer Information'),
                  const SizedBox(height: 16),
                  _buildTextField(_nameController, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField(_emailController, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildTextField(_nikController, 'NIK (Identity Number)', Icons.badge_outlined),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Select Category'),
                  const SizedBox(height: 16),
                  _buildCategorySelector(),
                  
                  const SizedBox(height: 48),
                  if (posProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(posProvider.error!, style: const TextStyle(color: Colors.red)),
                    ),
                    
                  ElevatedButton(
                    onPressed: posProvider.isLoading ? null : _submitSale,
                    child: posProvider.isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Complete Sale & Print'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryColor));
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, [TextInputType? type]) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: type,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      children: _categories.map((cat) {
        final bool isFull = cat['sold_count'] >= cat['quota'];
        final bool isSelected = _selectedCategoryId == cat['id'];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.2) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? AppConstants.primaryColor : Colors.transparent),
          ),
          child: ListTile(
            onTap: isFull ? null : () => setState(() => _selectedCategoryId = cat['id']),
            title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Sold: ${cat['sold_count']} / ${cat['quota']}'),
            trailing: isFull 
              ? const Text('FULL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              : isSelected ? const Icon(Icons.check_circle, color: AppConstants.primaryColor) : null,
          ),
        );
      }).toList(),
    );
  }

  void _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final event = context.read<EventProvider>().selectedEvent!;
    await context.read<POSProvider>().sellTicket(
      eventId: event.id,
      categoryId: _selectedCategoryId!,
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      nik: _nikController.text,
    );

    if (mounted && context.read<POSProvider>().isSuccess == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale Successful')));
      Navigator.pop(context);
    }
  }
}

extension on POSProvider {
  String? get error => isSuccess == false ? message : null;
}
