import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/core/utils/thousands_separator_formatter.dart';
import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/cart_provider.dart';
import 'package:foodie/providers/storage_provider.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThousandsSeparatorInputFormatter Unit Tests', () {
    final formatter = ThousandsSeparatorInputFormatter();

    test('1. Mengetik bertahap menambahkan pemisah ribuan titik', () {
      // Ketik '1'
      var res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(res.text, '1');
      expect(res.selection.baseOffset, 1);

      // Ketik '12'
      res = formatter.formatEditUpdate(
        res,
        const TextEditingValue(
          text: '12',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(res.text, '12');

      // Ketik '123'
      res = formatter.formatEditUpdate(
        res,
        const TextEditingValue(
          text: '123',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(res.text, '123');

      // Ketik '1234' -> '1.234'
      res = formatter.formatEditUpdate(
        res,
        const TextEditingValue(
          text: '1234',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(res.text, '1.234');
      expect(res.selection.baseOffset, 5);

      // Ketik '1234567' -> '1.234.567'
      res = formatter.formatEditUpdate(
        res,
        const TextEditingValue(
          text: '1.234567',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(res.text, '1.234.567');
      expect(res.selection.baseOffset, 9);
    });

    test(
      '2. Menghapus karakter (backspace) memperbarui format dengan benar',
      () {
        // Hapus karakter terakhir dari '1.234' -> '123'
        final oldValue = const TextEditingValue(
          text: '1.234',
          selection: TextSelection.collapsed(offset: 5),
        );
        final newValue = const TextEditingValue(
          text: '1.23',
          selection: TextSelection.collapsed(offset: 4),
        );
        final res = formatter.formatEditUpdate(oldValue, newValue);
        expect(res.text, '123');
        expect(res.selection.baseOffset, 3);
      },
    );

    test(
      '3. Menempel (paste) teks dengan format mata uang & karakter non-angka',
      () {
        final res = formatter.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
            text: 'Rp 45.000,-',
            selection: TextSelection.collapsed(offset: 11),
          ),
        );
        expect(res.text, '45.000');
      },
    );

    test('4. Menempel teks murni non-angka menghasilkan string kosong', () {
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'tidak ada angka di sini!',
          selection: TextSelection.collapsed(offset: 24),
        ),
      );
      expect(res.text, '');
      expect(res.selection.baseOffset, 0);
    });

    test('5. Batas maksimal 9 digit (hingga 999.999.999)', () {
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '123456789012345',
          selection: TextSelection.collapsed(offset: 15),
        ),
      );
      expect(res.text, '123.456.789');
    });
  });

  group('Cart Isolation per Akun & Sinkronisasi Total (PRD §5)', () {
    test('1. Akun demo memiliki seed default Rp 18.000 (total) & Rp 9.000 / Rp 20.000 (subtotal)', () async {
      final boxes = await initTestBoxes();
      final container = ProviderContainer(
        overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
      );
      addTearDown(container.dispose);

      // Pastikan demo user aktif
      await container
          .read(authProvider.notifier)
          .login(email: kDemoEmail, password: kDemoPassword);

      expect(container.read(currentUserIdProvider), kDemoUserId);
      final groups = container.read(cartProvider);
      expect(groups.isNotEmpty, isTrue);

      // Subtotals
      final nasgor = groups.firstWhere((g) => g.name == 'Nasi Goreng Spesial');
      final soto = groups.firstWhere((g) => g.name == 'Soto Ayam');
      expect(container.read(cartSubtotalProvider(nasgor.id)), 9000);
      expect(container.read(cartSubtotalProvider(soto.id)), 20000);

      // Total estimasi unchecked (3000 + 5000 + 3000 + 7000)
      expect(container.read(cartTotalUncheckedProvider), 18000);
    });

    final testRecipe = Recipe(
      id: 'test-recipe-isolation',
      title: 'Resep Test',
      description: 'Desc',
      category: 'Test',
      cuisine: 'ID',
      meal: MealType.lunch,
      mainIngredient: 'Bahan',
      rating: 5.0,
      reviews: 1,
      timeMin: 10,
      servings: 1,
      kcal: 100,
      difficulty: Difficulty.mudah,
      ingredients: [
        Ingredient(id: 'item-1', name: 'Daging Test', qty: '500 g', price: 0),
      ],
      steps: const [],
    );

    test('2. User A menambah resep, mengisi harga, dan mencentang item -> total/subtotal sinkron', () async {
      final boxes = await initTestBoxes();
      final container = ProviderContainer(
        overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
      );
      addTearDown(container.dispose);

      // Buat & login sebagai User A
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'Password123!',
          );
      final userAId = container.read(currentUserIdProvider)!;
      expect(userAId, isNot(kDemoUserId));

      // Keranjang awal User A harus kosong
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(cartTotalUncheckedProvider), 0);

      // User A menambah resep
      await container.read(cartProvider.notifier).addRecipe(testRecipe);

      var groupsA = container.read(cartProvider);
      expect(groupsA.length, 1);
      final group = groupsA.first;

      // Harga awal bahan diisi oleh User A
      final item = group.items.first;
      await container
          .read(cartProvider.notifier)
          .updatePrice(group.id, item.id, 60000);

      // Subtotal & total bertambah menjadi 60.000
      expect(container.read(cartSubtotalProvider(group.id)), 60000);
      expect(container.read(cartTotalUncheckedProvider), 60000);

      // Centang item -> mengurangi total estimasi, subtotal tetap 60.000
      await container.read(cartProvider.notifier).toggleItem(group.id, item.id);
      expect(container.read(cartTotalUncheckedProvider), 0);
      expect(container.read(cartSubtotalProvider(group.id)), 60000);
    });

    test('3. Login User B -> keranjang kosong, User B tambah resep sama dengan harga berbeda, User A tidak terpengaruh', () async {
      final boxes = await initTestBoxes();
      final container = ProviderContainer(
        overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
      );
      addTearDown(container.dispose);

      // 1. Setup User A
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User A',
            email: 'usera@example.com',
            password: 'Password123!',
          );
      final userAId = container.read(currentUserIdProvider)!;

      await container.read(cartProvider.notifier).addRecipe(testRecipe);
      var groupA = container.read(cartProvider).first;
      final itemA = groupA.items.first;
      await container
          .read(cartProvider.notifier)
          .updatePrice(groupA.id, itemA.id, 75000);
      expect(container.read(cartTotalUncheckedProvider), 75000);

      // 2. Login User B
      await container
          .read(authProvider.notifier)
          .register(
            name: 'User B',
            email: 'userb@example.com',
            password: 'Password123!',
          );
      final userBId = container.read(currentUserIdProvider)!;
      expect(userBId, isNot(userAId));

      // Keranjang User B harus kosong
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(cartTotalUncheckedProvider), 0);

      // User B menambah resep yang SAMA, tapi mengisi harga berbeda (Rp 50.000)
      await container.read(cartProvider.notifier).addRecipe(testRecipe);
      var groupB = container.read(cartProvider).first;
      final itemB = groupB.items.first;
      await container
          .read(cartProvider.notifier)
          .updatePrice(groupB.id, itemB.id, 50000);
      expect(container.read(cartTotalUncheckedProvider), 50000);

      // 3. User B -> kembali ke User A: data User A harus persis Rp 75.000
      await container
          .read(authProvider.notifier)
          .login(email: 'usera@example.com', password: 'Password123!');
      expect(container.read(currentUserIdProvider), userAId);
      final restoredA = container.read(cartProvider).first;
      expect(restoredA.items.first.price, 75000);
      expect(container.read(cartTotalUncheckedProvider), 75000);

      // 4. Hapus grup di User A -> User B tidak terpengaruh
      await container.read(cartProvider.notifier).removeGroup(restoredA.id);
      expect(container.read(cartProvider), isEmpty);

      // Login kembali ke User B -> data User B tetap ada dengan harga 50.000
      await container
          .read(authProvider.notifier)
          .login(email: 'userb@example.com', password: 'Password123!');
      expect(container.read(currentUserIdProvider), userBId);
      final restoredB = container.read(cartProvider).first;
      expect(restoredB.items.first.price, 50000);
      expect(container.read(cartTotalUncheckedProvider), 50000);
    });
  });

  group('GroceriesPage Widget & Bottom Sheet "Atur harga" Tests', () {
    testWidgets(
      'Tampil chip "Isi harga" bila harga 0 dan catatan kecil menampilkan jumlah bahan belum diisi',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        // Buat akun baru tanpa seed agar kita bisa tambah resep API/custom dengan harga 0
        final router = createRouter(
          initialLocation: '/groceries',
          getAuthState: () => const AuthState(
            isLoggedIn: true,
            user: User(
              id: 'test-user-0',
              name: 'Tester',
              email: 'tester@test.com',
            ),
          ),
        );

        late WidgetRef refHolder;

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
        await tester.pumpAndSettle();

        // Tambahkan resep dengan bahan berharga 0
        final recipeZero = Recipe(
          id: 'recipe-zero',
          title: 'Sayur Asem',
          description: 'Deskripsi',
          category: 'Makan Siang',
          cuisine: 'Indonesia',
          meal: MealType.lunch,
          mainIngredient: 'Jagung',
          rating: 4.8,
          reviews: 10,
          timeMin: 30,
          servings: 4,
          kcal: 120,
          difficulty: Difficulty.mudah,
          ingredients: [
            Ingredient(
              id: 'ing-1',
              name: 'Jagung Manis',
              qty: '1 buah',
              price: 0,
            ),
            Ingredient(
              id: 'ing-2',
              name: 'Kacang Panjang',
              qty: '5 lonjor',
              price: 0,
            ),
          ],
          steps: const [],
        );

        await refHolder.read(cartProvider.notifier).addRecipe(recipeZero);
        await tester.pumpAndSettle();

        // Karena ada 2 bahan berharga 0:
        // 1. Harus muncul teks "2 bahan belum diisi harganya" di bawah add bar
        expect(find.text('2 bahan belum diisi harganya'), findsOneWidget);

        // 2. Harus muncul 2 chip "Isi harga"
        expect(find.text('Isi harga'), findsNWidgets(2));

        // Ketuk pada area nama atau chip "Isi harga" Jagung Manis untuk membuka bottom sheet
        await tester.tap(find.text('Jagung Manis'));
        await tester.pumpAndSettle();

        // Bottom Sheet "Atur harga" muncul
        expect(find.text('Atur harga'), findsOneWidget);
        expect(find.text('Jagung Manis'), findsWidgets);
        expect(find.text('1 buah'), findsWidgets);

        // Input harga bernilai awal KOSONG karena harga 0
        final sheetInput = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(TextField),
        );
        final textController = tester.widget<TextField>(sheetInput).controller!;
        expect(textController.text, '');

        // Isi harga 8000
        await tester.enterText(sheetInput, '8000');
        await tester.pumpAndSettle();
        expect(textController.text, '8.000');

        // Simpan harga
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        // Sheet tertutup
        expect(find.text('Atur harga'), findsNothing);

        // Sekarang sisa 1 bahan berharga 0: "1 bahan belum diisi harganya"
        expect(find.text('1 bahan belum diisi harganya'), findsOneWidget);
        expect(find.text('Rp 8.000'), findsOneWidget);

        // Total estimasi sekarang Rp 8.000
        expect(find.text('Rp 8.000'), findsWidgets);
      },
    );
  });
}
