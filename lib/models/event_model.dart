class EventModel {
  final int id;
  final int tenantId;
  final String name;
  final String venue;
  final DateTime eventStartDate;
  final String? backgroundImage;
  final String? securityCode;
  final String purchaseFlow;

  bool get requiresSecurityCode => (securityCode ?? '').trim().isNotEmpty;
  bool get isRedeemFlow => purchaseFlow == 'redeem';

  EventModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.venue,
    required this.eventStartDate,
    this.backgroundImage,
    this.securityCode,
    this.purchaseFlow = 'direct',
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final rawStartDate = json['event_start_date']?.toString();

    return EventModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      tenantId: int.tryParse((json['tenant_id'] ?? 0).toString()) ?? 0,
      name: json['name']?.toString() ?? '-',
      venue: json['venue']?.toString() ?? '-',
      eventStartDate: rawStartDate != null && rawStartDate.isNotEmpty
          ? DateTime.tryParse(rawStartDate) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      backgroundImage: json['background_image']?.toString(),
      securityCode: json['security_code']?.toString(),
      purchaseFlow: (json['purchase_flow']?.toString() ?? 'direct').toLowerCase(),
    );
  }
}