/// Model entri rencana makan harian sesuai PRD §9
class MealPlanEntry {
  final String id;
  final String date; // Format: YYYY-MM-DD
  final String recipeId;

  const MealPlanEntry({
    required this.id,
    required this.date,
    required this.recipeId,
  });

  MealPlanEntry copyWith({String? id, String? date, String? recipeId}) {
    return MealPlanEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      recipeId: recipeId ?? this.recipeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'date': date, 'recipeId': recipeId};
  }

  factory MealPlanEntry.fromJson(Map<String, dynamic> json) {
    return MealPlanEntry(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      recipeId: json['recipeId'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          recipeId == other.recipeId;

  @override
  int get hashCode => Object.hash(id, date, recipeId);
}
