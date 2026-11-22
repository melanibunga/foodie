import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/pages/groceries_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/grocery_group_header.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase E1 — Bagian A: Groceries Hapus Menu Alignment Test', () {
    for (final width in [360.0, 440.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('Pohon asli GroceriesPage lebar $width scale $scale: '
            'Hapus menu rata kanan dengan harga dan sejajar baris pertama judul', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final boxes = await initTestBoxes();
          final prefs = await SharedPreferences.getInstance();

          final testGroups = [
            // Custom group (tetap di atas, tanpa Hapus menu)
            CartGroup(
              id: 'custom',
              name: 'Belanjaan Kamu Nich',
              items: [
                CartItem(
                  id: 'custom-1',
                  name: 'Minyak Goreng',
                  qty: '1 liter',
                  price: 14000,
                ),
              ],
            ),
            // Short title group
            CartGroup(
              id: 'soto',
              recipeId: 'soto-ayam',
              name: 'Soto Ayam',
              items: [
                CartItem(
                  id: 'soto-1',
                  name: 'Daging Ayam',
                  qty: '250 gram',
                  price: 15000,
                ),
              ],
            ),
            // Long title group (2 baris)
            CartGroup(
              id: 'nasgor-long',
              recipeId: 'nasgor-long',
              name: 'Nasi Goreng Spesial Ekstra Pedas Level Dewa',
              items: [
                CartItem(
                  id: 'nasgor-1',
                  name: 'Beras Pulen',
                  qty: '500 gram',
                  price: 8000,
                ),
              ],
            ),
          ];

          await prefs.setString(
            CartNotifier.prefKey,
            jsonEncode(testGroups.map((g) => g.toJson()).toList()),
          );
          await boxes.cart.put(
            seedUser.id,
            testGroups.map((g) => g.toJson()).toList(),
          );
          await boxes.cart.put(
            kDemoUserId,
            testGroups.map((g) => g.toJson()).toList(),
          );

          final router = createRouter(
            initialLocation: '/groceries',
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

          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(
            () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pumpAndSettle();

          expect(find.byType(GroceriesPage), findsOneWidget);
          expect(find.byType(GroceryGroupHeader), findsNWidgets(2));

          // Pastikan Belanjaan Kamu Nich tetap ada dan tanpa tombol Hapus menu
          expect(find.text('Belanjaan Kamu Nich'), findsOneWidget);

          // Bounding box calculation for line 1 height
          final tp = TextPainter(
            text: const TextSpan(
              text: 'A',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
          )..layout();
          final line1Height = tp.height;

          // 1. Grup Judul Pendek ("Soto Ayam")
          final sotoTitleFinder = find.text('Soto Ayam');
          final sotoHeaderFinder = find.ancestor(
            of: sotoTitleFinder,
            matching: find.byType(GroceryGroupHeader),
          );
          final sotoHapusFinder = find.descendant(
            of: sotoHeaderFinder,
            matching: find.text('Hapus menu'),
          );
          final sotoPriceFinder = find.text('Rp 15.000');

          expect(sotoTitleFinder, findsOneWidget);
          expect(sotoHapusFinder, findsOneWidget);
          expect(sotoPriceFinder, findsOneWidget);

          final sotoHapusRect = tester.getRect(sotoHapusFinder);
          final sotoPriceRect = tester.getRect(sotoPriceFinder);
          final sotoTitleRect = tester.getRect(sotoTitleFinder);
          final sotoLine1Center = sotoTitleRect.top + line1Height / 2;

          // Assert: Rect.right "Hapus menu" == Rect.right teks harga (toleransi 0.5 dp)
          expect(
            (sotoHapusRect.right - sotoPriceRect.right).abs(),
            lessThanOrEqualTo(0.5),
            reason:
                'Soto Ayam: Rect.right Hapus menu ($sotoHapusRect) '
                'harus sama dengan Rect.right teks harga ($sotoPriceRect)',
          );

          // Assert: Pusat vertikal tombol sejajar baris pertama judul (toleransi 2 dp)
          expect(
            (sotoHapusRect.center.dy - sotoLine1Center).abs(),
            lessThanOrEqualTo(2.0),
            reason:
                'Soto Ayam: Pusat vertikal Hapus menu (${sotoHapusRect.center.dy}) '
                'harus sejajar baris pertama judul ($sotoLine1Center)',
          );

          // 2. Grup Judul Panjang ("Nasi Goreng Spesial Ekstra Pedas Level Dewa")
          final nasgorTitleFinder = find.text(
            'Nasi Goreng Spesial Ekstra Pedas Level Dewa',
          );
          final nasgorHeaderFinder = find.ancestor(
            of: nasgorTitleFinder,
            matching: find.byType(GroceryGroupHeader),
          );
          final nasgorHapusFinder = find.descendant(
            of: nasgorHeaderFinder,
            matching: find.text('Hapus menu'),
          );
          final nasgorPriceFinder = find.text('Rp 8.000');

          expect(nasgorTitleFinder, findsOneWidget);
          expect(nasgorHapusFinder, findsOneWidget);
          expect(nasgorPriceFinder, findsOneWidget);

          final nasgorHapusRect = tester.getRect(nasgorHapusFinder);
          final nasgorPriceRect = tester.getRect(nasgorPriceFinder);
          final nasgorTitleRect = tester.getRect(nasgorTitleFinder);
          final nasgorLine1Center = nasgorTitleRect.top + line1Height / 2;

          // Assert: Rect.right "Hapus menu" == Rect.right teks harga (toleransi 0.5 dp)
          expect(
            (nasgorHapusRect.right - nasgorPriceRect.right).abs(),
            lessThanOrEqualTo(0.5),
            reason:
                'Nasi Goreng: Rect.right Hapus menu ($nasgorHapusRect) '
                'harus sama dengan Rect.right teks harga ($nasgorPriceRect)',
          );

          // Assert: Pusat vertikal tombol sejajar baris pertama judul (toleransi 2 dp)
          expect(
            (nasgorHapusRect.center.dy - nasgorLine1Center).abs(),
            lessThanOrEqualTo(2.0),
            reason:
                'Nasi Goreng: Pusat vertikal Hapus menu (${nasgorHapusRect.center.dy}) '
                'harus sejajar baris pertama judul ($nasgorLine1Center)',
          );

          // Tidak ada exception / overflow
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
