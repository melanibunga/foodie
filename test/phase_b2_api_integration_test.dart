import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/data/recipes.dart';
import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/api_recipe_service.dart';
import 'package:foodie/services/recipe_service.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late FoodieBoxes boxes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('foodie_api_test_');
    Hive.init(tempDir.path);
    boxes = await FoodieBoxes.open();
    await seedDemoAccountIfNeeded(boxes);
  });

  tearDown(() async {
    await boxes.clearAll();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
    );
  }

  group('Fase B2 — Adapter API Resep (#1 & #2) & Nilai Derived', () {
    test(
      '1. Adapter API #1 memetakan fixture detail ke model Recipe valid',
      () async {
        final fixtureFile = File(
          'test/fixtures/api1_recipe_detail_by_slug.json',
        );
        expect(fixtureFile.existsSync(), isTrue);

        final jsonMap = jsonDecode(
          await fixtureFile.readAsString(),
        ) as Map<String, dynamic>;
        final rawData = jsonMap['data'] as Map<String, dynamic>;

        final recipe = ResepMasakanApiAdapter.fromJson(rawData);

        // Verifikasi ID
        expect(recipe.id, 'api:rendang-daging-khas-minang');

        // Verifikasi nama bersih tanpa prefix nomor
        expect(recipe.title, 'Rendang Daging Khas Minang');
        expect(recipe.title.startsWith('1.'), isFalse);

        // Verifikasi deskripsi
        expect(recipe.description, contains('Sumatera Barat'));
        expect(recipe.description, contains('Daging Sapi & Kambing'));

        // Verifikasi bahan & price = 0
        expect(recipe.ingredients.isNotEmpty, isTrue);
        for (final ing in recipe.ingredients) {
          expect(ing.price, 0, reason: 'Harga bahan dari API wajib 0');
          expect(ing.name.isNotEmpty, isTrue);
          expect(ing.qty.isNotEmpty, isTrue);
        }

        // Verifikasi langkah memasak terparse
        expect(recipe.steps.isNotEmpty, isTrue);
        expect(recipe.steps.first.title.isNotEmpty, isTrue);
        expect(recipe.steps.first.description.isNotEmpty, isTrue);

        // Verifikasi nilai derived dalam batasan yang ditentukan PRD
        expect(recipe.servings >= 1 && recipe.servings <= 6, isTrue);
        expect(recipe.kcal >= 150 && recipe.kcal <= 700, isTrue);
        expect(
          [
            Difficulty.mudah,
            Difficulty.sedang,
            Difficulty.sulit,
          ].contains(recipe.difficulty),
          isTrue,
        );
        expect(recipe.rating >= 3.8 && recipe.rating <= 5.0, isTrue);
        expect(recipe.reviews >= 10 && recipe.reviews <= 210, isTrue);
        expect(recipe.timeMin > 0, isTrue);
        expect(
          recipe.mainIngredient,
          'Sapi',
        ); // diturunkan dari daftar bahan Daging Sapi
      },
    );

    test('2. Nilai derived konsisten untuk id resep yang sama', () async {
      final fixtureFile = File('test/fixtures/api1_recipe_detail_by_slug.json');
      final jsonMap =
          jsonDecode(await fixtureFile.readAsString()) as Map<String, dynamic>;
      final rawData = jsonMap['data'] as Map<String, dynamic>;

      final recipe1 = ResepMasakanApiAdapter.fromJson(rawData);
      final recipe2 = ResepMasakanApiAdapter.fromJson(rawData);

      expect(recipe1.id, recipe2.id);
      expect(recipe1.servings, recipe2.servings);
      expect(recipe1.kcal, recipe2.kcal);
      expect(recipe1.difficulty, recipe2.difficulty);
      expect(recipe1.rating, recipe2.rating);
      expect(recipe1.reviews, recipe2.reviews);
      expect(recipe1.timeMin, recipe2.timeMin);
      expect(recipe1.meal, recipe2.meal);
      expect(recipe1.mainIngredient, recipe2.mainIngredient);
    });

    test('3. Adapter API #1 list mapping dari fixture search soto', () async {
      final fixtureFile = File('test/fixtures/api1_search_soto.json');
      expect(fixtureFile.existsSync(), isTrue);

      final jsonMap =
          jsonDecode(await fixtureFile.readAsString()) as Map<String, dynamic>;
      final rawList = jsonMap['data'] as List;

      final recipes = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => ResepMasakanApiAdapter.fromJson(item))
          .toList();

      expect(recipes.isNotEmpty, isTrue);
      for (final r in recipes) {
        expect(r.id.startsWith('api:'), isTrue);
        expect(r.title.isNotEmpty, isTrue);
        expect(r.title.contains(RegExp(r'^\d+\.')), isFalse);
        expect(r.rating >= 3.8 && r.rating <= 5.0, isTrue);
      }
    });
  });

  group('Fase B2 — Fallback Berantai & Cache Hive', () {
    test(
      'Fallback ke seed resep ketika offline atau API tidak dapat dijangkau',
      () async {
        final service = ApiRecipeService(
          boxes: boxes,
          localService: LocalRecipeService(null, seedRecipes),
        );

        // List dengan query sembarang ketika offline/invalid endpoint harus fallback dengan aman
        final list = await service.list(limit: 5);
        expect(list.isNotEmpty, isTrue);

        // Resep pertama dari seed tetap dapat diakses
        final recipe = await service.getById('ayam-kecap-bawang');
        expect(recipe, isNotNull);
        expect(recipe!.title, 'Ayam Kecap Bawang');
      },
    );

    test(
      'Detail resep tersimpan di box recipes dan dapat dibuka offline',
      () async {
        // Siapkan satu resep API di box recipes
        const testRecipe = Recipe(
          id: 'api:soto-madura-spesial',
          title: 'Soto Madura Spesial',
          description: 'Masakan khas Madura',
          category: 'Sup & Soto',
          cuisine: 'Jawa Timur',
          meal: MealType.lunch,
          mainIngredient: 'Sapi',
          rating: 4.9,
          reviews: 80,
          timeMin: 45,
          servings: 4,
          kcal: 350,
          difficulty: Difficulty.sedang,
          ingredients: [
            Ingredient(id: 'i1', name: 'Daging sapi', qty: '500 g', price: 0),
          ],
          steps: [
            RecipeStep(
              id: 's1',
              title: 'Rebus',
              description: 'Rebus daging hingga empuk',
            ),
          ],
        );

        await boxes.recipes.put(testRecipe.id, testRecipe.toJson());

        final service = ApiRecipeService(
          boxes: boxes,
          localService: LocalRecipeService(null, seedRecipes),
        );
        final loaded = await service.getById('api:soto-madura-spesial');
        expect(loaded, isNotNull);
        expect(loaded!.title, 'Soto Madura Spesial');
        expect(loaded.ingredients.first.price, 0);
      },
    );
  });

  group('Fase B2 — Keranjang Groceries dengan Resep API', () {
    test('Bahan resep API masuk keranjang dengan price = 0, edit harga memperbarui total & subtotal', () async {
      final container = createContainer();

      // Login akun user A
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User Groceries',
            email: 'groceries@foodie.id',
            password: 'password123',
          );

      const apiRecipe = Recipe(
        id: 'api:gulai-ayam-padang',
        title: 'Gulai Ayam Padang',
        description: 'Masakan khas Sumatera Barat',
        category: 'Ayam & Bebek',
        cuisine: 'Sumatera Barat',
        meal: MealType.dinner,
        mainIngredient: 'Ayam',
        rating: 4.8,
        reviews: 45,
        timeMin: 40,
        servings: 4,
        kcal: 420,
        difficulty: Difficulty.sedang,
        ingredients: [
          Ingredient(
            id: 'ing-1',
            name: 'Ayam kampung',
            qty: '1',
            unit: 'ekor',
            price: 0,
          ),
          Ingredient(
            id: 'ing-2',
            name: 'Santan kental',
            qty: '500',
            unit: 'ml',
            price: 0,
          ),
        ],
        steps: [],
      );

      // Tambah resep API ke keranjang
      final status = await container
          .read(cartProvider.notifier)
          .addRecipe(apiRecipe);
      expect(status, AddRecipeStatus.added);

      final groups = container.read(cartProvider);
      final gulaiGroup = groups.firstWhere(
        (g) => g.recipeId == 'api:gulai-ayam-padang',
      );
      expect(gulaiGroup.items.length, 2);

      // Harga awal bahan adalah 0
      for (final item in gulaiGroup.items) {
        expect(item.price, 0);
      }

      // Subtotal grup awal = 0
      expect(container.read(cartSubtotalProvider(gulaiGroup.id)), 0);
      expect(container.read(cartTotalUncheckedProvider), 0);

      // User mengisi harga inline untuk item 1: Ayam kampung = Rp 45.000
      final itemAyam = gulaiGroup.items.first;
      await container
          .read(cartProvider.notifier)
          .updatePrice(gulaiGroup.id, itemAyam.id, 45000);

      // Subtotal grup bertambah menjadi 45.000
      expect(container.read(cartSubtotalProvider(gulaiGroup.id)), 45000);
      // Total estimasi belum dicentang bertambah menjadi 45.000
      expect(container.read(cartTotalUncheckedProvider), 45000);

      // User mengisi harga item 2: Santan kental = Rp 10.000
      final itemSantan = gulaiGroup.items[1];
      await container
          .read(cartProvider.notifier)
          .updatePrice(gulaiGroup.id, itemSantan.id, 10000);

      // Subtotal sekarang 45.000 + 10.000 = 55.000
      expect(container.read(cartSubtotalProvider(gulaiGroup.id)), 55000);
      expect(container.read(cartTotalUncheckedProvider), 55000);

      // Jika item ayam dicentang, maka item yang belum dicentang tinggal santan (Rp 10.000)
      await container
          .read(cartProvider.notifier)
          .toggleItem(gulaiGroup.id, itemAyam.id);
      expect(container.read(cartTotalUncheckedProvider), 10000);
      // Subtotal grup tetap 55.000 (subtotal = semua item di grup)
      expect(container.read(cartSubtotalProvider(gulaiGroup.id)), 55000);

      // Cek akun demo: seed tetap Rp 18.000 (checked), subtotal Rp 9.000 dan Rp 20.000
      await container
          .read(authProvider.notifier)
          .login(email: kDemoEmail, password: kDemoPassword);
      final demoGroups = container.read(cartProvider);
      final ngsGroup = demoGroups.firstWhere(
        (g) => g.recipeId == 'nasi-goreng-spesial',
      );
      final saGroup = demoGroups.firstWhere((g) => g.recipeId == 'soto-ayam');
      expect(container.read(cartSubtotalProvider(ngsGroup.id)), 9000);
      expect(container.read(cartSubtotalProvider(saGroup.id)), 20000);
      expect(container.read(cartCheckedTotalProvider), 18000);
    });
  });
}
