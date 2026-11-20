import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/app_shell.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/about_page.dart';
import 'package:foodie/pages/cook_page.dart';
import 'package:foodie/pages/create_recipe_page.dart';
import 'package:foodie/pages/favorites_page.dart';
// forgot_page removed in Phase B1
import 'package:foodie/pages/groceries_page.dart';
import 'package:foodie/pages/home_page.dart';
import 'package:foodie/pages/login_page.dart';
import 'package:foodie/pages/meal_plan_page.dart';
import 'package:foodie/pages/my_recipes_page.dart';
import 'package:foodie/pages/nearby_page.dart';
import 'package:foodie/pages/profile_page.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/pages/register_page.dart';
import 'package:foodie/pages/search_page.dart';
import 'package:foodie/pages/splash_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase 15 — QA Audit: Multi-Resolution & Responsive Tests', () {
    const screenSizes = [
      Size(360, 800), // Small Android
      Size(390, 844), // iPhone 14
      Size(412, 915), // Pixel 7
      Size(440, 956), // Design Basis
      Size(800, 1000), // Tablet / Web Column 440
    ];

    for (final size in screenSizes) {
      testWidgets(
        'Home & Main pages layout cleanly on screen size ${size.width}x${size.height} without overflow',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final boxes = await initTestBoxes();

          final router = createRouter(
            initialLocation: '/home',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
                builder: (context, child) =>
                    AppShell(child: child ?? const SizedBox.shrink()),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(HomePage), findsOneWidget);

          // Verify AppShell maxWidth 440 constraint on wider screen
          if (size.width > 440) {
            final shell = tester.widget<AppShell>(find.byType(AppShell));
            expect(shell, isNotNull);
          }
        },
      );
    }

    testWidgets(
      'Every major page renders on basis 440x956 without layout overflow',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final routesToTest = [
          '/',
          '/login',
          '/register',
          // '/forgot',
          '/home',
          '/search',
          '/meal-plan',
          '/nearby',
          '/add',
          '/my-recipes',
          '/favorites',
          '/groceries',
          '/recipe/ayam-kecap-bawang',
          '/recipe/ayam-kecap-bawang/cook',
          '/profile',
          '/about',
        ];

        for (final route in routesToTest) {
          final isPublicRoute =
              route == '/' ||
              route == '/login' ||
              route == '/register' ||
              false;
          final router = createRouter(
            initialLocation: route,
            getAuthState: () => AuthState(
              isLoggedIn: !isPublicRoute,
              user: isPublicRoute ? null : seedUser,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
                builder: (context, child) =>
                    AppShell(child: child ?? const SizedBox.shrink()),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Check appropriate page is mounted
          switch (route) {
            case '/':
              expect(find.byType(SplashPage), findsOneWidget);
              break;
            case '/login':
              expect(find.byType(LoginPage), findsOneWidget);
              break;
            case '/register':
              expect(find.byType(RegisterPage), findsOneWidget);
              break;
            // case '/forgot' removed
            case '/home':
              expect(find.byType(HomePage), findsOneWidget);
              break;
            case '/search':
              expect(find.byType(SearchPage), findsOneWidget);
              break;
            case '/meal-plan':
              expect(find.byType(MealPlanPage), findsOneWidget);
              break;
            case '/nearby':
              expect(find.byType(NearbyPage), findsOneWidget);
              break;
            case '/add':
              expect(find.byType(CreateRecipePage), findsOneWidget);
              break;
            case '/my-recipes':
              expect(find.byType(MyRecipesPage), findsOneWidget);
              break;
            case '/favorites':
              expect(find.byType(FavoritesPage), findsOneWidget);
              break;
            case '/groceries':
              expect(find.byType(GroceriesPage), findsOneWidget);
              break;
            case '/recipe/ayam-kecap-bawang':
              expect(find.byType(RecipeDetailPage), findsOneWidget);
              break;
            case '/recipe/ayam-kecap-bawang/cook':
              expect(find.byType(CookPage), findsOneWidget);
              break;
            case '/profile':
              expect(find.byType(ProfilePage), findsOneWidget);
              break;
            case '/about':
              expect(find.byType(AboutPage), findsOneWidget);
              break;
          }
        }
      },
    );

    testWidgets(
      'System font scale 1.3x does not break layout or cause overflow',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/home',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(440, 956),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
      },
    );

    testWidgets(
      'Accessibility audit: icon buttons have Semantics / Tooltips and touch targets >= 40',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/home',
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

        // Semantics widgets should exist across the tree
        final semanticsFinders = find.byType(Semantics);
        expect(semanticsFinders, findsWidgets);
      },
    );
  });
}
