import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_radius.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/providers/ui_helper.dart';
import 'package:foodie/widgets/app_header.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase C2 — Greeting Unit Tests (PRD §15.2)', () {
    test('greetingFor(DateTime) returns exact greetings across day time boundaries', () {
      // 04.00–10.59: "Selamat pagi"
      expect(greetingFor(DateTime(2026, 3, 1, 4, 0)), equals('Selamat pagi'));
      expect(greetingFor(DateTime(2026, 3, 1, 10, 59)), equals('Selamat pagi'));

      // 11.00–14.59: "Selamat siang"
      expect(greetingFor(DateTime(2026, 3, 1, 11, 0)), equals('Selamat siang'));
      expect(
        greetingFor(DateTime(2026, 3, 1, 14, 59)),
        equals('Selamat siang'),
      );

      // 15.00–17.59: "Selamat sore"
      expect(greetingFor(DateTime(2026, 3, 1, 15, 0)), equals('Selamat sore'));
      expect(greetingFor(DateTime(2026, 3, 1, 17, 59)), equals('Selamat sore'));

      // 18.00–03.59: "Selamat malam"
      expect(greetingFor(DateTime(2026, 3, 1, 18, 0)), equals('Selamat malam'));
      expect(
        greetingFor(DateTime(2026, 3, 1, 23, 59)),
        equals('Selamat malam'),
      );
      expect(greetingFor(DateTime(2026, 3, 1, 0, 0)), equals('Selamat malam'));
      expect(greetingFor(DateTime(2026, 3, 1, 3, 59)), equals('Selamat malam'));
    });
  });

  group('Fase C2 — AppHeader Greeting & Robustness (PRD §15.2)', () {
    testWidgets(
      'AppHeader renders greeting and user first name without overflow at 360dp with 1.3x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(360.0, 640.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        const longNamedUser = User(
          id: 'u-long',
          name: 'Siti Aminah Nurhaliza bin Abdul Rahman',
          email: 'siti@example.com',
        );

        final boxes = await initTestBoxes();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              foodieBoxesProvider.overrideWithValue(boxes),
              currentUserProvider.overrideWith((ref) => longNamedUser),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360.0, 640.0),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: AppHeader(
                    currentTime: DateTime(2026, 3, 1, 9, 30), // Pagi
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Memastikan sapaan "Selamat pagi" dan nama depan "Siti" tampil
        expect(find.text('Selamat pagi'), findsOneWidget);
        expect(find.text('Siti'), findsOneWidget);

        // Verifikasi avatar 48x48
        final avatarFinder = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Profil Saya',
        );
        expect(avatarFinder, findsOneWidget);
        final avatarSize = tester.getSize(avatarFinder);
        expect(avatarSize.width, equals(48.0));
        expect(avatarSize.height, equals(48.0));

        // Verifikasi pill favorit 59x38
        final pillFinder = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Favorit',
        );
        expect(pillFinder, findsOneWidget);
        final pillSize = tester.getSize(pillFinder);
        expect(pillSize.width, equals(59.0));
        expect(pillSize.height, equals(38.0));

        // Tidak ada RenderFlex overflow
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Fase C2 — Toast Maroon Style & Positioning (PRD §15.1)', () {
    testWidgets('showAppToast renders maroon background and white text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440.0, 956.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showAppToast(ctx, 'Resep berhasil ditambahkan!');
                  },
                  child: const Text('Tampilkan Toast'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tampilkan Toast'));
      await tester.pump(); // frame 1
      await tester.pump(const Duration(milliseconds: 100));

      // Cari widget Text toast
      final toastText = find.text('Resep berhasil ditambahkan!');
      expect(toastText, findsOneWidget);

      final textWidget = tester.widget<Text>(toastText);
      expect(textWidget.style?.color, equals(AppColors.white));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w600));
      expect(textWidget.style?.fontSize, equals(12.0));

      // Cari Container dekorasi toast
      final containerFinder = find
          .ancestor(of: toastText, matching: find.byType(Container))
          .first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(decoration.color, equals(AppColors.maroon));
      expect(decoration.borderRadius, equals(AppRadius.pill));

      // Tunggu hingga timer toast selesai (2.2 detik)
      await tester.pump(const Duration(milliseconds: 2500));
    });
  });

  group('Fase C2 — Fixed Header Area (PRD §15.3, §15.4)', () {
    testWidgets(
      'FavoritesPage: header area (Title + Badge + Sub + Search) stays fixed when scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(440.0, 956.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

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
        await tester.pumpAndSettle();

        // Elemen-elemen di area header fixed
        final titleFinder = find.text('Menu Favoritmu');
        final searchFinder = find.widgetWithText(
          TextField,
          'Cari nama menu favorit...',
        );
        expect(titleFinder, findsOneWidget);
        expect(searchFinder, findsOneWidget);

        final titleRectBefore = tester.getRect(titleFinder);
        final searchRectBefore = tester.getRect(searchFinder);

        // Scroll ke bawah 300 dp
        final scrollableFinder = find.byType(Scrollable).first;
        await tester.drag(scrollableFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        final titleRectAfter = tester.getRect(titleFinder);
        final searchRectAfter = tester.getRect(searchFinder);

        // Posisi area header fixed TETAP DIAM (tidak terpengaruh scroll)
        expect(titleRectAfter, equals(titleRectBefore));
        expect(searchRectAfter, equals(searchRectBefore));

        // Tombol sticky "Kembali Ke Beranda" tetap terlihat di bawah
        final backButton = find.text('Kembali Ke Beranda');
        expect(backButton, findsOneWidget);
      },
    );

    testWidgets(
      'MealPlanPage: AppHeader + week picker stay fixed when scrolling day sections',
      (tester) async {
        tester.view.physicalSize = const Size(440.0, 956.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final boxes = await initTestBoxes();
        final router = createRouter(
          initialLocation: '/meal-plan',
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

        // Week picker header
        final weekPickerFinder = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Minggu sebelumnya',
        );
        expect(weekPickerFinder, findsOneWidget);
        final weekPickerRectBefore = tester.getRect(weekPickerFinder);

        final appHeaderAvatar = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Profil Saya',
        );
        expect(appHeaderAvatar, findsOneWidget);
        final avatarRectBefore = tester.getRect(appHeaderAvatar);

        // Scroll ke bawah 300 dp pada scrollable meal plan
        final scrollableFinder = find.byKey(
          const PageStorageKey<String>('meal_plan_scroll_view'),
        );
        expect(scrollableFinder, findsOneWidget);
        await tester.drag(scrollableFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        final weekPickerRectAfter = tester.getRect(weekPickerFinder);
        final avatarRectAfter = tester.getRect(appHeaderAvatar);

        // AppHeader dan week picker TETAP DIAM di tempat yang sama
        expect(avatarRectAfter, equals(avatarRectBefore));
        expect(weekPickerRectAfter, equals(weekPickerRectBefore));
      },
    );

    testWidgets(
      'CookedPage: header area (Title + Badge + Sub + Search) stays fixed when scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(440.0, 956.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final boxes = await initTestBoxes();
        final router = createRouter(
          initialLocation: '/cooked',
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

        final titleFinder = find.text('Riwayat Masak');
        final searchFinder = find.widgetWithText(
          TextField,
          'Cari riwayat masak...',
        );
        expect(titleFinder, findsOneWidget);
        expect(searchFinder, findsOneWidget);

        final titleRectBefore = tester.getRect(titleFinder);
        final searchRectBefore = tester.getRect(searchFinder);

        final scrollableFinder = find.byType(CustomScrollView);
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pumpAndSettle();

        final titleRectAfter = tester.getRect(titleFinder);
        final searchRectAfter = tester.getRect(searchFinder);

        expect(titleRectAfter, equals(titleRectBefore));
        expect(searchRectAfter, equals(searchRectBefore));
      },
    );

    testWidgets(
      'MyRecipesPage: header area (Title + Badge + Sub + Search) stays fixed when scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(440.0, 956.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final boxes = await initTestBoxes();
        final router = createRouter(
          initialLocation: '/my-recipes',
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

        final titleFinder = find.text('Resep Saya');
        final searchFinder = find.widgetWithText(
          TextField,
          'Cari resep buatanmu...',
        );
        expect(titleFinder, findsOneWidget);
        expect(searchFinder, findsOneWidget);

        final titleRectBefore = tester.getRect(titleFinder);
        final searchRectBefore = tester.getRect(searchFinder);

        final scrollableFinder = find.byType(CustomScrollView);
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pumpAndSettle();

        final titleRectAfter = tester.getRect(titleFinder);
        final searchRectAfter = tester.getRect(searchFinder);

        expect(titleRectAfter, equals(titleRectBefore));
        expect(searchRectAfter, equals(searchRectBefore));
      },
    );

    testWidgets(
      'Short screen (360x640): pages render with comfortable scrollable content',
      (tester) async {
        tester.view.physicalSize = const Size(360.0, 640.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

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
        await tester.pumpAndSettle();

        // Tidak ada error atau overflow
        expect(tester.takeException(), isNull);

        // Area scroll memiliki tinggi yang cukup (mis. > 250 dp)
        final scrollable = find.byType(CustomScrollView);
        expect(scrollable, findsOneWidget);
        final scrollableSize = tester.getSize(scrollable);
        expect(scrollableSize.height, greaterThan(250.0));
      },
    );
  });
}
