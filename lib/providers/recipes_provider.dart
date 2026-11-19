import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipes.dart';
import '../models/models.dart';
import '../services/recipe_service.dart';
import 'favorites_provider.dart';
import 'storage_provider.dart';

/// State Notifier untuk mengelola seluruh resep (seed + resep buatan user).
class RecipesNotifier extends Notifier<List<Recipe>> {
  static const String prefKey = 'foodie:my_recipes';

  @override
  List<Recipe> build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        final userRecipes = decoded
            .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
            .toList();
        return [...seedRecipes, ...userRecipes];
      }
    } catch (_) {}
    return seedRecipes;
  }

  Future<void> addCustomRecipe(Recipe recipe) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final userRecipes = state
        .where((r) => !seedRecipes.any((s) => s.id == r.id))
        .toList();
    userRecipes.add(recipe);

    await prefs.setString(
      prefKey,
      jsonEncode(userRecipes.map((r) => r.toJson()).toList()),
    );

    state = [...seedRecipes, ...userRecipes];
  }

  Future<void> removeCustomRecipe(String recipeId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final userRecipes = state
        .where((r) => !seedRecipes.any((s) => s.id == r.id) && r.id != recipeId)
        .toList();

    await prefs.setString(
      prefKey,
      jsonEncode(userRecipes.map((r) => r.toJson()).toList()),
    );

    state = [...seedRecipes, ...userRecipes];
  }

  Future<void> resetToSeed() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(prefKey);
    state = seedRecipes;
  }
}

final recipesProvider = NotifierProvider<RecipesNotifier, List<Recipe>>(() {
  return RecipesNotifier();
});

/// Provider khusus untuk resep buatan user sendiri (/my-recipes)
final myRecipesProvider = Provider<List<Recipe>>((ref) {
  final allRecipes = ref.watch(recipesProvider);
  return allRecipes
      .where((r) => !seedRecipes.any((s) => s.id == r.id))
      .toList();
});

/// Provider resep yang ada di daftar favorit pengguna (/favorites)
final favoriteRecipesProvider = Provider<List<Recipe>>((ref) {
  final allRecipes = ref.watch(recipesProvider);
  final favIds = ref.watch(favoritesProvider);
  final map = {for (final r in allRecipes) r.id: r};
  return favIds.map((id) => map[id]).whereType<Recipe>().toList();
});

/// Key tanggal harian YYYY-MM-DD
final todayDateKeyProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

/// Provider resep Daily Inspiration (rekomendasi acak stabil per hari lewat RecipeService.inspiration)
final inspirationRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.watch(recipesProvider);
  final dateKey = ref.watch(todayDateKeyProvider);
  final service = ref.watch(recipeServiceProvider);
  return service.inspiration(dateKey, limit: 6);
});

/// Provider resep Popular (urut rating * ulasan lewat RecipeService.popular)
final popularRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.watch(recipesProvider);
  final service = ref.watch(recipeServiceProvider);
  return service.popular(limit: 10);
});

/// Provider detail resep berdasarkan ID
final recipeDetailProvider = FutureProvider.family<Recipe?, String>((
  ref,
  id,
) async {
  ref.watch(recipesProvider);
  final service = ref.watch(recipeServiceProvider);
  return service.getById(id);
});

/// Notifier untuk menyimpan status centang bahan ("sudah punya") per resep secara lokal (PRD §6.10)
class CheckedIngredientsNotifier extends Notifier<Map<String, Set<String>>> {
  static const String prefPrefix = 'foodie:checked_ing:';

  @override
  Map<String, Set<String>> build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final map = <String, Set<String>>{};
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(prefPrefix)) {
          final recipeId = key.substring(prefPrefix.length);
          final list = prefs.getStringList(key);
          if (list != null) {
            map[recipeId] = list.toSet();
          }
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> toggle(String recipeId, String ingredientId) async {
    final currentMap = Map<String, Set<String>>.from(state);
    final currentSet = Set<String>.from(currentMap[recipeId] ?? <String>{});
    if (currentSet.contains(ingredientId)) {
      currentSet.remove(ingredientId);
    } else {
      currentSet.add(ingredientId);
    }
    currentMap[recipeId] = currentSet;
    state = currentMap;

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList('$prefPrefix$recipeId', currentSet.toList());
    } catch (_) {}
  }
}

final checkedIngredientsProvider =
    NotifierProvider<CheckedIngredientsNotifier, Map<String, Set<String>>>(() {
      return CheckedIngredientsNotifier();
    });

final recipeCheckedIngredientsProvider = Provider.family<Set<String>, String>((
  ref,
  recipeId,
) {
  final map = ref.watch(checkedIngredientsProvider);
  return map[recipeId] ?? const <String>{};
});
