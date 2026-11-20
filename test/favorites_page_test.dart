import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/favorites_page.dart';
import 'package:foodie/pages/home_page.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:foodie/widgets/ui/app_badge.dart';
import 'package:foodie/widgets/ui/app_chip.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase 9 — Favorites Page (/favorites) Tests', () {
    testWidgets(
      'FavoritesPage renders header, badge count, search, chips, and sticky button',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/favorites',
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

        // Page rendered
        expect(find.byType(FavoritesPage), findsOneWidget);

        // Title & Subtitle
        expect(find.text('Menu Favoritmu'), findsOneWidget);
        expect(find.text('Simpan idenya, masak kapan saja.'), findsOneWidget);

        // Badge amber 42x42 with count (6 from seed)
        expect(find.byType(AppBadge), findsOneWidget);
        expect(find.text('6'), findsOneWidget);

        // Search bar
        expect(find.text('Cari nama menu favorit...'), findsOneWidget);

        // Filter bahan utama label & chips
        expect(find.text('Filter bahan utama'), findsOneWidget);
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Ayam'), findsOneWidget);

        // Grid of FavoriteRecipeCard
        expect(find.byType(FavoriteRecipeCard), findsWidgets);
        expect(find.text('Ayam Kecap Bawang'), findsOneWidget);

        // Sticky button "Kembali Ke Beranda"
        final stickyBtn = find.text('Kembali Ke Beranda');
        expect(stickyBtn, findsOneWidget);

        // Verify sticky button width & height (exact 355x48)
        final btnFinder = find.widgetWithText(
          ElevatedButton,
          'Kembali Ke Beranda',
        );
        final btnSize = tester.getSize(btnFinder);
        expect(btnSize.height, equals(48.0));
        expect(btnSize.width, equals(355.0));
      },
    );

    testWidgets('Filter by main ingredient chip filters recipes correctly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/favorites',
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

      // Tap "Ayam" filter chip
      await tester.tap(find.widgetWithText(AppChip, 'Ayam'));
      await tester.pumpAndSettle();

      // Should show Ayam recipes and hide non-ayam recipes
      expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
      expect(find.text('Soto Ayam'), findsOneWidget);
      expect(find.text('Tumis Kangkung'), findsNothing);

      // Tap "Semua" to reset
      await tester.tap(find.widgetWithText(AppChip, 'Semua'));
      await tester.pumpAndSettle();

      expect(find.text('Tumis Kangkung'), findsOneWidget);
    });

    testWidgets('Search query filters favorite recipes', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/favorites',
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

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Kangkung');
      await tester.pumpAndSettle();

      expect(find.text('Tumis Kangkung'), findsOneWidget);
      expect(find.text('Ayam Kecap Bawang'), findsNothing);

      // Tap clear icon (x)
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
    });

    testWidgets(
      'Trash icon opens confirmation dialog; confirming removes item and updates badge count',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();
        late WidgetRef refHolder;

        final router = createRouter(
          initialLocation: '/favorites',
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

        expect(refHolder.read(favoriteCountProvider), equals(6));

        // Tap trash icon on the first recipe card (Ayam Kecap Bawang)
        final trashBtn = find.byIcon(LucideIcons.trash2).first;
        await tester.tap(trashBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog should appear
        expect(find.text('Hapus dari favorit?'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);

        // Tap "Batal"
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        // Item should still be present, count still 6
        expect(refHolder.read(favoriteCountProvider), equals(6));

        // Tap trash again
        await tester.tap(trashBtn);
        await tester.pumpAndSettle();

        // Tap "Hapus"
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Count drops to 5
        expect(refHolder.read(favoriteCountProvider), equals(5));
        expect(find.text('5'), findsOneWidget);

        // Drain toast timer (2.2s)
        await tester.pump(const Duration(milliseconds: 2500));
      },
    );

    testWidgets('Tapping a favorite card navigates to recipe detail page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/favorites',
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

      // Tap first recipe title
      await tester.tap(find.text('Ayam Kecap Bawang'));
      await tester.pumpAndSettle();

      // Should be at RecipeDetailPage
      expect(find.byType(RecipeDetailPage), findsOneWidget);
    });

    testWidgets('Tapping sticky button Kembali Ke Beranda navigates to /home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/favorites',
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

      // Tap "Kembali Ke Beranda"
      await tester.tap(find.text('Kembali Ke Beranda'));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
