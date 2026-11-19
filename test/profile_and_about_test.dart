import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/about_page.dart';
import 'package:foodie/pages/favorites_page.dart';
import 'package:foodie/pages/login_page.dart';
import 'package:foodie/pages/my_recipes_page.dart';
import 'package:foodie/pages/profile_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
    });
  });

  group(
    'Fase 14 — Profil Saya (/profile) & Tentang Aplikasi (/about) Tests',
    () {
      testWidgets('ProfilePage renders exact elements from design/akun.jpg', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/profile',
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

        // Top bar
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(find.text('Profil Saya'), findsOneWidget);

        // User card
        expect(find.text('Najmah Cleosaa Tokek'), findsOneWidget);
        expect(find.text('benjolmwahh@gmail.com'), findsOneWidget);
        expect(find.text('Edit profil'), findsOneWidget);

        // Stats card 3 columns (Favorit, Dimasak, Resep Saya)
        expect(find.text('Favorit'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('Dimasak'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('Resep Saya'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);

        // Section Pengaturan
        expect(find.text('Pengaturan'), findsOneWidget);
        expect(find.text('Pengingat makan'), findsOneWidget);
        expect(find.text('Notifikasi jadwal makan aktif'), findsOneWidget);
        expect(find.text('Mode gelap'), findsOneWidget);
        expect(find.text('Tampilan terang sedang digunakan'), findsOneWidget);

        // Kartu Tentang Aplikasi
        expect(find.text('Tentang aplikasi'), findsOneWidget);
        expect(find.text('Kenali teman masakmu lebih dekat'), findsOneWidget);

        // Tombol Logout
        expect(find.text('Logout'), findsOneWidget);

        // Footer Versi
        expect(find.text('Versi 1.0.0'), findsOneWidget);
      });

      testWidgets(
        'Tapping Resep Saya and Favorit navigates to respective pages',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final prefs = await SharedPreferences.getInstance();

          final router = createRouter(
            initialLocation: '/profile',
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

          // Tap "Resep Saya"
          await tester.tap(find.text('Resep Saya'));
          await tester.pumpAndSettle();

          expect(find.byType(MyRecipesPage), findsOneWidget);

          // Go back to profile
          router.go('/profile');
          await tester.pumpAndSettle();

          // Tap "Favorit"
          await tester.tap(find.text('Favorit'));
          await tester.pumpAndSettle();

          expect(find.byType(FavoritesPage), findsOneWidget);
        },
      );

      testWidgets(
        'Tapping Tentang aplikasi navigates to /about and renders full details',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final prefs = await SharedPreferences.getInstance();

          final router = createRouter(
            initialLocation: '/profile',
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

          // Tap "Tentang aplikasi"
          await tester.tap(find.text('Tentang aplikasi'));
          await tester.pumpAndSettle();

          // On AboutPage
          expect(find.byType(AboutPage), findsOneWidget);
          expect(find.text('FOODIE'), findsOneWidget);
          expect(find.text('.'), findsOneWidget);
          expect(find.text('ID'), findsOneWidget);
          expect(
            find.text('Masak Lebih Mudah, Hidup Lebih Teratur.'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Inspirasi Resep Nusantara'),
            findsOneWidget,
          );
          expect(find.textContaining('Meal Plan Mingguan'), findsOneWidget);
          expect(find.textContaining('My Groceries'), findsOneWidget);
        },
      );

      testWidgets(
        'Toggling Pengingat makan and Mode gelap updates settings and shows toast',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'foodie:auth',
            jsonEncode(
              const AuthState(isLoggedIn: true, user: seedUser).toJson(),
            ),
          );

          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          final router = createRouter(
            initialLocation: '/profile',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Toggle 1: Pengingat makan (initial true)
          final mealReminderToggle = find.byKey(
            const ValueKey('toggle-meal-reminder'),
          );
          expect(mealReminderToggle, findsOneWidget);
          await tester.tap(mealReminderToggle);
          await tester.pumpAndSettle();

          expect(
            container.read(currentUserProvider)?.settings.mealReminder,
            isFalse,
          );
          expect(find.text('Notifikasi jadwal makan nonaktif'), findsOneWidget);

          // Toggle 2: Mode gelap (initial false)
          final darkModeToggle = find.byKey(const ValueKey('toggle-dark-mode'));
          expect(darkModeToggle, findsOneWidget);
          await tester.tap(darkModeToggle);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Mode gelap segera hadir'), findsOneWidget);
          expect(
            container.read(currentUserProvider)?.settings.darkMode,
            isTrue,
          );

          // Settle toast timer (2.2s)
          await tester.pump(const Duration(milliseconds: 2300));
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'Edit profil bottom sheet allows editing name and saving updates state',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'foodie:auth',
            jsonEncode(
              const AuthState(isLoggedIn: true, user: seedUser).toJson(),
            ),
          );

          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          final router = createRouter(
            initialLocation: '/profile',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Tap "Edit profil" chip
          await tester.tap(find.text('Edit profil'));
          await tester.pumpAndSettle();

          // Bottom sheet is visible
          expect(find.text('Edit Profil'), findsOneWidget);
          expect(find.text('Nama Lengkap'), findsOneWidget);
          expect(find.text('Email (tidak dapat diubah)'), findsOneWidget);

          // Change name
          final nameField = find.widgetWithText(
            TextField,
            'Najmah Cleosaa Tokek',
          );
          await tester.enterText(nameField, 'Chef Najmah');
          await tester.pumpAndSettle();

          // Tap "Simpan"
          await tester.tap(find.text('Simpan'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Toast appears and profile name updated
          expect(find.text('Profil berhasil diperbarui'), findsOneWidget);
          await tester.pumpAndSettle();
          expect(find.text('Chef Najmah'), findsOneWidget);
          expect(container.read(currentUserProvider)?.name, 'Chef Najmah');

          // Settle toast timer
          await tester.pump(const Duration(milliseconds: 2300));
          await tester.pumpAndSettle();
        },
      );

      testWidgets('Logout button confirms and navigates to /login', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'foodie:auth',
          jsonEncode(
            const AuthState(isLoggedIn: true, user: seedUser).toJson(),
          ),
        );

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final router = createRouter(
          initialLocation: '/profile',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap Logout button on profile page
        final logoutButton = find.byKey(const ValueKey('logout-button'));
        expect(logoutButton, findsOneWidget);
        await tester.tap(logoutButton);
        await tester.pumpAndSettle();

        // Dialog confirms
        expect(find.text('Keluar dari akun?'), findsOneWidget);

        // Tap Logout button in confirmation dialog
        await tester.tap(find.text('Logout').last);
        await tester.pumpAndSettle();

        // Navigated to /login
        expect(find.byType(LoginPage), findsOneWidget);
      });

      testWidgets(
        'Long press Versi 1.0.0 triggers Reset data demo dialog and resets seed data',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'foodie:auth',
            jsonEncode(
              const AuthState(isLoggedIn: true, user: seedUser).toJson(),
            ),
          );

          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          final router = createRouter(
            initialLocation: '/profile',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Long press "Versi 1.0.0"
          await tester.longPress(find.text('Versi 1.0.0'));
          await tester.pumpAndSettle();

          // Dialog appears
          expect(find.text('Reset data demo?'), findsOneWidget);
          expect(
            find.textContaining('Semua resep kustom, jadwal meal plan'),
            findsOneWidget,
          );

          // Confirm Reset
          await tester.tap(find.text('Reset'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Data demo berhasil di-reset'), findsOneWidget);

          // Settle toast timer
          await tester.pump(const Duration(milliseconds: 2300));
          await tester.pumpAndSettle();
        },
      );
    },
  );
}
