import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/home_page.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/favorites_provider.dart';
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

  group('Fase 5 — Home Page Tests', () {
    testWidgets(
      'HomePage renders AppHeader, Daily Inspiration, and Popular sections',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/home',
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

        // Loading state shows skeletons
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // AppHeader elements
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.text('Daily Inspiration'), findsOneWidget);
        expect(find.text('Popular'), findsOneWidget);
        expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget);

        // Cards rendered
        expect(find.byType(FeaturedRecipeCard), findsWidgets);
        expect(find.byType(GridRecipeCard), findsWidgets);

        // Favorit & cart counts from seed
        expect(
          find.descendant(
            of: find.byType(AppHeader),
            matching: find.byIcon(Icons.favorite),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(LucideIcons.shoppingCart), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping heart button toggles favorite and updates bookmark pill',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        late WidgetRef refHolder;

        final router = createRouter(
          initialLocation: '/home',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

        final initialFavCount = refHolder.read(favoriteCountProvider);

        // Find the first HeartButton and tap it
        final heartFinder = find.byType(HeartButton).first;
        expect(heartFinder, findsOneWidget);

        await tester.tap(heartFinder);
        await tester.pumpAndSettle();

        final updatedFavCount = refHolder.read(favoriteCountProvider);
        expect(updatedFavCount != initialFavCount, true);
      },
    );

    testWidgets(
      'Tapping quick-add icon on Popular card adds recipe to cart and shows toast',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/home',
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

        // Find the quick-add icon in GridRecipeCard
        final quickAddFinder = find.byIcon(LucideIcons.plusCircle).first;
        expect(quickAddFinder, findsOneWidget);

        await tester.tap(quickAddFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Either "Bahan ditambahkan ke keranjang" or "Sudah ada di keranjang" toast appears
        final toastFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Bahan ditambahkan ke keranjang' ||
                  widget.data == 'Sudah ada di keranjang'),
        );
        expect(toastFinder, findsOneWidget);

        // Let toast timer complete
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Tapping recipe card navigates to /recipe/:id', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/home',
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

      // Tap "Lihat Resep" on FeaturedRecipeCard
      final ctaButton = find.text('Lihat Resep').first;
      expect(ctaButton, findsOneWidget);

      await tester.tap(ctaButton);
      await tester.pumpAndSettle();

      // Recipe detail page should be shown
      expect(find.byType(RecipeDetailPage), findsOneWidget);
    });
  });
}
