import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/utils/format_rupiah.dart';
import 'package:foodie/core/utils/week_utils.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/recipe_service.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    // mock storage initialized
    final boxes = await initTestBoxes();

    container = ProviderContainer(
      overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Fase 2 — Data Layer & State Tests', () {
    test(
      'RecipeService.getById ayam-kecap-bawang returns 4 steps & 6 ingredients',
      () async {
        final service = container.read(recipeServiceProvider);
        final recipe = await service.getById('ayam-kecap-bawang');

        expect(recipe, isNotNull);
        expect(recipe!.id, 'ayam-kecap-bawang');
        expect(recipe.title, 'Ayam Kecap Bawang');
        expect(recipe.rating, 4.9);
        expect(recipe.reviews, 184);
        expect(recipe.servings, 2);
        expect(recipe.kcal, 450);
        expect(recipe.difficulty, Difficulty.mudah);
        expect(recipe.timeMin, 25);
        expect(recipe.mainIngredient, 'Ayam');
        expect(recipe.image, isNull);

        // Verifikasi 6 bahan
        expect(recipe.ingredients.length, 6);
        expect(recipe.ingredients[0].name, 'Nasi putih dingin');
        expect(recipe.ingredients[1].name, 'Telur ayam');
        expect(recipe.ingredients[2].name, 'Bawang merah & putih');
        expect(recipe.ingredients[3].name, 'Kecap manis istimewa');
        expect(recipe.ingredients[4].name, 'Cabai rawit merah');
        expect(recipe.ingredients[5].name, 'Minyak goreng / margarin');

        // Verifikasi 4 langkah
        expect(recipe.steps.length, 4);
        expect(recipe.steps[0].title, 'Siapkan Bahan');
        expect(recipe.steps[1].title, 'Tumis Bawang');
        expect(recipe.steps[2].title, 'Masak Ayam');
        expect(recipe.steps[3].title, 'Sajikan Selagi Hangat');
      },
    );

    test('RecipeService list & popular filtering works properly', () async {
      final service = container.read(recipeServiceProvider);

      final all = await service.list();
      expect(all.length >= 10, true);

      final ayamList = await service.list(mainIngredient: 'Ayam');
      expect(ayamList.isNotEmpty, true);
      expect(
        ayamList.every(
          (r) =>
              r.mainIngredient.toLowerCase() == 'ayam' ||
              r.ingredients.any((i) => i.name.toLowerCase().contains('ayam')),
        ),
        true,
      );

      final popularList = await service.popular(limit: 5);
      expect(popularList.length, 5);
      // Urutan popularitas menurun
      expect(
        popularList[0].rating * popularList[0].reviews >=
            popularList[1].rating * popularList[1].reviews,
        true,
      );
    });

    test('Cart initial seed calculations: total unchecked 18.000, subtotals 9.000 & 20.000', () {
      final groups = container.read(cartProvider);

      final ngsGroup = groups.firstWhere(
        (g) => g.name == 'Nasi Goreng Spesial',
      );
      final saGroup = groups.firstWhere((g) => g.name == 'Soto Ayam');
      final customGroup = groups.firstWhere((g) => g.recipeId == null);

      expect(ngsGroup, isNotNull);
      expect(saGroup, isNotNull);
      expect(customGroup.name, 'Belanjaan Kamu Nich');

      // Subtotal "Nasi Goreng Spesial" harus 9000
      final subtotalNgs = container.read(cartSubtotalProvider(ngsGroup.id));
      expect(subtotalNgs, 9000);

      // Subtotal "Soto Ayam" harus 20000
      final subtotalSa = container.read(cartSubtotalProvider(saGroup.id));
      expect(subtotalSa, 20000);

      // Total unchecked di semua grup harus 18000
      final totalUnchecked = container.read(cartTotalUncheckedProvider);
      expect(totalUnchecked, 18000);
    });

    test('Cart addRecipe twice does not duplicate group', () async {
      final cartNotifier = container.read(cartProvider.notifier);
      final service = container.read(recipeServiceProvider);
      final recipe = await service.getById('ayam-kecap-bawang');
      expect(recipe, isNotNull);

      final initialGroupCount = container.read(cartProvider).length;

      // Penambahan pertama
      final status1 = await cartNotifier.addRecipe(recipe!);
      expect(status1, AddRecipeStatus.added);
      expect(container.read(cartProvider).length, initialGroupCount + 1);

      // Penambahan kedua dengan resep yang sama
      final status2 = await cartNotifier.addRecipe(recipe);
      expect(status2, AddRecipeStatus.exists);
      expect(container.read(cartProvider).length, initialGroupCount + 1);

      // Pastikan grup resep ayam-kecap-bawang hanya ada 1
      final ayamGroups = container
          .read(cartProvider)
          .where((g) => g.recipeId == 'ayam-kecap-bawang')
          .toList();
      expect(ayamGroups.length, 1);
    });

    test('Cart item toggling updates cartTotalUnchecked', () async {
      final cartNotifier = container.read(cartProvider.notifier);
      final groups = container.read(cartProvider);
      final customGroup = groups.firstWhere((g) => g.recipeId == null);
      final customItem =
          customGroup.items.first; // Tisu Rp 7.000, initial unchecked

      expect(container.read(cartTotalUncheckedProvider), 18000);

      // Centang item tisu
      await cartNotifier.toggleItem(customGroup.id, customItem.id);

      // Total unchecked berkurang 7000 jadi 11000
      expect(container.read(cartTotalUncheckedProvider), 11000);

      // Batal centang item tisu
      await cartNotifier.toggleItem(customGroup.id, customItem.id);
      expect(container.read(cartTotalUncheckedProvider), 18000);
    });

    test('Favorites provider toggle, has, and count', () async {
      final favNotifier = container.read(favoritesProvider.notifier);

      expect(favNotifier.count, 6);
      expect(favNotifier.has('ayam-kecap-bawang'), true);

      // Toggle off
      final added1 = await favNotifier.toggle('ayam-kecap-bawang');
      expect(added1, false);
      expect(favNotifier.has('ayam-kecap-bawang'), false);
      expect(favNotifier.count, 5);

      // Toggle on
      final added2 = await favNotifier.toggle('ayam-kecap-bawang');
      expect(added2, true);
      expect(favNotifier.has('ayam-kecap-bawang'), true);
      expect(favNotifier.count, 6);
    });

    test('formatRupiah formats currency correctly', () {
      expect(formatRupiah(12000), 'Rp 12.000');
      expect(formatRupiah(4000), 'Rp 4.000');
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(1000000), 'Rp 1.000.000');
    });

    test('WeekUtils calculations and labeling', () {
      final date = DateTime(2026, 11, 18); // Rabu
      final monday = WeekUtils.getWeekStart(date);
      expect(monday.weekday, DateTime.monday);
      expect(WeekUtils.formatDateKey(monday), '2026-11-16');

      final days = WeekUtils.getWeekDays(monday);
      expect(days.length, 7);
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);

      expect(WeekUtils.getWeekLabel(monday, date), 'This Week');
    });
  });
}
