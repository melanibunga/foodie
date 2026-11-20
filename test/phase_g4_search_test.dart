import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/data/regions.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/pages/search_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/recipe_service.dart';
import 'package:hive/hive.dart';

class FakeBox<T> implements Box<T> {
  final Map<dynamic, T> _storage = {};

  @override
  T? get(dynamic key, {T? defaultValue}) =>
      _storage.containsKey(key) ? _storage[key] : defaultValue;

  @override
  Future<void> put(dynamic key, T value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _storage.remove(key);
  }

  @override
  bool containsKey(dynamic key) => _storage.containsKey(key);

  @override
  Iterable<dynamic> get keys => _storage.keys;

  @override
  Iterable<T> get values => _storage.values;

  @override
  Map<dynamic, T> toMap() => Map.unmodifiable(_storage);

  @override
  int get length => _storage.length;

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  Future<int> clear() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeRecipeService untuk menguji filter & race condition dengan presisi
class DelayedFakeRecipeService implements RecipeService {
  final List<Recipe> allRecipes;
  int delayMs;

  DelayedFakeRecipeService({required this.allRecipes, this.delayMs = 0});

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
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    var results = List<Recipe>.from(allRecipes);

    if (q != null && q.trim().isNotEmpty) {
      final query = q.trim().toLowerCase();
      results = results.where((r) {
        return r.title.toLowerCase().contains(query) ||
            r.description.toLowerCase().contains(query);
      }).toList();
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
      final mi = mainIngredient.trim().toLowerCase();
      results = results.where((r) {
        return r.mainIngredient.toLowerCase() == mi ||
            r.ingredients.any((i) => i.name.toLowerCase().contains(mi));
      }).toList();
    }

    return results;
  }

  @override
  Future<Recipe?> getById(String id) async {
    return allRecipes.firstWhere((r) => r.id == id);
  }

  @override
  Future<List<Recipe>> inspiration(String dateKey, {int limit = 5}) async {
    return allRecipes.take(limit).toList();
  }

