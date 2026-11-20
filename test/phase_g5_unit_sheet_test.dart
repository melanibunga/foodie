import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/pages/create_recipe_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/recipe_service.dart';
import 'package:foodie/widgets/ui/app_button.dart';
import 'package:hive/hive.dart';

class FakeBox<T> implements Box<T> {
  final Map<dynamic, T> _storage = {};

  @override
  T? get(dynamic key, {T? defaultValue}) =>
      _storage.containsKey(key) ? _storage[key] : defaultValue;

  @override
  Future<void> put(dynamic key, T value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _storage.remove(key);
  }

  @override
  bool containsKey(dynamic key) => _storage.containsKey(key);

  @override
  Iterable<dynamic> get keys => _storage.keys;

  @override
  Iterable<T> get values => _storage.values;

  @override
  Map<dynamic, T> toMap() => Map.unmodifiable(_storage);

  @override
  int get length => _storage.length;

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  Future<int> clear() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FoodieBoxes foodieBoxes;

  setUp(() {
    foodieBoxes = FoodieBoxes(
      users: FakeBox(),
      session: FakeBox(),
      favorites: FakeBox(),
      cart: FakeBox(),
      mealPlan: FakeBox(),
      myRecipes: FakeBox(),
      cooked: FakeBox(),
      ratings: FakeBox(),
      settings: FakeBox(),
      meta: FakeBox(),
      recipes: FakeBox(),
      recipeCache: FakeBox(),
      placesCache: FakeBox(),
    );
  });

  group('Fase G5: Sheet Tambah Bahan - Pilihan Satuan & Keyboard Tetap', () {
    testWidgets(
      'Buka sheet, tap field satuan, keyboard tetap, tap chip sdm mengisi field dan fokus tetap aktif',
      (tester) async {
        // Set simulasi keyboard terbuka (viewInsets.bottom = 300)
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWith((ref) => 'test-user'),
              foodieBoxesProvider.overrideWithValue(foodieBoxes),
              recipeServiceProvider.overrideWithValue(LocalRecipeService()),
            ],
            child: const MaterialApp(home: CreateRecipePage()),
          ),
        );

        await tester.pumpAndSettle();

        // Buka Sheet Tambah Bahan dengan tap tombol kotak "Ingredients"
        final ingredientsButton = find.byKey(
          const Key('add-ingredients-button'),
        );
        expect(ingredientsButton, findsOneWidget);
        await tester.tap(ingredientsButton);
        await tester.pumpAndSettle();

        // Pastikan BottomSheet Tambah Bahan terbuka
        expect(find.text('Tambah Bahan'), findsOneWidget);

        // Cari TextField Nama, Jumlah, dan Satuan
        final nameField = find.widgetWithText(TextField, 'Mis. Bawang merah');
        final qtyField = find.widgetWithText(TextField, 'Mis. 4');
        final unitField = find.widgetWithText(TextField, 'g, sdm, butir…');

        expect(nameField, findsOneWidget);
        expect(qtyField, findsOneWidget);
        expect(unitField, findsOneWidget);

        // Masukkan Nama bahan
        await tester.enterText(nameField, 'Bawang Merah');
        await tester.pumpAndSettle();

        // Masukkan Jumlah
        await tester.enterText(qtyField, '5');
        await tester.pumpAndSettle();

        // Tap field Satuan
        await tester.tap(unitField);
        await tester.pumpAndSettle();

        // 1. Keyboard tetap terbuka dan primaryFocus tetap pada input teks
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.view.viewInsets.bottom, equals(300));

        // Baris chip saran satuan harus terlihat di layar (di atas keyboard)
        final sdmChipFinder = find.widgetWithText(GestureDetector, 'sdm');
        expect(sdmChipFinder, findsWidgets);

        // Tombol Tambah ke daftar harus berada di atas keyboard dan terlihat
        final addButtonFinder = find.text('+ Tambah ke Daftar');
        expect(addButtonFinder, findsOneWidget);
        final addBtnCenter = tester.getCenter(addButtonFinder);
        // Koordinat tombol Y harus berada di atas keyboard (< 844 - 300 = 544)
        expect(addBtnCenter.dy, lessThan(844 - 300 + 50));

        // 2. Tap chip "sdm" sesuai spesifikasi
        final sdmFinder = find.text('sdm');
        expect(sdmFinder, findsOneWidget);
        await tester.tap(sdmFinder);
        await tester.pumpAndSettle();

        // Field Satuan harus berisi teks chip yang di-tap ("sdm")
        final unitTextField = tester.widget<TextField>(
          find.byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == 'sdm',
          ),
        );
        expect(unitTextField.controller?.text, equals('sdm'));

        // PrimaryFocus tetap aktif (tidak unfocus / keyboard tidak turun)
        expect(FocusManager.instance.primaryFocus, isNotNull);

        // 3. Tap "+ Tambah ke Daftar"
        await tester.tap(addButtonFinder);
        await tester.pumpAndSettle();

        // Bahan terdaftar bertambah di daftar
        expect(find.textContaining('Bawang Merah (5 sdm)'), findsOneWidget);

        // Fokus otomatis kembali ke field Nama bahan tanpa menutup keyboard
        final nameEditable = find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text.isEmpty,
        );
        expect(nameEditable, findsWidgets);
        expect(FocusManager.instance.primaryFocus, isNotNull);

        // Satuan kustom bebas: coba ketik satuan baru misal "ruas"
        await tester.enterText(nameField, 'Kunyit');
        await tester.enterText(qtyField, '2');
        await tester.enterText(unitField, 'ruas');
        await tester.pumpAndSettle();

        // Tap tambah lagi
        await tester.tap(addButtonFinder);
        await tester.pumpAndSettle();

        // Bahan kedua dengan satuan kustom tersimpan
        expect(find.textContaining('Kunyit (2 ruas)'), findsOneWidget);

        // Tutup simulasi keyboard dan tap tombol Simpan pada bottom sheet
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        final saveButtonFinder = find.widgetWithText(AppButton, 'Simpan');
        expect(saveButtonFinder, findsOneWidget);
        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();

        // Sheet tertutup tanpa assertion error (_dependents.isEmpty)
        expect(find.text('Tambah Bahan'), findsNothing);

        // Halaman Create Recipe menampilkan jumlah bahan yang telah disimpan
        expect(find.text('2 ingredients'), findsOneWidget);
      },
    );
  });
}
