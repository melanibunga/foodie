import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipes.dart';
import '../models/models.dart';
import '../services/recipe_cache_service.dart';
import '../services/recipe_service.dart';
import 'auth_provider.dart';
import 'favorites_provider.dart';
import 'meal_plan_provider.dart';
import 'storage_provider.dart';

/// Notifier untuk mengelola resep buatan pengguna sendiri (My Recipes), diisolasi per akun user di box `myRecipes`.
class MyRecipesNotifier extends Notifier<List<Recipe>> {
  @override
  List<Recipe> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    try {
      final box = ref.watch(myRecipesBoxProvider);
      final raw = box.get(userId);
      if (raw is List) {
        return raw
            .map(
              (item) => Recipe.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> addRecipe(Recipe recipe) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final recipeWithAuthor = recipe.copyWith(authorId: userId);
    state = [...state, recipeWithAuthor];

    final box = ref.read(myRecipesBoxProvider);
    await box.put(userId, state.map((r) => r.toJson()).toList());
  }

  Future<void> removeRecipe(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.where((r) => r.id != recipeId).toList();
    final box = ref.read(myRecipesBoxProvider);
    await box.put(userId, state.map((r) => r.toJson()).toList());
  }

  Future<void> resetToSeed() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const [];
    final box = ref.read(myRecipesBoxProvider);
    await box.put(userId, <dynamic>[]);
  }
}

final myRecipesNotifierProvider =
    NotifierProvider<MyRecipesNotifier, List<Recipe>>(MyRecipesNotifier.new);

/// Provider khusus untuk resep buatan user sendiri (/my-recipes)
final myRecipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(myRecipesNotifierProvider);
});

/// State Notifier untuk seluruh resep (seed + resep buatan user aktif)
class RecipesNotifier extends Notifier<List<Recipe>> {
  @override
  List<Recipe> build() {
    final myRecipes = ref.watch(myRecipesProvider);
    return [...seedRecipes, ...myRecipes];
  }

  Future<void> addCustomRecipe(Recipe recipe) async {
    await ref.read(myRecipesNotifierProvider.notifier).addRecipe(recipe);
  }

  Future<void> removeCustomRecipe(String recipeId) async {
    await ref.read(myRecipesNotifierProvider.notifier).removeRecipe(recipeId);
  }

  Future<void> resetToSeed() async {
    await ref.read(myRecipesNotifierProvider.notifier).resetToSeed();
  }
}

final recipesProvider = NotifierProvider<RecipesNotifier, List<Recipe>>(() {
  return RecipesNotifier();
});

/// Resolusi resep sinkron: Memori (seed + myRecipes) -> Cache persist Hive (summary / detail).
/// Menerima [ref] (Ref atau WidgetRef) untuk kompatibilitas di Riverpod.
Recipe? resolveRecipeSync(dynamic ref, String id) {
  // 1. Memori
  final List<Recipe> allRecipes = ref.watch(recipesProvider);
  for (final r in allRecipes) {
    if (r.id == id) return r;
  }

  // 2. Cache persist Hive (recipeCache box)
  try {
    final cacheBox = ref.watch(recipeCacheBoxProvider);
    final cached = RecipeCacheService.getSummary(cacheBox, id);
    if (cached != null) return cached;
  } catch (_) {}

  // 3. Cache detail Hive (recipes box)
  try {
    final recipesBox = ref.watch(recipesBoxProvider);
    final raw = recipesBox.get(id);
    if (raw is Map) {
      return Recipe.fromJson(Map<String, dynamic>.from(raw));
    }
  } catch (_) {}

  return null;
}

/// Provider resolusi terpadu: Memori -> Cache Persist -> API getById (PRD §17)
final recipeByIdProvider = FutureProvider.family<Recipe?, String>((
  ref,
  id,
) async {
  // 1. Cek sinkron memori & cache terlebih dahulu
  final syncRecipe = resolveRecipeSync(ref, id);
  if (syncRecipe != null) {
    return syncRecipe;
  }

  // 2. Fetch dari RecipeService (API / fallback)
  final service = ref.watch(recipeServiceProvider);
  final recipe = await service.getById(id);

  if (recipe != null) {
    try {
      final cacheBox = ref.read(recipeCacheBoxProvider);
      await RecipeCacheService.saveSummary(cacheBox, recipe);
    } catch (_) {}
    return recipe;
  }

  throw Exception('Resep tidak dapat dimuat');
});

/// Provider resep yang ada di daftar favorit pengguna (/favorites)
final favoriteRecipesProvider = Provider<List<Recipe>>((ref) {
  final favIds = ref.watch(favoritesProvider);
  final result = <Recipe>[];
  for (final id in favIds) {
    final recipe = resolveRecipeSync(ref, id);
    if (recipe != null) {
      result.add(recipe);
    }
  }
  return result;
});

/// Key tanggal harian YYYY-MM-DD berbasis clockProvider dari meal_plan_provider
final todayDateKeyProvider = Provider<String>((ref) {
  final now = ref.watch(clockProvider);
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

/// Provider resep Daily Inspiration (rekomendasi acak stabil per hari lewat RecipeService.inspiration, maksimal 5)
final inspirationRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.watch(recipesProvider);
  final dateKey = ref.watch(todayDateKeyProvider);
  final service = ref.watch(recipeServiceProvider);
  return service.inspiration(dateKey, limit: 5);
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

/// Provider gambar pertama untuk tile Search by Meal per kategori
final mealCategoryImageProvider = Provider.family<String?, MealType>((
  ref,
  meal,
) {
  final recipes = ref.watch(recipesProvider);
  for (final r in recipes) {
    if (r.meal == meal && r.image != null && r.image!.isNotEmpty) {
      return r.image;
    }
  }
  return null;
});
