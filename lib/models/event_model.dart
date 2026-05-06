class EventModel {
  final int id;
  final String name;
  final String venue;
  final DateTime eventStartDate;
  final String? backgroundImage;
  final String? securityCode;

  EventModel({
    required this.id,
    required this.name,
    required this.venue,
    required this.eventStartDate,
    this.backgroundImage,
    this.securityCode,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      name: json['name'],
      venue: json['venue'],
      eventStartDate: DateTime.parse(json['event_start_date']),
      backgroundImage: json['background_image'],
      securityCode: json['security_code'],
    );
  }
}
