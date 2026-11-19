/// Tingkat kesulitan memasak sesuai PRD §9
enum Difficulty {
  mudah('Mudah'),
  sedang('Sedang'),
  sulit('Sulit');

  final String label;
  const Difficulty(this.label);

  static Difficulty fromString(String? value) {
    if (value == null) return Difficulty.mudah;
    for (final d in Difficulty.values) {
      if (d.name.toLowerCase() == value.toLowerCase() ||
          d.label.toLowerCase() == value.toLowerCase()) {
        return d;
      }
    }
    return Difficulty.mudah;
  }
}

/// Kategori waktu makan sesuai PRD §9
enum MealType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack'),
  dessert('Dessert'),
  drinks('Drinks');

  final String label;
  const MealType(this.label);

  static MealType fromString(String? value) {
    if (value == null) return MealType.lunch;
    for (final m in MealType.values) {
      if (m.name.toLowerCase() == value.toLowerCase() ||
          m.label.toLowerCase() == value.toLowerCase()) {
        return m;
      }
    }
    return MealType.lunch;
  }
}
