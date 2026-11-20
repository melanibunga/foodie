import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_data.dart';
import '../data/seed_helper.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'meal_plan_provider.dart';
import 'storage_provider.dart';

enum AddRecipeStatus { added, exists }

/// State Notifier untuk keranjang belanja bahan masakan (My Groceries), diisolasi per akun user (Hive).
class CartNotifier extends Notifier<List<CartGroup>> {
  static const String prefKey = 'cart';
  static const String customGroupName = 'Belanjaan Kamu Nich';

  @override
  List<CartGroup> build() {
    return _loadFromStorage();
  }

  List<CartGroup> _loadFromStorage() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    try {
      final box = ref.watch(cartBoxProvider);
      final raw = box.get(userId);
      if (raw is List && raw.isNotEmpty) {
        final baseTime = DateTime(2026, 1, 1);
        return raw.asMap().entries.map((entry) {
          final idx = entry.key;
          final map = Map<String, dynamic>.from(entry.value as Map);
          final fallbackTime = baseTime.add(Duration(minutes: idx));
          return CartGroup.fromJson(map, fallbackTime);
        }).toList();
      } else if (userId == kDemoUserId && raw == null) {
        return List<CartGroup>.from(seedCartGroups);
      }
    } catch (_) {}

    return const [];
  }

  Future<void> _saveToStorage() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final box = ref.read(cartBoxProvider);
      await box.put(userId, state.map((g) => g.toJson()).toList());
    } catch (_) {}
  }

  /// Tambah semua bahan dari resep ke dalam satu grup resep di keranjang.
  Future<AddRecipeStatus> addRecipe(Recipe recipe) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return AddRecipeStatus.exists;

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
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

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
      final updatedGroup = existingGroup.copyWith(
        addedAt: now,
        items: [newItem, ...existingGroup.items],
      );
      groups[customIndex] = updatedGroup;
    } else {
      final newCustomGroup = CartGroup(
        id: 'cart-group-custom',
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

  /// Toggle status centang item (mendukung pemanggilan toggleItem(itemId) atau toggleItem(groupId, itemId))
  Future<void> toggleItem(
    dynamic groupIdOrItemId, [
    String? maybeItemId,
  ]) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final String itemId = maybeItemId ?? groupIdOrItemId.toString();
    final String? groupId = maybeItemId != null
        ? groupIdOrItemId.toString()
        : null;

    state = state.map((group) {
      if (groupId != null && group.id != groupId) return group;
      final itemIndex = group.items.indexWhere((i) => i.id == itemId);
      if (itemIndex == -1) return group;

      final updatedItems = List<CartItem>.from(group.items);
      final item = updatedItems[itemIndex];
      updatedItems[itemIndex] = item.copyWith(checked: !item.checked);
      return group.copyWith(items: updatedItems);
    }).toList();

    await _saveToStorage();
  }

  /// Ubah estimasi harga item
  Future<void> updatePrice(String groupId, String itemId, int newPrice) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

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

  /// Centang/batalkan centang semua item dalam satu grup
  Future<void> toggleAllInGroup(String groupId, bool checked) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.map((group) {
      if (group.id != groupId) return group;
      final updatedItems = group.items
          .map((item) => item.copyWith(checked: checked))
          .toList();
      return group.copyWith(items: updatedItems);
    }).toList();

    await _saveToStorage();
  }

  /// Hapus semua item yang sudah dicentang (checked) di semua grup
  Future<void> removeCheckedItems() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state
        .map((group) {
          final remainingItems = group.items
              .where((item) => !item.checked)
              .toList();
          return group.copyWith(items: remainingItems);
        })
        .where((group) => group.items.isNotEmpty)
        .toList();

    await _saveToStorage();
  }

  /// Hapus satu grup menu dari keranjang
  Future<void> removeGroup(String groupId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.where((g) => g.id != groupId).toList();
    await _saveToStorage();
  }

  /// Hapus satu item spesifik dari grup tertentu
  Future<void> removeItem(String groupId, String itemId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state
        .map((group) {
          if (group.id != groupId) return group;
          final remainingItems = group.items
              .where((i) => i.id != itemId)
              .toList();
          return group.copyWith(items: remainingItems);
        })
        .where((group) => group.items.isNotEmpty)
        .toList();

    await _saveToStorage();
  }

  /// Cek apakah resep dengan [recipeId] sudah ada di keranjang
  bool hasRecipe(String recipeId) {
    return state.any((g) => g.recipeId == recipeId);
  }

  /// Hapus grup resep berdasarkan [recipeId] dari keranjang
  Future<void> removeByRecipe(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.where((g) => g.recipeId != recipeId).toList();
    await _saveToStorage();
  }

  /// Kosongkan seluruh keranjang belanja user
  Future<void> clearAll() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = [];
    await _saveToStorage();
  }

  /// Reset ke data demo
  Future<void> resetToSeed() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final box = ref.read(cartBoxProvider);
    if (userId == kDemoUserId) {
      state = List<CartGroup>.from(seedCartGroups);
      await box.put(userId, state.map((g) => g.toJson()).toList());
    } else {
      state = const [];
      await box.put(userId, <dynamic>[]);
    }
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartGroup>>(() {
  return CartNotifier();
});

/// Provider untuk grup belanja yang siap ditampilkan di halaman My Groceries:
/// 1. Grup custom ("Belanjaan Kamu Nich") SELALU di paling atas (index 0).
/// 2. Grup resep diurutkan DESCENDING menurut addedAt (terbaru di atas).
/// 3. Item di grup custom diurutkan DESCENDING menurut addedAt (terbaru di atas).
/// 4. Item di grup resep tetap dalam urutan resep aslinya.
final displayCartGroupsProvider = Provider<List<CartGroup>>((ref) {
  final groups = ref.watch(cartProvider);

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

  final recipeGroups = groups.where((g) => g.recipeId != null).toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  return [customGroup, ...recipeGroups];
});

/// Total harga seluruh item yang dicentang (checked) di keranjang
final cartCheckedTotalProvider = Provider<int>((ref) {
  final groups = ref.watch(cartProvider);
  int total = 0;
  for (final group in groups) {
    for (final item in group.items) {
      if (item.checked) {
        total += item.price;
      }
    }
  }
  return total;
});

/// Jumlah seluruh item yang dicentang di keranjang
final cartCheckedCountProvider = Provider<int>((ref) {
  final groups = ref.watch(cartProvider);
  int count = 0;
  for (final group in groups) {
    for (final item in group.items) {
      if (item.checked) {
        count++;
      }
    }
  }
  return count;
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
