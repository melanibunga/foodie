/// Model item belanja keranjang sesuai PRD §9 & §15.8
class CartItem {
  final String id;
  final String name;
  final String qty;
  final int price;
  final bool checked;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
    this.checked = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  CartItem copyWith({
    String? id,
    String? name,
    String? qty,
    int? price,
    bool? checked,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      checked: checked ?? this.checked,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'qty': qty,
      'price': price,
      'checked': checked,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CartItem.fromJson(
    Map<String, dynamic> json, [
    DateTime? fallbackAddedAt,
  ]) {
    final addedAtStr = json['addedAt'] as String?;
    final parsed = addedAtStr != null ? DateTime.tryParse(addedAtStr) : null;
    return CartItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qty: json['qty']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      checked: json['checked'] as bool? ?? false,
      addedAt:
          parsed ?? fallbackAddedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
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
          checked == other.checked &&
          addedAt == other.addedAt;

  @override
  int get hashCode => Object.hash(id, name, qty, price, checked, addedAt);
}

/// Model grup belanja keranjang per resep / custom item sesuai PRD §9 & §15.8
class CartGroup {
  final String id;
  final String? recipeId; // null = custom group "Belanjaan Kamu Nich"
  final String name;
  final List<CartItem> items;
  final DateTime addedAt;

  CartGroup({
    required this.id,
    this.recipeId,
    required this.name,
    required this.items,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  CartGroup copyWith({
    String? id,
    String? recipeId,
    String? name,
    List<CartItem>? items,
    DateTime? addedAt,
  }) {
    return CartGroup(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      items: items ?? this.items,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'name': name,
      'addedAt': addedAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory CartGroup.fromJson(
    Map<String, dynamic> json, [
    DateTime? fallbackAddedAt,
  ]) {
    final addedAtStr = json['addedAt'] as String?;
    final groupAddedAt =
        (addedAtStr != null ? DateTime.tryParse(addedAtStr) : null) ??
        fallbackAddedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final rawItems = json['items'] as List<dynamic>?;
    final items = rawItems != null
        ? rawItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final itemMap = Map<String, dynamic>.from(entry.value as Map);
            final itemFallback = groupAddedAt.add(Duration(seconds: idx));
            return CartItem.fromJson(itemMap, itemFallback);
          }).toList()
        : const <CartItem>[];

    return CartGroup(
      id: json['id'] as String? ?? '',
      recipeId: json['recipeId'] as String?,
      name: json['name'] as String? ?? '',
      addedAt: groupAddedAt,
      items: items,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          recipeId == other.recipeId &&
          name == other.name &&
          addedAt == other.addedAt;

  @override
  int get hashCode => Object.hash(id, recipeId, name, addedAt);
}
