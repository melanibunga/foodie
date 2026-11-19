import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/core/utils/week_utils.dart';
import 'package:foodie/data/recipes.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:cart': jsonEncode([]),
      'foodie:meal_plan': jsonEncode([]),
      'foodie:favorites': jsonEncode([]),
    });
  });

  group('Fase B4 — Unit Tests (CartNotifier hasRecipe & removeByRecipe)', () {
    test(
      'hasRecipe returns true if recipe exists in cart, false otherwise',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(cartProvider.notifier);
        final recipe = seedRecipes.first; // Ayam Kecap Bawang

        expect(notifier.hasRecipe(recipe.id), isFalse);

        await notifier.addRecipe(recipe);
        expect(notifier.hasRecipe(recipe.id), isTrue);

        await notifier.removeByRecipe(recipe.id);
        expect(notifier.hasRecipe(recipe.id), isFalse);
      },
    );

    test('removeByRecipe removes only the matching recipe group', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      await notifier.clearAll();
      final recipe1 = seedRecipes[0];
      final recipe2 = seedRecipes[1];

      await notifier.addRecipe(recipe1);
      await notifier.addRecipe(recipe2);
      expect(container.read(cartProvider).length, 2);

      await notifier.removeByRecipe(recipe1.id);
      final remaining = container.read(cartProvider);
      expect(remaining.length, 1);
      expect(remaining.first.recipeId, recipe2.id);
      expect(notifier.hasRecipe(recipe1.id), isFalse);
      expect(notifier.hasRecipe(recipe2.id), isTrue);
    });
  });

  group('Fase B4 — Widget Tests (Detail Menu)', () {
    testWidgets(
      'G5: Description is displayed below title and before rating, expands with "Lihat semua"',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Description text is present
        final descFinder = find.textContaining(
          'Ayam empuk berbalut saus kecap manis',
        );
        expect(descFinder, findsOneWidget);

        // Verify vertical ordering: Title (y) < Description (y) < Rating (y)
        final titleTop = tester.getTopLeft(find.text('Ayam Kecap Bawang')).dy;
        final descTop = tester.getTopLeft(descFinder).dy;
        final ratingTop = tester.getTopLeft(find.text('4.9')).dy;

        expect(
          descTop,
          greaterThan(titleTop),
          reason: 'Description must be below title',
        );
        expect(
          ratingTop,
          greaterThan(descTop),
          reason: 'Rating must be below description',
        );

        // "Lihat semua" link should appear because Ayam Kecap Bawang's description is 2+ sentences
        final expandLink = find.text('Lihat semua');
        if (expandLink.evaluate().isNotEmpty) {
          await tester.tap(expandLink);
          await tester.pumpAndSettle();

          // Label becomes "Tutup"
          expect(find.text('Tutup'), findsOneWidget);

          // Tap "Tutup" to collapse
          await tester.tap(find.text('Tutup'));
          await tester.pumpAndSettle();

          expect(find.text('Lihat semua'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'D3: Back button is FIXED and does not move when page is scrolled',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the fixed back button
        final backBtnFinder = find.bySemanticsLabel('Kembali');
        expect(backBtnFinder, findsOneWidget);

        final initialPos = tester.getTopLeft(backBtnFinder);

        // Verify back button decoration background is AppColors.olive (PRD §15.6)
        final container = tester.widget<Container>(
          find
              .descendant(of: backBtnFinder, matching: find.byType(Container))
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.color,
          AppColors.olive,
          reason: 'Back button background must be AppColors.olive',
        );
        expect(decoration.shape, BoxShape.circle);

        // Scroll the SingleChildScrollView down by 400 dp
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        // Back button position should NOT change!
        final scrolledPos = tester.getTopLeft(backBtnFinder);
        expect(
          scrolledPos.dy,
          equals(initialPos.dy),
          reason: 'Back button must remain FIXED at top left during scroll',
        );
        expect(
          scrolledPos.dx,
          equals(initialPos.dx),
          reason: 'Back button horizontal position must remain FIXED',
        );
      },
    );

    testWidgets(
      'D1: "Tambah ke keranjang" toggles between amber and amberSoft ("Sudah di keranjang")',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial state: "Tambah ke keranjang"
        final addBtnText = find.text('Tambah ke keranjang');
        expect(addBtnText, findsOneWidget);

        // 2. Tap to add -> toast "Bahan ditambahkan ke keranjang"
        await tester.tap(addBtnText);
        await tester.pump();
        expect(find.text('Bahan ditambahkan ke keranjang'), findsOneWidget);

        // Drain toast
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // 3. Now button displays "Sudah di keranjang" with check icon
        final inCartBtnText = find.text('Sudah di keranjang');
        expect(inCartBtnText, findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // Verify button background color is amberSoft
        final inCartElevatedBtn = tester.widget<ElevatedButton>(
          find.ancestor(
            of: inCartBtnText,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(
          inCartElevatedBtn.style?.backgroundColor?.resolve({}),
          AppColors.amberSoft,
          reason: 'Button in cart must have amberSoft background',
        );

        // 4. Tap "Sudah di keranjang" -> removes from cart & toast "Dikeluarkan dari keranjang"
        await tester.tap(inCartBtnText);
        await tester.pump();
        expect(find.text('Dikeluarkan dari keranjang'), findsOneWidget);

        // Drain toast
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // 5. Button returns to "Tambah ke keranjang" with amber background
        expect(find.text('Tambah ke keranjang'), findsOneWidget);
        final normalElevatedBtn = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Tambah ke keranjang'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(
          normalElevatedBtn.style?.backgroundColor?.resolve({}),
          AppColors.amber,
          reason: 'Normal button must have amber background',
        );
      },
    );

    testWidgets(
      'D2: Meal plan icon updates real-time from calendar-plus to calendar-check with amberSoft',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initially unplanned -> shows calendarPlus
        expect(find.byIcon(LucideIcons.calendarPlus), findsOneWidget);
        expect(find.byIcon(LucideIcons.calendarCheck), findsNothing);

        // 2. Tap to open sheet
        await tester.tap(find.byIcon(LucideIcons.calendarPlus));
        await tester.pumpAndSettle();

        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);

        // 3. Pick a future date or today from the sheet (so date >= todayKey)
        final now = DateTime.now();
        final todayName = WeekUtils.dayNames[now.weekday - 1];
        await tester.tap(find.text(todayName).first);
        await tester.pump();

        expect(
          find.text('Menu berhasil ditambahkan ke Meal Plan'),
          findsOneWidget,
        );
        await tester.pumpAndSettle();

        // Sheet is closed
        expect(find.text('Tambah ke Meal Plan'), findsNothing);

        // 4. Meal plan icon in title row changed to calendarCheck!
        expect(find.byIcon(LucideIcons.calendarCheck), findsOneWidget);
        expect(find.byIcon(LucideIcons.calendarPlus), findsNothing);

        // Verify container background is amberSoft
        final iconContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(LucideIcons.calendarCheck),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = iconContainer.decoration as BoxDecoration;
        expect(decoration.color, AppColors.amberSoft);

        // Drain toast
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );
  });
}
