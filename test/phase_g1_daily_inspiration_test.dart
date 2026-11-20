import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/data/recipes.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/api_recipe_service.dart';
import 'package:foodie/services/recipe_service.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:foodie/widgets/ui/image_placeholder.dart';
import 'package:foodie/widgets/ui/smart_image.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box recipeCacheBox;
  late Box recipesBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('foodie_g1_test_');
    Hive.init(tempDir.path);
    recipeCacheBox = await Hive.openBox(HiveBoxNames.recipeCache);
    recipesBox = await Hive.openBox(HiveBoxNames.recipes);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Map<String, dynamic> createSampleApiListFixture({int count = 10}) {
    return {
      'statusCode': 200,
      'success': true,
      'message': 'OK',
      'data': List.generate(count, (i) {
        return {
          'id': 'api-uuid-$i',
          'slug': 'resep-ke-$i',
          'name': 'Menu Lezat $i',
          'origin': 'Nusantara',
          'imageUrl':
              'https://images.example.com/storage/v1/object/public/recipes/menu-$i.jpg',
          'prepTimeMinutes': 15,
          'cookTimeMinutes': 25,
          'servings': 4,
          'difficulty': 'MEDIUM',
          'category': {'name': 'Masakan Nusantara', 'slug': 'nusantara'},
        };
      }),
      'meta': {'page': 1, 'limit': 100, 'hasNextPage': false},
    };
  }

  group('Fase G1 — RecipeService.inspiration Logic', () {
    test('(1) Maksimal 5 resep unik terpilih', () async {
      final fixture = createSampleApiListFixture(count: 15);
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode(fixture),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final boxes = FoodieBoxes(
        users: recipesBox,
        session: recipesBox,
        favorites: recipesBox,
        cart: recipesBox,
        mealPlan: recipesBox,
        myRecipes: recipesBox,
        cooked: recipesBox,
        ratings: recipesBox,
        settings: recipesBox,
        meta: recipesBox,
        recipes: recipesBox,
        recipeCache: recipeCacheBox,
        placesCache: recipesBox,
      );

      final service = ApiRecipeService(
        dio: dio,
        boxes: boxes,
        localService: LocalRecipeService(),
      );

      final results = await service.inspiration('2026-11-20', limit: 5);
      expect(results.length, equals(5));

      final uniqueIds = results.map((r) => r.id).toSet();
      expect(uniqueIds.length, equals(5));
    });

    test(
      '(2) Tanggal sama -> hasil sama persis tanpa panggilan API kedua',
      () async {
        int apiCallCount = 0;
        final fixture = createSampleApiListFixture(count: 8);
        final dio = Dio();
        dio.httpClientAdapter = _MockHttpClientAdapter((options) {
          apiCallCount++;
          return ResponseBody.fromString(
            jsonEncode(fixture),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final boxes = FoodieBoxes(
          users: recipesBox,
          session: recipesBox,
          favorites: recipesBox,
          cart: recipesBox,
          mealPlan: recipesBox,
          myRecipes: recipesBox,
          cooked: recipesBox,
          ratings: recipesBox,
          settings: recipesBox,
          meta: recipesBox,
          recipes: recipesBox,
          recipeCache: recipeCacheBox,
          placesCache: recipesBox,
        );

        final service = ApiRecipeService(
          dio: dio,
          boxes: boxes,
          localService: LocalRecipeService(),
        );

        // Panggilan 1 (memanggil API dan simpan cache)
        final day1Result = await service.inspiration('2026-11-20', limit: 5);
        expect(apiCallCount, equals(1));
        expect(day1Result.length, equals(5));

        // Panggilan 2 di tanggal yang sama (harus membaca dari persist cache tanpa request kedua)
        final day1ResultSecond = await service.inspiration(
          '2026-11-20',
          limit: 5,
        );
        expect(apiCallCount, equals(1)); // TIDAK BERTAMBAH
        expect(
          day1ResultSecond.map((r) => r.id),
          equals(day1Result.map((r) => r.id)),
        );
      },
    );

    test(
      '(3) Tanggal berbeda -> daftar berbeda & membersihkan cache lama',
      () async {
        final fixture = createSampleApiListFixture(count: 20);
        final dio = Dio();
        dio.httpClientAdapter = _MockHttpClientAdapter((options) {
          return ResponseBody.fromString(
            jsonEncode(fixture),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final boxes = FoodieBoxes(
          users: recipesBox,
          session: recipesBox,
          favorites: recipesBox,
          cart: recipesBox,
          mealPlan: recipesBox,
          myRecipes: recipesBox,
          cooked: recipesBox,
          ratings: recipesBox,
          settings: recipesBox,
          meta: recipesBox,
          recipes: recipesBox,
          recipeCache: recipeCacheBox,
          placesCache: recipesBox,
        );

        final service = ApiRecipeService(
          dio: dio,
          boxes: boxes,
          localService: LocalRecipeService(),
        );

        // Hari 1
        await service.inspiration('2026-11-20', limit: 5);
        expect(
          recipeCacheBox.containsKey('foodie:inspiration:2026-11-20'),
          isTrue,
        );

        // Hari 2 (besoknya)
        await service.inspiration('2026-11-21', limit: 5);
        expect(
          recipeCacheBox.containsKey('foodie:inspiration:2026-11-21'),
          isTrue,
        );
        // Cache hari lama harus sudah dibersihkan
        expect(
          recipeCacheBox.containsKey('foodie:inspiration:2026-11-20'),
          isFalse,
        );
      },
    );

    test('(4) API gagal + ada cache -> tampil cache; API gagal tanpa cache -> seed lokal', () async {
      final boxes = FoodieBoxes(
        users: recipesBox,
        session: recipesBox,
        favorites: recipesBox,
        cart: recipesBox,
        mealPlan: recipesBox,
        myRecipes: recipesBox,
        cooked: recipesBox,
        ratings: recipesBox,
        settings: recipesBox,
        meta: recipesBox,
        recipes: recipesBox,
        recipeCache: recipeCacheBox,
        placesCache: recipesBox,
      );

      // Skenario 4A: Simpan cache lama terlebih dahulu
      final cachedSample = [
        const Recipe(
          id: 'cached-1',
          title: 'Resep Cache 1',
          description: 'Dari cache',
          category: 'Tradisional',
          cuisine: 'Jawa',
          meal: MealType.lunch,
          mainIngredient: 'Ayam',
          rating: 4.5,
          reviews: 10,
          timeMin: 30,
          servings: 4,
          kcal: 300,
          difficulty: Difficulty.sedang,
          ingredients: [],
          steps: [],
        ),
      ];
      await recipeCacheBox.put(
        'foodie:inspiration:2026-11-19',
        cachedSample.map((r) => r.toJson()).toList(),
      );

      // Dio yang selalu melempar error
      final dioFailing = Dio();
      dioFailing.httpClientAdapter = _MockHttpClientAdapter((options) {
        throw DioException(
          requestOptions: options,
          error: 'Connection timeout',
          type: DioExceptionType.connectionTimeout,
        );
      });

      final serviceWithOldCache = ApiRecipeService(
        dio: dioFailing,
        boxes: boxes,
        localService: LocalRecipeService(),
      );

      // Hari ini 2026-11-20 belum ada cache, API gagal -> fallback ke cache terakhir (2026-11-19)
      final fallbackToCache = await serviceWithOldCache.inspiration(
        '2026-11-20',
        limit: 5,
      );
      expect(fallbackToCache.isNotEmpty, isTrue);
      expect(fallbackToCache.first.id, equals('cached-1'));

      // Skenario 4B: Bersihkan semua cache, API gagal -> fallback ke seed lokal
      await recipeCacheBox.clear();
      final fallbackToLocal = await serviceWithOldCache.inspiration(
        '2026-11-20',
        limit: 5,
      );
      expect(fallbackToLocal.isNotEmpty, isTrue);
      // seedRecipes IDs
      final seedIds = seedRecipes.map((r) => r.id).toSet();
      expect(seedIds.contains(fallbackToLocal.first.id), isTrue);
    });
  });

  group('Fase G1 — Widget Test FeaturedRecipeCard & SmartImage', () {
    testWidgets(
      '(5) FeaturedRecipeCard & SmartImage: bila image terisi tampil gambar, bila gagal/kosong tampil placeholder',
      (tester) async {
        final boxes = FoodieBoxes(
          users: recipesBox,
          session: recipesBox,
          favorites: recipesBox,
          cart: recipesBox,
          mealPlan: recipesBox,
          myRecipes: recipesBox,
          cooked: recipesBox,
          ratings: recipesBox,
          settings: recipesBox,
          meta: recipesBox,
          recipes: recipesBox,
          recipeCache: recipeCacheBox,
          placesCache: recipesBox,
        );

        // Data URI 1x1 PNG transparan valid
        const validImageDataUri =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        const sampleRecipeWithImage = Recipe(
          id: 'r-1',
          title: 'Rendang Sapi',
          description: 'Enak',
          image: validImageDataUri,
          category: 'Daging',
          cuisine: 'Padang',
          meal: MealType.lunch,
          mainIngredient: 'Sapi',
          rating: 4.8,
          reviews: 20,
          timeMin: 60,
          servings: 4,
          kcal: 400,
          difficulty: Difficulty.sedang,
          ingredients: [],
          steps: [],
        );

        const sampleRecipeWithoutImage = Recipe(
          id: 'r-2',
          title: 'Soto Ayam',
          description: 'Segar',
          image: null,
          category: 'Sup',
          cuisine: 'Lamongan',
          meal: MealType.lunch,
          mainIngredient: 'Ayam',
          rating: 4.6,
          reviews: 15,
          timeMin: 40,
          servings: 4,
          kcal: 350,
          difficulty: Difficulty.mudah,
          ingredients: [],
          steps: [],
        );

        // 1. Resep dengan image terisi -> SmartImage me-render Image (bukan placeholder)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: const MaterialApp(
              home: Scaffold(
                body: FeaturedRecipeCard(recipe: sampleRecipeWithImage),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SmartImage), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(ImagePlaceholder), findsNothing);

        // 2. Resep tanpa image (image: null) -> SmartImage me-render ImagePlaceholder
        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: const MaterialApp(
              home: Scaffold(
                body: FeaturedRecipeCard(recipe: sampleRecipeWithoutImage),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SmartImage), findsOneWidget);
        expect(find.byType(ImagePlaceholder), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      },
    );
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) _handler;

  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
