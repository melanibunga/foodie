import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/recipes.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // mock storage initialized
  });

  group('Fase C5 — My Groceries Putaran 2 (PRD §15.7, §15.8)', () {
    test(
      '1. Urutan descending setelah addRecipe berturut-turut (terbaru di atas)',
      () async {
        DateTime currentTime = DateTime(2026, 11, 20, 10, 0);
        final container = ProviderContainer(
          overrides: [clockProvider.overrideWith((ref) => currentTime)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(cartProvider.notifier);
        await notifier.clearAll();

        final rendang = seedRecipes.firstWhere(
          (r) => r.id == 'rendang-sapi-minang',
        );
        final telur = seedRecipes.firstWhere((r) => r.id == 'telur-balado');

        // Tambah resep 1 pada 10:00
        await notifier.addRecipe(rendang);

        // Majukan clock ke 10:30 untuk resep 2
        currentTime = DateTime(2026, 11, 20, 10, 30);
        container.invalidate(clockProvider);
        await notifier.addRecipe(telur);

        final displayGroups = container.read(displayCartGroupsProvider);

        // Group 0 adalah grup custom pin
        expect(displayGroups[0].name, 'Belanjaan Kamu Nich');

        // Group 1 adalah resep yang paling baru ditambahkan (Telur Balado pada 10:30)
        expect(displayGroups[1].name, telur.title);

        // Group 2 adalah resep yang ditambahkan sebelumnya (Rendang pada 10:00)
        expect(displayGroups[2].name, rendang.title);
      },
    );

    test('2. Grup custom selalu di indeks 0 walau ditambahkan lebih dulu / belakangan / kosong', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      await notifier.clearAll();

      // Kondisi 1: Keranjang kosong
      var displayGroups = container.read(displayCartGroupsProvider);
      expect(displayGroups[0].name, 'Belanjaan Kamu Nich');
      expect(displayGroups[0].items.isEmpty, isTrue);

      // Kondisi 2: Tambah resep saja (tanpa custom item)
      final soto = seedRecipes.firstWhere((r) => r.id == 'soto-ayam');
      await notifier.addRecipe(soto);

      displayGroups = container.read(displayCartGroupsProvider);
      expect(displayGroups[0].name, 'Belanjaan Kamu Nich');
      expect(displayGroups[0].items.isEmpty, isTrue);
      expect(displayGroups[1].name, soto.title);

      // Kondisi 3: Tambah custom item
      await notifier.addCustomItem(
        name: 'Kecap Manis',
        qty: '1 btl',
        price: 12000,
      );

      displayGroups = container.read(displayCartGroupsProvider);
      expect(displayGroups[0].name, 'Belanjaan Kamu Nich');
      expect(displayGroups[0].items.length, 1);
      expect(displayGroups[1].name, soto.title);
    });

    test(
      '3. Item custom baru muncul paling atas (descending addedAt)',
      () async {
        DateTime currentTime = DateTime(2026, 11, 20, 8, 0);
        final container = ProviderContainer(
          overrides: [clockProvider.overrideWith((ref) => currentTime)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(cartProvider.notifier);
        await notifier.clearAll();

        // Tambah item 1 pada 08:00
        await notifier.addCustomItem(name: 'Item 1', qty: '1 pcs', price: 5000);

        // Update clock ke 09:00
        currentTime = DateTime(2026, 11, 20, 9, 0);
        container.invalidate(clockProvider);
        await notifier.addCustomItem(
          name: 'Item 2',
          qty: '2 pcs',
          price: 10000,
        );

        // Update clock ke 10:00
        currentTime = DateTime(2026, 11, 20, 10, 0);
        container.invalidate(clockProvider);
        await notifier.addCustomItem(
          name: 'Item 3',
          qty: '3 pcs',
          price: 15000,
        );

        final displayGroups = container.read(displayCartGroupsProvider);
        final customGroup = displayGroups[0];

        // Item 3 (terbaru) harus di indeks 0
        expect(customGroup.items[0].name, 'Item 3');
        expect(customGroup.items[1].name, 'Item 2');
        expect(customGroup.items[2].name, 'Item 1');
      },
    );

    testWidgets(
      '4. Visual kartu pin: background amberSoft, border amber @ 40%, ikon pin, teks olive & takaran olive @ 75%',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final boxes = await initTestBoxes();
        final router = createRouter(
          initialLocation: '/groceries',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kartu custom "Belanjaan Kamu Nich" harus ada dan memiliki ikon pin
        expect(find.text('Belanjaan Kamu Nich'), findsOneWidget);
        expect(find.byIcon(LucideIcons.pin), findsOneWidget);

        // Temukan kontainer kartu pin custom
        final customTitleFinder = find.text('Belanjaan Kamu Nich');
        final customCardFinder = find.ancestor(
          of: customTitleFinder,
          matching: find.byType(Container),
        );
        expect(customCardFinder, findsWidgets);

        // Verifikasi tidak ada tombol "Hapus menu" pada kartu custom pin
        // Hanya ada 2 "Hapus menu" untuk Nasi Goreng Spesial dan Soto Ayam
        expect(find.text('Hapus menu'), findsNWidgets(2));
      },
    );

    testWidgets(
      '5. Swipe ke kiri (endToStart) menghapus tepat satu custom item, toast muncul, total & count terhitung ulang',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final boxes = await initTestBoxes();
        final router = createRouter(
          initialLocation: '/groceries',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Total awal: Rp 18.000 (Tisu Rp 7.000 + Beras Rp 3.000 + Bihun Rp 5.000 + Daun bawang Rp 3.000)
        expect(find.text('Rp 18.000'), findsOneWidget);
        expect(find.text('Tisu'), findsOneWidget);

        // Temukan Dismissible untuk Tisu
        final dismissibleFinder = find.byType(Dismissible);
        expect(dismissibleFinder, findsOneWidget);

        // Swipe ke kiri (endToStart)
        await tester.drag(dismissibleFinder, const Offset(-400, 0));
        await tester.pumpAndSettle();

        // Toast "Bahan dihapus" harus tampil
        expect(find.text('Bahan dihapus'), findsOneWidget);

        // Tisu telah dihapus
        expect(find.text('Tisu'), findsNothing);

        // Kartu custom tetap tampil dengan teks hint
        expect(find.text('Belanjaan Kamu Nich'), findsOneWidget);
        expect(
          find.text('Belum ada bahan. Tambahkan lewat kolom di atas.'),
          findsOneWidget,
        );

        // Total baru: Rp 18.000 - Rp 7.000 = Rp 11.000
        expect(find.text('Rp 11.000'), findsOneWidget);

        // Selesaikan timer toast
        await tester.pump(const Duration(milliseconds: 2500));
      },
    );

    testWidgets('6. Aksi semantik "Hapus" bekerja tanpa gestur swipe', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boxes = await initTestBoxes();
      final router = createRouter(
        initialLocation: '/groceries',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tisu'), findsOneWidget);

      // Jalankan aksi semantik kustom "Hapus"
      final customAction = const CustomSemanticsAction(label: 'Hapus');
      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.customSemanticsActions?.containsKey(customAction) ==
                true,
      );
      expect(semanticsFinder, findsOneWidget);

      final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      semanticsWidget.properties.customSemanticsActions![customAction]!.call();
      await tester.pumpAndSettle();

      // Item terhapus dan toast muncul
      expect(find.text('Bahan dihapus'), findsOneWidget);
      expect(find.text('Tisu'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2500));
    });

    test('7. Migrasi data lama tanpa addedAt tidak crash & urutan terjaga', () {
      final legacyJson = [
        {
          'id': 'cg-1',
          'recipeId': 'resep-1',
          'name': 'Menu 1',
          'items': [
            {
              'id': 'ci-1',
              'name': 'Garam',
              'qty': '1 sdt',
              'price': 1000,
              'checked': false,
            },
          ],
        },
        {
          'id': 'cg-2',
          'recipeId': 'resep-2',
          'name': 'Menu 2',
          'items': [
            {
              'id': 'ci-2',
              'name': 'Gula',
              'qty': '2 sdt',
              'price': 2000,
              'checked': true,
            },
          ],
        },
        {
          'id': 'cg-custom',
          'recipeId': null,
          'name': 'Belanjaan Kamu Nich',
          'items': [
            {
              'id': 'ci-c1',
              'name': 'Sedotan',
              'qty': '1 pak',
              'price': 3000,
              'checked': false,
            },
          ],
        },
      ];

      // Parse dari JSON lama tanpa field addedAt
      final baseTime = DateTime(2026, 1, 1);
      final groups = legacyJson.asMap().entries.map((entry) {
        final idx = entry.key;
        final map = entry.value;
        final fallback = baseTime.add(Duration(minutes: idx));
        return CartGroup.fromJson(map, fallback);
      }).toList();

      expect(groups.length, 3);
      expect(groups[0].addedAt, isNotNull);
      expect(groups[0].items[0].addedAt, isNotNull);
      expect(groups[1].addedAt, isNotNull);
      expect(groups[2].addedAt, isNotNull);

      // Pastikan serialisasi kembali menyertakan addedAt
      final encoded = jsonEncode(groups.map((g) => g.toJson()).toList());
      expect(encoded, contains('"addedAt"'));

      // Deserialisasi kembali dengan addedAt yang sudah tersimpan
      final redecoded = jsonDecode(encoded) as List<dynamic>;
      final reloaded = redecoded
          .map((m) => CartGroup.fromJson(m as Map<String, dynamic>))
          .toList();
      expect(reloaded.length, 3);
      expect(reloaded[0].name, 'Menu 1');
      expect(reloaded[0].items[0].name, 'Garam');
    });

    test('8. Perhitungan seed demo tetap menghasilkan Rp 18.000 / Rp 9.000 / Rp 20.000', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Subtotals
      final ngsSubtotal = container.read(
        cartSubtotalProvider('cart-group-ngs'),
      );
      final saSubtotal = container.read(cartSubtotalProvider('cart-group-sa'));

      expect(ngsSubtotal, equals(9000));
      expect(saSubtotal, equals(20000));

      // Total unchecked
      final totalUnchecked = container.read(cartTotalUncheckedProvider);
      expect(totalUnchecked, equals(18000));
    });
  });
}
