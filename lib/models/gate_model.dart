class GateModel {
  final int id;
  final String name;
  final List<String> allowedCategories;

  GateModel({
    required this.id,
    required this.name,
    required this.allowedCategories,
  });

  factory GateModel.fromJson(Map<String, dynamic> json) {
    return GateModel(
      id: json['id'],
      name: json['name'],
      allowedCategories: (json['ticket_categories'] as List?)
          ?.map((c) => c['name'].toString())
          .toList() ?? [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GateModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
