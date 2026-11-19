import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/pages/home_page.dart';
import 'package:foodie/pages/login_page.dart';
import 'package:foodie/pages/splash_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/ui/app_checkbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 4 — Splash Page Tests', () {
    testWidgets(
      'SplashPage renders floating pills, title, logo, and CTA button',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SplashPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Floating labels
        expect(find.text('Bumbu Halus'), findsOneWidget);
        expect(find.text('Kecap Manis'), findsOneWidget);
        expect(find.text('Siap Masak'), findsOneWidget);

        // Logo & Title
        expect(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('FOODIE.ID'),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains(
                  'Jelajahi Cita Rasa\nAutentik Nusantara',
                ),
          ),
          findsOneWidget,
        );

        // CTA button
        expect(find.text('Mulai Eksplorasi →'), findsOneWidget);
        // Halal tagline
        expect(find.text('100% Halal'), findsOneWidget);
        expect(find.text('Bahan Segar Terpilih'), findsOneWidget);
      },
    );
  });

  group('Fase 4 — Login Page Tests', () {
    testWidgets('LoginPage validates fields and submits successfully', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();
      late WidgetRef refHolder;

      final router = createRouter(
        initialLocation: '/login',
        getAuthState: () => refHolder.read(authProvider),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('MASAK LEBIH MUDAH'), findsOneWidget);
      expect(find.text('Selamat\ndatang kembali.'), findsOneWidget);
      expect(find.text('Ingat saya'), findsOneWidget);
      expect(find.text('Lupa kata sandi?'), findsOneWidget);

      // Submit with empty inputs -> shows validation errors
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid'), findsOneWidget);
      expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);

      // Enter valid email and short password
      await tester.enterText(find.byType(TextField).at(0), 'test@foodie.id');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid'), findsNothing);
      expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);

      // Enter valid password (>= 8 chars)
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      // Check auth state is now logged in
      expect(refHolder.read(authProvider).isLoggedIn, true);
    });
  });

  group('Fase 4 — Register Page Tests', () {
    testWidgets('RegisterPage validates all fields and terms checkbox', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();
      late WidgetRef refHolder;

      final router = createRouter(
        initialLocation: '/register',
        getAuthState: () => refHolder.read(authProvider),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
      await tester.pumpAndSettle();

      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Resep baru,\ncerita baru.'), findsOneWidget);

      // Submit empty
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Nama lengkap wajib diisi'), findsOneWidget);
      expect(find.text('Format email tidak valid'), findsOneWidget);
      expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);
      expect(
        find.text('Kamu harus menyetujui Syarat & Ketentuan'),
        findsOneWidget,
      );

      // Fill name & email, mismatched password
      await tester.enterText(find.byType(TextField).at(0), 'Chef Nusantara');
      await tester.enterText(find.byType(TextField).at(1), 'chef@foodie.id');
      await tester.enterText(find.byType(TextField).at(2), 'rahasia123');
      await tester.enterText(find.byType(TextField).at(3), 'beda12345');
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Nama lengkap wajib diisi'), findsNothing);
      expect(find.text('Konfirmasi kata sandi tidak cocok'), findsOneWidget);

      // Fix password and check terms
      await tester.enterText(find.byType(TextField).at(3), 'rahasia123');
      await tester.tap(find.byType(AppCheckbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(refHolder.read(authProvider).isLoggedIn, true);
      expect(refHolder.read(authProvider).user?.name, 'Chef Nusantara');
    });
  });

  group('Fase 4 — Forgot Page Tests', () {
    testWidgets('ForgotPage validates email and triggers toast on submit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(initialLocation: '/forgot');

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

      expect(find.text('Lupa kata sandi'), findsOneWidget);
      expect(find.text('Atur ulang\nkata sandi.'), findsOneWidget);

      // Submit empty
      await tester.tap(find.text('Kirim tautan'));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid'), findsOneWidget);

      // Enter valid email
      await tester.enterText(find.byType(TextField), 'user@foodie.id');
      await tester.tap(find.text('Kirim tautan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text('Tautan reset telah dikirim ke email kamu'),
        findsOneWidget,
      );

      // Advance through pending timers (toast 2.2s + delay 1.5s)
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();
    });
  });

  group('Fase 4 — Route Guard Tests', () {
    testWidgets(
      'Unauthenticated user is redirected to /login when accessing protected route',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/home',
          getAuthState: () => const AuthState(isLoggedIn: false, user: null),
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

        expect(find.byType(LoginPage), findsOneWidget);
      },
    );

    testWidgets('Authenticated user opening / is redirected to /home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/',
        getAuthState: () => const AuthState(isLoggedIn: true, user: null),
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

      // Protected route /home is rendered
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
    });
  });
}
