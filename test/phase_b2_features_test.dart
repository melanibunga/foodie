import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_radius.dart';
import 'package:foodie/core/theme/app_shadows.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/providers/ui_helper.dart';
import 'package:foodie/widgets/app_bottom_nav.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/ui/page_with_header.dart';
import 'package:foodie/widgets/ui/sticky_bottom_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
    });
  });

  group('Fase B2 — Header fixed, Tab Nearby, Pill Favorit, & Toast Tests', () {
    testWidgets(
      'G4: Header is fixed outside scroll area and stays still when scrolling (Home, Search, Meal Plan, Nearby, Add)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        // 1. Home Page (/home)
        final homeRouter = createRouter(
          initialLocation: '/home',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: homeRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PageWithHeader), findsOneWidget);
        final headerFinder = find.byType(AppHeader);
        expect(headerFinder, findsOneWidget);
        final initialHeaderRect = tester.getRect(headerFinder);

        // Scroll the content down by 400px
        await tester.drag(
          find.text('Daily Inspiration'),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        final scrolledHeaderRect = tester.getRect(headerFinder);
        expect(
          scrolledHeaderRect,
          equals(initialHeaderRect),
          reason: 'AppHeader on HomePage must remain completely fixed while content scrolls underneath',
        );

        // 2. Search Page (/search)
        final searchRouter = createRouter(
          initialLocation: '/search',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: searchRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final searchHeaderRect = tester.getRect(find.byType(AppHeader));
        await tester.drag(find.text('Search by Meal'), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(AppHeader)),
          equals(searchHeaderRect),
          reason: 'AppHeader on SearchPage must remain fixed when scrolling',
        );

        // 3. Meal Plan Page (/meal-plan)
        final mealPlanRouter = createRouter(
          initialLocation: '/meal-plan',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: mealPlanRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mealPlanHeaderRect = tester.getRect(find.byType(AppHeader));
        await tester.drag(find.text('Monday'), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(AppHeader)),
          equals(mealPlanHeaderRect),
          reason: 'AppHeader on MealPlanPage must remain fixed when scrolling',
        );

        // 4. Nearby Page (/nearby)
        final nearbyRouter = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: nearbyRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nearbyHeaderRect = tester.getRect(find.byType(AppHeader));
        await tester.drag(find.text('Terdekat'), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(AppHeader)),
          equals(nearbyHeaderRect),
          reason: 'AppHeader on NearbyPage must remain fixed when scrolling',
        );

        // 5. Add Page (/add)
        final addRouter = createRouter(
          initialLocation: '/add',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: addRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addHeaderRect = tester.getRect(find.byType(AppHeader));
        await tester.drag(find.text('Recipe Title'), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(AppHeader)),
          equals(addHeaderRect),
          reason:
              'AppHeader on CreateRecipePage must remain fixed when scrolling',
        );
      },
    );

    testWidgets(
      'G2: Tab ke-5 berlabel "Nearby" dengan ikon mapPin, muat di lingkaran amber 59x57',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Tab Nearby label and icon in AppBottomNav
        expect(find.text('Nearby'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBottomNav),
            matching: find.byIcon(LucideIcons.mapPin),
          ),
          findsOneWidget,
        );
        expect(find.text('Loc'), findsNothing);

        // Verify active state: lingkaran amber 59x57
        final activeTabContainer = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 59.0 &&
              w.constraints?.maxHeight == 57.0 &&
              (w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color == AppColors.amber),
        );
        expect(activeTabContainer, findsOneWidget);

        // Ensure "Nearby" text renders inside active circle without clipping
        final nearbyTextRect = tester.getRect(find.text('Nearby'));
        final activeCircleRect = tester.getRect(activeTabContainer);
        expect(
          activeCircleRect.left <= nearbyTextRect.left &&
              activeCircleRect.right >= nearbyTextRect.right &&
              activeCircleRect.top <= nearbyTextRect.top &&
              activeCircleRect.bottom >= nearbyTextRect.bottom,
          isTrue,
          reason: '"Nearby" text must fit completely inside the active amber 59x57 container',
        );

        // Verify Semantics
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Nearby (aktif)',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'G1: Pill di AppHeader memakai ikon heart (terisi putih), Semantics "Favorit", ukuran 59x38, dan navigasi ke /favorites',
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
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify heart icon in AppHeader
        final heartInHeader = find.descendant(
          of: find.byType(AppHeader),
          matching: find.byIcon(Icons.favorite),
        );
        expect(heartInHeader, findsOneWidget);

        // 2. Verify pill container size (59 x 38)
        final favPill = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 59.0 &&
              w.constraints?.maxHeight == 38.0 &&
              (w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color == AppColors.olive),
        );
        expect(favPill, findsOneWidget);

        // 3. Verify Semantics label "Favorit"
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Favorit',
          ),
          findsOneWidget,
        );

        // 4. Tap pill navigates to /favorites
        await tester.tap(favPill);
        await tester.pumpAndSettle();

        expect(find.text('Menu Favoritmu'), findsOneWidget);
      },
    );

    testWidgets(
      'G3: Toast bergaya bg amberSoft, teks olive 12/600, radius pill, bayangan kartu, dan posisi 16 px di atas bottom element',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        // 1. Test Toast on page with bottom nav (/home)
        final homeRouter = createRouter(
          initialLocation: '/home',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: homeRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final homeContext = tester.element(find.byType(AppHeader));
        showAppToast(homeContext, 'Test Toast Nav');
        await tester.pump();

        final toastTextFinder = find.text('Test Toast Nav');
        expect(toastTextFinder, findsOneWidget);

        // Verify Toast styling
        final toastContainerFinder = find
            .ancestor(of: toastTextFinder, matching: find.byType(Container))
            .first;
        final toastContainer = tester.widget<Container>(toastContainerFinder);
        final decoration = toastContainer.decoration as BoxDecoration;

        expect(decoration.color, AppColors.amberSoft);
        expect(decoration.borderRadius, AppRadius.pill);
        expect(decoration.boxShadow, AppShadows.card);

        final textWidget = tester.widget<Text>(toastTextFinder);
        expect(textWidget.style?.color, AppColors.olive);
        expect(textWidget.style?.fontSize, 12.0);
        expect(textWidget.style?.fontWeight, FontWeight.w600);

        // Verify Position on page with bottom nav: bottom = bottomGap + 75 + 16
        final expectedBottom = bottomGap(homeContext) + 75.0 + 16.0;
        final containerRect = tester.getRect(toastContainerFinder);
        expect(956.0 - containerRect.bottom, closeTo(expectedBottom, 0.5));

        // Let toast disappear
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
        expect(find.text('Test Toast Nav'), findsNothing);

        // 2. Test Toast on page with sticky button (/favorites)
        final favRouter = createRouter(
          initialLocation: '/favorites',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: favRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final favContext = tester.element(find.text('Menu Favoritmu'));
        showAppToast(favContext, 'Test Toast Sticky');
        await tester.pump();

        final favToastFinder = find.text('Test Toast Sticky');
        expect(favToastFinder, findsOneWidget);

        final favContainerRect = tester.getRect(
          find
              .ancestor(of: favToastFinder, matching: find.byType(Container))
              .first,
        );
        final expectedFavBottom = bottomGap(favContext) + 52.0 + 16.0;
        expect(
          956.0 - favContainerRect.bottom,
          closeTo(expectedFavBottom, 0.5),
        );

        // Drain timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );
  });
}
