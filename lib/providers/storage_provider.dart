import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Daftar nama Box Hive yang digunakan di seluruh aplikasi Foodie.id.
/// Sesuai PRD Fase B1, semua penyimpanan lokal menggunakan Hive (tanpa TypeAdapter).
class HiveBoxNames {
  static const String users = 'users';
  static const String session = 'session';
  static const String favorites = 'favorites';
  static const String cart = 'cart';
  static const String mealPlan = 'mealPlan';
  static const String myRecipes = 'myRecipes';
  static const String cooked = 'cooked';
  static const String ratings = 'ratings';
  static const String settings = 'settings';
  static const String meta = 'meta';
  static const String recipes = 'recipes';
  static const String recipeCache = 'recipeCache';
  static const String placesCache = 'placesCache';

  static const List<String> all = [
    users,
    session,
    favorites,
    cart,
    mealPlan,
    myRecipes,
    cooked,
    ratings,
    settings,
    meta,
    recipes,
    recipeCache,
    placesCache,
  ];
}

/// Wadah (container) untuk semua box Hive aplikasi Foodie.id
class FoodieBoxes {
  final Box users;
  final Box session;
  final Box favorites;
  final Box cart;
  final Box mealPlan;
  final Box myRecipes;
  final Box cooked;
  final Box ratings;
  final Box settings;
  final Box meta;
  final Box recipes;
  final Box recipeCache;
  final Box placesCache;

  const FoodieBoxes({
    required this.users,
    required this.session,
    required this.favorites,
    required this.cart,
    required this.mealPlan,
    required this.myRecipes,
    required this.cooked,
    required this.ratings,
    required this.settings,
    required this.meta,
    required this.recipes,
    required this.recipeCache,
    required this.placesCache,
  });

  /// Membuka seluruh box Hive yang dibutuhkan aplikasi sebelum runApp
  static Future<FoodieBoxes> open() async {
    final users = await Hive.openBox(HiveBoxNames.users);
    final session = await Hive.openBox(HiveBoxNames.session);
    final favorites = await Hive.openBox(HiveBoxNames.favorites);
    final cart = await Hive.openBox(HiveBoxNames.cart);
    final mealPlan = await Hive.openBox(HiveBoxNames.mealPlan);
    final myRecipes = await Hive.openBox(HiveBoxNames.myRecipes);
    final cooked = await Hive.openBox(HiveBoxNames.cooked);
    final ratings = await Hive.openBox(HiveBoxNames.ratings);
    final settings = await Hive.openBox(HiveBoxNames.settings);
    final meta = await Hive.openBox(HiveBoxNames.meta);
    final recipes = await Hive.openBox(HiveBoxNames.recipes);
    final recipeCache = await Hive.openBox(HiveBoxNames.recipeCache);
    final placesCache = await Hive.openBox(HiveBoxNames.placesCache);

    return FoodieBoxes(
      users: users,
      session: session,
      favorites: favorites,
      cart: cart,
      mealPlan: mealPlan,
      myRecipes: myRecipes,
      cooked: cooked,
      ratings: ratings,
      settings: settings,
      meta: meta,
      recipes: recipes,
      recipeCache: recipeCache,
      placesCache: placesCache,
    );
  }

  /// Menghapus seluruh data dari semua box (untuk reset atau test)
  Future<void> clearAll() async {
    await users.clear();
    await session.clear();
    await favorites.clear();
    await cart.clear();
    await mealPlan.clear();
    await myRecipes.clear();
    await cooked.clear();
    await ratings.clear();
    await settings.clear();
    await meta.clear();
    await recipes.clear();
    await recipeCache.clear();
    await placesCache.clear();
  }
}

/// Provider utama untuk instance FoodieBoxes yang di-override di main() atau test
final foodieBoxesProvider = Provider<FoodieBoxes>((ref) {
  throw UnimplementedError(
    'foodieBoxesProvider must be overridden in main() or ProviderScope',
  );
});

/// Shim backward-compatibility untuk pengujian lama yang meng-override sharedPreferencesProvider
final sharedPreferencesProvider = Provider<dynamic>((ref) => null);

// Provider terpisah untuk tiap box agar modular dan mudah diakses
final usersBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).users,
);
final sessionBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).session,
);
final favoritesBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).favorites,
);
final cartBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).cart,
);
final mealPlanBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).mealPlan,
);
final myRecipesBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).myRecipes,
);
final cookedBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).cooked,
);
final ratingsBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).ratings,
);
final settingsBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).settings,
);
final metaBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).meta,
);
final recipesBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).recipes,
);
final recipeCacheBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).recipeCache,
);
final placesCacheBoxProvider = Provider<Box>(
  (ref) => ref.watch(foodieBoxesProvider).placesCache,
);
