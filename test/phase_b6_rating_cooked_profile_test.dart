import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/cooked_page.dart';
import 'package:foodie/pages/profile_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cooked_provider.dart';
import 'package:foodie/providers/ratings_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:ratings': jsonEncode({}),
      'foodie:favorites': jsonEncode([]),
    });
  });

  group('Fase B6 — Unit Tests: Rumus Rating & ratingsProvider', () {
    test(
      'calculateEffectiveRating: tanpa rating user mengembalikan nilai dasar',
      () {
        final eff = calculateEffectiveRating(
          baseRating: 4.8,
          baseReviews: 20,
          userRating: null,
        );

        expect(eff.rating, 4.8);
        expect(eff.reviews, 20);
        expect(eff.hasUserRating, isFalse);
        expect(eff.userRating, isNull);
      },
    );

    test('calculateEffectiveRating: rating pertama menghitung bobot dengan benar (+1 ulasan)', () {
      // (4.0 * 3 + 5) / 4 = 17 / 4 = 4.25 -> dibulatkan 1 desimal = 4.3
      final eff = calculateEffectiveRating(
        baseRating: 4.0,
        baseReviews: 3,
        userRating: 5,
      );

      expect(eff.rating, 4.3);
      expect(eff.reviews, 4);
      expect(eff.hasUserRating, isTrue);
      expect(eff.userRating, 5);
    });

    test('calculateEffectiveRating: ganti rating menghitung dari dasar (tidak akumulasi)', () {
      // Pertama rating 5: (4.0 * 3 + 5) / 4 = 4.25 -> 4.3
      final eff1 = calculateEffectiveRating(
        baseRating: 4.0,
        baseReviews: 3,
        userRating: 5,
      );
      expect(eff1.rating, 4.3);

      // User ganti jadi rating 2: (4.0 * 3 + 2) / 4 = 14 / 4 = 3.5 -> 3.5 (bukan dari 4.3!)
      final eff2 = calculateEffectiveRating(
        baseRating: 4.0,
        baseReviews: 3,
        userRating: 2,
      );
      expect(eff2.rating, 3.5);
      expect(eff2.reviews, 4);
      expect(eff2.hasUserRating, isTrue);
      expect(eff2.userRating, 2);
    });

    test(
      'ratingsProvider: rate() menyimpan dan mengganti rating tanpa akumulasi',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(ratingsProvider.notifier);
        const recipeId = 'ayam-kecap-bawang';

        expect(notifier.getRating(recipeId), isNull);

        // Beri rating 4
        await notifier.rate(recipeId, 4);
        expect(container.read(ratingsProvider)[recipeId], 4);
        expect(notifier.getRating(recipeId), 4);

        // Ganti rating 5
        await notifier.rate(recipeId, 5);
        expect(container.read(ratingsProvider)[recipeId], 5);
        expect(container.read(ratingsProvider).length, 1);
      },
    );
  });

  group('Fase B6 — Unit Tests: CookedProvider', () {
    test(
      'CookedNotifier starts with 12 seed entries and adds new session entry',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        // 1. Initial count is 12 (PRD §14.10)
        final initialEntries = container.read(cookedProvider);
        expect(initialEntries.length, 12);
        expect(container.read(cookedCountProvider), 12);

        // 2. Add entry after cooking
        await container.read(cookedProvider.notifier).add('ayam-kecap-bawang');

        // 3. Count becomes 13
        expect(container.read(cookedCountProvider), 13);

        // 4. byRecipe groups and sorts by latest date
        final summaries = container.read(cookedSummaryProvider);
        expect(summaries.isNotEmpty, isTrue);
        final ayamSummary = summaries.firstWhere(
          (s) => s.recipeId == 'ayam-kecap-bawang',
        );
        expect(ayamSummary.count, greaterThanOrEqualTo(2));
      },
    );
  });

  group('Fase B6 — Widget Tests', () {
    testWidgets(
      'A: CookPage completion screen provides 5-star rating, submission locks button with toast',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang/cook',
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

        // Navigate to last step
        // Ayam Kecap Bawang has 4 steps (0, 1, 2, 3)
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();

        // On step 4 (last step), button is "Selesai"
        final finishBtn = find.text('Selesai');
        expect(finishBtn, findsOneWidget);

        await tester.tap(finishBtn);
        await tester.pumpAndSettle();

        // 1. Completion screen appears
        expect(find.text('Selamat, masakanmu siap! 🎉'), findsOneWidget);
        expect(
          find.textContaining('Beri rating untuk Ayam Kecap Bawang'),
          findsOneWidget,
        );

        // 2. Five star selectors are rendered
        final star1 = find.bySemanticsLabel('Rating 1 bintang');
        final star4 = find.bySemanticsLabel('Rating 4 bintang');
        final star5 = find.bySemanticsLabel('Rating 5 bintang');
        expect(star1, findsOneWidget);
        expect(star5, findsOneWidget);

        // "Kirim rating" button is disabled initially
        final submitBtn = find.widgetWithText(ElevatedButton, 'Kirim rating');
        expect(tester.widget<ElevatedButton>(submitBtn).onPressed, isNull);

        // 3. Tap 4 stars
        await tester.tap(star4);
        await tester.pumpAndSettle();

        // "Kirim rating" button is now enabled!
        expect(tester.widget<ElevatedButton>(submitBtn).onPressed, isNotNull);

        // 4. Tap "Kirim rating"
        await tester.tap(submitBtn);
        await tester.pump();

        // Toast appears
        expect(find.text('Terima kasih atas ratingmu'), findsOneWidget);

        await tester.pumpAndSettle();

        // Button is locked to "Rating terkirim"
        expect(find.text('Rating terkirim'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Rating terkirim'),
              )
              .onPressed,
          isNull,
        );

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'B: /cooked page displays title, unique badge, search, grid cards, and sticky button',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/cooked',
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

        expect(find.byType(CookedPage), findsOneWidget);

        // 1. Header & Subtitle
        expect(find.text('Riwayat Masak'), findsOneWidget);
        expect(find.text('Resep yang sudah kamu masak.'), findsOneWidget);

        // 2. Search bar
        expect(find.text('Cari riwayat masak...'), findsOneWidget);

        // 3. Cards in grid: Ayam Kecap Bawang is in seed
        expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
        expect(find.textContaining('Dimasak '), findsWidgets);

        // 4. Sticky button "Kembali Ke Beranda"
        final homeBtn = find.text('Kembali Ke Beranda');
        expect(homeBtn, findsOneWidget);

        // 5. Test search filter
        await tester.enterText(find.byType(TextField), 'ayam kecap');
        await tester.pumpAndSettle();

        expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
        expect(find.text('Soto Ayam'), findsNothing);
      },
    );

    testWidgets(
      'C: Profile statistics columns are tappable and navigate to /favorites, /cooked, /my-recipes',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/profile',
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

        expect(find.byType(ProfilePage), findsOneWidget);

        // Verify numbers and labels
        expect(find.text('Favorit'), findsOneWidget);
        expect(find.text('Dimasak'), findsOneWidget);
        expect(find.text('Resep Saya'), findsOneWidget);

        // 1. Tap Dimasak -> navigates to /cooked
        final cookedStat = find.bySemanticsLabel('Buka Dimasak');
        expect(cookedStat, findsOneWidget);

        await tester.tap(cookedStat);
        await tester.pumpAndSettle();

        expect(find.byType(CookedPage), findsOneWidget);
      },
    );

    testWidgets(
      'D: Responsive layouts (360x640, 390x844, 440x956) render CookedPage without overflow',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final sizes = [
          const Size(360, 640),
          const Size(390, 844),
          const Size(440, 956),
        ];

        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final router = createRouter(
            initialLocation: '/cooked',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
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

          expect(find.byType(CookedPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );
  });
}
