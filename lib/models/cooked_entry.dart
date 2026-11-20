/// Model entri riwayat masakan yang telah diselesaikan pengguna (PRD §14.10).
class CookedEntry {
  final String id;
  final String recipeId;
  final String date; // Format: YYYY-MM-DD
  final int? rating; // Rating bintang 1-5 (opsional)

  const CookedEntry({
    required this.id,
    required this.recipeId,
    required this.date,
    this.rating,
  });

  CookedEntry copyWith({
    String? id,
    String? recipeId,
    String? date,
    int? rating,
  }) {
    return CookedEntry(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      date: date ?? this.date,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'date': date,
      if (rating != null) 'rating': rating,
    };
  }

  factory CookedEntry.fromJson(Map<String, dynamic> json) {
    return CookedEntry(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String,
      date: json['date'] as String,
      rating: (json['rating'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CookedEntry &&
        other.id == id &&
        other.recipeId == recipeId &&
        other.date == date &&
        other.rating == rating;
  }

  @override
  int get hashCode => Object.hash(id, recipeId, date, rating);
}
