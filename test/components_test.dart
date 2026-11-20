import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/recipes.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/widgets.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FoodieBoxes boxes;

  setUp(() async {
    boxes = await initTestBoxes();
  });

  Widget wrapWithTheme(Widget child) {
    return ProviderScope(
      overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Fase 3 — Reusable UI Components Tests', () {
    testWidgets('AppButton renders label and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppButton(label: 'Uji Tombol', onPressed: () => tapped = true),
        ),
      );

      expect(find.text('Uji Tombol'), findsOneWidget);
      await tester.tap(find.text('Uji Tombol'));
      expect(tapped, true);
    });

    testWidgets('AppChip displays label and handles selection', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return AppChip(
                label: 'Ayam',
                selected: selected,
                onTap: () => setState(() => selected = !selected),
              );
            },
          ),
        ),
      );

      expect(find.text('Ayam'), findsOneWidget);
      await tester.tap(find.text('Ayam'));
      await tester.pump();
      expect(selected, true);
    });

    testWidgets('AppInput supports normal and password obscure toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(const AppInput(label: 'Kata Sandi', isPassword: true)),
      );

      expect(find.text('Kata Sandi'), findsOneWidget);
      final iconButton = find.byType(IconButton);
      expect(iconButton, findsOneWidget);
      await tester.tap(iconButton);
      await tester.pump();
    });

    testWidgets('AppCheckbox toggles state', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return AppCheckbox(
                value: checked,
                onChanged: (v) => setState(() => checked = v),
              );
            },
          ),
        ),
      );

      expect(find.byType(AppCheckbox), findsOneWidget);
      await tester.tap(find.byType(AppCheckbox));
      await tester.pump();
      expect(checked, true);
    });

    testWidgets('AppToggle toggles state', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return AppToggle(
                value: toggled,
                onChanged: (v) => setState(() => toggled = v),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(AppToggle));
      await tester.pump();
      expect(toggled, true);
    });

    testWidgets(
      'ImagePlaceholder & SmartImage fallback to placeholder on null src',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            const Column(
              children: [
                SmartImage(src: null, width: 80, height: 80),
                ImagePlaceholder(
                  width: 48,
                  height: 48,
                  isCircle: true,
                  initials: 'NC',
                ),
              ],
            ),
          ),
        );

        expect(find.byType(ImagePlaceholder), findsNWidgets(2));
        expect(find.text('NC'), findsOneWidget);
      },
    );

    testWidgets('AppHeader displays avatar initials and counter badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(const AppHeader(includeTopPadding: false)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('AppBottomNav renders 5 tabs and highlights active tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Stack(children: [AppBottomNav(currentRoute: '/home')]),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
    });

    testWidgets(
      'FeaturedRecipeCard displays recipe information and CTA button',
      (tester) async {
        final recipe = seedRecipes.first; // Ayam Kecap Bawang
        var opened = false;

        await tester.pumpWidget(
          wrapWithTheme(
            Center(
              child: SizedBox(
                width: 330,
                child: FeaturedRecipeCard(
                  recipe: recipe,
                  onOpen: () => opened = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Ayam Kecap Bawang'), findsOneWidget);
        expect(find.text('Lihat Resep'), findsOneWidget);
        expect(find.text('25 Menit'), findsOneWidget);

        await tester.tap(find.text('Lihat Resep'));
        expect(opened, true);
      },
    );

    testWidgets('GridRecipeCard displays recipe and quick-add button', (
      tester,
    ) async {
      final recipe = seedRecipes[2]; // Soto Ayam
      var quickAdded = false;

      await tester.pumpWidget(
        wrapWithTheme(
          Center(
            child: SizedBox(
              width: 190,
              child: GridRecipeCard(
                recipe: recipe,
                onQuickAdd: () => quickAdded = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Soto Ayam'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.plusCircle));
      expect(quickAdded, true);
    });

    testWidgets('PageWithNav adds 120 bottom padding', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const PageWithNav(child: Text('Konten'))),
      );

      final paddingWidget = tester.widget<Padding>(find.byType(Padding).first);
      expect(paddingWidget.padding, const EdgeInsets.only(bottom: 120.0));
    });
  });
}
