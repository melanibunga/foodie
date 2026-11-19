/// Model langkah memasak sesuai PRD §9 (dinamai RecipeStep agar tidak bentrok dengan Stepper)
class RecipeStep {
  final String id;
  final String title;
  final String description;
  final int? durationMin;

  const RecipeStep({
    required this.id,
    required this.title,
    required this.description,
    this.durationMin,
  });

  RecipeStep copyWith({
    String? id,
    String? title,
    String? description,
    int? durationMin,
  }) {
    return RecipeStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMin: durationMin ?? this.durationMin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'durationMin': durationMin,
    };
  }

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationMin: (json['durationMin'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeStep &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          durationMin == other.durationMin;

  @override
  int get hashCode => Object.hash(id, title, description, durationMin);
}
