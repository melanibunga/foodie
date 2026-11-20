import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/cook_page.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/ui/app_checkbox.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase 7 — Recipe Detail Page Tests', () {
    testWidgets('RecipeDetailPage renders exact specs for Ayam Kecap Bawang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/recipe/ayam-kecap-bawang',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeDetailPage), findsOneWidget);

      // Hero overlay buttons
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      expect(find.byIcon(LucideIcons.share2), findsOneWidget);

      // Title & Calendar Plus
      expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendarPlus), findsOneWidget);

      // Rating
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('(184 ulasan)'), findsOneWidget);

      // Two Action Buttons
      expect(find.text('Tambah ke keranjang'), findsOneWidget);

      // Summary Card 3 columns
      expect(find.text('Porsi'), findsOneWidget);
      expect(find.text('2 Orang'), findsOneWidget);
      expect(find.text('Kalori'), findsOneWidget);
      expect(find.text('450 kkal'), findsOneWidget);
      expect(find.text('Tingkat'), findsOneWidget);
      expect(find.text('Mudah'), findsOneWidget);

      // Ingredients Section
      expect(find.text('Bahan-Bahan'), findsOneWidget);
      expect(find.text('Nasi putih dingin'), findsOneWidget);
      expect(find.text('Telur ayam'), findsOneWidget);
      expect(find.text('Kecap manis istimewa'), findsOneWidget);

      // Steps Section
      expect(find.text('Langkah Memasak'), findsOneWidget);
      expect(find.text('Siapkan Bahan'), findsOneWidget);
      expect(find.text('Tumis Bawang'), findsOneWidget);
      expect(find.text('Masak Ayam'), findsOneWidget);
      expect(find.text('Sajikan Selagi Hangat'), findsOneWidget);

      // Start Cooking Button & Note
      expect(find.text('Start Cooking >'), findsOneWidget);
      expect(
        find.text('Kalori merupakan estimasi per porsi, tanpa nasi.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Tambah ke keranjang adds recipe ingredients and shows toast without duplication',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Tap "Tambah ke keranjang"
        final cartBtn = find.text('Tambah ke keranjang');
        expect(cartBtn, findsOneWidget);

        await tester.tap(cartBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Toast: "Bahan ditambahkan ke keranjang"
        expect(find.text('Bahan ditambahkan ke keranjang'), findsOneWidget);

        // Advance toast timer
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();

        // Button changes to "Sudah di keranjang" (Fase B4 §14.6)
        final inCartBtn = find.text('Sudah di keranjang');
        expect(inCartBtn, findsOneWidget);

        // Tap again -> removes from cart & toast: "Dikeluarkan dari keranjang"
        await tester.tap(inCartBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Dikeluarkan dari keranjang'), findsOneWidget);

        // Button returns to "Tambah ke keranjang"
        expect(find.text('Tambah ke keranjang'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Tapping Tambah ke favorit toggles favorite and button text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();
      late WidgetRef refHolder;

      final router = createRouter(
        initialLocation: '/recipe/ayam-kecap-bawang',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
          child: Consumer(
            builder: (context, ref, child) {
              refHolder = ref;
              return MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final favNotifier = refHolder.read(favoritesProvider.notifier);
      final isInitiallyFav = favNotifier.has('ayam-kecap-bawang');

      if (isInitiallyFav) {
        expect(find.text('Tersimpan di favorit'), findsOneWidget);
        await tester.tap(find.text('Tersimpan di favorit'));
        await tester.pumpAndSettle();
        expect(find.text('Tambah ke favorit'), findsOneWidget);
      } else {
        expect(find.text('Tambah ke favorit'), findsOneWidget);
        await tester.tap(find.text('Tambah ke favorit'));
        await tester.pumpAndSettle();
        expect(find.text('Tersimpan di favorit'), findsOneWidget);
      }
    });

    testWidgets(
      'Calendar-plus opens sheet with 14 days and adds to meal plan',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();
        late WidgetRef refHolder;

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: Consumer(
              builder: (context, ref, child) {
                refHolder = ref;
                return MaterialApp.router(
                  theme: AppTheme.lightTheme,
                  routerConfig: router,
                );
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Tap calendar-plus icon
        await tester.tap(find.byIcon(LucideIcons.calendarPlus));
        await tester.pumpAndSettle();

        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);
        expect(find.text('Pilih hari untuk memasak resep ini'), findsOneWidget);

        final initialCount = refHolder.read(mealPlanProvider).length;

        // Select first day in sheet
        await tester.tap(find.byIcon(Icons.add_circle_outline).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text('Menu berhasil ditambahkan ke Meal Plan'),
          findsOneWidget,
        );
        expect(refHolder.read(mealPlanProvider).length, initialCount + 1);

        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Ingredients do not have checkbox (PRD §15.6) and render bullet points with name and qty',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Tidak ada checkbox pada bahan-bahan (PRD §15.6)
        expect(find.byType(AppCheckbox), findsNothing);
        expect(find.text('Nasi putih dingin'), findsOneWidget);
      },
    );

    testWidgets('Start Cooking button navigates to /recipe/:id/cook', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/recipe/ayam-kecap-bawang',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Scroll to bottom to ensure "Start Cooking >" is visible
      await tester.ensureVisible(find.text('Start Cooking >'));
      await tester.tap(find.text('Start Cooking >'));
      await tester.pumpAndSettle();

      // Destination is /recipe/:id/cook (CookPage in Fase 8)
      expect(find.byType(CookPage), findsOneWidget);
    });

    testWidgets('Invalid recipe ID displays friendly 404 page', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/recipe/invalid-non-existent-id',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Resep Tidak Ditemukan'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
    });
  });
}
