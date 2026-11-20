import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_data.dart';
import '../models/models.dart';
import 'meal_plan_provider.dart';
import 'storage_provider.dart';

enum AddRecipeStatus { added, exists }

/// State Notifier untuk keranjang belanja bahan masakan (My Groceries).
class CartNotifier extends Notifier<List<CartGroup>> {
  static const String prefKey = 'foodie:cart';
  static const String customGroupName = 'Belanjaan Kamu Nich';

  @override
  List<CartGroup> build() {
    return _loadFromStorage();
  }

  List<CartGroup> _loadFromStorage() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        final baseTime = DateTime(2026, 1, 1);
        return decoded.asMap().entries.map((entry) {
          final idx = entry.key;
          final map = entry.value as Map<String, dynamic>;
          final fallbackTime = baseTime.add(Duration(minutes: idx));
          return CartGroup.fromJson(map, fallbackTime);
        }).toList();
      }
    } catch (_) {}
    return seedCartGroups;
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(
        prefKey,
        jsonEncode(state.map((g) => g.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Tambah semua bahan dari resep ke dalam satu grup resep di keranjang.
  /// Jika resep sudah ada di keranjang, tidak menduplikasi dan mengembalikan [AddRecipeStatus.exists].
  Future<AddRecipeStatus> addRecipe(Recipe recipe) async {
    final alreadyExists = state.any((g) => g.recipeId == recipe.id);
    if (alreadyExists) {
      return AddRecipeStatus.exists;
    }

    final now = ref.read(clockProvider);

    final newItems = recipe.ingredients.map((ing) {
      final unitStr = ing.unit != null && ing.unit!.isNotEmpty
          ? ' ${ing.unit}'
          : '';
      return CartItem(
        id: 'ci-${recipe.id}-${ing.id}',
        name: ing.name,
        qty: '${ing.qty}$unitStr',
        price: ing.price,
        checked: false,
        addedAt: now,
      );
    }).toList();

    final newGroup = CartGroup(
      id: 'cg-${recipe.id}',
      recipeId: recipe.id,
      name: recipe.title,
      addedAt: now,
      items: newItems,
    );

    state = [...state, newGroup];
    await _saveToStorage();
    return AddRecipeStatus.added;
  }

  /// Tambah item belanja custom ke grup "Belanjaan Kamu Nich"
  Future<void> addCustomItem({
    required String name,
    required String qty,
    required int price,
  }) async {
    final now = ref.read(clockProvider);
    final groups = List<CartGroup>.from(state);
    final customIndex = groups.indexWhere((g) => g.recipeId == null);

    final newItem = CartItem(
      id: 'ci-custom-${now.millisecondsSinceEpoch}',
      name: name,
      qty: qty,
      price: price,
      checked: false,
      addedAt: now,
    );

    if (customIndex >= 0) {
      final existingGroup = groups[customIndex];
      final updatedItems = [newItem, ...existingGroup.items];
      groups[customIndex] = existingGroup.copyWith(
        addedAt: now,
        items: updatedItems,
      );
    } else {
      final newCustomGroup = CartGroup(
        id: 'cg-custom-${now.millisecondsSinceEpoch}',
        recipeId: null,
        name: customGroupName,
        addedAt: now,
        items: [newItem],
      );
      groups.insert(0, newCustomGroup);
    }

    state = groups;
    await _saveToStorage();
  }

  /// Toggle status centang item
  Future<void> toggleItem(String groupId, String itemId) async {
    final groups = state.map((group) {
      if (group.id == groupId) {
        final updatedItems = group.items.map((item) {
          if (item.id == itemId) {
            return item.copyWith(checked: !item.checked);
          }
          return item;
        }).toList();
        return group.copyWith(items: updatedItems);
      }
      return group;
    }).toList();

    state = groups;
    await _saveToStorage();
  }

  /// Ubah estimasi harga item
  Future<void> updatePrice(String groupId, String itemId, int newPrice) async {
    final groups = state.map((group) {
      if (group.id == groupId) {
        final updatedItems = group.items.map((item) {
          if (item.id == itemId) {
            return item.copyWith(price: newPrice);
          }
          return item;
        }).toList();
        return group.copyWith(items: updatedItems);
      }
      return group;
    }).toList();

    state = groups;
    await _saveToStorage();
  }

  /// Hapus satu item dari suatu grup (dipakai saat swipe hapus bahan custom)
  Future<void> removeItem(String groupId, String itemId) async {
    final groups = state.map((group) {
      if (group.id == groupId) {
        final updatedItems = group.items
            .where((item) => item.id != itemId)
            .toList();
        return group.copyWith(items: updatedItems);
      }
      return group;
    }).toList();

    state = groups;
    await _saveToStorage();
  }

  /// Hapus satu grup menu dari keranjang
  Future<void> removeGroup(String groupId) async {
    state = state.where((g) => g.id != groupId).toList();
    await _saveToStorage();
  }

  /// Cek apakah resep dengan [recipeId] sudah ada di keranjang
  bool hasRecipe(String recipeId) {
    return state.any((g) => g.recipeId == recipeId);
  }

  /// Hapus grup resep berdasarkan [recipeId] dari keranjang
  Future<void> removeByRecipe(String recipeId) async {
    state = state.where((g) => g.recipeId != recipeId).toList();
    await _saveToStorage();
  }

  /// Kosongkan semua item di keranjang
  Future<void> clearAll() async {
    state = [];
    await _saveToStorage();
  }

  /// Reset ke seed demo
  Future<void> resetToSeed() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(prefKey);
    state = seedCartGroups;
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartGroup>>(() {
  return CartNotifier();
});

/// Provider untuk grup belanja yang siap ditampilkan di halaman My Groceries:
/// 1. Grup custom ("Belanjaan Kamu Nich") SELALU di paling atas (index 0), selalu ada meski kosong.
/// 2. Grup resep diurutkan DESCENDING menurut addedAt (terbaru di atas).
/// 3. Item di grup custom diurutkan DESCENDING menurut addedAt (terbaru di atas).
/// 4. Item di grup resep tetap dalam urutan resep aslinya.
final displayCartGroupsProvider = Provider<List<CartGroup>>((ref) {
  final groups = ref.watch(cartProvider);

  // 1. Cari atau buat grup custom
  final customIndex = groups.indexWhere((g) => g.recipeId == null);
  final CartGroup customGroup;
  if (customIndex >= 0) {
    final rawCustom = groups[customIndex];
    final sortedItems = List<CartItem>.from(rawCustom.items)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    customGroup = rawCustom.copyWith(items: sortedItems);
  } else {
    customGroup = CartGroup(
      id: 'cart-group-custom',
      recipeId: null,
      name: CartNotifier.customGroupName,
      items: const [],
      addedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // 2. Grup resep diurutkan descending menurut addedAt
  final recipeGroups = groups.where((g) => g.recipeId != null).toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  return [customGroup, ...recipeGroups];
});

/// Jumlah semua CartItem di semua grup (untuk badge keranjang header)
final cartCountProvider = Provider<int>((ref) {
  final groups = ref.watch(cartProvider);
  return groups.fold<int>(0, (sum, g) => sum + g.items.length);
});

/// Subtotal satu grup menu = jumlah SEMUA item di grup (sesuai PRD §6.11 & §13)
final cartSubtotalProvider = Provider.family<int, String>((ref, groupId) {
  final groups = ref.watch(cartProvider);
  final group = groups.where((g) => g.id == groupId).firstOrNull;
  if (group == null) return 0;
  return group.items.fold<int>(0, (sum, item) => sum + item.price);
});

/// Total estimasi keranjang = jumlah item yang BELUM DICENTANG di semua grup
final cartTotalUncheckedProvider = Provider<int>((ref) {
  final groups = ref.watch(cartProvider);
  var total = 0;
  for (final group in groups) {
    for (final item in group.items) {
      if (!item.checked) {
        total += item.price;
      }
    }
  }
  return total;
});
