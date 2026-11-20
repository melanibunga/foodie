import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_data.dart';
import '../data/seed_helper.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

/// State Notifier untuk daftar menu favorit pengguna, diisolasi per akun user (Hive).
class FavoritesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final box = ref.watch(favoritesBoxProvider);
    final raw = box.get(userId);

    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }

    // Jika akun demo dan belum ada entri di box, gunakan seedFavorites
    if (userId == kDemoUserId) {
      return List<String>.from(seedFavorites);
    }

    return const [];
  }

  Future<void> _saveToStorage() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final box = ref.read(favoritesBoxProvider);
      await box.put(userId, state);
    } catch (_) {}
  }

  bool has(String recipeId) {
    return state.contains(recipeId);
  }

  int get count => state.length;

  Future<bool> toggle(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;

    final current = List<String>.from(state);
    final exists = current.contains(recipeId);
    if (exists) {
      current.remove(recipeId);
    } else {
      current.add(recipeId);
    }
    state = current;
    await _saveToStorage();
    return !exists;
  }

  Future<void> remove(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    if (state.contains(recipeId)) {
      final current = List<String>.from(state)..remove(recipeId);
      state = current;
      await _saveToStorage();
    }
  }

  Future<void> resetToSeed() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final box = ref.read(favoritesBoxProvider);
    if (userId == kDemoUserId) {
      state = List<String>.from(seedFavorites);
      await box.put(userId, state);
    } else {
      state = const [];
      await box.put(userId, state);
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<String>>(() {
  return FavoritesNotifier();
});

/// Provider jumlah favorit untuk pill bookmark
final favoriteCountProvider = Provider<int>((ref) {
  return ref.watch(favoritesProvider).length;
});
