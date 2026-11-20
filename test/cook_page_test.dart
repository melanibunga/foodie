import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/cook_page.dart';
import 'package:foodie/pages/home_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase 8 — Start Cooking Page Tests', () {
    testWidgets(
      'CookPage renders top bar, step 1 details, and navigation button',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang/cook',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // CookPage should be present
        expect(find.byType(CookPage), findsOneWidget);

        // Top bar elements
        expect(find.byIcon(LucideIcons.x), findsOneWidget);
        expect(find.text('Langkah 1 dari 4'), findsOneWidget);

        // Step 1 details
        expect(find.text('1'), findsWidgets); // In circle
        expect(find.text('Siapkan Bahan'), findsOneWidget);
        expect(
          find.textContaining('Potong ayam seukuran satu suapan'),
          findsOneWidget,
        );

        // First step: Only "Berikutnya" button
        expect(find.text('Berikutnya'), findsOneWidget);
        expect(find.text('Sebelumnya'), findsNothing);
      },
    );

    testWidgets(
      'Tapping Berikutnya advances step and shows timer chip on step 2',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang/cook',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Tap "Berikutnya"
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();

        // Step 2 should now be visible
        expect(find.text('Langkah 2 dari 4'), findsOneWidget);
        expect(find.text('Tumis Bawang'), findsOneWidget);
        expect(find.text('Sebelumnya'), findsOneWidget);
        expect(find.text('Berikutnya'), findsOneWidget);

        // Step 2 has 3 minutes duration -> Timer chip visible
        expect(find.textContaining('⏱ 3 menit'), findsOneWidget);
        expect(find.text('Mulai'), findsOneWidget);

        // Tap "Mulai" to start countdown
        await tester.tap(find.text('Mulai'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Timer should be running and display "Jeda"
        expect(find.text('Jeda'), findsOneWidget);
        expect(find.textContaining('02:59'), findsOneWidget);

        // Tap "Jeda" to pause countdown
        await tester.tap(find.text('Jeda'));
        await tester.pumpAndSettle();
        expect(find.text('Mulai'), findsOneWidget);
      },
    );

    testWidgets('Swiping PageView backwards and forwards works seamlessly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/recipe/ayam-kecap-bawang/cook',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Swipe left on PageView to advance to step 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Langkah 2 dari 4'), findsOneWidget);
      expect(find.text('Tumis Bawang'), findsOneWidget);

      // Tap "Sebelumnya" to go back to step 1
      await tester.tap(find.text('Sebelumnya'));
      await tester.pumpAndSettle();

      expect(find.text('Langkah 1 dari 4'), findsOneWidget);
      expect(find.text('Siapkan Bahan'), findsOneWidget);
    });

    testWidgets(
      'Navigating to last step shows Selesai button, finishes cooking, and increments user.cooked',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();
        late WidgetRef refHolder;

        final router = createRouter(
          initialLocation: '/recipe/ayam-kecap-bawang/cook',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: Consumer(
              builder: (context, ref, child) {
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

        await refHolder
            .read(authProvider.notifier)
            .login(email: seedUser.email, password: 'password123');
        await tester.pumpAndSettle();

        final initialCooked = refHolder.read(currentUserProvider)?.cooked ?? 0;
        expect(initialCooked, equals(seedUser.cooked)); // 12

        // Step 1 -> Step 2
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();

        // Step 2 -> Step 3
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 3 dari 4'), findsOneWidget);

        // Step 3 -> Step 4 (last step)
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 4 dari 4'), findsOneWidget);
        expect(find.text('Sajikan Selagi Hangat'), findsOneWidget);

        // Button on last step should be "Selesai" (amber)
        final finishButton = find.text('Selesai');
        expect(finishButton, findsOneWidget);

        // Tap "Selesai"
        await tester.tap(finishButton);
        await tester.pumpAndSettle();

        // Completion screen shown
        expect(find.text('Selamat, masakanmu siap! 🎉'), findsOneWidget);
        expect(find.textContaining('Ayam Kecap Bawang'), findsWidgets);
        expect(find.text('Kembali ke Beranda'), findsOneWidget);

        // User cooked count incremented by 1
        final updatedCooked = refHolder.read(currentUserProvider)?.cooked ?? 0;
        expect(updatedCooked, equals(initialCooked + 1)); // 13

        // Tap "Kembali ke Beranda"
        await tester.tap(find.text('Kembali ke Beranda'));
        await tester.pumpAndSettle();

        // Should be navigated to /home
        expect(find.byType(HomePage), findsOneWidget);
      },
    );

    testWidgets('Tapping close button (x) navigates back', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/recipe/ayam-kecap-bawang',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // From detail page, tap "Start Cooking >"
      await tester.ensureVisible(find.text('Start Cooking >'));
      await tester.tap(find.text('Start Cooking >'));
      await tester.pumpAndSettle();

      expect(find.byType(CookPage), findsOneWidget);

      // Tap close button (x)
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      // Should be back at recipe detail page
      expect(find.byType(CookPage), findsNothing);
      expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
    });
  });
}
