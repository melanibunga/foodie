import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/providers/ui_helper.dart';
import 'package:foodie/widgets/app_bottom_nav.dart';
import 'package:foodie/widgets/ui/sticky_bottom_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:recipes': jsonEncode([]),
      'foodie:favorites': jsonEncode([]),
      'foodie:ratings': jsonEncode({}),
    });
  });

  group(
    'Fase C3 — Route /add in ShellRoute with BottomNav (PRD §15.5, §5.2)',
    () {
      const screenWidth = 440.0;
      const screenHeight = 956.0;

      testWidgets(
        '/add renders AppBottomNav with Add tab active (amber circle)',
        (tester) async {
          tester.view.physicalSize = const Size(screenWidth, screenHeight);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.reset());

          final prefs = await SharedPreferences.getInstance();
          final router = createRouter(
            initialLocation: '/add',
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

          // 1. BottomNav tampil
          final bottomNavFinder = find.byType(AppBottomNav);
          expect(bottomNavFinder, findsOneWidget);

          // 2. Tab "Add" aktif dengan lingkaran amber
          final activeAddTab = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Add (aktif)',
          );
          expect(activeAddTab, findsOneWidget);

          final amberCircle = find.descendant(
            of: activeAddTab,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color == AppColors.amber &&
                  (w.decoration as BoxDecoration).shape == BoxShape.circle,
            ),
          );
          expect(amberCircle, findsOneWidget);

          // 3. Tombol back "<" pada baris "Create Recipe" bernavigasi ke /home
          final backButton = find.bySemanticsLabel('Kembali');
          expect(backButton, findsOneWidget);
          await tester.tap(backButton);
          await tester.pumpAndSettle();

          expect(
            router.routeInformationProvider.value.uri.path,
            equals('/home'),
          );
        },
      );

      testWidgets('AppBottomNav on /add does NOT move when keyboard appears', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        final navRectBefore = tester.getRect(find.byType(AppBottomNav));

        // Simulasikan keyboard muncul (300 dp)
        tester.view.viewInsets = const FakeViewPadding(bottom: 300.0);
        await tester.pump();
        await tester.pumpAndSettle();

        final navRectAfter = tester.getRect(find.byType(AppBottomNav));

        // Posisi BottomNav tetap IDENTIK (tidak didorong keyboard)
        expect(navRectAfter, equals(navRectBefore));
      });

      testWidgets('Toast on /add is positioned above BottomNav', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        final addContext = tester.element(find.text('Create Recipe'));
        showAppToast(addContext, 'Test Toast on Add');
        await tester.pump();

        final toastTextFinder = find.text('Test Toast on Add');
        expect(toastTextFinder, findsOneWidget);

        final toastContainerFinder = find
            .ancestor(of: toastTextFinder, matching: find.byType(Container))
            .first;
        final containerRect = tester.getRect(toastContainerFinder);

        // Harapannya: berada 16 px di atas BottomNav (bottomGap + 75 + 16)
        final expectedBottom = bottomGap(addContext) + 75.0 + 16.0;
        expect(
          screenHeight - containerRect.bottom,
          closeTo(expectedBottom, 0.5),
        );

        await tester.pump(const Duration(milliseconds: 2500));
      });
    },
  );

  group('Fase C3 — Cooking Instructions List & DONE Button (PRD §15.5, §14.8)', () {
    const screenWidth = 440.0;
    const screenHeight = 956.0;

    testWidgets(
      'Initial layout: no inline ingredients or steps list before adding',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        // List bahan & langkah tidak tampil di awal
        expect(find.textContaining('Ingredients ('), findsNothing);
        expect(find.textContaining('Cooking Instructions ('), findsNothing);

        // Tombol DONE ada di dalam scroll view (bukan sticky)
        final doneButton = find.widgetWithText(ElevatedButton, 'DONE');
        expect(doneButton, findsOneWidget);
      },
    );

    testWidgets(
      'Add 1, 3, 6 steps -> expandable list, inline toggle, reordering on deletion',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        // 1. Buka sheet Cooking Instructions
        await tester.tap(find.text('Add one or multiple steps'));
        await tester.pumpAndSettle();

        // Helper untuk menambah langkah di sheet
        Future<void> addStepInSheet(
          String title,
          String desc,
          String minutes,
        ) async {
          await tester.tap(find.text('Tambah Langkah'));
          await tester.pumpAndSettle();

          final titleField = find.widgetWithText(
            TextField,
            'Mis. Tumis Bawang',
          );
          await tester.enterText(titleField, title);

          final descField = find.widgetWithText(
            TextField,
            'Tuliskan detail langkah...',
          );
          await tester.enterText(descField, desc);

          final durField = find.widgetWithText(TextField, '0');
          await tester.enterText(durField, minutes);

          await tester.tap(find.text('Tambahkan'));
          await tester.pumpAndSettle();
        }

        // Tambah langkah 1
        await addStepInSheet(
          'Langkah Pertama',
          'Tumis bumbu sampai harum',
          '5',
        );

        // Simpan sheet
        final simpanBtn = find.descendant(
          of: find.byKey(const Key('app_bottom_sheet_container')),
          matching: find.text('Simpan'),
        );
        await tester.tap(simpanBtn);
        await tester.pumpAndSettle();

        // Form sekarang menampilkan list "Cooking Instructions (1)"
        expect(find.text('Cooking Instructions (1)'), findsOneWidget);
        expect(find.text('Langkah Pertama'), findsOneWidget);
        expect(find.textContaining('Tumis bumbu sampai harum'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // Nomor lingkaran

        // 2. Tambah 2 langkah lagi sehingga total 3
        await tester.tap(find.textContaining('1 steps configured'));
        await tester.pumpAndSettle();

        await addStepInSheet(
          'Langkah Kedua',
          'Masukkan ayam dan aduk rata',
          '10',
        );
        await addStepInSheet('Langkah Ketiga', 'Tuangkan kecap dan air', '15');

        await tester.tap(simpanBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cooking Instructions (3)'), findsOneWidget);
        expect(find.text('Langkah Pertama'), findsOneWidget);
        expect(find.text('Langkah Kedua'), findsOneWidget);
        expect(find.text('Langkah Ketiga'), findsOneWidget);
        // Belum ada tombol "Lihat semua" karena <= 3
        expect(find.textContaining('Lihat semua'), findsNothing);

        // 3. Tambah 3 langkah lagi sehingga total 6
        await tester.tap(find.textContaining('3 steps configured'));
        await tester.pumpAndSettle();

        await addStepInSheet('Langkah Keempat', 'Masak sampai mendidih', '10');
        await addStepInSheet('Langkah Kelima', 'Koreksi rasa', '2');
        await addStepInSheet('Langkah Keenam', 'Sajikan hangat', '1');

        await tester.tap(simpanBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cooking Instructions (6)'), findsOneWidget);
        // Saat collapsed: hanya 3 langkah pertama yang tampil + tombol "Lihat semua (6)"
        expect(find.text('Langkah Pertama'), findsOneWidget);
        expect(find.text('Langkah Kedua'), findsOneWidget);
        expect(find.text('Langkah Ketiga'), findsOneWidget);
        expect(find.text('Langkah Keenam'), findsNothing);

        final expandButton = find.text('Lihat semua (6)');
        expect(expandButton, findsOneWidget);

        // Scroll agar expandButton tidak terhalang floating BottomNav
        await tester.scrollUntilVisible(
          expandButton,
          50,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();

        // Tap expand
        await tester.tap(expandButton);
        await tester.pumpAndSettle();

        // Sekarang semua 6 langkah terlihat + tombol berubah menjadi "Sembunyikan"
        await tester.scrollUntilVisible(
          find.text('Langkah Keenam'),
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Langkah Keenam'), findsOneWidget);
        expect(find.text('Sembunyikan'), findsOneWidget);

        // 4. Hapus langkah 2 -> Verifikasi nomor otomatis diurut ulang
        await tester.scrollUntilVisible(
          find.text('Langkah Kedua'),
          -50,
          scrollable: find.byType(Scrollable).first,
        );
        final trashStep2 = find.bySemanticsLabel('Hapus langkah 2');
        expect(trashStep2, findsOneWidget);
        await tester.tap(trashStep2);
        await tester.pumpAndSettle();

        // Sisa 5 langkah
        expect(find.text('Cooking Instructions (5)'), findsOneWidget);
        expect(find.text('Langkah Kedua'), findsNothing);
        expect(
          find.text('Langkah Ketiga'),
          findsOneWidget,
        ); // Sekarang menjadi langkah nomor 2
      },
    );

    testWidgets(
      'DONE button is reachable at end of scroll and triggers recipe creation',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        // 1. Validasi error saat DONE di-tap tanpa input
        final doneButton = find.widgetWithText(ElevatedButton, 'DONE');
        await tester.scrollUntilVisible(
          doneButton,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(doneButton);
        await tester.pumpAndSettle();

        expect(find.text('Recipe Title tidak boleh kosong'), findsOneWidget);
        expect(find.text('Minimal tambahkan 1 bahan'), findsOneWidget);
        expect(
          find.text('Minimal tambahkan 1 langkah memasak'),
          findsOneWidget,
        );

        // 2. Scroll kembali ke atas dan isi judul resep
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, 1000),
          1000,
        );
        await tester.pumpAndSettle();

        final titleField = find.widgetWithText(
          TextField,
          'Type your recipe name here',
        );
        await tester.enterText(titleField, 'Sop Buntut Spesial');

        // 3. Tambah 1 bahan
        await tester.tap(find.text('Add ingredients to recipe'));
        await tester.pumpAndSettle();

        final ingNameField = find.widgetWithText(
          TextField,
          'Mis. Bawang merah',
        );
        await tester.enterText(ingNameField, 'Buntut Sapi');
        final ingQtyField = find.widgetWithText(TextField, 'Mis. 4');
        await tester.enterText(ingQtyField, '500');

        await tester.tap(find.text('+ Tambah ke Daftar'));
        await tester.pumpAndSettle();

        final saveIngBtn = find.descendant(
          of: find.byKey(const Key('app_bottom_sheet_container')),
          matching: find.text('Simpan'),
        );
        await tester.tap(saveIngBtn);
        await tester.pumpAndSettle();

        // 4. Tambah 1 langkah
        await tester.tap(find.text('Add one or multiple steps'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tambah Langkah'));
        await tester.pumpAndSettle();

        final stepTitleField = find.widgetWithText(
          TextField,
          'Mis. Tumis Bawang',
        );
        await tester.enterText(stepTitleField, 'Rebus Buntut');
        final stepDescField = find.widgetWithText(
          TextField,
          'Tuliskan detail langkah...',
        );
        await tester.enterText(stepDescField, 'Rebus sampai empuk');

        await tester.tap(find.text('Tambahkan'));
        await tester.pumpAndSettle();

        final saveStepBtn = find.descendant(
          of: find.byKey(const Key('app_bottom_sheet_container')),
          matching: find.text('Simpan'),
        );
        await tester.tap(saveStepBtn);
        await tester.pumpAndSettle();

        // 5. Scroll ke tombol DONE dan submit (pastikan melewati floating BottomNav dengan padding bawah 120)
        await tester.scrollUntilVisible(
          doneButton,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
        await tester.pumpAndSettle();
        await tester.tap(doneButton);
        await tester.pumpAndSettle();

        // Dialog sukses muncul
        expect(find.text('Resep berhasil disimpan'), findsOneWidget);

        // Tap "Oke" -> dialog ditutup dan berpindah ke /my-recipes
        await tester.tap(find.text('Oke'));
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          equals('/my-recipes'),
        );
        expect(find.text('Sop Buntut Spesial'), findsOneWidget);
      },
    );

    testWidgets(
      'DONE button width is smaller than AppBottomNav width (300 < 365)',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        // Cari tombol DONE dan AppBottomNav
        final doneButtonFinder = find.byKey(const Key('add-done-button'));
        expect(doneButtonFinder, findsOneWidget);

        final doneButtonSize = tester.getSize(doneButtonFinder);
        expect(doneButtonSize.width, equals(300.0));
        expect(doneButtonSize.width, lessThan(365.0)); // Navbar width is 365.0
      },
    );

    testWidgets('Judul langkah is REQUIRED in Detail Langkah dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final prefs = await SharedPreferences.getInstance();
      final router = createRouter(
        initialLocation: '/add',
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

      // Buka sheet Cooking Instructions
      await tester.tap(find.text('Add one or multiple steps'));
      await tester.pumpAndSettle();

      // Tap "Tambah Langkah"
      await tester.tap(find.text('Tambah Langkah'));
      await tester.pumpAndSettle();

      // Dialog "Detail Langkah" terbuka
      expect(find.text('Detail Langkah'), findsOneWidget);
      expect(find.text('Judul Langkah'), findsOneWidget);
      expect(find.text('*'), findsWidgets);

      // Hanya isi deskripsi, tanpa mengisi judul langkah
      final descField = find.widgetWithText(
        TextField,
        'Tuliskan detail langkah...',
      );
      await tester.enterText(descField, 'Hanya menulis deskripsi saja');
      await tester.pump();

      // Tap "Tambahkan"
      await tester.tap(find.text('Tambahkan'));
      await tester.pumpAndSettle();

      // Dialog HARUS TETAP TERBUKA dan muncul error
      expect(find.text('Detail Langkah'), findsOneWidget);
      expect(find.text('Judul langkah wajib diisi'), findsOneWidget);

      // Isi judul langkah
      final titleField = find.widgetWithText(TextField, 'Mis. Tumis Bawang');
      await tester.enterText(titleField, 'Kupas Bawang');
      await tester.pumpAndSettle();

      // Pesan error hilang
      expect(find.text('Judul langkah wajib diisi'), findsNothing);

      // Tap "Tambahkan" lagi
      await tester.tap(find.text('Tambahkan'));
      await tester.pumpAndSettle();

      // Dialog tertutup, langkah muncul di sheet
      expect(find.text('Detail Langkah'), findsNothing);
      expect(find.text('Kupas Bawang'), findsOneWidget);
    });

    testWidgets(
      'DONE button width is smaller than AppBottomNav width (300 < 365)',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        // Cari tombol DONE dan AppBottomNav
        final doneButtonFinder = find.byKey(const Key('add-done-button'));
        expect(doneButtonFinder, findsOneWidget);

        final doneButtonSize = tester.getSize(doneButtonFinder);
        expect(doneButtonSize.width, equals(300.0));
        expect(doneButtonSize.width, lessThan(365.0)); // Navbar width is 365.0
      },
    );

    testWidgets(
      'Judul langkah is REQUIRED in Detail Langkah dialog',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/add',
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

        // Buka sheet Cooking Instructions
        await tester.tap(find.text('Add one or multiple steps'));
        await tester.pumpAndSettle();

        // Tap "Tambah Langkah"
        await tester.tap(find.text('Tambah Langkah'));
        await tester.pumpAndSettle();

        // Dialog "Detail Langkah" terbuka
        expect(find.text('Detail Langkah'), findsOneWidget);
        expect(find.text('Judul Langkah'), findsOneWidget);
        expect(find.text('*'), findsWidgets);

        // Hanya isi deskripsi, tanpa mengisi judul langkah
        final descField = find.widgetWithText(
          TextField,
          'Tuliskan detail langkah...',
        );
        await tester.enterText(descField, 'Hanya menulis deskripsi saja');
        await tester.pump();

        // Tap "Tambahkan"
        await tester.tap(find.text('Tambahkan'));
        await tester.pumpAndSettle();

        // Dialog HARUS TETAP TERBUKA dan muncul error
        expect(find.text('Detail Langkah'), findsOneWidget);
        expect(find.text('Judul langkah wajib diisi'), findsOneWidget);

        // Isi judul langkah
        final titleField = find.widgetWithText(
          TextField,
          'Mis. Tumis Bawang',
        );
        await tester.enterText(titleField, 'Kupas Bawang');
        await tester.pumpAndSettle();

        // Pesan error hilang
        expect(find.text('Judul langkah wajib diisi'), findsNothing);

        // Tap "Tambahkan" lagi
        await tester.tap(find.text('Tambahkan'));
        await tester.pumpAndSettle();

        // Dialog tertutup, langkah muncul di sheet
        expect(find.text('Detail Langkah'), findsNothing);
        expect(find.text('Kupas Bawang'), findsOneWidget);
      },
    );
  });
}
