import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/ui/app_checkbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Rabu, 18 November 2026
  final fixedClock = DateTime(2026, 11, 18, 10, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:meal_plan': jsonEncode([]),
      'foodie:cart': jsonEncode([]),
      'foodie:favorites': jsonEncode([]),
    });
  });

  group('Fase C4 — Unit Tests (mealPlanProvider.add & pastDate rejection)', () {
    test('add for yesterday -> pastDate and entries count unchanged; today -> added; duplicate -> exists', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(fixedClock),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mealPlanProvider.notifier);
      expect(container.read(mealPlanProvider).length, equals(0));

      // 1. Tambah kemarin (2026-11-17) -> ditolak dengan status pastDate
      final resultYesterday = await notifier.add(
        '2026-11-17',
        'ayam-kecap-bawang',
      );
      expect(resultYesterday, equals(MealPlanAddResult.pastDate));
      expect(container.read(mealPlanProvider).length, equals(0));

      // 2. Tambah hari ini (2026-11-18) -> berhasil added
      final resultToday = await notifier.add('2026-11-18', 'ayam-kecap-bawang');
      expect(resultToday, equals(MealPlanAddResult.added));
      expect(container.read(mealPlanProvider).length, equals(1));

      // 3. Tambah lagi hari ini dengan resep sama -> ditolak dengan status exists
      final resultDup = await notifier.add('2026-11-18', 'ayam-kecap-bawang');
      expect(resultDup, equals(MealPlanAddResult.exists));
      expect(container.read(mealPlanProvider).length, equals(1));

      // 4. Tambah besok (2026-11-19) -> berhasil added
      final resultTomorrow = await notifier.add(
        '2026-11-19',
        'sayur-sop-bening',
      );
      expect(resultTomorrow, equals(MealPlanAddResult.added));
      expect(container.read(mealPlanProvider).length, equals(2));

      // 5. isPlanned check: hari ini/mendatang true
      expect(notifier.isPlanned('ayam-kecap-bawang'), isTrue);
      expect(notifier.isPlanned('sayur-sop-bening'), isTrue);
      expect(notifier.isPlanned('rendang-sapi'), isFalse);
    });
  });

  group('Fase C4 — Widget Tests (Detail Menu Fixed Bar & Ingredients Bullet)', () {
    testWidgets(
      'D1: Dynamic scroll floating top bar with back, share, and favorite buttons stays fixed during scroll',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(fixedClock),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // 1. Verifikasi Header Bar selebar layar
        final headerBarFinder = find.byKey(
          const Key('recipe-detail-header-bar'),
        );
        expect(headerBarFinder, findsOneWidget);
        final barBox = tester.getRect(headerBarFinder);
        expect(barBox.left, equals(0.0));
        expect(barBox.width, equals(440.0));

        // Keadaan awal (offset 0): background transparan (alpha = 0)
        final initialContainer = tester.widget<Container>(headerBarFinder);
        final initialDecoration = initialContainer.decoration as BoxDecoration;
        expect(
          initialDecoration.color,
          equals(AppColors.white.withValues(alpha: 0.0)),
        );

        // 2. Verifikasi tombol back, share, dan favorite ada di header
        final backBtnFinder = find.bySemanticsLabel('Kembali');
        expect(backBtnFinder, findsOneWidget);
        expect(find.bySemanticsLabel('Bagikan resep'), findsOneWidget);
        expect(find.bySemanticsLabel('Hapus dari favorit'), findsOneWidget);

        final initialBackPos = tester.getTopLeft(backBtnFinder);

        // 3. Scroll SingleChildScrollView sejauh 400 dp (scroll ke bawah)
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        // 4. Setelah di-scroll: Header bertransisi menjadi background putih solid (AppColors.white)
        final scrolledContainer = tester.widget<Container>(headerBarFinder);
        final scrolledDecoration =
            scrolledContainer.decoration as BoxDecoration;
        expect(scrolledDecoration.color, equals(AppColors.white));

        // Posisi tombol back dan header bar TETAP FIXED di atas layar
        final scrolledBackPos = tester.getTopLeft(backBtnFinder);
        expect(scrolledBackPos.dy, equals(initialBackPos.dy));
        expect(scrolledBackPos.dx, equals(initialBackPos.dx));

        final scrolledBarBox = tester.getRect(headerBarFinder);
        expect(scrolledBarBox.top, equals(barBox.top));
      },
    );

    testWidgets(
      'D3: Ingredients have no checkbox and render olive bullet points (10px)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(fixedClock),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Scroll ke bagian Bahan-Bahan
        await tester.scrollUntilVisible(
          find.text('Bahan-Bahan'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Tidak ada checkbox sama sekali
        expect(find.byType(AppCheckbox), findsNothing);

        // Verifikasi bullet points lingkaran olive 10x10 terisi
        final bulletFinders = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 10.0 &&
              w.constraints?.maxHeight == 10.0 &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == AppColors.olive &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(bulletFinders, findsWidgets);

        // Bahan pertama dan takaran
        expect(find.text('Nasi putih dingin'), findsOneWidget);
      },
    );

    testWidgets(
      'D2: Meal Plan sheet displays past days as disabled (onTap null, tap does not add)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        late WidgetRef refHolder;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(fixedClock),
            ],
            child: Consumer(
              builder: (context, ref, _) {
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

        // Buka sheet pilih tanggal lewat ikon kalender di samping judul resep
        final calendarBtn = find.bySemanticsLabel('Tambah ke Meal Plan');
        expect(calendarBtn, findsOneWidget);
        await tester.tap(calendarBtn);
        await tester.pumpAndSettle();

        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);

        // Senin 16 Nov 2026 adalah hari lampau (clock = Rabu 18 Nov 2026)
        final seninFinder = find.widgetWithText(InkWell, 'Senin');
        expect(seninFinder, findsOneWidget);
        final seninInkWell = tester.widget<InkWell>(seninFinder);
        expect(
          seninInkWell.onTap,
          isNull,
          reason: 'Hari lampau (Senin) harus non-aktif (onTap null)',
        );

        // Tap pada hari lampau tidak menambah entri dan sheet tidak tertutup
        await tester.tap(seninFinder);
        await tester.pumpAndSettle();
        expect(refHolder.read(mealPlanProvider).length, equals(0));
        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);

        // Rabu 18 Nov 2026 adalah hari ini (aktif)
        final rabuFinder = find.widgetWithText(InkWell, 'Rabu');
        expect(rabuFinder, findsOneWidget);
        final rabuInkWell = tester.widget<InkWell>(rabuFinder);
        expect(
          rabuInkWell.onTap,
          isNotNull,
          reason: 'Hari ini (Rabu) harus bisa dipilih',
        );

        // Tap Rabu -> bertambah dan sheet tertutup
        await tester.tap(rabuFinder);
        await tester.pumpAndSettle();

        expect(refHolder.read(mealPlanProvider).length, equals(1));
        expect(
          find.text('Menu berhasil ditambahkan ke Meal Plan'),
          findsOneWidget,
        );

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();
      },
    );
  });

  group('Fase C4 — Widget Tests (Meal Plan page & /search?pick=)', () {
    testWidgets('D2: Meal Plan page disables plus buttons on past days', (
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
            clockProvider.overrideWithValue(fixedClock),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Monday (16 Nov 2026) adalah hari lampau -> label semantik 'Hari lampau (Monday)' dan tombol non-aktif
      final pastPlusFinder = find.bySemanticsLabel('Hari lampau (Monday)');
      expect(pastPlusFinder, findsOneWidget);

      // Cek bahwa GestureDetector di tombol plus hari lampau onTap = null
      final pastGesture = tester.widget<GestureDetector>(
        find
            .descendant(
              of: pastPlusFinder,
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(
        pastGesture.onTap,
        isNull,
        reason: 'Tombol plus hari lampau harus non-aktif',
      );

      // Wednesday (18 Nov 2026) adalah hari ini -> tombol plus aktif
      final todayPlusFinder = find.bySemanticsLabel(
        'Tambah menu untuk Wednesday',
      );
      expect(todayPlusFinder, findsOneWidget);

      final todayGesture = tester.widget<GestureDetector>(
        find
            .descendant(
              of: todayPlusFinder,
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(
        todayGesture.onTap,
        isNotNull,
        reason: 'Tombol plus hari ini harus aktif',
      );
    });

    testWidgets(
      'D2: /search?pick=yesterday shows toast and navigates back to /meal-plan',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        // Buka /search dengan query param pick tanggal kemarin (2026-11-17)
        final router = createRouter(
          initialLocation: '/search?pick=2026-11-17',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(fixedClock),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Menampilkan toast dan kembali ke /meal-plan
        expect(
          find.text('Tidak dapat memilih tanggal yang sudah lewat'),
          findsOneWidget,
        );
        expect(
          router.routeInformationProvider.value.uri.path,
          equals('/meal-plan'),
        );

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();
      },
    );
  });
}
