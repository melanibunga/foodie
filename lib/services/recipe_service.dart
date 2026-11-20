import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipes.dart';
import '../models/models.dart';
import '../providers/recipes_provider.dart';
import '../providers/storage_provider.dart';
import 'api_recipe_service.dart';

/// Kontrak abstraksi data resep sesuai PRD §9.1.
/// Semua halaman dan store wajib mengakses data melalui service ini.
abstract class RecipeService {
  Future<List<Recipe>> list({
    String? q,
    MealType? meal,
    String? category,
    String? cuisine,
    String? mainIngredient,
    Difficulty? difficulty,
    int? maxTimeMin,
    int? minTimeMin,
    int page = 1,
    int limit = 10,
  });

  Future<Recipe?> getById(String id);

  Future<List<Recipe>> popular({int limit = 10});

  Future<List<Recipe>> inspiration(String dateKey, {int limit = 5});
}

/// Implementasi lokal untuk v1 yang menggabungkan data seed dan resep buatan user,
/// dilengkapi delay buatan 150 ms agar loading state dapat teruji.
class LocalRecipeService implements RecipeService {
  final Ref? _ref;
  final List<Recipe>? _fixedRecipePool;

  LocalRecipeService([this._ref, this._fixedRecipePool]);

  List<Recipe> _getAllRecipes() {
    if (_fixedRecipePool != null) {
      return _fixedRecipePool;
    }
    if (_ref != null) {
      final myRecipes = _ref.read(myRecipesProvider);
      return [...seedRecipes, ...myRecipes];
    }
    return seedRecipes;
  }

  @override
  Future<List<Recipe>> list({
    String? q,
    MealType? meal,
    String? category,
    String? cuisine,
    String? mainIngredient,
    Difficulty? difficulty,
    int? maxTimeMin,
    int? minTimeMin,
    int page = 1,
    int limit = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var results = List<Recipe>.from(_getAllRecipes());

    if (q != null && q.trim().isNotEmpty) {
      final query = q.trim().toLowerCase();
      results = results.where((r) {
        return r.title.toLowerCase().contains(query) ||
            r.description.toLowerCase().contains(query) ||
            r.category.toLowerCase().contains(query) ||
            r.cuisine.toLowerCase().contains(query);
      }).toList();
    }

    if (meal != null) {
      results = results.where((r) => r.meal == meal).toList();
    }

    if (category != null && category.trim().isNotEmpty) {
      final cat = category.trim().toLowerCase();
      results = results
          .where(
            (r) =>
                r.category.toLowerCase() == cat ||
                r.category.toLowerCase().contains(cat),
          )
          .toList();
    }

    if (cuisine != null && cuisine.trim().isNotEmpty) {
      final cui = cuisine.trim().toLowerCase();
      results = results.where((r) {
        final rc = r.cuisine.toLowerCase();
        return rc == cui || rc.contains(cui);
      }).toList();
    }

    if (mainIngredient != null && mainIngredient.trim().isNotEmpty) {
      final ingredientQuery = mainIngredient.trim().toLowerCase();
      results = results.where((r) {
        return r.mainIngredient.toLowerCase() == ingredientQuery ||
            r.ingredients.any(
              (i) => i.name.toLowerCase().contains(ingredientQuery),
            );
      }).toList();
    }

    if (difficulty != null) {
      results = results.where((r) => r.difficulty == difficulty).toList();
    }

    if (minTimeMin != null && minTimeMin > 0) {
      results = results.where((r) => r.timeMin >= minTimeMin).toList();
    }

    if (maxTimeMin != null && maxTimeMin > 0) {
      results = results.where((r) => r.timeMin <= maxTimeMin).toList();
    }

    return results;
  }

  @override
  Future<Recipe?> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final recipes = _getAllRecipes();
    try {
      return recipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Recipe>> popular({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final recipes = List<Recipe>.from(_getAllRecipes());
    // Urutkan berdasarkan rating * reviews (menu terpopuler)
    recipes.sort(
      (a, b) => (b.rating * b.reviews).compareTo(a.rating * a.reviews),
    );
    return recipes.take(limit).toList();
  }

  @override
  Future<List<Recipe>> inspiration(String dateKey, {int limit = 5}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final recipes = List<Recipe>.from(_getAllRecipes());
    if (recipes.isEmpty) return [];

    // Seed Random stabil per hari berdasarkan dateKey
    final seed = dateKey.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final random = Random(seed);

    final shuffled = List<Recipe>.from(recipes)..shuffle(random);
    return shuffled.take(limit.clamp(1, 5)).toList();
  }
}

/// Provider utama untuk RecipeService sesuai konfigurasi kRecipeSource
final recipeServiceProvider = Provider<RecipeService>((ref) {
  if (kRecipeSource == 'local') {
    return LocalRecipeService(ref);
  }
  return ApiRecipeService(
    ref: ref,
    boxes: ref.watch(foodieBoxesProvider),
    localService: LocalRecipeService(ref),
  );
});
