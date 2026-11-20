import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/utils/week_utils.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/pages/meal_plan_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/recipe_cache_service.dart';
import 'package:foodie/services/recipe_service.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:hive/hive.dart';

/// Fake Hive Box di memori untuk keperluan pengujian
class FakeBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  Iterable<dynamic> get keys => _map.keys;

  @override
  dynamic get(key, {defaultValue}) =>
      _map.containsKey(key) ? _map[key] : defaultValue;

  @override
  Future<void> put(key, value) async {
    _map[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    _map.addAll(entries);
  }

  @override
  Future<void> delete(key) async {
    _map.remove(key);
  }

  @override
  bool containsKey(key) => _map.containsKey(key);

  @override
  int get length => _map.length;

  @override
  Future<int> clear() async {
    final count = _map.length;
    _map.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecipeService implements RecipeService {
  final Map<String, Recipe> apiStore = {};
  bool shouldThrow = false;

  @override
  Future<Recipe?> getById(String id) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return apiStore[id];
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
    return apiStore.values.toList();
  }

  @override
  Future<List<Recipe>> popular({int limit = 10}) async {
    return apiStore.values.take(limit).toList();
  }

  @override
  Future<List<Recipe>> inspiration(String dateKey, {int limit = 5}) async {
    return apiStore.values.take(limit).toList();
  }
}

Recipe makeDummyRecipe({
  required String id,
  required String title,
  String image = 'https://example.com/food.jpg',
}) {
  return Recipe(
    id: id,
    title: title,
    description: 'Deskripsi lezat untuk $title',
    image: image,
    category: 'Tradisional',
    cuisine: 'Jawa',
    meal: MealType.dinner,
    mainIngredient: 'Ayam',
    rating: 4.8,
    reviews: 50,
    timeMin: 30,
    servings: 4,
    kcal: 350,
    difficulty: Difficulty.sedang,
    ingredients: const [
      Ingredient(id: 'ing-1', name: 'Ayam Segar', qty: '500 gram', price: 0),
    ],
    steps: const [
      RecipeStep(id: 'step-1', title: 'Persiapan', description: 'Potong ayam'),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase G2: LRU Recipe Cache Tests', () {
    test('Simpan dan ambil ringkasan resep dari box', () async {
      final box = FakeBox();
      final recipe = makeDummyRecipe(
        id: 'api:soto-ayam',
        title: 'Soto Ayam Lamongan',
      );

      await RecipeCacheService.saveSummary(box, recipe);

      expect(RecipeCacheService.hasSummary(box, 'api:soto-ayam'), isTrue);
      final retrieved = RecipeCacheService.getSummary(box, 'api:soto-ayam');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('api:soto-ayam'));
      expect(retrieved.title, equals('Soto Ayam Lamongan'));
    });

    test('Penggusuran LRU saat melebihi batas 300 entri', () async {
      final box = FakeBox();
      const testMax = 5;

      // Masukkan 5 resep awal
      for (int i = 1; i <= testMax; i++) {
        final r = makeDummyRecipe(id: 'api:resep-$i', title: 'Menu $i');
        await RecipeCacheService.saveSummary(box, r, maxEntries: testMax);
        // Delay kecil agar timestamp berbeda
        await Future.delayed(const Duration(milliseconds: 5));
      }

      expect(box.length, equals(testMax));

      // Akses resep-1 agar menjadi yang paling baru digunakan
      final accessed1 = RecipeCacheService.getSummary(box, 'api:resep-1');
      expect(accessed1, isNotNull);

      // Tambahkan resep ke-6
      final r6 = makeDummyRecipe(id: 'api:resep-6', title: 'Menu 6');
      await RecipeCacheService.saveSummary(box, r6, maxEntries: testMax);

      // Total entri tetap testMax (5)
      expect(box.length, equals(testMax));

      // resep-2 harusnya digusur karena resep-1 baru saja diakses
      expect(RecipeCacheService.hasSummary(box, 'api:resep-2'), isFalse);
      expect(RecipeCacheService.hasSummary(box, 'api:resep-1'), isTrue);
      expect(RecipeCacheService.hasSummary(box, 'api:resep-6'), isTrue);
    });
  });

  group('Fase G2: Meal Plan Card Empty Fix Widget Tests', () {
    late FakeBox fakeMealPlanBox;
    late FakeBox fakeRecipeCacheBox;
    late FakeBox fakeRecipesBox;
    late FakeBox fakeFavoritesBox;
    late FakeBox fakeRatingsBox;
    late FakeBox fakeMyRecipesBox;
    late FakeRecipeService fakeRecipeService;
    late FoodieBoxes testBoxes;

    final fixedMonday = DateTime(2026, 11, 16); // Senin

    setUp(() {
      fakeMealPlanBox = FakeBox();
      fakeRecipeCacheBox = FakeBox();
      fakeRecipesBox = FakeBox();
      fakeFavoritesBox = FakeBox();
      fakeRatingsBox = FakeBox();
      fakeMyRecipesBox = FakeBox();
      fakeRecipeService = FakeRecipeService();

      testBoxes = FoodieBoxes(
        users: FakeBox(),
        session: FakeBox(),
        favorites: fakeFavoritesBox,
        cart: FakeBox(),
        mealPlan: fakeMealPlanBox,
        myRecipes: fakeMyRecipesBox,
        cooked: FakeBox(),
        ratings: fakeRatingsBox,
        settings: FakeBox(),
        meta: FakeBox(),
        recipes: fakeRecipesBox,
        recipeCache: fakeRecipeCacheBox,
        placesCache: FakeBox(),
      );
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'test-user'),
          foodieBoxesProvider.overrideWithValue(testBoxes),
          recipeServiceProvider.overrideWithValue(fakeRecipeService),
          clockProvider.overrideWithValue(fixedMonday),
        ],
        child: const MaterialApp(home: Scaffold(body: MealPlanPage())),
      );
    }

    testWidgets(
      'Resep API di Meal Plan muncul sebagai kartu dengan judul & bukan SizedBox kosong',
      (tester) async {
        final apiRecipe = makeDummyRecipe(
          id: 'api:rawon-surabaya',
          title: 'Rawon Surabaya Daging Sapi',
        );
        fakeRecipeService.apiStore[apiRecipe.id] = apiRecipe;

        // Entri meal plan untuk hari Senin (2026-11-16)
        final mondayKey = WeekUtils.formatDateKey(fixedMonday);
        await fakeMealPlanBox.put('test-user', [
          {'id': 'mp-1', 'date': mondayKey, 'recipeId': apiRecipe.id},
        ]);

        // Cache persist Hive menyimpan ringkasan
        await RecipeCacheService.saveSummary(fakeRecipeCacheBox, apiRecipe);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Memastikan kartu resep ter-render dengan teks judul yang benar
        expect(find.text('Rawon Surabaya Daging Sapi'), findsOneWidget);
        expect(find.byType(FeaturedRecipeCard), findsWidgets);
      },
    );

    testWidgets(
      'Resep API di Meal Plan tetap muncul saat offline (data dari cache)',
      (tester) async {
        final apiRecipe = makeDummyRecipe(
          id: 'api:ayam-betutu',
          title: 'Ayam Betutu Khas Bali',
        );
        // Service API melempar error (offline)
        fakeRecipeService.shouldThrow = true;

        final mondayKey = WeekUtils.formatDateKey(fixedMonday);
        await fakeMealPlanBox.put('test-user', [
          {'id': 'mp-2', 'date': mondayKey, 'recipeId': apiRecipe.id},
        ]);

        // Karena pernah dimuat sebelumnya, ringkasan tersimpan di persist cache
        await RecipeCacheService.saveSummary(fakeRecipeCacheBox, apiRecipe);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Kartu tetap muncul berkat persist cache, tidak kosong dan tidak error!
        expect(find.text('Ayam Betutu Khas Bali'), findsOneWidget);
        expect(find.byType(FeaturedRecipeCard), findsWidgets);
      },
    );

    testWidgets(
      'Jika resep gagal dimuat dan tidak ada di cache, kartu error muncul (bukan ruang kosong)',
      (tester) async {
        // Service API melempar error & box cache kosong
        fakeRecipeService.shouldThrow = true;

        final mondayKey = WeekUtils.formatDateKey(fixedMonday);
        await fakeMealPlanBox.put('test-user', [
          {'id': 'mp-3', 'date': mondayKey, 'recipeId': 'api:resep-hilang'},
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Kartu error harus tampil
        expect(find.text('Resep tidak dapat dimuat'), findsOneWidget);
        expect(find.text('Coba lagi'), findsOneWidget);
        // Tidak boleh ada FeaturedRecipeCard untuk resep hilang
        expect(find.byType(FeaturedRecipeCard), findsNothing);
      },
    );
  });
}
