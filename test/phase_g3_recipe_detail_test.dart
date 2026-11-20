import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/utils/recipe_formatters.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/recipe_service.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/app_header_metrics.dart';
import 'package:hive/hive.dart';

class FakeBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  Iterable<dynamic> get keys => _map.keys;

  @override
  dynamic get(key, {defaultValue}) =>
      _map.containsKey(key) ? _map[key] : defaultValue;

  @override
  Future<void> put(key, value) async => _map[key] = value;

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _map.addAll(entries);

  @override
  Future<void> delete(key) async => _map.remove(key);

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

  @override
  Future<Recipe?> getById(String id) async => apiStore[id];

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
  }) async => apiStore.values.toList();

  @override
  Future<List<Recipe>> popular({int limit = 10}) async =>
      apiStore.values.take(limit).toList();

  @override
  Future<List<Recipe>> inspiration(String dateKey, {int limit = 5}) async =>
      apiStore.values.take(limit).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase G3: Parser Bahan & Langkah (RecipeFormatters)', () {
    test('Membersihkan duplikasi kata takaran dan nama bahan kembar', () {
      final rawIngredients = [
        const Ingredient(
          id: '1',
          name: 'Garam',
          qty: 'secukupnya secukupnya',
          price: 0,
        ),
        const Ingredient(
          id: '2',
          name: 'Air perasan 1 buah Jeruk limau',
          qty: 'Air perasan 1 buah Jeruk limau',
          price: 0,
        ),
        const Ingredient(
          id: '3',
          name: 'Daun singkong secukupnya (direbus setengah matang lalu peras)',
          qty: 'Daun singkong secukupnya (direbus setengah matang lalu peras)',
          price: 0,
        ),
        const Ingredient(id: '4', name: 'Cabai rawit', qty: '10', price: 0),
        const Ingredient(
          id: '5',
          name: '1 kg Daging Sapi',
          qty: '1 kg',
          price: 0,
        ),
      ];

      final formatted = RecipeFormatters.formatIngredients(rawIngredients);

      // 1. Duplikasi "secukupnya secukupnya" dibersihkan menjadi "secukupnya"
      expect(formatted[0].qty, equals('secukupnya'));

      // 2. Air perasan dipisah kuantitasnya
      expect(formatted[1].qty, equals('1 buah'));
      expect(formatted[1].name.toLowerCase(), contains('jeruk limau'));

      // 3. Daun singkong diringkas dan tidak duplikat kalimat
      expect(formatted[2].qty, equals('secukupnya'));
      expect(formatted[2].name, equals('Daun singkong (rebus)'));

      // 4. Angka murni 10 untuk cabai dilengkapi satuan buah
      expect(formatted[3].qty, equals('10 buah'));

      // 5. Nama yang diawali takaran dibersihkan sehingga nama menjadi "Daging Sapi"
      expect(formatted[4].name, equals('Daging Sapi'));
      expect(formatted[4].qty, equals('1 kg'));
    });

    test('Memecah blok teks langkah menjadi N langkah bernomor dengan judul bermakna', () {
      const rawBlock = '''
1. Rebus santan cair bersama bumbu halus dan bumbu rempah di wajan besar. Aduk perlahan tanpa henti agar santan tidak pecah (menyangrai bumbu).
2. Masukkan daging sapi, aduk rata dan masak hingga daging kaku dan berubah warna.
3. Tuang santan kental, kecilkan api. Masak perlahan selama 4-6 jam sambil sesekali diaduk dari dasar wajan agar bumbu tidak gosong (proses slow cooking).
4. Masak terus hingga bumbu menghitam, mengering, dan minyak kelapa terpisah. Tiriskan daging dan siap disajikan.
''';

      final steps = RecipeFormatters.formatSteps([], rawContent: rawBlock);

      expect(steps.length, equals(4));
      // Judul langkah bermakna
      expect(steps[0].title, equals('Menyangrai Bumbu'));
      expect(steps[1].title, equals('Memasukkan Daging'));
      expect(steps[2].title, equals('Proses Slow Cooking'));
      expect(steps[3].title, equals('Penyelesaian'));
    });
  });

  group('Fase G3: Header Bar Metrics & Keseragaman Tinggi (D1)', () {
    testWidgets('Tinggi bar detail == tinggi area fixed AppHeader', (
      tester,
    ) async {
      double detailBarHeight = 0.0;
      double appHeaderHeight = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                detailBarHeight = AppHeaderMetrics.fixedHeight(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final foodieBoxes = FoodieBoxes(
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
            foodieBoxesProvider.overrideWithValue(foodieBoxes),
          ],
          child: const MaterialApp(home: Scaffold(body: AppHeader())),
        ),
      );

      final appHeaderFinder = find.byType(AppHeader);
      expect(appHeaderFinder, findsOneWidget);
      final appHeaderSize = tester.getSize(appHeaderFinder);
      appHeaderHeight = appHeaderSize.height;

      // Tinggi area fixed AppHeader dan detailBarHeight harus presisi sama
      expect(detailBarHeight, equals(appHeaderHeight));
    });
  });

  group('Fase G3: Anti-Overflow & Ketahanan UI di Layar Sempit 360px & Font 1.3x', () {
    testWidgets(
      'Teks panjang bahan dan deskripsi tidak menyebabkan RenderFlex overflow di lebar 360 & font 1.3x',
      (tester) async {
        // Set resolusi layar sempit 360 x 640
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final recipe = Recipe(
          id: 'api:ayam-taliwang-ekstrem',
          title:
              'Ayam Bakar Taliwang Super Pedas Khas Lombok Nusa Tenggara Barat',
          description: 'Ayam bakar khas Lombok dengan bumbu pedas gurih yang meresap sempurna hingga ke serat daging paling dalam, disajikan dengan plecing kangkung segar.',
          image: 'https://example.com/taliwang.jpg',
          category: 'Tradisional',
          cuisine: 'Lombok',
          meal: MealType.dinner,
          mainIngredient: 'Ayam',
          rating: 4.8,
          reviews: 145,
          timeMin: 50,
          servings: 4,
          kcal: 380,
          difficulty: Difficulty.sedang,
          ingredients: const [
            Ingredient(
              id: '1',
              name: 'Daun singkong secukupnya (direbus setengah matang lalu peras airnya)',
              qty: 'Daun singkong secukupnya (direbus setengah matang lalu peras airnya)',
              price: 0,
            ),
            Ingredient(
              id: '2',
              name: 'Air perasan 1 buah Jeruk limau segar harum',
              qty: 'Air perasan 1 buah Jeruk limau segar harum',
              price: 0,
            ),
            Ingredient(
              id: '3',
              name: 'Minyak kelapa murni untuk menumis bumbu halus khas nusantara',
              qty: 'Minyak kelapa murni untuk menumis bumbu halus khas nusantara',
              price: 0,
            ),
          ],
          steps: const [
            RecipeStep(
              id: '1',
              title: 'Langkah 1',
              description: 'Lumuri ayam dengan garam dan perasan jeruk limau. Bakar setengah matang di atas bara api.',
            ),
            RecipeStep(
              id: '2',
              title: 'Langkah 2',
              description: 'Tumis bumbu halus hingga harum, berminyak, dan pekat. Tambahkan gula merah secukupnya.',
            ),
          ],
        );

        final fakeRecipeService = FakeRecipeService();
        fakeRecipeService.apiStore[recipe.id] = recipe;

        final foodieBoxes = FoodieBoxes(
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

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWith((ref) => 'test-user'),
              foodieBoxesProvider.overrideWithValue(foodieBoxes),
              recipeServiceProvider.overrideWithValue(fakeRecipeService),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.3), // Font besar 1.3x
                  size: Size(360, 640),
                ),
                child: const RecipeDetailPage(
                  recipeId: 'api:ayam-taliwang-ekstrem',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Memastikan tidak ada exception overflow dan elemen terpenting ter-render
        final err = tester.takeException();
        expect(err, isNull);
        expect(find.text('Bahan-Bahan'), findsOneWidget);
        expect(find.text('Langkah Memasak'), findsOneWidget);
        expect(find.textContaining('Start Cooking'), findsOneWidget);

        // Memastikan bar atas fixed ada
        final headerBarFinder = find.byKey(
          const Key('recipe-detail-header-bar'),
        );
        expect(headerBarFinder, findsOneWidget);
      },
    );

    testWidgets('Tampil 404 ramah bila id resep tidak ditemukan', (
      tester,
    ) async {
      final fakeRecipeService = FakeRecipeService();
      final foodieBoxes = FoodieBoxes(
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
            foodieBoxesProvider.overrideWithValue(foodieBoxes),
            recipeServiceProvider.overrideWithValue(fakeRecipeService),
          ],
          child: const MaterialApp(
            home: RecipeDetailPage(recipeId: 'api:tidak-ada'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Resep Tidak Ditemukan'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
    });
  });
}
