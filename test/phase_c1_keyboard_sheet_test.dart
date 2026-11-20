import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase C1 — Keyboard Inset & Sheet Focus Reproduction Tests (PRD §15.4)', () {
    const screenWidth = 440.0;
    const screenHeight = 956.0;
    const keyboardHeight = 300.0;
    final paddingVariants = [0.0, 24.0, 48.0];

    for (final pad in paddingVariants) {
      testWidgets(
        'Edit Profil Sheet (viewPadding bottom $pad): focused field remains visible above keyboard & Simpan accessible',
        (tester) async {
          tester.view.physicalSize = const Size(screenWidth, screenHeight);
          tester.view.devicePixelRatio = 1.0;
          tester.view.padding = FakeViewPadding(bottom: pad);
          tester.view.viewPadding = FakeViewPadding(bottom: pad);
          addTearDown(() => tester.view.reset());

          final boxes = await initTestBoxes();
          final router = createRouter(
            initialLocation: '/profile',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
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

          // 1. Buka sheet Edit Profil lewat tombol aslinya
          final editProfileButton = find.text('Edit profil');
          expect(editProfileButton, findsOneWidget);
          await tester.tap(editProfileButton);
          await tester.pumpAndSettle();

          expect(find.text('Edit Profil'), findsOneWidget);

          // 2. Saat keyboard tertutup: tinggi sheet <= screenHeight - topChrome
          final sheetFinder = find.byKey(
            const Key('app_bottom_sheet_container'),
          );
          expect(sheetFinder, findsOneWidget);
          final sheetRectClosed = tester.getRect(sheetFinder);
          expect(sheetRectClosed.height, lessThanOrEqualTo(screenHeight));

          // 3. Tombol Simpan tidak tertutup navigasi sistem saat keyboard tertutup
          final saveButton = find.text('Simpan');
          expect(saveButton, findsOneWidget);
          final saveRectClosed = tester.getRect(saveButton);
          expect(saveRectClosed.bottom, lessThanOrEqualTo(screenHeight - pad));

          // 4. Simulasikan keyboard muncul (300 dp)
          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboardHeight,
          );
          await tester.pump();
          await tester.pumpAndSettle();

          // 5. Fokus ke field Nama Lengkap
          final nameField = find.widgetWithText(TextField, seedUser.name);
          expect(nameField, findsOneWidget);
          await tester.tap(nameField);
          await tester.pumpAndSettle();

          // 6. Ukur Rect global field yang fokus
          final fieldRect = tester.getRect(nameField);
          final visibleBottom = screenHeight - keyboardHeight;

          // Assert: field berada di atas keyboard dan di bawah status bar
          expect(
            fieldRect.bottom,
            lessThanOrEqualTo(visibleBottom - 8.0),
            reason:
                'Field bottom (${fieldRect.bottom}) harus berada di atas keyboard ($visibleBottom)',
          );
          expect(
            fieldRect.top,
            greaterThanOrEqualTo(0.0),
            reason:
                'Field top (${fieldRect.top}) tidak boleh keluar dari atas layar',
          );

          // 7. Tombol Simpan tetap dapat dijangkau lewat scroll saat keyboard aktif
          final sheetScrollable = find
              .descendant(
                of: find.byKey(const Key('app_bottom_sheet_container')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            saveButton,
            50.0,
            scrollable: sheetScrollable,
          );
          expect(saveButton, findsOneWidget);
          final saveRectOpen = tester.getRect(saveButton);
          expect(
            saveRectOpen.bottom,
            lessThanOrEqualTo(visibleBottom),
            reason:
                'Tombol Simpan setelah di-scroll harus berada di atas keyboard',
          );
        },
      );
    }

    testWidgets(
      'Tambah Bahan Sheet: focused TextField and buttons stay within visible area',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 34.0);
        addTearDown(() => tester.view.reset());

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

        // 1. Buka sheet Tambah Bahan
        final addIngredientsBox = find.text('Add ingredients to recipe');
        expect(addIngredientsBox, findsOneWidget);
        await tester.tap(addIngredientsBox);
        await tester.pumpAndSettle();

        expect(find.text('Tambah Bahan'), findsOneWidget);

        // 2. Simulasikan keyboard muncul (300 dp)
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
        await tester.pump();
        await tester.pumpAndSettle();

        // 3. Fokus ke field Nama Bahan
        final nameField = find.widgetWithText(TextField, 'Mis. Bawang merah');
        expect(nameField, findsOneWidget);
        await tester.tap(nameField);
        await tester.pumpAndSettle();

        final visibleBottom = screenHeight - keyboardHeight;
        final nameRect = tester.getRect(nameField);
        expect(nameRect.bottom, lessThanOrEqualTo(visibleBottom - 8.0));

        // 4. Fokus ke field Jumlah
        final qtyField = find.widgetWithText(TextField, 'Mis. 4');
        expect(qtyField, findsOneWidget);
        await tester.tap(qtyField);
        await tester.pumpAndSettle();

        final qtyRect = tester.getRect(qtyField);
        expect(qtyRect.bottom, lessThanOrEqualTo(visibleBottom - 8.0));

        // 5. Tombol Simpan dapat dijangkau
        final saveBtn = find.descendant(
          of: find.byKey(const Key('app_bottom_sheet_container')),
          matching: find.text('Simpan'),
        );
        final sheetScrollable = find
            .descendant(
              of: find.byKey(const Key('app_bottom_sheet_container')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          saveBtn,
          50.0,
          scrollable: sheetScrollable,
        );
        expect(saveBtn, findsOneWidget);
        final saveRect = tester.getRect(saveBtn);
        expect(saveRect.bottom, lessThanOrEqualTo(visibleBottom));
      },
    );

    testWidgets(
      'Langkah Memasak Sheet: steps list and save button accessible with keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(screenWidth, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 34.0);
        addTearDown(() => tester.view.reset());

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

        // 1. Buka sheet Langkah Memasak
        final stepsBox = find.text('Add one or multiple steps');
        expect(stepsBox, findsOneWidget);
        await tester.tap(stepsBox);
        await tester.pumpAndSettle();

        expect(find.text('Langkah Memasak'), findsOneWidget);

        // 2. Simulasikan keyboard muncul (300 dp)
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
        await tester.pump();
        await tester.pumpAndSettle();

        // 3. Tombol Tambah Langkah & Simpan tetap di atas keyboard / terjangkau
        final addStepBtn = find.descendant(
          of: find.byKey(const Key('app_bottom_sheet_container')),
          matching: find.text('Tambah Langkah'),
        );
        expect(addStepBtn, findsOneWidget);
        final addStepRect = tester.getRect(addStepBtn);
        final visibleBottom = screenHeight - keyboardHeight;
        expect(addStepRect.bottom, lessThanOrEqualTo(visibleBottom));

        final saveBtn = find.descendant(
          of: find.byKey(const Key('app_bottom_sheet_container')),
          matching: find.text('Simpan'),
        );
        final sheetScrollable = find
            .descendant(
              of: find.byKey(const Key('app_bottom_sheet_container')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          saveBtn,
          50.0,
          scrollable: sheetScrollable,
        );
        final saveRect = tester.getRect(saveBtn);
        expect(saveRect.bottom, lessThanOrEqualTo(visibleBottom));
      },
    );
  });
}
