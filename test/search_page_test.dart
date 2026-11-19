import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/search_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/app_bottom_nav.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:foodie/widgets/ui/empty_state.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 6 — Search Page Tests', () {
    testWidgets(
      'SearchPage renders AppHeader, search bar, and Search by Meal tiles',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/search',
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

        // AppHeader & Search Bar
        expect(find.byType(SearchPage), findsOneWidget);
        expect(find.byType(AppHeader), findsOneWidget);
        expect(find.text('Search Recipes...'), findsOneWidget);
        expect(find.byIcon(LucideIcons.slidersHorizontal), findsOneWidget);

        // Search by Meal Section & 6 Tiles
        expect(find.text('Search by Meal'), findsOneWidget);
        expect(find.text('Breakfast'), findsOneWidget);
        expect(find.text('Lunch'), findsOneWidget);
        expect(find.text('Dinner'), findsOneWidget);
        expect(find.text('Snack'), findsOneWidget);
        expect(find.text('Dessert'), findsOneWidget);
        expect(find.text('Drinks'), findsOneWidget);

        // Bottom Nav active tab is Search
        expect(find.byType(AppBottomNav), findsOneWidget);
      },
    );

    testWidgets(
      'Typing in search bar triggers debounced search and shows results',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/search',
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

        // Enter query "ayam"
        await tester.enterText(find.byType(TextField), 'ayam');
        // Wait for debounce (250ms) and service delay (150ms)
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('Hasil pencarian'), findsOneWidget);
        expect(find.text('Bersihkan'), findsOneWidget);
        expect(find.byType(GridRecipeCard), findsWidgets);

        // Clear search
        await tester.tap(find.text('Bersihkan'));
        await tester.pumpAndSettle();

        expect(find.text('Search by Meal'), findsOneWidget);
      },
    );

    testWidgets('Tapping category tile executes search for that meal type', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/search',
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

      // Tap "Breakfast" tile
      await tester.tap(find.text('Breakfast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Hasil pencarian'), findsOneWidget);
      expect(find.byType(GridRecipeCard), findsWidgets);
    });

    testWidgets(
      'Filter bottom sheet opens, applies filter, and updates results',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/search',
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

        // Open filter sheet
        await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
        await tester.pumpAndSettle();

        expect(find.text('Tingkat kesulitan'), findsOneWidget);
        expect(find.text('Waktu masak'), findsOneWidget);
        expect(find.text('Bahan utama'), findsOneWidget);

        // Select 'Mudah'
        await tester.tap(find.text('Mudah'));
        await tester.pumpAndSettle();

        // Tap 'Terapkan'
        await tester.ensureVisible(find.text('Terapkan'));
        await tester.tap(find.text('Terapkan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Hasil pencarian'), findsOneWidget);
        expect(find.byType(GridRecipeCard), findsWidgets);
      },
    );

    testWidgets('Empty search shows EmptyState', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/search',
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

      await tester.enterText(find.byType(TextField), 'zzzzzzzzzzzzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Tidak ada resep ditemukan'), findsOneWidget);
    });

    testWidgets('Meal Plan pick mode displays banner and Tambahkan button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();
      late WidgetRef refHolder;

      final router = createRouter(
        initialLocation: '/search?pick=2026-11-18',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(DateTime(2026, 11, 18)),
          ],
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

      await tester.pumpAndSettle();

      // Banner is shown
      expect(find.textContaining('Pilih menu untuk'), findsOneWidget);

      // Search to show cards
      await tester.enterText(find.byType(TextField), 'nasi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Cards display "Tambahkan" button
      final addButtons = find.text('Tambahkan');
      expect(addButtons, findsWidgets);

      final initialPlanCount = refHolder.read(mealPlanProvider).length;

      // Tap "Tambahkan"
      await tester.tap(addButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Toast appears
      expect(
        find.text('Menu berhasil ditambahkan ke Meal Plan'),
        findsOneWidget,
      );

      final updatedPlanCount = refHolder.read(mealPlanProvider).length;
      expect(updatedPlanCount, initialPlanCount + 1);

      // Advance timers for toast
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
    });
  });
}
