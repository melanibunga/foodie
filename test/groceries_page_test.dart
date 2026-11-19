import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/groceries_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/ui/app_checkbox.dart';
import 'package:foodie/widgets/ui/empty_state.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 10 — My Groceries Page (/groceries) Tests', () {
    testWidgets(
      'GroceriesPage renders top bar, add bar, group cards, and sticky panel with correct calculation',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/groceries',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Page rendered
        expect(find.byType(GroceriesPage), findsOneWidget);

        // Top Bar
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
        expect(find.text('My Groceries'), findsOneWidget);

        // Add Bar
        expect(find.text('+ Tambah bahan belanja…'), findsOneWidget);
        expect(find.text('Rp '), findsOneWidget);
        expect(find.byIcon(LucideIcons.plus), findsOneWidget);

        // Seed Groups
        expect(find.text('Nasi Goreng Spesial'), findsOneWidget);
        expect(find.text('Soto Ayam'), findsOneWidget);
        expect(find.text('Belanjaan Kamu Nich'), findsOneWidget);

        // Subtotals (Aturan hitung: subtotal = jumlah SEMUA item di grup)
        expect(
          find.text('Subtotal Rp 9.000'),
          findsOneWidget,
        ); // Nasi Goreng Spesial: 4000+2000+3000
        expect(
          find.text('Subtotal Rp 20.000'),
          findsOneWidget,
        ); // Soto Ayam: 12000+5000+3000

        // Custom group ("Belanjaan Kamu Nich") must NOT display subtotal
        expect(find.textContaining('Subtotal Rp 7.000'), findsNothing);

        // Sticky Bottom Summary Panel
        expect(find.text('Total estimasi (belum dibeli)'), findsOneWidget);

        // Big total (Aturan hitung: total = hanya item yang BELUM dicentang: 3000 + 5000 + 3000 + 7000 = 18.000)
        expect(find.text('Rp 18.000'), findsOneWidget);

        // Button "Kosongkan semua"
        final clearAllBtn = find.widgetWithText(
          ElevatedButton,
          'Kosongkan semua',
        );
        expect(clearAllBtn, findsOneWidget);
        final btnSize = tester.getSize(clearAllBtn);
        expect(btnSize.width, equals(164.0));
        expect(btnSize.height, equals(44.0));

        // Note text
        expect(
          find.text('Harga estimasi, ketuk item untuk mengubah'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Toggling item checkbox updates total calculation without changing subtotal',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/groceries',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Initial total: Rp 18.000
        expect(find.text('Rp 18.000'), findsOneWidget);

        // Find the checkbox for "Beras" (third checkbox in Nasi Goreng Spesial, which is unchecked Rp 3.000)
        final checkboxes = find.byType(AppCheckbox);
        // Item 0: Telur (checked)
        // Item 1: Bawang merah (checked)
        // Item 2: Beras (unchecked)
        await tester.tap(checkboxes.at(2));
        await tester.pumpAndSettle();

        // Now "Beras" is checked, so total estimasi drops by 3.000 to Rp 15.000
        expect(find.text('Rp 15.000'), findsOneWidget);

        // Subtotal of Nasi Goreng Spesial remains Rp 9.000
        expect(find.text('Subtotal Rp 9.000'), findsOneWidget);
      },
    );

    testWidgets(
      'Adding custom item adds to Belanjaan Kamu Nich and updates total',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/groceries',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Enter custom item name & price
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'Minyak Goreng');
        await tester.enterText(textFields.at(1), '15000');
        await tester.pumpAndSettle();

        // Tap "+" button
        await tester.tap(find.byIcon(LucideIcons.plus));
        await tester.pumpAndSettle();

        // Minyak Goreng should appear
        expect(find.text('Minyak Goreng'), findsOneWidget);

        // Total should increase by 15.000 (18.000 + 15.000 = 33.000)
        expect(find.text('Rp 33.000'), findsOneWidget);

        // Drain toast timer (2.2s)
        await tester.pump(const Duration(milliseconds: 2500));
      },
    );

    testWidgets('Inline price edit updates item price and total', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/groceries',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Tap on price of Beras (Rp 3.000)
      final priceTarget = find.text('Rp 3.000').first;
      await tester.ensureVisible(priceTarget);
      await tester.tap(priceTarget);
      await tester.pumpAndSettle();

      // Inline price editor input should appear
      final checkIcon = find.byIcon(LucideIcons.check);
      expect(checkIcon, findsOneWidget);

      // Change price from 3000 to 5000
      final inlineInput = find.byType(TextField).last;
      await tester.enterText(inlineInput, '5000');
      await tester.pumpAndSettle();

      // Confirm inline edit
      await tester.tap(checkIcon);
      await tester.pumpAndSettle();

      // Price updated to Rp 5.000
      expect(find.text('Rp 5.000'), findsWidgets);

      // Total increases from 18.000 to 20.000 (3000 -> 5000)
      expect(find.text('Rp 20.000'), findsWidgets);
    });

    testWidgets(
      'Hapus menu opens confirmation dialog and removes group upon confirm',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        late WidgetRef refHolder;

        final router = createRouter(
          initialLocation: '/groceries',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(refHolder.read(cartProvider).length, equals(3));

        // Tap "Hapus menu" on first group (Nasi Goreng Spesial)
        await tester.tap(find.text('Hapus menu').first);
        await tester.pumpAndSettle();

        // Confirmation dialog
        expect(find.text('Hapus menu dari keranjang?'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);

        // Cancel
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(refHolder.read(cartProvider).length, equals(3));

        // Tap "Hapus menu" again and confirm
        await tester.tap(find.text('Hapus menu').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Group removed
        expect(refHolder.read(cartProvider).length, equals(2));
        expect(find.text('Nasi Goreng Spesial'), findsNothing);

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2500));
      },
    );

    testWidgets('Kosongkan semua clears cart and displays EmptyState', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prefs = await SharedPreferences.getInstance();

      final router = createRouter(
        initialLocation: '/groceries',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Tap "Kosongkan semua" button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kosongkan semua'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Kosongkan keranjang?'), findsOneWidget);
      expect(find.text('Kosongkan'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Kosongkan'));
      await tester.pumpAndSettle();

      // EmptyState should now be shown
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Keranjang Belanja Kosong'), findsOneWidget);

      // Drain toast timer
      await tester.pump(const Duration(milliseconds: 2500));
    });
  });
}
