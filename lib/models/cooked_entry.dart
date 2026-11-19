/// Model entri riwayat masakan yang telah diselesaikan pengguna (PRD §14.10).
class CookedEntry {
  final String id;
  final String recipeId;
  final String date; // Format: YYYY-MM-DD

  const CookedEntry({
    required this.id,
    required this.recipeId,
    required this.date,
  });

  CookedEntry copyWith({String? id, String? recipeId, String? date}) {
    return CookedEntry(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'recipeId': recipeId, 'date': date};
  }

  factory CookedEntry.fromJson(Map<String, dynamic> json) {
    return CookedEntry(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String,
      date: json['date'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CookedEntry &&
        other.id == id &&
        other.recipeId == recipeId &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(id, recipeId, date);
}
