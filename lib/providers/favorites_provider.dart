import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_data.dart';
import 'storage_provider.dart';

/// State Notifier untuk daftar menu favorit pengguna.
class FavoritesNotifier extends Notifier<List<String>> {
  static const String prefKey = 'foodie:favorites';

  @override
  List<String> build() {
    _loadFromStorage();
    return seedFavorites;
  }

  void _loadFromStorage() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        state = decoded.map((e) => e.toString()).toList();
      } else {
        state = seedFavorites;
      }
    } catch (_) {
      state = seedFavorites;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(prefKey, jsonEncode(state));
    } catch (_) {}
  }

  bool has(String recipeId) {
    return state.contains(recipeId);
  }

  int get count => state.length;

  Future<bool> toggle(String recipeId) async {
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
    if (state.contains(recipeId)) {
      final current = List<String>.from(state)..remove(recipeId);
      state = current;
      await _saveToStorage();
    }
  }

  Future<void> resetToSeed() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(prefKey);
    state = seedFavorites;
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<String>>(() {
  return FavoritesNotifier();
});

/// Provider jumlah favorit untuk pill bookmark
final favoriteCountProvider = Provider<int>((ref) {
  return ref.watch(favoritesProvider).length;
});
