import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/create_recipe_page.dart';
import 'package:foodie/pages/home_page.dart';
import 'package:foodie/pages/my_recipes_page.dart';
import 'package:foodie/pages/recipe_detail_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/ui/app_badge.dart';
import 'package:foodie/widgets/ui/empty_state.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'test_helper.dart';

void main() {
  setUp(() {
    // mock storage initialized
  });

  group('Fase 11 — Create Recipe (/add) Tests', () {
    testWidgets(
      'CreateRecipePage renders AppHeader, title, fields, and DONE button',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.byType(CreateRecipePage), findsOneWidget);

        // 1. AppHeader global
        expect(find.byType(AppHeader), findsOneWidget);

        // 2. Baris judul: "< Create Recipe"
        expect(find.text('Create Recipe'), findsOneWidget);
        expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);

        // 3. Labels & Fields
        expect(find.text('Recipe Title'), findsOneWidget);
        expect(find.text('Type your recipe name here'), findsOneWidget);

        expect(find.text('Add Cover Image'), findsWidgets);
        expect(find.text('Ingredients'), findsOneWidget);
        expect(find.text('Add ingredients to recipe'), findsOneWidget);

        expect(find.text('Serving Size'), findsOneWidget);
        expect(find.text('2 Porsi'), findsOneWidget);

        expect(find.text('Cooking Instructions'), findsOneWidget);
        expect(find.text('Add one or multiple steps'), findsOneWidget);

        // 4. DONE button
        final doneBtn = find.text('DONE');
        expect(doneBtn, findsOneWidget);
      },
    );

    testWidgets('Tapping DONE with empty form triggers field validations', (
      tester,
    ) async {
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Tap DONE without entering any info
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(find.text('Recipe Title tidak boleh kosong'), findsOneWidget);
      expect(find.text('Minimal tambahkan 1 bahan'), findsOneWidget);
      expect(find.text('Minimal tambahkan 1 langkah memasak'), findsOneWidget);
    });

    testWidgets(
      'Full Create Recipe flow: enter details, save, see success dialog, and land on /my-recipes',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // 1. Enter Recipe Title
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'Nasi Liwet Gurih');
        await tester.pumpAndSettle();

        // 2. Open Ingredients Sheet & Add Ingredient
        await tester.tap(find.text('Add ingredients to recipe'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Bahan'), findsOneWidget);

        // Enter ingredient name & quantity
        final sheetFields = find.byType(TextField);
        await tester.enterText(sheetFields.at(1), 'Beras');
        await tester.enterText(sheetFields.at(2), '500');
        await tester.enterText(sheetFields.at(3), '12000');
        await tester.pumpAndSettle();

        // Tap "+ Tambah ke Daftar"
        await tester.tap(find.text('+ Tambah ke Daftar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Beras (500 g)'), findsOneWidget);

        // Tap "Simpan" in ingredients sheet
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('1 ingredients'), findsOneWidget);

        // 3. Open Cooking Instructions Sheet & Add Step
        await tester.tap(find.text('Add one or multiple steps'));
        await tester.pumpAndSettle();

        expect(find.text('Langkah Memasak'), findsOneWidget);

        // Tap "Tambah Langkah"
        await tester.tap(find.text('Tambah Langkah'));
        await tester.pumpAndSettle();

        expect(find.text('Detail Langkah'), findsOneWidget);

        // Fill in Step
        final stepFields = find.byType(TextField);
        await tester.enterText(stepFields.at(1), 'Masak Nasi');
        await tester.enterText(
          stepFields.at(2),
          'Campur beras dengan santan dan bumbu.',
        );
        await tester.enterText(stepFields.at(3), '25');
        await tester.pumpAndSettle();

        // Tap "Tambahkan"
        await tester.tap(find.text('Tambahkan'));
        await tester.pumpAndSettle();

        expect(find.text('Masak Nasi'), findsOneWidget);

        // Tap "Simpan" in instructions sheet
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('1 steps configured'), findsOneWidget);

        // 4. Scroll to DONE button and tap (pastikan melewati floating BottomNav)
        final doneFinder = find.text('DONE');
        await tester.scrollUntilVisible(
          doneFinder,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
        await tester.pumpAndSettle();
        await tester.tap(doneFinder);
        await tester.pumpAndSettle();

        // 5. Success Dialog should appear
        expect(find.text('Resep berhasil disimpan'), findsOneWidget);
        expect(
          find.text('Resepmu sudah bisa dilihat di Resep Saya.'),
          findsOneWidget,
        );

        // 6. Tap "Oke" in success dialog
        await tester.tap(find.text('Oke'));
        await tester.pumpAndSettle();

        // 7. Should navigate to /my-recipes
        expect(find.byType(MyRecipesPage), findsOneWidget);
        expect(find.text('Resep Saya'), findsOneWidget);
        expect(find.text('Nasi Liwet Gurih'), findsOneWidget);
      },
    );
  });

  group('Fase 11 — My Recipes (/my-recipes) Tests', () {
    testWidgets(
      'MyRecipesPage shows EmptyState when user has no custom recipes',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = await initTestBoxes();

        final router = createRouter(
          initialLocation: '/my-recipes',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.byType(MyRecipesPage), findsOneWidget);

        // Header & Badge count 0
        expect(find.text('Resep Saya'), findsOneWidget);
        expect(find.byType(AppBadge), findsOneWidget);
        expect(find.text('0'), findsOneWidget);

        // Empty State
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Belum Ada Resep'), findsOneWidget);
        expect(
          find.text('Belum ada resep. Yuk buat yang pertama!'),
          findsOneWidget,
        );

        // Button "Buat Resep"
        final addBtn = find.text('Buat Resep');
        expect(addBtn, findsOneWidget);

        // Tap "Buat Resep" navigates to /add
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.byType(CreateRecipePage), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping trash icon deletes recipe and shows confirmation dialog',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Pre-seed a custom recipe in shared_preferences
        final boxes = await initTestBoxes();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'foodie:my_recipes',
          '[{"id":"custom-test-1","title":"Sambal Matah Bali","description":"Sambal segar khas Bali","category":"Kreasi","cuisine":"Indonesian","meal":"lunch","mainIngredient":"Cabai","rating":5.0,"reviews":1,"timeMin":10,"servings":2,"kcal":120,"difficulty":"mudah","ingredients":[{"id":"i1","name":"Cabai rawit","qty":"10","unit":"buah","price":2000}],"steps":[{"id":"s1","title":"Iris Bumbu","description":"Iris tipis semua bahan lalu siram minyak panas."}],"authorId":"user-default-1"}]',
        );

        final router = createRouter(
          initialLocation: '/my-recipes',
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Card rendered
        expect(find.text('Sambal Matah Bali'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // Badge count 1

        // Tap trash icon
        await tester.tap(find.byIcon(LucideIcons.trash2));
        await tester.pumpAndSettle();

        // Confirmation dialog
        expect(find.text('Hapus resep?'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);

        // Cancel
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.text('Sambal Matah Bali'), findsOneWidget);

        // Tap trash icon again and confirm
        await tester.tap(find.byIcon(LucideIcons.trash2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Recipe should be removed, EmptyState should appear
        expect(find.text('Sambal Matah Bali'), findsNothing);
        expect(find.text('Belum Ada Resep'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2500));
      },
    );

    testWidgets('Tapping custom recipe card opens recipe detail page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'foodie:my_recipes',
        '[{"id":"custom-test-2","title":"Karedok Sunda","description":"Sayuran mentah segar saus kacang","category":"Kreasi","cuisine":"Indonesian","meal":"lunch","mainIngredient":"Sayur","rating":5.0,"reviews":1,"timeMin":15,"servings":2,"kcal":210,"difficulty":"mudah","ingredients":[{"id":"i1","name":"Kacang panjang","qty":"5","unit":"ikat","price":3000}],"steps":[{"id":"s1","title":"Ulek Bumbu","description":"Ulek cabai, kencur, kacang, dan gula merah."}],"authorId":"user-default-1"}]',
      );

      final router = createRouter(
        initialLocation: '/my-recipes',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Tap recipe card
      await tester.tap(find.text('Karedok Sunda'));
      await tester.pumpAndSettle();

      // Should open RecipeDetailPage
      expect(find.byType(RecipeDetailPage), findsOneWidget);
      expect(find.text('Karedok Sunda'), findsOneWidget);
      expect(find.text('Kacang panjang'), findsOneWidget);
      expect(find.text('Ulek Bumbu'), findsOneWidget);
    });

    testWidgets('Tapping sticky button Kembali Ke Beranda navigates to /home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = await initTestBoxes();

      final router = createRouter(
        initialLocation: '/my-recipes',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Tap "Kembali Ke Beranda"
      await tester.tap(find.text('Kembali Ke Beranda'));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
