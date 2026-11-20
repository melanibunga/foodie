import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipes.dart';
import '../models/models.dart';
import '../services/recipe_service.dart';
import 'auth_provider.dart';
import 'favorites_provider.dart';
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
