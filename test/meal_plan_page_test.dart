import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/meal_plan_page.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/pages/search_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:foodie/widgets/ui/photo_overlay.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 12 — Meal Plan Page (/meal-plan) Tests', () {
    testWidgets(
      'MealPlanPage renders AppHeader, week selector ("This Week"), and 7 day sections',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/meal-plan',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Verify page is rendered
        expect(find.byType(MealPlanPage), findsOneWidget);

        // Verify AppHeader is rendered
        expect(find.byType(AppHeader), findsOneWidget);

        // Verify Week selector shows "This Week"
        expect(find.text('This Week'), findsOneWidget);

        // Verify day titles on screen
        expect(find.text('Monday'), findsOneWidget);
        expect(find.text('Tuesday'), findsOneWidget);

        // Scroll to verify Wednesday
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(find.text('Wednesday'), findsOneWidget);
        // Other days are scrollable
        expect(find.byType(FeaturedRecipeCard), findsWidgets);
      },
    );

    testWidgets('Week selector chevrons switch weeks (Last Week, Next Week)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/meal-plan',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(DateTime(2026, 11, 16)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('This Week'), findsOneWidget);

      // Tap previous week chevron
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pumpAndSettle();

      expect(find.text('Last Week'), findsOneWidget);

      // Tap next week chevron twice
      await tester.tap(find.byIcon(LucideIcons.chevronRight));
      await tester.pumpAndSettle();
      expect(find.text('This Week'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.chevronRight));
      await tester.pumpAndSettle();
      expect(find.text('Next Week'), findsOneWidget);
    });

    testWidgets(
      'Empty day shows dashed card "Belum ada menu" and "+ Tambah menu"',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/meal-plan',
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

        // Switch to Next Week where no seed recipes exist
        await tester.tap(find.byIcon(LucideIcons.chevronRight));
        await tester.pumpAndSettle();

        // Now all days should have empty state cards
        expect(find.text('Belum ada menu'), findsWidgets);
        expect(find.text('Tambah menu'), findsWidgets);
      },
    );

    testWidgets('Tap plus button navigates to /search?pick=YYYY-MM-DD', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/meal-plan',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(DateTime(2026, 11, 16)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap first day plus button
      final mondayPlusButton = find.byIcon(LucideIcons.plus).first;
      expect(mondayPlusButton, findsOneWidget);
      await tester.tap(mondayPlusButton);
      await tester.pumpAndSettle();

      // Should be on SearchPage with pick banner
      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.textContaining('Pilih menu untuk'), findsOneWidget);
    });

    testWidgets(
      'Long press on FeaturedRecipeCard opens confirmation dialog and deleting removes it',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/meal-plan',
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

        // Find Ayam Kecap Bawang card on Monday
        final recipeCard = find.text('Ayam Kecap Bawang');
        expect(recipeCard, findsOneWidget);

        // Long press card
        await tester.longPress(recipeCard);
        await tester.pumpAndSettle();

        // Dialog should be shown
        expect(find.text('Hapus dari meal plan?'), findsOneWidget);
        expect(
          find.textContaining(
            'Apakah kamu yakin ingin menghapus "Ayam Kecap Bawang" dari jadwal Monday?',
          ),
          findsOneWidget,
        );

        // Tap "Hapus"
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Toast feedback appears and recipe is gone
        expect(find.text('Menu dihapus dari Meal Plan'), findsOneWidget);
        expect(find.text('Ayam Kecap Bawang'), findsNothing);

        // Wait for toast timer to finish
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Tapping recipe card navigates to recipe detail /recipe/:id', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/meal-plan',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(DateTime(2026, 11, 16)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Ayam Kecap Bawang card
      final recipeCard = find.text('Ayam Kecap Bawang');
      await tester.tap(recipeCard);
      await tester.pumpAndSettle();

      // Navigated to RecipeDetailPage
      expect(find.byType(RecipeDetailPage), findsOneWidget);
      expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
    });

    testWidgets(
      'Tapping favorite heart icon on FeaturedRecipeCard toggles favorite',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final router = createRouter(
          initialLocation: '/meal-plan',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Ayam Kecap Bawang is initially favorite in seed
        expect(
          container.read(favoritesProvider).contains('ayam-kecap-bawang'),
          isTrue,
        );

        // Find the favorite button on the card and tap it
        final favButton = find.byType(HeartButton).first;
        await tester.tap(favButton);
        await tester.pumpAndSettle();

        // Now should be toggled off
        expect(
          container.read(favoritesProvider).contains('ayam-kecap-bawang'),
          isFalse,
        );
      },
    );
  });
}