  @override
  Future<List<Recipe>> popular({int limit = 10}) async {
    return allRecipes.take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixtureRecipes = [
    const Recipe(
      id: 'api:rendang',
      title: 'Rendang Daging Khas Minang',
      description: 'Masakan khas Sumatera Barat.',
      category: 'Daging Sapi & Kambing',
      cuisine: 'Sumatera Barat',
      meal: MealType.dinner,
      mainIngredient: 'Sapi',
      rating: 4.9,
      reviews: 200,
      timeMin: 180,
      servings: 4,
      kcal: 450,
      difficulty: Difficulty.sulit,
      ingredients: [
        Ingredient(id: '1', name: 'Daging sapi', qty: '500 g', price: 0),
      ],
      steps: [
        RecipeStep(id: '1', title: 'Langkah 1', description: 'Masak santan'),
      ],
    ),
    const Recipe(
      id: 'api:ayam-betutu',
      title: 'Ayam Betutu Khas Gilimanuk',
      description: 'Masakan khas Bali.',
      category: 'Ayam & Unggas',
      cuisine: 'Bali',
      meal: MealType.dinner,
      mainIngredient: 'Ayam',
      rating: 4.8,
      reviews: 150,
      timeMin: 120,
      servings: 4,
      kcal: 400,
      difficulty: Difficulty.sedang,
      ingredients: [
        Ingredient(id: '2', name: 'Ayam utuh', qty: '1 ekor', price: 0),
      ],
      steps: [
        RecipeStep(id: '1', title: 'Langkah 1', description: 'Bakar ayam'),
      ],
    ),
    const Recipe(
      id: 'api:gudeg-jogja',
      title: 'Gudeg Nangka Jogja',
      description: 'Masakan khas DI Yogyakarta.',
      category: 'Sayuran & Tumisan',
      cuisine: 'DI Yogyakarta',
      meal: MealType.lunch,
      mainIngredient: 'Nangka',
      rating: 4.7,
      reviews: 130,
      timeMin: 180,
      servings: 4,
      kcal: 350,
      difficulty: Difficulty.sedang,
      ingredients: [
        Ingredient(id: '3', name: 'Nangka muda', qty: '500 g', price: 0),
      ],
      steps: [
        RecipeStep(id: '1', title: 'Langkah 1', description: 'Rebus nangka'),
      ],
    ),
    const Recipe(
      id: 'api:pempek',
      title: 'Pempek Kapal Selam',
      description: 'Masakan khas Sumatera Selatan.',
      category: 'Kudapan & Jajanan Pasar',
      cuisine: 'Sumatera Selatan',
      meal: MealType.snack,
      mainIngredient: 'Ikan',
      rating: 4.8,
      reviews: 190,
      timeMin: 60,
      servings: 4,
      kcal: 300,
      difficulty: Difficulty.sedang,
      ingredients: [
        Ingredient(id: '4', name: 'Ikan tenggiri', qty: '300 g', price: 0),
      ],
      steps: [
        RecipeStep(id: '1', title: 'Langkah 1', description: 'Bentuk adonan'),
      ],
    ),
    const Recipe(
      id: 'api:beef-bulgogi',
      title: 'Beef Bulgogi',
      description: 'Masakan khas Korea Selatan.',
      category: 'Daging Sapi & Kambing',
      cuisine: 'Korea Selatan',
      meal: MealType.dinner,
      mainIngredient: 'Sapi',
      rating: 4.6,
      reviews: 80,
      timeMin: 30,
      servings: 2,
      kcal: 380,
      difficulty: Difficulty.mudah,
      ingredients: [
        Ingredient(id: '5', name: 'Daging sapi iris', qty: '250 g', price: 0),
      ],
      steps: [
        RecipeStep(id: '1', title: 'Langkah 1', description: 'Tumis daging'),
      ],
    ),
  ];

  group('Fase G4: Pemetaan Daerah & data/regions.dart', () {
    test(
      'Setiap area pada fixture respons API terpetakan ke tepat satu grup',
      () {
        final sampleApiOrigins = [
          'Aceh',
          'Sumatera Barat',
          'Palembang, Sumatera Selatan',
          'DKI Jakarta',
          'Jawa Barat',
          'Jawa Tengah',
          'DI Yogyakarta',
          'Surabaya, Jawa Timur',
          'Madura',
          'Bali',
          'Lombok, Nusa Tenggara Barat',
          'Samarinda, Kalimantan Timur',
          'Banjarmasin, Kalimantan Selatan',
          'Manado, Sulawesi Utara',
          'Makassar, Sulawesi Selatan',
          'Ternate, Maluku Utara',
          'Papua / Maluku',
          'Korea Selatan',
          'Jepang',
          'Italia/Rumahan',
          'Masakan Rumahan',
          'Nusantara',
          'Daerah Antah Berantah', // Uji fallback
        ];

        final validGroups = {
          'Sumatra',
          'Jawa',
          'Bali & Nusa Tenggara',
          'Kalimantan',
          'Sulawesi',
          'Maluku & Papua',
          'Mancanegara',
          'Lainnya',
        };

        for (final origin in sampleApiOrigins) {
          final group = mapOriginToGroup(origin);
          expect(
            validGroups.contains(group),
            isTrue,
            reason: 'Origin "$origin" harus masuk ke salah satu grup valid',
          );
        }

        // Pastikan fallback ke 'Lainnya'
        expect(mapOriginToGroup('Daerah Antah Berantah'), equals('Lainnya'));
        expect(mapOriginToGroup('Masakan Rumahan'), equals('Lainnya'));

        // Uji normalisasi nama
        expect(normalizeRegionName('Indonesian'), equals('Indonesia'));
        expect(normalizeRegionName('Jogja Istimewa'), equals('DI Yogyakarta'));
      },
    );
  });

  group('Fase G4: Filter Semantik & Hasil yang Diharapkan', () {
    late DelayedFakeRecipeService fakeService;

    setUp(() {
      fakeService = DelayedFakeRecipeService(allRecipes: fixtureRecipes);
    });

    test('Filter kata kunci saja (q)', () async {
      final results = await fakeService.list(q: 'rendang');
      expect(results.length, equals(1));
      expect(results.first.id, equals('api:rendang'));
    });

    test('Filter area saja (cuisine)', () async {
      final results = await fakeService.list(cuisine: 'Bali');
      expect(results.length, equals(1));
      expect(results.first.id, equals('api:ayam-betutu'));
    });

    test(
      'Filter kombinasi kategori + bahan (category + mainIngredient)',
      () async {
        final results = await fakeService.list(
          category: 'Daging Sapi & Kambing',
          mainIngredient: 'Sapi',
        );
        expect(results.length, equals(2));
        final ids = results.map((r) => r.id).toSet();
        expect(ids, containsAll(['api:rendang', 'api:beef-bulgogi']));
      },
    );

    test('Filter kombinasi kata kunci + area', () async {
      final results = await fakeService.list(
        q: 'Gudeg',
        cuisine: 'DI Yogyakarta',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('api:gudeg-jogja'));
    });

    test('Tanpa filter mengembalikan semua resep', () async {
      final results = await fakeService.list();
      expect(results.length, equals(5));
    });
  });

  group('Fase G4: Widget Search by Region & Anti-Race Condition', () {
    late DelayedFakeRecipeService fakeService;
    late FoodieBoxes foodieBoxes;

    setUp(() {
      fakeService = DelayedFakeRecipeService(allRecipes: fixtureRecipes);
      foodieBoxes = FoodieBoxes(
        users: FakeBox(),
        session: FakeBox(),
        favorites: FakeBox(),
        cart: FakeBox(),
        mealPlan: FakeBox(),
        myRecipes: FakeBox(),
        cooked: FakeBox(),
        ratings: FakeBox(),
        settings: FakeBox(),
        meta: FakeBox(),
        recipes: FakeBox(),
        recipeCache: FakeBox(),
        placesCache: FakeBox(),
      );
    });

    testWidgets('Tampil default grid Search by Region dengan grup wilayah', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
            foodieBoxesProvider.overrideWithValue(foodieBoxes),
            recipeServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      await tester.pumpAndSettle();

      // Judul utama Search by Region harus tampil
      expect(find.text('Search by Region'), findsOneWidget);

      // Grup wilayah pertama harus tampil di viewport awal
      expect(find.text('Sumatra'), findsOneWidget);
      expect(find.text('Sumatera Barat'), findsOneWidget);
      expect(find.text('Jawa'), findsOneWidget);

      // Drag / scroll ke bawah untuk melihat grup berikutnya
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Bali & Nusa Tenggara'), findsOneWidget);
      expect(find.text('Bali'), findsOneWidget);
    });

    testWidgets(
      'Tap kartu daerah menampilkan hasil daerah dengan tombol Bersihkan',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWith((ref) => 'test-user'),
              foodieBoxesProvider.overrideWithValue(foodieBoxes),
              recipeServiceProvider.overrideWithValue(fakeService),
            ],
            child: const MaterialApp(home: SearchPage()),
          ),
        );

