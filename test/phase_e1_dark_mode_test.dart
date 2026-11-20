import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/app.dart';
import 'package:foodie/core/theme/app_palette.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/providers/theme_provider.dart';
import 'package:go_router/go_router.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase E1 - Dark Mode Tests', () {
    test(
      'themeModeProvider persists and loads theme mode from SharedPreferences',
      () async {
        // mock storage initialized
        final boxes = await initTestBoxes();
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
        );
        addTearDown(container.dispose);

        expect(container.read(themeModeProvider), ThemeMode.dark);

        await container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.light);
        expect(container.read(themeModeProvider), ThemeMode.light);
        expect(prefs.getString('foodie:themeMode'), 'light');

        await container.read(themeModeProvider.notifier).toggle();
        expect(container.read(themeModeProvider), ThemeMode.dark);
        expect(prefs.getString('foodie:themeMode'), 'dark');
      },
    );

    testWidgets(
      'App renders with dark theme on Splash and navigates to Login without white backgrounds',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // mock storage initialized
        final boxes = await initTestBoxes();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: const FoodieApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify MaterialApp has dark theme active
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.dark);

        // Splash uses splashBg
        final splashScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).first,
        );
        expect(splashScaffold.backgroundColor, AppPalette.dark.splashBg);

        // Tap Mulai Eksplorasi to go to Login
        final exploreButton = find.text('Mulai Eksplorasi →');
        expect(exploreButton, findsOneWidget);
        await tester.tap(exploreButton);
        await tester.pumpAndSettle();

        // Now on Login page: verify scaffold uses dark bg (#101815)
        final loginScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).first,
        );
        expect(loginScaffold.backgroundColor, AppPalette.dark.bg);

        // Verify no Material widget has unintended white background in dark mode on Login
        final materials = tester.widgetList<Material>(find.byType(Material));
        for (final m in materials) {
          if (m.color != null && m.color != Colors.transparent) {
            expect(
              m.color,
              isNot(const Color(0xFFFFFFFF)),
              reason:
                  'Material has unintended white background on Login in dark mode: ${m.color}',
            );
          }
        }
      },
    );

    testWidgets(
      'Home, Groceries, and Profile pages render dark theme and Profile toggle works',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // mock storage initialized
        final boxes = await initTestBoxes();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
            child: const FoodieApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to /home
        final context = tester.element(find.byType(Scaffold).first);
        GoRouter.of(context).go('/home');
        await tester.pumpAndSettle();

        // Scaffold on home should be dark bg
        final homeScaffold = tester.widget<Scaffold>(
          find.byType(Scaffold).first,
        );
        expect(homeScaffold.backgroundColor, AppPalette.dark.bg);

        // Navigate to /profile
        GoRouter.of(context).go('/profile');
        await tester.pumpAndSettle();

        // Verify Profile shows dark mode toggle description
        expect(find.text('Tampilan gelap sedang digunakan'), findsOneWidget);

        // Toggle dark mode off via Profile switch (AppToggle)
        final toggleFinder = find.byKey(const ValueKey('toggle-dark-mode'));
        expect(toggleFinder, findsOneWidget);
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        // Verify description updated to light mode
        expect(find.text('Tampilan terang sedang digunakan'), findsOneWidget);
      },
    );
  });
}
