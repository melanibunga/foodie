import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/app_bottom_nav.dart';
import 'package:foodie/widgets/ui/app_button.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
    });
  });

  group('Fase B1 — Insets, Keyboard, Sheet, & Focus Tests', () {
    testWidgets(
      '(a) Rect tombol DONE, "Kembali Ke Beranda", dan BottomNav identik antara viewInsets.bottom = 0 dan viewInsets.bottom = 300',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetViewInsets();
        });

        final prefs = await SharedPreferences.getInstance();

        // 1. Test CreateRecipePage DONE button
        final addRouter = createRouter(
          initialLocation: '/add',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: addRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final doneFinder = find.widgetWithText(ElevatedButton, 'DONE');
        expect(doneFinder, findsOneWidget);
        final rectDone0 = tester.getRect(doneFinder);

        // Simulate keyboard popup
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        final rectDone300 = tester.getRect(doneFinder);
        expect(
          rectDone300,
          equals(rectDone0),
          reason: 'DONE button must remain sticky and not move when keyboard appears',
        );

        // Reset insets
        tester.view.viewInsets = FakeViewPadding.zero;

        // 2. Test FavoritesPage "Kembali Ke Beranda"
        final favRouter = createRouter(
          initialLocation: '/favorites',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: favRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final favBackFinder = find.text('Kembali Ke Beranda');
        expect(favBackFinder, findsOneWidget);
        final rectFav0 = tester.getRect(favBackFinder);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        final rectFav300 = tester.getRect(favBackFinder);
        expect(
          rectFav300,
          equals(rectFav0),
          reason: '"Kembali Ke Beranda" on Favorites must not move when keyboard appears',
        );

        // Reset insets
        tester.view.viewInsets = FakeViewPadding.zero;

        // 3. Test MyRecipesPage "Kembali Ke Beranda"
        final myRouter = createRouter(
          initialLocation: '/my-recipes',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: myRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final myBackFinder = find.text('Kembali Ke Beranda');
        expect(myBackFinder, findsOneWidget);
        final rectMy0 = tester.getRect(myBackFinder);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        final rectMy300 = tester.getRect(myBackFinder);
        expect(
          rectMy300,
          equals(rectMy0),
          reason: '"Kembali Ke Beranda" on My Recipes must not move when keyboard appears',
        );

        // Reset insets
        tester.view.viewInsets = FakeViewPadding.zero;

        // 4. Test ShellRoute BottomNav
        final shellRouter = createRouter(
          initialLocation: '/search',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: shellRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final navFinder = find.byType(AppBottomNav);
        expect(navFinder, findsOneWidget);
        final rectNav0 = tester.getRect(navFinder);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        final rectNav300 = tester.getRect(navFinder);
        expect(
          rectNav300,
          equals(rectNav0),
          reason: 'AppBottomNav in ShellRoute must not jump up when keyboard appears',
        );
      },
    );

    testWidgets(
      '(b) Bottom tombol "Simpan" di sheet Edit Profil dan "Terapkan" di sheet Filter Nearby punya jarak >= 16 dari (screenHeight - viewPadding.bottom) pada viewPadding.bottom = 0, 24, 34, 48',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
          tester.view.resetViewInsets();
        });

        final prefs = await SharedPreferences.getInstance();

        // 1. Edit Profil sheet "Simpan" button
        for (final p in [0.0, 24.0, 34.0, 48.0]) {
          tester.view.padding = FakeViewPadding(bottom: p, top: 24.0);
          tester.view.viewPadding = FakeViewPadding(bottom: p, top: 24.0);

          final profileRouter = createRouter(
            initialLocation: '/profile',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: profileRouter,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open Edit Profile sheet
          await tester.tap(find.text('Edit profil'));
          await tester.pumpAndSettle();

          final simpanFinder = find.widgetWithText(AppButton, 'Simpan');
          expect(simpanFinder, findsOneWidget);

          final saveRect = tester.getRect(simpanFinder);
          final clearance = (956.0 - p) - saveRect.bottom;
          expect(
            clearance,
            greaterThanOrEqualTo(16.0),
            reason: 'For padding $p, clearance $clearance must be >= 16.0',
          );

          // Close sheet by tapping outside at top of screen
          await tester.tapAt(const Offset(20, 20));
          await tester.pumpAndSettle();
        }

        // 2. Filter Nearby sheet "Terapkan" button
        for (final p in [0.0, 24.0, 34.0, 48.0]) {
          tester.view.padding = FakeViewPadding(bottom: p, top: 24.0);
          tester.view.viewPadding = FakeViewPadding(bottom: p, top: 24.0);

          final nearbyRouter = createRouter(
            initialLocation: '/nearby',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: nearbyRouter,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open Filter Nearby sheet
          await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
          await tester.pumpAndSettle();

          final terapkanFinder = find.widgetWithText(AppButton, 'Terapkan');
          expect(terapkanFinder, findsOneWidget);

          final applyRect = tester.getRect(terapkanFinder);
          final clearance = (956.0 - p) - applyRect.bottom;
          expect(
            clearance,
            greaterThanOrEqualTo(16.0),
            reason: 'For padding $p, clearance $clearance must be >= 16.0',
          );

          // Close sheet by tapping Terapkan
          await tester.tap(terapkanFinder);
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      '(c) Sheet dengan keyboard tidak pernah melebihi (screenHeight - topChrome) dan field yang fokus terlihat (tidak terpotong)',
      (tester) async {
        const screenHeight = 956.0;
        const topPadding = 24.0;
        const keyboardHeight = 300.0;
        const topChrome = topPadding + 16.0; // 40.0

        tester.view.physicalSize = const Size(440, screenHeight);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: topPadding);
        tester.view.viewPadding = const FakeViewPadding(top: topPadding);
        tester.view.viewInsets = FakeViewPadding.zero;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
          tester.view.resetViewInsets();
        });

        final prefs = await SharedPreferences.getInstance();
        final profileRouter = createRouter(
          initialLocation: '/profile',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: profileRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Edit Profile sheet
        await tester.tap(find.text('Edit profil'));
        await tester.pumpAndSettle();

        // Focus the name field
        final nameField = find.byType(TextField).first;
        await tester.tap(nameField);
        await tester.pump();

        // Simulate keyboard opening
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
        await tester.pump();
        await tester.ensureVisible(nameField);
        await tester.pumpAndSettle();

        // Find modal sheet container
        final sheetFinder = find.byKey(const Key('app_bottom_sheet_container'));
        expect(sheetFinder, findsOneWidget);

        final sheetRect = tester.getRect(sheetFinder);
        // 1. Sheet top position must not go above topChrome
        expect(
          sheetRect.top,
          greaterThanOrEqualTo(topChrome),
          reason:
              'Sheet top (${sheetRect.top}) must be >= topChrome ($topChrome)',
        );

        // 2. Sheet height must not exceed screenHeight - topChrome - keyboardHeight
        final maxAllowedHeight = screenHeight - topChrome - keyboardHeight;
        expect(
          sheetRect.height,
          lessThanOrEqualTo(maxAllowedHeight + 1.0), // allow 1px rounding
          reason:
              'Sheet height (${sheetRect.height}) must be <= $maxAllowedHeight',
        );

        // 3. Focused input field must be visible (not covered by keyboard)
        final inputRect = tester.getRect(nameField);
        expect(
          inputRect.top,
          greaterThanOrEqualTo(0.0),
          reason: 'Focused input top must be inside viewport',
        );
        expect(
          inputRect.bottom,
          lessThanOrEqualTo(screenHeight - keyboardHeight),
          reason:
              'Focused input bottom (${inputRect.bottom}) must be above keyboard (${screenHeight - keyboardHeight})',
        );
      },
    );

    testWidgets(
      '(d) Setelah sheet ditutup (Navigator.pop), primaryFocus bernilai null (atau fokus tidak kembali ke field acak)',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = FakeViewPadding.zero;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetViewInsets();
        });

        final prefs = await SharedPreferences.getInstance();
        final addRouter = createRouter(
          initialLocation: '/add',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: addRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially focus the Recipe Title
        final titleFinder = find.byType(TextField).first;
        expect(titleFinder, findsOneWidget);
        await tester.tap(titleFinder);
        await tester.enterText(titleFinder, 'Ayam Bakar');
        await tester.pumpAndSettle();

        // Recipe Title is focused
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

        // Open Ingredients sheet
        final addIngredientsTile = find.text('Add ingredients to recipe');
        expect(addIngredientsTile, findsOneWidget);
        await tester.tap(addIngredientsTile);
        await tester.pumpAndSettle();

        // Sheet is open
        expect(find.text('Tambah Bahan'), findsOneWidget);

        // Close the sheet via Close button
        await tester.tap(find.byIcon(LucideIcons.x));
        await tester.pumpAndSettle();

        // Sheet is closed: focus must not return to Recipe Title or any input field
        final primaryFocus = FocusManager.instance.primaryFocus;
        final isInputFocused =
            primaryFocus != null &&
            primaryFocus is! FocusScopeNode &&
            primaryFocus.context?.widget is EditableText;

        expect(
          isInputFocused,
          isFalse,
          reason: 'Focus must not restore automatically to Recipe Title or any input field after closing sheet',
        );
      },
    );
  });
}
