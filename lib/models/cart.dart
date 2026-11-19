/// Model item belanja keranjang sesuai PRD §9
class CartItem {
  final String id;
  final String name;
  final String qty;
  final int price;
  final bool checked;

  const CartItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
    this.checked = false,
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? qty,
    int? price,
    bool? checked,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      checked: checked ?? this.checked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'qty': qty,
      'price': price,
      'checked': checked,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qty: json['qty']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      checked: json['checked'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          qty == other.qty &&
          price == other.price &&
          checked == other.checked;

  @override
  int get hashCode => Object.hash(id, name, qty, price, checked);
}

/// Model grup belanja keranjang per resep / custom item sesuai PRD §9
class CartGroup {
  final String id;
  final String? recipeId; // null = custom group "Belanjaan Kamu Nich"
  final String name;
  final List<CartItem> items;

  const CartGroup({
    required this.id,
    this.recipeId,
    required this.name,
    required this.items,
  });

  CartGroup copyWith({
    String? id,
    String? recipeId,
    String? name,
    List<CartItem>? items,
  }) {
    return CartGroup(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'name': name,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory CartGroup.fromJson(Map<String, dynamic> json) {
    return CartGroup(
      id: json['id'] as String? ?? '',
      recipeId: json['recipeId'] as String?,
      name: json['name'] as String? ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => CartItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          recipeId == other.recipeId &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, recipeId, name);
}
