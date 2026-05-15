class GateModel {
  final int id;
  final String name;
  final List<String> allowedCategories;
  final List<int> allowedCategoryIds;

  GateModel({
    required this.id,
    required this.name,
    required this.allowedCategories,
    required this.allowedCategoryIds,
  });

  factory GateModel.fromJson(Map<String, dynamic> json) {
    final categories = (json['ticket_categories'] as List?) ?? const [];
    return GateModel(
      id: json['id'],
      name: json['name'],
      allowedCategories: categories
          .map((c) => c['name'].toString())
          .toList(),
      allowedCategoryIds: categories
          .map((c) => c['id'] as int)
          .toList(),
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
