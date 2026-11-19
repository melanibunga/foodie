import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/utils/week_utils.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:meal_plan': jsonEncode([]),
    });
  });

  group('Fase B3 — Meal Plan Unit Tests (M2 Logika)', () {
    test('mealPlanProvider.add returns added or exists and prevents duplicate on same date', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mealPlanProvider.notifier);
      const testDate = '2026-11-24';
      const otherDate = '2026-11-25';
      const recipeId = 'ayam-kecap-bawang';

      // 1. Initial state is empty
      expect(container.read(mealPlanProvider), isEmpty);
      expect(notifier.has(testDate, recipeId), isFalse);

      // 2. Add new recipe -> returns added
      final res1 = await notifier.add(testDate, recipeId);
      expect(res1, MealPlanAddResult.added);
      expect(container.read(mealPlanProvider).length, 1);
      expect(notifier.has(testDate, recipeId), isTrue);

      // 3. Add duplicate on the SAME date -> returns exists and does not increase length
      final res2 = await notifier.add(testDate, recipeId);
      expect(res2, MealPlanAddResult.exists);
      expect(container.read(mealPlanProvider).length, 1);

      // 4. Add same recipe on a DIFFERENT date -> returns added and increases length
      final res3 = await notifier.add(otherDate, recipeId);
      expect(res3, MealPlanAddResult.added);
      expect(container.read(mealPlanProvider).length, 2);
      expect(notifier.has(otherDate, recipeId), isTrue);

      // 5. datesFor(recipeId) returns all planned dates
      final dates = notifier.datesFor(recipeId);
      expect(dates, containsAll([testDate, otherDate]));
    });

    test('isPlanned accurately distinguishes past dates from today and future dates', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mealPlanProvider.notifier);
      final now = DateTime.now();
      final pastDate = WeekUtils.formatDateKey(
        now.subtract(const Duration(days: 2)),
      );
      final todayDate = WeekUtils.formatDateKey(
        DateTime(now.year, now.month, now.day),
      );
      final futureDate = WeekUtils.formatDateKey(
        now.add(const Duration(days: 3)),
      );

      const recipePast = 'recipe-past';
      const recipeToday = 'recipe-today';
      const recipeFuture = 'recipe-future';

      await notifier.add(pastDate, recipePast);
      await notifier.add(todayDate, recipeToday);
      await notifier.add(futureDate, recipeFuture);

      // Past recipe is NOT planned for today/future
      expect(notifier.isPlanned(recipePast), isFalse);

      // Today recipe IS planned
      expect(notifier.isPlanned(recipeToday), isTrue);

      // Future recipe IS planned
      expect(notifier.isPlanned(recipeFuture), isTrue);
    });
  });

  group('Fase B3 — Meal Plan UI & Layout Tests', () {
    testWidgets(
      'M1: FeaturedRecipeCard and empty day dashed card always have fixed width 330 (1 menu vs 2 menu)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final now = DateTime.now();
        final currentWeekMonday = WeekUtils.getWeekStart(now);
        final mondayKey = WeekUtils.formatDateKey(currentWeekMonday);
        final tuesdayKey = WeekUtils.formatDateKey(
          currentWeekMonday.add(const Duration(days: 1)),
        );

        // Seed: Monday has 1 recipe, Tuesday has 2 recipes, Wednesday is empty
        final initialEntries = [
          MealPlanEntry(
            id: 'mp-1',
            date: mondayKey,
            recipeId: 'ayam-kecap-bawang',
          ),
          MealPlanEntry(id: 'mp-2', date: tuesdayKey, recipeId: 'soto-ayam'),
          MealPlanEntry(
            id: 'mp-3',
            date: tuesdayKey,
            recipeId: 'rendang-sapi-minang',
          ),
        ];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'foodie:meal_plan',
          jsonEncode(initialEntries.map((e) => e.toJson()).toList()),
        );

        final router = createRouter(
          initialLocation: '/meal-plan',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(currentWeekMonday),
            ],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify cards in Monday (1 menu) and Tuesday (2 menus) all have width 330.0
        final initialFeaturedCards = tester.widgetList<FeaturedRecipeCard>(
          find.byType(FeaturedRecipeCard),
        );
        expect(initialFeaturedCards.isNotEmpty, isTrue);
        for (final card in initialFeaturedCards) {
          expect(
            card.width,
            330.0,
            reason: 'All FeaturedRecipeCards in Meal Plan must have fixed width 330.0 regardless of menu count',
          );
        }

        // Drag Tuesday carousel horizontally to reveal the 2nd card
        await tester.drag(find.text('Soto Ayam'), const Offset(-300, 0));
        await tester.pumpAndSettle();

        final secondCardFinder = find.widgetWithText(
          FeaturedRecipeCard,
          'Rendang Sapi Minang',
        );
        expect(secondCardFinder, findsOneWidget);
        expect(
          tester.widget<FeaturedRecipeCard>(secondCardFinder).width,
          330.0,
          reason: 'Second card on Tuesday also has width 330.0',
        );

        // 2. Verify empty day dashed card width is 330.0
        // Drag vertically to bring Wednesday (empty day) into view
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();

        final emptyTextFinder = find.text('Belum ada menu');
        expect(emptyTextFinder, findsWidgets);

        final dashedCardPaintFinder = find
            .ancestor(
              of: emptyTextFinder.first,
              matching: find.byType(CustomPaint),
            )
            .first;
        final dashedCardSize = tester.getSize(dashedCardPaintFinder);
        expect(
          dashedCardSize.width,
          330.0,
          reason: 'Empty day dashed card must have fixed width 330.0 to match recipe cards',
        );
      },
    );

    testWidgets(
      'M2 UI jalur plus: /search?pick= shows "Sudah ada" for planned recipe and rejects duplicate with toast',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const pickDate = '2026-11-25';
        final currentWeekMonday = WeekUtils.getWeekStart(DateTime.now());
        final initialEntries = [
          MealPlanEntry(
            id: 'mp-test-1',
            date: pickDate,
            recipeId: 'nasi-goreng-nusantara',
          ),
        ];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'foodie:meal_plan',
          jsonEncode(initialEntries.map((e) => e.toJson()).toList()),
        );

        final router = createRouter(
          initialLocation: '/search?pick=$pickDate',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(currentWeekMonday),
            ],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Search for 'nasi'
        await tester.enterText(find.byType(TextField), 'nasi');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // The already planned recipe has button "Sudah ada"
        final alreadyPlannedBtn = find.text('Sudah ada');
        expect(alreadyPlannedBtn, findsOneWidget);

        // Tap "Sudah ada" -> shows toast "Menu sudah ada di meal plan" and does NOT navigate
        await tester.tap(alreadyPlannedBtn);
        await tester.pump();

        expect(find.text('Menu sudah ada di meal plan'), findsOneWidget);
        // Still on search page!
        expect(find.text('Sudah ada'), findsOneWidget);

        // Advance toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // Find an unplanned recipe with button "Tambahkan"
        final addBtn = find.text('Tambahkan');
        expect(addBtn, findsWidgets);

        // Tap "Tambahkan" -> succeeds, shows success toast and navigates to /meal-plan
        await tester.tap(addBtn.first);
        await tester.pump();

        expect(
          find.text('Menu berhasil ditambahkan ke Meal Plan'),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Navigated to /meal-plan
        expect(find.text('This Week'), findsOneWidget);

        // Advance toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'M2 UI jalur detail: date picker sheet shows checkmark on planned dates, rejects tap with toast, and allows other dates',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final now = DateTime.now();
        final currentWeekMonday = WeekUtils.getWeekStart(now);
        final plannedDateKey = WeekUtils.formatDateKey(
          currentWeekMonday,
        ); // Monday this week
        final otherDateKey = WeekUtils.formatDateKey(
          currentWeekMonday.add(const Duration(days: 1)),
        ); // Tuesday this week

        const recipeId = 'ayam-kecap-bawang';
        final initialEntries = [
          MealPlanEntry(
            id: 'mp-detail-1',
            date: plannedDateKey,
            recipeId: recipeId,
          ),
        ];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'foodie:meal_plan',
          jsonEncode(initialEntries.map((e) => e.toJson()).toList()),
        );

        final router = createRouter(
          initialLocation: '/recipe/$recipeId',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(currentWeekMonday),
            ],
            child: MaterialApp.router(
              theme: ThemeData(fontFamily: 'Poppins'),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Meal Plan Date Picker Sheet via calendar-check icon (since recipe is already planned)
        final calendarBtn = find.byIcon(LucideIcons.calendarCheck);
        expect(calendarBtn, findsOneWidget);
        await tester.tap(calendarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);

        // 1. The planned date (Monday) displays checkmark
        final checkmarkIcon = find.descendant(
          of: find.byType(ListView),
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkmarkIcon, findsOneWidget);

        // 2. Tap on the already planned date -> shows toast and sheet STAYS OPEN
        await tester.tap(checkmarkIcon);
        await tester.pump();

        expect(find.text('Menu sudah ada di meal plan'), findsOneWidget);
        // Sheet remains open!
        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // 3. Tap on an unplanned date (Tuesday) with add_circle_outline
        final addCircleIcons = find.descendant(
          of: find.byType(ListView),
          matching: find.byIcon(Icons.add_circle_outline),
        );
        expect(addCircleIcons, findsWidgets);

        await tester.tap(addCircleIcons.first);
        await tester.pump();

        // Toast success appears
        expect(
          find.text('Menu berhasil ditambahkan ke Meal Plan'),
          findsOneWidget,
        );

        await tester.pumpAndSettle();

        // Sheet is closed!
        expect(find.text('Tambah ke Meal Plan'), findsNothing);

        // Verify Tuesday now has the recipe in mealPlanProvider
        final updatedEntries = prefs.getString('foodie:meal_plan');
        expect(updatedEntries, contains(otherDateKey));

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );
  });
}
