/// Model bahan masakan sesuai PRD §9
class Ingredient {
  final String id;
  final String name;
  final String qty;
  final String? unit;
  final int price;

  const Ingredient({
    required this.id,
    required this.name,
    required this.qty,
    this.unit,
    required this.price,
  });

  Ingredient copyWith({
    String? id,
    String? name,
    String? qty,
    String? unit,
    int? price,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'qty': qty, 'unit': unit, 'price': price};
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qty: json['qty']?.toString() ?? '',
      unit: json['unit'] as String?,
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ingredient &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          qty == other.qty &&
          unit == other.unit &&
          price == other.price;

  @override
  int get hashCode => Object.hash(id, name, qty, unit, price);
}
