import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/app_bottom_nav.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:foodie/widgets/ui/photo_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 5 — Visual & Layout Verification (440x956 & 440x1280)', () {
    testWidgets(
      'Verify Home page dimensions at 440x956 against design/home.jpg',
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

        // 1. Verify AppHeader
        final headerFinder = find.byType(AppHeader);
        expect(headerFinder, findsOneWidget);

        // Verify Bookmark pill size (59 x 38)
        final bookmarkPill = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 59.0 &&
              w.constraints?.maxHeight == 38.0,
        );
        expect(bookmarkPill, findsOneWidget);

        // 2. Verify FeaturedRecipeCard (Daily Inspiration)
        final featuredCards = find.byType(FeaturedRecipeCard);
        expect(featuredCards, findsWidgets);

        // Verify time chip ("25 Menit") inside FeaturedRecipeCard
        final timeChips = find.byType(TimeChip);
        expect(timeChips, findsWidgets);

        // Verify "Lihat Resep" button size (122 x 40)
        final ctaButtonContainer = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 122.0 &&
              w.constraints?.maxHeight == 40.0,
        );
        expect(ctaButtonContainer, findsWidgets);

        // 3. Verify Popular GridRecipeCard
        final gridCards = find.byType(GridRecipeCard);
        expect(gridCards, findsWidgets);

        // 4. Verify Floating Bottom Nav is present with Home active
        expect(find.byType(AppBottomNav), findsOneWidget);
      },
    );

    testWidgets(
      'Verify Home page scrolling to bottom at 440x1280 without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(440, 1280);
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

        // Scroll to bottom
        final scrollFinder = find.byKey(
          const PageStorageKey<String>('home_scroll_view'),
        );
        expect(scrollFinder, findsOneWidget);

        await tester.drag(scrollFinder, const Offset(0, -1500));
        await tester.pumpAndSettle();

        // Ensure last grid items are visible and no RenderFlex overflow occurs
        expect(find.byType(GridRecipeCard), findsWidgets);
      },
    );
  });
}
