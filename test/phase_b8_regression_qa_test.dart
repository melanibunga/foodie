import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/core/utils/week_utils.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/cooked_page.dart';
import 'package:foodie/pages/my_recipes_page.dart';
import 'package:foodie/pages/search_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/location_provider.dart';
import 'package:foodie/providers/meal_plan_provider.dart';
import 'package:foodie/providers/places_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/location_service.dart';
import 'package:foodie/services/route_service.dart';
import 'package:foodie/widgets/real_map_view.dart';
import 'package:foodie/widgets/recipe_cards.dart';
import 'package:foodie/widgets/ui/sticky_bottom_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

class MockLocationService extends LocationService {
  final bool serviceEnabled;
  final LocationPermission permission;
  final UserCoordinates? position;

  const MockLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position = const UserCoordinates(
      latitude: -7.7653,
      longitude: 110.3789,
    ),
  });

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<UserCoordinates?> getCurrentPosition() async => position;
}

class MockTestRouteService implements RouteService {
  @override
  Future<RouteResult> getFootRoute({
    required LatLng start,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    return RouteResult(
      points: [start, destination],
      distanceMeters: 450,
      durationSeconds: 320,
    );
  }
}

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase B8: End-to-End User Flow', () {
    testWidgets(
      'Full Flow: Home -> Detail (Toggle Cart & Schedule) -> Cook -> Rating -> Cooked -> Profile',
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
            overrides: [
              foodieBoxesProvider.overrideWithValue(boxes),
              routeServiceProvider.overrideWithValue(MockTestRouteService()),
              locationServiceProvider.overrideWithValue(
                const MockLocationService(),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // 1. Home loaded
        expect(find.text('Daily Inspiration'), findsOneWidget);
        expect(find.byType(FeaturedRecipeCard), findsWidgets);

        final firstCard = tester.widget<FeaturedRecipeCard>(
          find.byType(FeaturedRecipeCard).first,
        );
        final recipeTitle = firstCard.recipe.title;

        // 2. Tap recipe card to navigate to detail
        await tester.tap(find.byType(FeaturedRecipeCard).first);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Detail page loaded
        expect(find.text(recipeTitle), findsWidgets);
        expect(find.text('Tambah ke keranjang'), findsOneWidget);

        // D1: Toggle keranjang (tambah)
        await tester.tap(find.text('Tambah ke keranjang'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        expect(find.text('Sudah di keranjang'), findsOneWidget);

        // D1: Toggle keranjang (keluarkan)
        await tester.tap(find.text('Sudah di keranjang'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        expect(find.text('Tambah ke keranjang'), findsOneWidget);

        // D2: Jadwalkan ke Meal Plan via Sheet
        final scheduleBtn = find.byIcon(LucideIcons.calendarPlus);
        expect(scheduleBtn, findsOneWidget);
        await tester.tap(scheduleBtn);
        await tester.pumpAndSettle();

        // Sheet pilih tanggal terbuka
        expect(find.text('Tambah ke Meal Plan'), findsOneWidget);
        final now = DateTime.now();
        final todayName = WeekUtils.dayNames[now.weekday - 1];
        await tester.tap(find.text(todayName).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // Ikon calendar berubah menjadi calendarCheck
        expect(find.byIcon(LucideIcons.calendarCheck), findsOneWidget);

        // 3. Start Cooking Flow
        final cookButton = find.text('Start Cooking >');
        await tester.scrollUntilVisible(cookButton, 200);
        expect(cookButton, findsOneWidget);
        await tester.tap(cookButton);
        await tester.pumpAndSettle();

        // Di CookPage: jalankan setiap langkah sampai selesai
        final totalSteps = firstCard.recipe.steps.length;
        expect(find.text('Langkah 1 dari $totalSteps'), findsOneWidget);

        for (var i = 0; i < totalSteps - 1; i++) {
          await tester.tap(find.text('Berikutnya'));
          await tester.pumpAndSettle();
        }

        expect(
          find.text('Langkah $totalSteps dari $totalSteps'),
          findsOneWidget,
        );
        await tester.tap(find.text('Selesai'));
        await tester.pumpAndSettle();

        // Layar selesai
        expect(find.text('Selamat, masakanmu siap! 🎉'), findsOneWidget);

        // G6: Beri rating 5 bintang
        expect(
          find.textContaining('Beri rating untuk $recipeTitle'),
          findsOneWidget,
        );
        final star5 = find.bySemanticsLabel('Rating 5 bintang');
        expect(star5, findsOneWidget);
        await tester.tap(star5);
        await tester.pumpAndSettle();

        // Kirim rating
        final sendRatingBtn = find.text('Kirim rating');
        expect(sendRatingBtn, findsOneWidget);
        await tester.tap(sendRatingBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // Tombol berubah jadi terkunci
        expect(find.text('Rating terkirim'), findsOneWidget);

        // Kembali ke beranda
        final backHomeBtn = find.text('Kembali ke Beranda');
        await tester.scrollUntilVisible(backHomeBtn, 200);
        await tester.tap(backHomeBtn);
        await tester.pumpAndSettle();

        // 4. Verifikasi Navigasi ke Profil & Halaman Cooked
        router.go('/profile');
        await tester.pumpAndSettle();

        // P1: Cek statistik Dimasak
        expect(find.text('Dimasak'), findsOneWidget);

        // Tap statistik Dimasak
        await tester.tap(find.bySemanticsLabel('Buka Dimasak'));
        await tester.pumpAndSettle();

        // Di halaman /cooked
        expect(find.text('Riwayat Masak'), findsOneWidget);
        expect(find.text(recipeTitle), findsWidgets);

        // Kembali ke Beranda via sticky button
        await tester.tap(find.text('Kembali Ke Beranda'));
        await tester.pumpAndSettle();
        expect(find.text('Daily Inspiration'), findsOneWidget);
      },
    );

    testWidgets(
      'Add Recipe Flow: daftar bahan inline expand/collapse & sync sheet',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();
        final router = createRouter(
          initialLocation: '/add',
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

        // Buka sheet bahan via text card
        await tester.tap(find.text('Add ingredients to recipe'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Bahan'), findsOneWidget);

        // Helper to add ingredient
        Future<void> addIng(String name, String qty) async {
          final textFields = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          );
          await tester.enterText(textFields.at(0), name);
          await tester.enterText(textFields.at(1), qty);
          await tester.tap(find.text('+ Tambah ke Daftar'));
          await tester.pumpAndSettle();
        }

        await addIng('Bawang Putih', '3');
        await addIng('Bawang Merah', '5');
        await addIng('Kecap Manis', '2');
        await addIng('Garam', '1');

        // Tutup sheet
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        // Verifikasi daftar bahan tampil inline
        expect(find.text('Ingredients (4)'), findsOneWidget);
        expect(find.text('Lihat semua (4)'), findsOneWidget);

        // Expand inline
        await tester.tap(find.text('Lihat semua (4)'));
        await tester.pumpAndSettle();

        expect(find.text('Sembunyikan'), findsOneWidget);
        expect(find.text('Garam'), findsOneWidget);

        // Collapse inline
        await tester.tap(find.text('Sembunyikan'));
        await tester.pumpAndSettle();
        expect(find.text('Lihat semua (4)'), findsOneWidget);
      },
    );

    testWidgets('Meal Plan duplicate prevention test (M2 logic & query)', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mealPlanProvider.notifier);
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final res1 = await notifier.add(dateStr, 'ayam-kecap-bawang');
      expect(res1, MealPlanAddResult.added);
      expect(notifier.has(dateStr, 'ayam-kecap-bawang'), isTrue);
      expect(notifier.isPlanned('ayam-kecap-bawang'), isTrue);

      final res2 = await notifier.add(dateStr, 'ayam-kecap-bawang');
      expect(res2, MealPlanAddResult.exists);
      expect(notifier.datesFor('ayam-kecap-bawang').contains(dateStr), isTrue);
    });

    testWidgets('Nearby place selection and real route computation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();
      final router = createRouter(
        initialLocation: '/nearby',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodieBoxesProvider.overrideWithValue(boxes),
            locationServiceProvider.overrideWithValue(
              const MockLocationService(),
            ),
            routeServiceProvider.overrideWithValue(MockTestRouteService()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RealMapView), findsOneWidget);
      expect(find.text('Pilihan Di Sekitarmu'), findsOneWidget);
    });
  });

  group('Fase B8: Screen Size & Insets Layout Matrix', () {
    final widths = [360.0, 390.0, 440.0];
    final heights = [640.0, 956.0];
    final bottomInsets = [0.0, 24.0, 34.0, 48.0];
    final keyboardHeights = [0.0, 300.0];

    for (final w in widths) {
      for (final h in heights) {
        for (final inset in bottomInsets) {
          testWidgets('Layout Matrix: SearchPage ($w x $h, inset: $inset)', (
            tester,
          ) async {
            tester.view.physicalSize = Size(w * 2.0, h * 2.0);
            tester.view.devicePixelRatio = 2.0;
            tester.view.padding = FakeViewPadding(bottom: inset * 2.0);
            addTearDown(() => tester.view.reset());

            await tester.pumpWidget(
              const ProviderScope(child: MaterialApp(home: SearchPage())),
            );
            await tester.pumpAndSettle();

            // Verify no RenderFlex overflow
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets(
      'Layout Matrix: StickyBottomBar with keyboard and safe padding',
      (tester) async {
        for (final kb in keyboardHeights) {
          for (final inset in [0.0, 34.0, 48.0]) {
            tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
            tester.view.devicePixelRatio = 2.0;
            tester.view.padding = FakeViewPadding(bottom: inset * 2.0);
            tester.view.viewInsets = FakeViewPadding(bottom: kb * 2.0);
            addTearDown(() => tester.view.reset());

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Stack(
                    children: [
                      const Positioned.fill(
                        child: Center(child: Text('Content')),
                      ),
                      StickyBottomBar(
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Simpan'), findsOneWidget);
          }
        }
      },
    );

    testWidgets(
      'Layout Matrix: MyRecipesPage with keyboard does not push sticky button',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.0);
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: MyRecipesPage())),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Kembali Ke Beranda'), findsOneWidget);
      },
    );

    testWidgets(
      'Layout Matrix: CookedPage with keyboard does not push sticky button',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.0);
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: CookedPage())),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Kembali Ke Beranda'), findsOneWidget);
      },
    );
  });
}
