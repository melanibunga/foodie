import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/cooked_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/ratings_provider.dart';
import 'package:foodie/providers/recipes_provider.dart';
import 'package:foodie/providers/reset_data.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/providers/theme_provider.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

void main() {
  late Directory tempDir;
  late FoodieBoxes boxes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('foodie_hive_unit_test_');
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

  group('Fase B1 — Hive & Isolasi Akun Lokal Per User', () {
    test('1. Register A dan B; email sama ditolak; sandi salah ditolak; sandi benar sukses', () async {
      final container = createContainer();

      // Register User A
      final regA = await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'password123',
            rememberMe: true,
          );
      expect(regA, isTrue);
      expect(container.read(currentUserProvider)?.email, 'usera@example.com');
      final userAId = container.read(currentUserIdProvider)!;

      // Logout
      await container.read(authProvider.notifier).logout();
      expect(container.read(currentUserProvider), isNull);

      // Register email sama ditolak
      final regSame = await container
          .read(authProvider.notifier)
          .register(
            name: 'User A Duplicate',
            email: 'UserA@example.com', // case-insensitive
            password: 'password999',
          );
      expect(regSame, isFalse);
      expect(
        container.read(authProvider).errorMessage,
        'Email sudah terdaftar',
      );

      // Register User B
      final regB = await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'passwordB123',
            rememberMe: true,
          );
      expect(regB, isTrue);
      expect(container.read(currentUserProvider)?.email, 'userb@example.com');

      // Logout
      await container.read(authProvider.notifier).logout();

      // Login User A dengan sandi salah ditolak
      final loginWrong = await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'wrongpassword');
      expect(loginWrong, isFalse);
      expect(
        container.read(authProvider).errorMessage,
        'Email atau kata sandi salah',
      );

      // Login User A dengan sandi benar sukses
      final loginSuccess = await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'password123');
      expect(loginSuccess, isTrue);
      expect(container.read(currentUserIdProvider), userAId);
      expect(container.read(currentUserProvider)?.name, 'User A');
    });

    test('2. A menambah data (favorit, keranjang, meal plan, resep buatan, dimasak, rating) -> login B: semuanya kosong', () async {
      final container = createContainer();

      // Register & Login User A
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'password123',
          );

      // A tambah favorit
      await container
          .read(favoritesProvider.notifier)
          .toggle('ayam-kecap-bawang');
      expect(container.read(favoritesProvider), ['ayam-kecap-bawang']);

      // A tambah keranjang
      await container
          .read(cartProvider.notifier)
          .addCustomItem(name: 'Bawang Bombay', qty: '2 buah', price: 5000);
      expect(container.read(cartProvider).isNotEmpty, isTrue);

      // A tambah meal plan
      final addResult = await container
          .read(mealPlanProvider.notifier)
          .add('2026-12-01', 'ayam-kecap-bawang');
      expect(addResult, MealPlanAddResult.added);
      expect(container.read(mealPlanProvider).length, 1);

      // A tambah resep buatan
      const customRecipe = Recipe(
        id: 'recipe-custom-a',
        title: 'Sambal Goreng A',
        description: 'Sambal lezat buatan A',
        category: 'Sambal & Saus',
        cuisine: 'Jawa',
        meal: MealType.lunch,
        mainIngredient: 'Cabai',
        rating: 5.0,
        reviews: 1,
        timeMin: 15,
        servings: 4,
        kcal: 100,
        difficulty: Difficulty.mudah,
        ingredients: [],
        steps: [],
      );
      await container
          .read(recipesProvider.notifier)
          .addCustomRecipe(customRecipe);
      expect(container.read(myRecipesProvider).length, 1);

      // A tambah riwayat dimasak
      await container
          .read(cookedProvider.notifier)
          .add('ayam-kecap-bawang', '2026-11-20');
      expect(container.read(cookedCountProvider), 1);

      // A beri rating
      await container
          .read(ratingsProvider.notifier)
          .rate('ayam-kecap-bawang', 5);
      expect(container.read(ratingsProvider)['ayam-kecap-bawang'], 5);

      // Register & Login User B
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'passwordB123',
          );

      // Pastikan SEMUA data di User B kosong!
      expect(
        container.read(favoritesProvider),
        isEmpty,
        reason: 'Favorit B harus kosong',
      );
      expect(
        container.read(cartProvider),
        isEmpty,
        reason: 'Keranjang B harus kosong',
      );
      expect(
        container.read(mealPlanProvider),
        isEmpty,
        reason: 'Meal Plan B harus kosong',
      );
      expect(
        container.read(myRecipesProvider),
        isEmpty,
        reason: 'Resep buatan B harus kosong',
      );
      expect(
        container.read(cookedProvider),
        isEmpty,
        reason: 'Riwayat cooked B harus kosong',
      );
      expect(
        container.read(cookedCountProvider),
        0,
        reason: 'Dimasak B harus 0',
      );
      expect(
        container.read(ratingsProvider),
        isEmpty,
        reason: 'Ratings B harus kosong',
      );
    });

    test('3. A menghapus data -> data B dan akun demo tetap utuh', () async {
      final container = createContainer();

      // Akun demo sudah punya seed meal plan, favorit, keranjang, dimasak
      await container
          .read(authProvider.notifier)
          .login(email: kDemoEmail, password: kDemoPassword);
      final demoMealPlanCount = container.read(mealPlanProvider).length;
      final demoFavCount = container.read(favoritesProvider).length;
      final demoCartCount = container.read(cartProvider).length;

      // User A register & isi data
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'password123',
          );
      await container
          .read(mealPlanProvider.notifier)
          .add('2026-12-05', 'soto-ayam');
      await container.read(favoritesProvider.notifier).toggle('soto-ayam');
      await container
          .read(cartProvider.notifier)
          .addCustomItem(name: 'Kecap', qty: '1 btl', price: 10000);
      const customRecipe = Recipe(
        id: 'recipe-custom-a2',
        title: 'Nasi Liwet A',
        description: 'Resep A',
        category: 'Nasi, Mie & Pasta',
        cuisine: 'Sunda',
        meal: MealType.lunch,
        mainIngredient: 'Beras',
        rating: 5.0,
        reviews: 1,
        timeMin: 30,
        servings: 4,
        kcal: 300,
        difficulty: Difficulty.mudah,
        ingredients: [],
        steps: [],
      );
      await container
          .read(recipesProvider.notifier)
          .addCustomRecipe(customRecipe);

      // User B register & isi data
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'passwordB123',
          );
      await container
          .read(mealPlanProvider.notifier)
          .add('2026-12-10', 'rendang-sapi-minang');
      await container
          .read(favoritesProvider.notifier)
          .toggle('rendang-sapi-minang');
      await container
          .read(cartProvider.notifier)
          .addCustomItem(name: 'Santan', qty: '1 bks', price: 4000);

      // Kembali ke User A dan hapus datanya
      await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'password123');
      final aEntry = container.read(mealPlanProvider).first;
      await container.read(mealPlanProvider.notifier).remove(aEntry.id);
      expect(container.read(mealPlanProvider), isEmpty);

      await container.read(favoritesProvider.notifier).remove('soto-ayam');
      expect(container.read(favoritesProvider), isEmpty);

      final aGroup = container.read(cartProvider).first;
      await container.read(cartProvider.notifier).removeGroup(aGroup.id);
      expect(container.read(cartProvider), isEmpty);

      await container
          .read(recipesProvider.notifier)
          .removeCustomRecipe('recipe-custom-a2');
      expect(container.read(myRecipesProvider), isEmpty);

      // Cek User B: datanya tetap utuh!
      await container
          .read(authProvider.notifier)
          .login(email: 'userb@example.com', password: 'passwordB123');
      expect(container.read(mealPlanProvider).length, 1);
      expect(
        container.read(mealPlanProvider).first.recipeId,
        'rendang-sapi-minang',
      );
      expect(container.read(favoritesProvider), ['rendang-sapi-minang']);
      expect(container.read(cartProvider).length, 1);

      // Cek Akun Demo: datanya tetap utuh!
      await container
          .read(authProvider.notifier)
          .login(email: kDemoEmail, password: kDemoPassword);
      expect(container.read(mealPlanProvider).length, demoMealPlanCount);
      expect(container.read(favoritesProvider).length, demoFavCount);
      expect(container.read(cartProvider).length, demoCartCount);
    });

    test('4. Ganti A -> B -> A: data A kembali persis, tidak ada data B yang masuk', () async {
      final container = createContainer();

      // Setup User A
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'password123',
          );
      await container
          .read(favoritesProvider.notifier)
          .toggle('ayam-kecap-bawang');
      await container.read(favoritesProvider.notifier).toggle('soto-ayam');
      await container
          .read(cookedProvider.notifier)
          .add('ayam-kecap-bawang', '2026-11-19');

      // Setup User B
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'passwordB123',
          );
      await container.read(favoritesProvider.notifier).toggle('telur-balado');
      expect(container.read(favoritesProvider), ['telur-balado']);

      // Ganti kembali ke User A
      await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'password123');

      expect(container.read(favoritesProvider), [
        'ayam-kecap-bawang',
        'soto-ayam',
      ]);
      expect(container.read(cookedCountProvider), 1);
      expect(
        container.read(favoritesProvider).contains('telur-balado'),
        isFalse,
      );
    });

    test('5. Rating A tidak mengubah rating B', () async {
      final container = createContainer();

      // User A beri rating 5
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'password123',
          );
      await container.read(ratingsProvider.notifier).rate('soto-ayam', 5);
      expect(container.read(ratingsProvider)['soto-ayam'], 5);

      final ratingA = container.read(effectiveRatingProvider('soto-ayam'));
      expect(ratingA.hasUserRating, isTrue);
      expect(ratingA.userRating, 5);

      // Login User B -> belum pernah beri rating
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'passwordB123',
          );
      expect(container.read(ratingsProvider)['soto-ayam'], isNull);

      final ratingB = container.read(effectiveRatingProvider('soto-ayam'));
      expect(ratingB.hasUserRating, isFalse);
      expect(ratingB.userRating, isNull);

      // User B beri rating 1
      await container.read(ratingsProvider.notifier).rate('soto-ayam', 1);
      expect(container.read(ratingsProvider)['soto-ayam'], 1);

      // Kembali ke User A -> tetap 5
      await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'password123');
      expect(container.read(ratingsProvider)['soto-ayam'], 5);
    });

    test(
      '6. Pengaturan A (darkMode, mealReminder) tidak mengubah pengaturan B',
      () async {
        final container = createContainer();

        // User A set darkMode = true, mealReminder = false
        await container
            .read(authProvider.notifier)
            .register(
              name: 'User A',
              email: 'usera@example.com',
              password: 'password123',
            );
        await container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.dark);
        await container.read(authProvider.notifier).toggleMealReminder();

        expect(container.read(themeModeProvider), ThemeMode.dark);
        expect(container.read(currentUserProvider)?.settings.darkMode, isTrue);
        expect(
          container.read(currentUserProvider)?.settings.mealReminder,
          isFalse,
        );

        // User B register -> default darkMode = false, mealReminder = true
        await container
            .read(authProvider.notifier)
            .register(
              name: 'User B',
              email: 'userb@example.com',
              password: 'passwordB123',
            );

        expect(container.read(themeModeProvider), ThemeMode.light);
        expect(container.read(currentUserProvider)?.settings.darkMode, isFalse);
        expect(
          container.read(currentUserProvider)?.settings.mealReminder,
          isTrue,
        );

        // Kembali ke User A -> tetap dark & reminder false
        await container
            .read(authProvider.notifier)
            .login(email: 'usera@example.com', password: 'password123');

        expect(container.read(themeModeProvider), ThemeMode.dark);
        expect(container.read(currentUserProvider)?.settings.darkMode, isTrue);
        expect(
          container.read(currentUserProvider)?.settings.mealReminder,
          isFalse,
        );
      },
    );

    test('7. Seed demo: total keranjang Rp 18.000, subtotal Rp 9.000 dan Rp 20.000', () async {
      final container = createContainer();

      await container
          .read(authProvider.notifier)
          .login(email: kDemoEmail, password: kDemoPassword);

      final groups = container.read(cartProvider);
      expect(groups.length, 3);

      // Grup 2: Nasi Goreng Spesial -> subtotal Rp 9.000
      final ngsGroup = groups.firstWhere(
        (g) => g.recipeId == 'nasi-goreng-spesial',
      );
      final ngsSubtotal = ngsGroup.items.fold<int>(
        0,
        (sum, item) => sum + item.price,
      );
      expect(ngsSubtotal, 9000);

      // Grup 3: Soto Ayam -> subtotal Rp 20.000
      final saGroup = groups.firstWhere((g) => g.recipeId == 'soto-ayam');
      final saSubtotal = saGroup.items.fold<int>(
        0,
        (sum, item) => sum + item.price,
      );
      expect(saSubtotal, 20000);

      // Total keranjang (checked items) = Rp 18.000
      final checkedTotal = container.read(cartCheckedTotalProvider);
      expect(checkedTotal, 18000);
    });

    test(
      '8. Tutup lalu buka app: session (Ingat saya) dan data tetap ada',
      () async {
        // Sesi 1: Login User A dengan rememberMe = true dan buat data
        final container1 = createContainer();
        await container1
            .read(authProvider.notifier)
            .register(
              name: 'User A',
              email: 'usera@example.com',
              password: 'password123',
              rememberMe: true,
            );
        await container1
            .read(favoritesProvider.notifier)
            .toggle('ayam-kecap-bawang');
        await container1
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.dark);
        container1.dispose();

        // Sesi 2: Buka aplikasi baru dengan box Hive yang sama
        final container2 = createContainer();
        expect(container2.read(currentUserIdProvider), isNotNull);
        expect(
          container2.read(currentUserProvider)?.email,
          'usera@example.com',
        );
        expect(container2.read(favoritesProvider), ['ayam-kecap-bawang']);
        expect(container2.read(themeModeProvider), ThemeMode.dark);

        // Logout dan login kembali tanpa rememberMe
        await container2.read(authProvider.notifier).logout();
        await container2
            .read(authProvider.notifier)
            .login(
              email: 'usera@example.com',
              password: 'password123',
              rememberMe: false,
            );
        container2.dispose();

        // Sesi 3: Buka aplikasi baru -> session harus null karena rememberMe = false
        final container3 = createContainer();
        expect(container3.read(currentUserIdProvider), isNull);
        expect(container3.read(currentUserProvider), isNull);
        container3.dispose();
      },
    );

    test('9. Reset demo: HANYA akun demo yang kembali ke seed, akun A dan B tetap utuh', () async {
      final container = createContainer();

      // Register User A & tambah data
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'password123',
          );
      await container
          .read(favoritesProvider.notifier)
          .toggle('ayam-kecap-bawang');
      await container
          .read(cartProvider.notifier)
          .addCustomItem(name: 'Barang A', qty: '1', price: 5000);

      // Register User B & tambah data
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'passwordB123',
          );
      await container.read(favoritesProvider.notifier).toggle('soto-ayam');

      // Login Akun Demo & ubah datanya (misal hapus 1 favorit demo: nasi-goreng-nusantara)
      await container
          .read(authProvider.notifier)
          .login(email: kDemoEmail, password: kDemoPassword);
      expect(
        container.read(favoritesProvider).contains('nasi-goreng-nusantara'),
        isTrue,
      );
      await container
          .read(favoritesProvider.notifier)
          .remove('nasi-goreng-nusantara');
      expect(
        container.read(favoritesProvider).contains('nasi-goreng-nusantara'),
        isFalse,
      );

      // Jalankan Reset Demo Data
      await resetAllData(container);

      // Akun Demo kembali ke seed awal (nasi-goreng-nusantara ada lagi)
      expect(
        container.read(favoritesProvider).contains('nasi-goreng-nusantara'),
        isTrue,
      );

      // Verifikasi User A: akun dan datanya TETAP UTUH!
      await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'password123');
      expect(container.read(currentUserProvider)?.email, 'usera@example.com');
      expect(container.read(favoritesProvider), ['ayam-kecap-bawang']);
      expect(container.read(cartProvider).isNotEmpty, isTrue);

      // Verifikasi User B: akun dan datanya TETAP UTUH!
      await container
          .read(authProvider.notifier)
          .login(email: 'userb@example.com', password: 'passwordB123');
      expect(container.read(currentUserProvider)?.email, 'userb@example.com');
      expect(container.read(favoritesProvider), ['soto-ayam']);
    });
  });
}
