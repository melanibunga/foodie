import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase B5 — Add Recipe: Daftar Ingredients Tests', () {
    testWidgets(
      'Layout without ingredients: inline list is not shown, identical to add.jpg',
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

        // 1. Two-column boxes are present
        expect(find.text('Add Cover Image'), findsWidgets);
        expect(find.text('Ingredients'), findsOneWidget);
        expect(find.text('Add ingredients to recipe'), findsOneWidget);

        // 2. Inline ingredients list is NOT displayed
        expect(find.textContaining('Ingredients ('), findsNothing);
        expect(find.byIcon(LucideIcons.trash2), findsNothing);
      },
    );

    testWidgets(
      'Adding 1, 3, and 6 ingredients displays list, triggers "Lihat semua (N)" and "Sembunyikan"',
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

        // Open Ingredients Sheet
        await tester.tap(find.text('Add ingredients to recipe'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Bahan'), findsOneWidget);

        // Helper to add ingredient in sheet
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

        // Add 1st ingredient
        await addIng('Bawang Merah', '4');

        // Tap Simpan
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        // 1. Title shows "Ingredients (1)"
        expect(find.text('Ingredients (1)'), findsOneWidget);
        expect(find.text('Bawang Merah'), findsOneWidget);
        expect(find.text('4 g'), findsOneWidget);
        expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
        // "Lihat semua" should not appear for <= 3 items
        expect(find.textContaining('Lihat semua'), findsNothing);

        // 2. Re-open sheet and add 2 more ingredients (total 3)
        await tester.tap(find.text('1 ingredients'));
        await tester.pumpAndSettle();

        await addIng('Bawang Putih', '2');
        await addIng('Cabai Rawit', '5');

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('Ingredients (3)'), findsOneWidget);
        expect(find.text('Bawang Merah'), findsOneWidget);
        expect(find.text('Bawang Putih'), findsOneWidget);
        expect(find.text('Cabai Rawit'), findsOneWidget);
        expect(find.textContaining('Lihat semua'), findsNothing);

        // 3. Re-open sheet and add 3 more ingredients (total 6)
        await tester.tap(find.text('3 ingredients'));
        await tester.pumpAndSettle();

        await addIng('Garam', '1');
        await addIng('Merica', '1');
        await addIng('Kecap Manis', '2');

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('Ingredients (6)'), findsOneWidget);

        // For > 3 items: initial state shows first 3 + "Lihat semua (6)"
        expect(find.text('Bawang Merah'), findsOneWidget);
        expect(find.text('Bawang Putih'), findsOneWidget);
        expect(find.text('Cabai Rawit'), findsOneWidget);
        // 4th, 5th, 6th are hidden initially
        expect(find.text('Garam'), findsNothing);
        expect(find.text('Merica'), findsNothing);
        expect(find.text('Kecap Manis'), findsNothing);

        final expandLink = find.text('Lihat semua (6)');
        expect(expandLink, findsOneWidget);

        // Tap "Lihat semua (6)" -> all 6 items visible
        await tester.tap(expandLink);
        await tester.pumpAndSettle();

        expect(find.text('Garam'), findsOneWidget);
        expect(find.text('Merica'), findsOneWidget);
        expect(find.text('Kecap Manis'), findsOneWidget);
        expect(find.text('Sembunyikan'), findsOneWidget);

        // Tap "Sembunyikan" -> collapses back to 3
        await tester.tap(find.text('Sembunyikan'));
        await tester.pumpAndSettle();

        expect(find.text('Garam'), findsNothing);
        expect(find.text('Lihat semua (6)'), findsOneWidget);
      },
    );

    testWidgets(
      'Deleting item from inline list removes it and synchronizes with sheet',
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

        // Open sheet and add 2 ingredients
        await tester.tap(find.text('Add ingredients to recipe'));
        await tester.pumpAndSettle();

        final textFields = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );
        await tester.enterText(textFields.at(0), 'Gula Pasir');
        await tester.enterText(textFields.at(1), '2');
        await tester.tap(find.text('+ Tambah ke Daftar'));
        await tester.pumpAndSettle();

        await tester.enterText(textFields.at(0), 'Garam');
        await tester.enterText(textFields.at(1), '1');
        await tester.tap(find.text('+ Tambah ke Daftar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('Ingredients (2)'), findsOneWidget);
        expect(find.text('Gula Pasir'), findsOneWidget);
        expect(find.text('Garam'), findsOneWidget);

        // Delete 'Gula Pasir' using trash icon on inline list
        final deleteGula = find.bySemanticsLabel('Hapus Gula Pasir');
        expect(deleteGula, findsOneWidget);
        await tester.tap(deleteGula);
        await tester.pumpAndSettle();

        // Now count is 1, only Garam remains
        expect(find.text('Ingredients (1)'), findsOneWidget);
        expect(find.text('Gula Pasir'), findsNothing);
        expect(find.text('Garam'), findsOneWidget);

        // Open sheet again -> verify Gula Pasir is not in the sheet either
        await tester.tap(find.text('1 ingredients'));
        await tester.pumpAndSettle();

        final sheetFinder = find.byType(BottomSheet);
        expect(
          find.descendant(
            of: sheetFinder,
            matching: find.textContaining('Gula Pasir'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: sheetFinder,
            matching: find.textContaining('Garam'),
          ),
          findsOneWidget,
        );

        // Close sheet
        await tester.tap(find.byIcon(LucideIcons.x));
        await tester.pumpAndSettle();

        // Delete remaining 'Garam' from inline list
        final deleteGaram = find.bySemanticsLabel('Hapus Garam');
        await tester.tap(deleteGaram);
        await tester.pumpAndSettle();

        // Now empty -> list is completely gone, box returns to "Add ingredients to recipe"
        expect(find.textContaining('Ingredients ('), findsNothing);
        expect(find.text('Add ingredients to recipe'), findsOneWidget);
      },
    );

    testWidgets(
      'Fokus & keyboard: saving ingredients sheet does not autofocus Recipe Title',
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

        // Tap Add ingredients box to open sheet
        await tester.tap(find.text('Add ingredients to recipe'));
        await tester.pumpAndSettle();

        // Tap Simpan directly
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        // Title input should NOT have focus!
        final titleField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Type your recipe name here'),
        );
        expect(titleField.focusNode?.hasFocus, isFalse);
      },
    );
  });
}
