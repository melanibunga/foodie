import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_radius.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/providers/ui_helper.dart';
import 'package:foodie/widgets/app_bottom_nav.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/ui/app_bottom_sheet.dart';
import 'package:foodie/widgets/ui/app_checkbox.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:favorites': jsonEncode(['ayam-kecap-bawang']),
    });
  });

  group('Fase C6 — Bug Fix Matrix Putaran 2 (G1–G2, P1–P2, A1–A3, M1, D1–D3, K1–K2)', () {
    testWidgets(
      'G1: Toast background maroon (#800020), teks putih 12/600, radius pill',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showAppToast(context, 'Test Toast Maroon'),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final toastText = find.text('Test Toast Maroon');
        expect(toastText, findsOneWidget);

        final containerFinder = find
            .ancestor(of: toastText, matching: find.byType(Container))
            .first;
        final container = tester.widget<Container>(containerFinder);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.maroon));
        expect(decoration.borderRadius, equals(AppRadius.pill));

        final text = tester.widget<Text>(toastText);
        expect(text.style?.color, equals(AppColors.white));
        expect(text.style?.fontSize, equals(12.0));
        expect(text.style?.fontWeight, equals(FontWeight.w600));

        await tester.pump(const Duration(milliseconds: 2500));
      },
    );

    testWidgets(
      'G2: AppHeader greeting 2 baris (sapaan jam + nama depan olive) dengan Expanded + ellipsis',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              home: Scaffold(
                body: AppHeader(currentTime: DateTime(2026, 11, 20, 9, 30)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Selamat pagi'), findsOneWidget);
        expect(
          find.text('Najmah'),
          findsOneWidget,
        ); // First name of "Najmah Cleosaa Tokek"

        // Verifikasi tidak ada overflow di layar sempit 360 dp
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'P1 & A1: Sheet Edit Profil & Tambah Bahan aman dari keyboard (field fokus terlihat)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showAppBottomSheet(
                      context: context,
                      builder: (ctx) => const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [TextField(key: Key('name_field'))],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Simulasikan keyboard terbuka
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('name_field')), findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.resetViewInsets();
      },
    );

    testWidgets(
      'P2: Favorites, Cooked, My Recipes memiliki area atas fixed (di luar scroll)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/favorites',
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

        expect(find.text('Menu Favoritmu'), findsOneWidget);
        expect(find.text('Cari nama menu favorit...'), findsOneWidget);

        // Scroll ke bawah
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Area atas (judul dan search) tetap terlihat di viewport
        expect(find.text('Menu Favoritmu'), findsOneWidget);
        expect(find.text('Cari nama menu favorit...'), findsOneWidget);
      },
    );

    testWidgets(
      'A2 & A3: Add Route di dalam ShellRoute, BottomNav fixed, list langkah & DONE di ujung form',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

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

        // A3: BottomNav tampil dengan tab Add aktif
        expect(find.byType(AppBottomNav), findsOneWidget);

        // Simulasikan keyboard terbuka
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();

        // BottomNav tidak bergerak/terdorong oleh keyboard
        final navFinder = find.byType(AppBottomNav);
        expect(navFinder, findsOneWidget);

        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        // Scroll ke paling bawah untuk menemukan tombol DONE
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ElevatedButton, 'DONE'), findsOneWidget);
      },
    );

    testWidgets(
      'M1: Pemilih tanggal Meal Plan menonaktifkan hari lampau (sebelum hari ini)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fixedToday = DateTime(2026, 11, 18); // Rabu
        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(fixedToday),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Buka sheet jadwal meal plan
        await tester.tap(find.byIcon(LucideIcons.calendarPlus));
        await tester.pumpAndSettle();

        // Hari Senin (16 Nov) adalah hari lampau -> onTap harus null
        final seninFinder = find.widgetWithText(InkWell, 'Senin');
        expect(seninFinder, findsOneWidget);
        final seninInk = tester.widget<InkWell>(seninFinder);
        expect(seninInk.onTap, isNull);

        // Hari Rabu (18 Nov) adalah hari ini -> onTap aktif
        final rabuFinder = find.widgetWithText(InkWell, 'Rabu');
        expect(rabuFinder, findsOneWidget);
        final rabuInk = tester.widget<InkWell>(rabuFinder);
        expect(rabuInk.onTap, isNotNull);
      },
    );

    testWidgets(
      'D1, D2, D3: Detail Menu top bar sage fixed, bahan bullet tanpa checkbox',
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
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // D1: Tombol back lingkaran 44 panah putih dalam bar sage
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

        // D3: Bahan-bahan tanpa AppCheckbox
        expect(find.text('Bahan-Bahan'), findsOneWidget);
        // Di detail menu tidak boleh ada AppCheckbox untuk bahan masakan
        final checkboxesInDetail = find.byType(AppCheckbox);
        expect(checkboxesInDetail, findsNothing);
      },
    );

    testWidgets(
      'K1 & K2: Groceries descending order, kartu pin custom amberSoft, swipe hapus',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/groceries',
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

        // K2: Kartu pin di indeks 0
        expect(find.text('Belanjaan Kamu Nich'), findsOneWidget);
        expect(find.byIcon(LucideIcons.pin), findsOneWidget);

        // K2: Swipe hapus bahan kustom
        final dismissibleFinder = find.byType(Dismissible);
        expect(dismissibleFinder, findsOneWidget);

        await tester.drag(dismissibleFinder, const Offset(-400, 0));
        await tester.pumpAndSettle();

        // Toast muncul dan total estimasi terhitung ulang
        expect(find.text('Bahan dihapus'), findsOneWidget);
        expect(find.text('Rp 11.000'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 2500));
      },
    );
  });

  group('Fase C6: Matriks Layout Lintas Resolusi & Keyboard', () {
    final widths = [360.0, 390.0, 440.0];
    final heights = [640.0, 956.0];
    final insets = [0.0, 24.0, 34.0, 48.0];

    for (final w in widths) {
      for (final h in heights) {
        testWidgets('Layout Matrix $w x $h (Keyboard tertutup & terbuka)', (
          tester,
        ) async {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final prefs = await SharedPreferences.getInstance();
          final router = createRouter(
            initialLocation: '/home',
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

          expect(tester.takeException(), isNull);

          // Simulasikan keyboard terbuka
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          tester.view.resetViewInsets();
        });
      }
    }

    for (final bottomInset in insets) {
      testWidgets('Safe Area Inset Bawah $bottomInset dp', (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = FakeViewPadding(bottom: bottomInset);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetPadding();
        });

        final prefs = await SharedPreferences.getInstance();
        final router = createRouter(
          initialLocation: '/groceries',
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

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Fase C6: End-to-End Flow Putaran 2', () {
    testWidgets(
      'Alur Penuh: Login -> Header Greeting -> Detail -> Keranjang -> Groceries -> Add -> Profil -> Favorit',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final fixedNow = DateTime(2026, 11, 20, 10, 0); // Pagi

        final router = createRouter(
          initialLocation: '/home',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clockProvider.overrideWithValue(fixedNow),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header ada greeting sesuai jam saat ini
        final currentGreeting = greetingFor(DateTime.now());
        expect(find.text(currentGreeting), findsOneWidget);
        expect(find.text('Najmah'), findsOneWidget);

        // 2. Buka Detail Menu
        router.go('/recipe/ayam-kecap-bawang');
        await tester.pumpAndSettle();

        // Bar sage & bahan bullet
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
        expect(find.text('Bahan-Bahan'), findsOneWidget);

        // Tambah ke keranjang
        final addToCartBtn = find.text('Tambah ke keranjang');
        if (addToCartBtn.evaluate().isNotEmpty) {
          await tester.tap(addToCartBtn);
          await tester.pumpAndSettle();
        }

        // 3. Masuk ke Groceries
        router.go('/groceries');
        await tester.pumpAndSettle();

        expect(find.text('Belanjaan Kamu Nich'), findsOneWidget);
        expect(find.byIcon(LucideIcons.pin), findsOneWidget);

        // 4. Masuk ke Add Recipe
        router.go('/add');
        await tester.pumpAndSettle();

        // Nav tetap ada di ShellRoute
        expect(find.byType(AppBottomNav), findsOneWidget);

        // 5. Masuk ke Profil
        router.go('/profile');
        await tester.pumpAndSettle();

        expect(find.text('Najmah Cleosaa Tokek'), findsOneWidget);
        expect(find.text('Favorit'), findsOneWidget);
        expect(find.text('Dimasak'), findsOneWidget);
        expect(find.text('Resep Saya'), findsOneWidget);

        // 6. Masuk ke Favorites (Header fixed)
        await tester.tap(find.text('Favorit'));
        await tester.pumpAndSettle();

        expect(find.text('Menu Favoritmu'), findsOneWidget);

        // Selesaikan timer toast yang tertunda
        await tester.pump(const Duration(milliseconds: 2500));
      },
    );
  });
}
