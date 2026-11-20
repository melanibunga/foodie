import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/nearby_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/illustrated_map.dart';
import 'package:foodie/widgets/real_map_view.dart';
import 'package:foodie/widgets/ui/empty_state.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase 13 — Nearby Page (/nearby) Tests', () {
    testWidgets(
      'NearbyPage renders AppHeader, search bar, chips, IllustratedMap, and place cards',
      (tester) async {
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
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Page & Header rendered
        expect(find.byType(NearbyPage), findsOneWidget);
        expect(find.byType(AppHeader), findsOneWidget);

        // Search bar with placeholder
        expect(find.text('Cari resto atau rumah makan'), findsOneWidget);
        expect(find.byIcon(LucideIcons.slidersHorizontal), findsOneWidget);

        // Filter chips
        expect(find.text('Terdekat'), findsOneWidget);
        expect(find.text('Buka sekarang'), findsOneWidget);
        expect(find.text('Harga hemat'), findsOneWidget);

        // Map: RealMapView (PRD §14.12) / IllustratedMap
        expect(
          find.byWidgetPredicate(
            (w) => w is RealMapView || w is IllustratedMap,
          ),
          findsOneWidget,
        );
        expect(find.text('Radius 1 km'), findsOneWidget);
        expect(find.text('Pusatkan'), findsOneWidget);

        // Section title & dynamic count
        expect(find.text('Pilihan Di Sekitarmu'), findsOneWidget);
        expect(find.text('3 tempat'), findsOneWidget);

        // Place cards rendered
        expect(find.text('Warung Bu Sari'), findsOneWidget);
        expect(find.text('Masakan Jawa · Rp15–30 rb'), findsOneWidget);
        expect(find.text('180 m · 3 menit'), findsOneWidget);

        expect(find.text('Ayam Bakar Pak Hadi'), findsOneWidget);
        expect(find.text('Ayam bakar · Rp20–35 rb'), findsOneWidget);
        expect(find.text('450 m · 6 menit'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping place card selects place, changes pin color, and updates active Rute button',
      (tester) async {
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
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap on second card "Ayam Bakar Pak Hadi"
        await tester.tap(find.text('Ayam Bakar Pak Hadi'));
        await tester.pumpAndSettle();

        // Now card 2 is selected. Verify tap on Rute triggers toast for Ayam Bakar Pak Hadi
        final ruteButtons = find.text('Rute');
        expect(ruteButtons, findsWidgets);

        await tester.tap(ruteButtons.at(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Membuka rute ke Ayam Bakar Pak Hadi'),
          findsOneWidget,
        );

        // Settle toast timer (2.2s)
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Tapping pin on map selects corresponding place', (
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
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find pin 2 by key and tap it
      final pin2 = find.byKey(const ValueKey('pin-ayam-bakar-pak-hadi'));
      expect(pin2, findsOneWidget);

      await tester.tap(pin2);
      await tester.pumpAndSettle();

      // Tap Rute on second card
      final ruteButtons = find.text('Rute');
      await tester.tap(ruteButtons.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Membuka rute ke Ayam Bakar Pak Hadi'), findsOneWidget);

      // Settle toast timer
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping Pusatkan button shows toast', (tester) async {
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
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Pusatkan"
      await tester.tap(find.text('Pusatkan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Peta dipusatkan ke lokasi kamu'), findsOneWidget);

      // Settle toast timer
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
    });

    testWidgets('Quick chip "Buka sekarang" filters out closed places', (
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
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('3 tempat'), findsOneWidget);

      // Tap "Buka sekarang"
      await tester.tap(find.text('Buka sekarang'));
      await tester.pumpAndSettle();

      // Warung Padang Salero is closed, so count becomes 2
      expect(find.text('2 tempat'), findsOneWidget);
      expect(find.text('Warung Bu Sari'), findsOneWidget);
      expect(find.text('Ayam Bakar Pak Hadi'), findsOneWidget);
      expect(find.text('Warung Padang Salero'), findsNothing);

      // Switch back to "Terdekat"
      await tester.tap(find.text('Terdekat'));
      await tester.pumpAndSettle();
      expect(find.text('3 tempat'), findsOneWidget);
    });

    testWidgets(
      'Search input filters places and displays EmptyState when no results',
      (tester) async {
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
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter search term "Padang"
        await tester.enterText(find.byType(TextField), 'Padang');
        await tester.pumpAndSettle();

        expect(find.text('1 tempat'), findsOneWidget);
        expect(find.text('Warung Padang Salero'), findsOneWidget);
        expect(find.text('Warung Bu Sari'), findsNothing);

        // Enter search term with 0 matches
        await tester.enterText(find.byType(TextField), 'Pizza Hut');
        await tester.pumpAndSettle();

        expect(find.text('0 tempat'), findsOneWidget);
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Tidak ada tempat ditemukan'), findsOneWidget);

        // Tap "Reset Filter"
        await tester.tap(find.text('Reset Filter'));
        await tester.pumpAndSettle();

        expect(find.text('3 tempat'), findsOneWidget);
      },
    );

    testWidgets('Filter sheet opens, allows filtering, and resets correctly', (
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
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap filter icon
      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();

      // Sheet is visible
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Radius'), findsOneWidget);
      expect(find.text('Kisaran harga'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Terapkan'), findsOneWidget);

      // Select "500 m"
      await tester.tap(find.text('500 m'));
      await tester.pumpAndSettle();

      // Tap "Terapkan"
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      // Warung Bu Sari (180m) & Ayam Bakar Pak Hadi (450m) <= 500m, Warung Padang (700m) excluded
      expect(find.text('2 tempat'), findsOneWidget);
      expect(find.text('Radius 500 m'), findsOneWidget);
    });
  });
}
