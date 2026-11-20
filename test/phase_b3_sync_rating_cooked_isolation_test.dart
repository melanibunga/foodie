import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cooked_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/ratings_provider.dart';
import 'package:foodie/providers/recipes_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late FoodieBoxes boxes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('foodie_b3_test_');
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

  group(
    'Fase B3 — Sinkronisasi Rating, Riwayat Dimasak, dan Audit Isolasi',
    () {
      test('1. Skenario dua akun: A masak + rating 5, B masak + rating 3 -> ratingSummary menggabungkan keduanya, riwayat dimasak terpisah', () async {
        final container = createContainer();

        // Register & Login User A
        await container
            .read(authProvider.notifier)
            .register(
              name: 'User A',
              email: 'usera@example.com',
              password: 'passwordA123',
            );
        final userAId = container.read(currentUserIdProvider)!;

        const recipeId = 'ayam-kecap-bawang';
        final initialSummary = container.read(ratingSummaryProvider(recipeId));
        expect(initialSummary.hasUserRating, isFalse);
        final double baseRating = initialSummary.rating;
        final int baseReviews = initialSummary.reviews;

        // User A memasak resep dan memberi rating 5
        await container
            .read(cookedProvider.notifier)
            .add(recipeId, '2026-11-20', 5);
        await container.read(ratingsProvider.notifier).rate(recipeId, 5);

        // Verifikasi data User A
        expect(container.read(cookedCountProvider), 1);
        final cookedListA = container.read(cookedProvider);
        expect(cookedListA.length, 1);
        expect(cookedListA.first.recipeId, recipeId);
        expect(cookedListA.first.rating, 5);
        expect(container.read(userRatingProvider(recipeId)), 5);

        // Verifikasi ratingSummary setelah A memberi rating 5
        // Rumus: avg = (base*dummyCount + 5)/(dummyCount + 1), reviews = dummyCount + 1
        final summaryAfterA = container.read(ratingSummaryProvider(recipeId));
        expect(summaryAfterA.hasUserRating, isTrue);
        expect(summaryAfterA.userRating, 5);
        expect(summaryAfterA.reviews, baseReviews + 1);
        final expectedRatingA = double.parse(
          (((baseRating * baseReviews) + 5) / (baseReviews + 1))
              .toStringAsFixed(1),
        );
        expect(summaryAfterA.rating, expectedRatingA);

        // User A logout -> User B Register & Login
        await container.read(authProvider.notifier).logout();
        await container
            .read(authProvider.notifier)
            .register(
              name: 'User B',
              email: 'userb@example.com',
              password: 'passwordB123',
            );
        final userBId = container.read(currentUserIdProvider)!;
        expect(userBId, isNot(equals(userAId)));

        // Verifikasi riwayat cooked User B masih KOSONG (terisolasi)
        expect(container.read(cookedCountProvider), 0);
        expect(container.read(cookedProvider), isEmpty);
        expect(container.read(userRatingProvider(recipeId)), isNull);

        // ratingSummary dilihat oleh User B tetap menampilkan ulasan dari A, tapi userRating = null
        final summarySeenByB = container.read(ratingSummaryProvider(recipeId));
        expect(summarySeenByB.reviews, baseReviews + 1);
        expect(summarySeenByB.hasUserRating, isFalse);
        expect(summarySeenByB.userRating, isNull);

        // User B memasak resep yang sama dan memberi rating 3
        await container
            .read(cookedProvider.notifier)
            .add(recipeId, '2026-11-21', 3);
        await container.read(ratingsProvider.notifier).rate(recipeId, 3);

        // Verifikasi data User B
        expect(container.read(cookedCountProvider), 1);
        final cookedListB = container.read(cookedProvider);
        expect(cookedListB.length, 1);
        expect(cookedListB.first.recipeId, recipeId);
        expect(cookedListB.first.rating, 3);
        expect(container.read(userRatingProvider(recipeId)), 3);

        // ratingSummary sekarang menggabungkan rating A (5) dan B (3)
        // Rumus: avg = (base*dummyCount + (5 + 3)) / (dummyCount + 2); reviews = dummyCount + 2
        final summaryAfterB = container.read(ratingSummaryProvider(recipeId));
        expect(summaryAfterB.hasUserRating, isTrue);
        expect(summaryAfterB.userRating, 3);
        expect(summaryAfterB.reviews, baseReviews + 2);
        final expectedRatingBoth = double.parse(
          (((baseRating * baseReviews) + (5 + 3)) / (baseReviews + 2))
              .toStringAsFixed(1),
        );
        expect(summaryAfterB.rating, expectedRatingBoth);

        // Login kembali sebagai User A
        await container.read(authProvider.notifier).logout();
        await container
            .read(authProvider.notifier)
            .login(email: 'usera@example.com', password: 'passwordA123');

        // Verifikasi User A melihat rating gabungan dengan userRating miliknya (5)
        final summarySeenByA = container.read(ratingSummaryProvider(recipeId));
        expect(summarySeenByA.reviews, baseReviews + 2);
        expect(summarySeenByA.rating, expectedRatingBoth);
        expect(summarySeenByA.hasUserRating, isTrue);
        expect(summarySeenByA.userRating, 5);

        // Riwayat dimasak User A tetap 1 dan milik A
        expect(container.read(cookedCountProvider), 1);
        expect(container.read(cookedProvider).first.date, '2026-11-20');
        expect(container.read(cookedProvider).first.rating, 5);
      });

      test('2. Memasak resep yang sama berulang tidak menduplikasi baris di halaman Dimasak (byRecipe), menampilkan tanggal terakhir', () async {
        final container = createContainer();

        await container
            .read(authProvider.notifier)
            .register(
              name: 'User Repeat Cook',
              email: 'repeat@example.com',
              password: 'password123',
            );

        const recipeId = 'soto-ayam';

        // Masak pertama: 2026-11-18
        await container
            .read(cookedProvider.notifier)
            .add(recipeId, '2026-11-18', 4);
        // Masak kedua: 2026-11-19
        await container
            .read(cookedProvider.notifier)
            .add(recipeId, '2026-11-19');
        // Masak ketiga: 2026-11-20
        await container
            .read(cookedProvider.notifier)
            .add(recipeId, '2026-11-20', 5);

        // Total riwayat adalah 3 entri
        expect(container.read(cookedCountProvider), 3);
        expect(container.read(cookedProvider).length, 3);

        // Di halaman Dimasak (byRecipe), resep unik hanya 1 baris
        final summaries = container.read(cookedSummaryProvider);
        expect(summaries.length, 1);
        expect(container.read(cookedUniqueCountProvider), 1);

        final summary = summaries.first;
        expect(summary.recipeId, recipeId);
        expect(summary.count, 3);
        expect(summary.latestDate, '2026-11-20');
        expect(summary.latestRating, 5);
      });

      test('3. Isolasi data E2E: User A hapus favorit, meal plan, resep buatan -> User B tidak terpengaruh', () async {
        final container = createContainer();

        // User A setup
        await container
            .read(authProvider.notifier)
            .register(
              name: 'User A',
              email: 'usera2@example.com',
              password: 'password123',
            );
        await container
            .read(favoritesProvider.notifier)
            .toggle('ayam-kecap-bawang');
        await container
            .read(mealPlanProvider.notifier)
            .add('2026-12-01', 'ayam-kecap-bawang');
        const recipeA = Recipe(
          id: 'recipe-a-custom',
          title: 'Resep A Spesial',
          description: 'Resep A',
          category: 'Ayam & Bebek',
          cuisine: 'Jawa',
          meal: MealType.dinner,
          mainIngredient: 'Ayam',
          rating: 5.0,
          reviews: 1,
          timeMin: 30,
          servings: 2,
          kcal: 300,
          difficulty: Difficulty.mudah,
          ingredients: [],
          steps: [],
        );
        await container.read(recipesProvider.notifier).addCustomRecipe(recipeA);

        // User B setup
        await container
            .read(authProvider.notifier)
            .register(
              name: 'User B',
              email: 'userb2@example.com',
              password: 'password123',
            );
        await container.read(favoritesProvider.notifier).toggle('soto-ayam');
        await container
            .read(mealPlanProvider.notifier)
            .add('2026-12-02', 'soto-ayam');
        const recipeB = Recipe(
          id: 'recipe-b-custom',
          title: 'Resep B Spesial',
          description: 'Resep B',
          category: 'Sup & Soto',
          cuisine: 'Madura',
          meal: MealType.lunch,
          mainIngredient: 'Ayam',
          rating: 5.0,
          reviews: 1,
          timeMin: 45,
          servings: 4,
          kcal: 350,
          difficulty: Difficulty.sedang,
          ingredients: [],
          steps: [],
        );
        await container.read(recipesProvider.notifier).addCustomRecipe(recipeB);

        // Login A dan hapus semua datanya
        await container
            .read(authProvider.notifier)
            .login(email: 'usera2@example.com', password: 'password123');
        await container
            .read(favoritesProvider.notifier)
            .remove('ayam-kecap-bawang');
        final aMealPlan = container.read(mealPlanProvider).first;
        await container.read(mealPlanProvider.notifier).remove(aMealPlan.id);
        await container
            .read(recipesProvider.notifier)
            .removeCustomRecipe('recipe-a-custom');

        expect(container.read(favoritesProvider), isEmpty);
        expect(container.read(mealPlanProvider), isEmpty);
        expect(container.read(myRecipesProvider), isEmpty);

        // Login B dan verifikasi semua datanya tetap utuh
        await container
            .read(authProvider.notifier)
            .login(email: 'userb2@example.com', password: 'password123');
        expect(container.read(favoritesProvider), ['soto-ayam']);
        expect(container.read(mealPlanProvider).length, 1);
        expect(container.read(mealPlanProvider).first.recipeId, 'soto-ayam');
        expect(container.read(myRecipesProvider).length, 1);
        expect(container.read(myRecipesProvider).first.id, 'recipe-b-custom');
      });
    },
  );
}