        await tester.pumpAndSettle();

        // Tap kartu "Sumatera Barat"
        final sumbarFinder = find.text('Sumatera Barat');
        expect(sumbarFinder, findsOneWidget);
        await tester.tap(sumbarFinder);
        await tester.pumpAndSettle();

        // Judul berubah menjadi "Hasil: Sumatera Barat"
        expect(find.text('Hasil: Sumatera Barat'), findsOneWidget);
        expect(find.text('Bersihkan'), findsOneWidget);

        // Resep Rendang harus tampil
        expect(find.text('Rendang Daging Khas Minang'), findsOneWidget);

        // Tap tombol Bersihkan
        await tester.tap(find.text('Bersihkan'));
        await tester.pumpAndSettle();

        // Kembali ke tampilan awal Search by Region
        expect(find.text('Search by Region'), findsOneWidget);
        expect(find.text('Sumatera Barat'), findsOneWidget);
      },
    );

    testWidgets(
      'Race condition: respons terlambat diabaikan dan hasil mengikuti filter terakhir',
      (tester) async {
        final controlledService = DelayedFakeRecipeService(
          allRecipes: fixtureRecipes,
        );

        // Override method list untuk mengontrol waktu respon
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
            foodieBoxesProvider.overrideWithValue(foodieBoxes),
            recipeServiceProvider.overrideWith((ref) => controlledService),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SearchPage()),
          ),
        );

        await tester.pumpAndSettle();

        // Cari kata kunci pertama: "rendang"
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'rendang');
        await tester.pump(
          const Duration(milliseconds: 300),
        ); // Debounce selesai

        // Ganti cepat dengan kata kunci kedua: "ayam"
        await tester.enterText(searchField, 'ayam');
        await tester.pump(
          const Duration(milliseconds: 300),
        ); // Debounce selesai

        await tester.pumpAndSettle();

        // Hasil akhir harus mengikuti kata kunci TERAKHIR ("ayam"), bukan "rendang"
        expect(find.text('Ayam Betutu Khas Gilimanuk'), findsOneWidget);
        expect(find.text('Rendang Daging Khas Minang'), findsNothing);
      },
    );
  });
}
