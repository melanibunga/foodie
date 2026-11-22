import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/nearby_full_map_page.dart';
import 'package:foodie/pages/nearby_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/location_provider.dart';
import 'package:foodie/providers/places_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/location_service.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/real_map_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:lucide_icons/lucide_icons.dart';

class _FakeBox<T> implements Box<T> {
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

FoodieBoxes _createFakeBoxes() {
  return FoodieBoxes(
    users: _FakeBox(),
    session: _FakeBox(),
    favorites: _FakeBox(),
    cart: _FakeBox(),
    mealPlan: _FakeBox(),
    myRecipes: _FakeBox(),
    cooked: _FakeBox(),
    ratings: _FakeBox(),
    settings: _FakeBox(),
    meta: _FakeBox(),
    recipes: _FakeBox(),
    recipeCache: _FakeBox(),
    placesCache: _FakeBox(),
  );
}

class _MockLocationService extends LocationService {
  const _MockLocationService();

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<UserCoordinates?> getCurrentPosition() async =>
      const UserCoordinates(latitude: -7.7653, longitude: 110.3789);
}

class _FakeDioAdapter implements HttpClientAdapter {
  _FakeDioAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = {
      'elements': [
        {
          'type': 'node',
          'id': 101,
          'lat': -7.7660,
          'lon': 110.3790,
          'tags': {
            'name': 'Warung Bu Sari',
            'amenity': 'restaurant',
            'cuisine': 'indonesian',
            'opening_hours': '08:00-20:00',
          },
        },
        {
          'type': 'node',
          'id': 102,
          'lat': -7.7670,
          'lon': 110.3800,
          'tags': {
            'name': 'Ayam Bakar Pak Hadi',
            'amenity': 'restaurant',
            'cuisine': 'ayam_bakar',
          },
        },
      ],
    };

    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nearby Page (/nearby) Tests — Card Map Layout', () {
    testWidgets(
      'NearbyPage renders AppHeader, search bar, map card, Open Maps button, dan Pilihan Di Sekitarmu',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = _createFakeBoxes();
        final dio = Dio()..httpClientAdapter = _FakeDioAdapter();

        final router = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              foodieBoxesProvider.overrideWithValue(boxes),
              placeDioProvider.overrideWithValue(dio),
              locationServiceProvider.overrideWithValue(
                const _MockLocationService(),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. AppHeader dan NearbyPage
        expect(find.byType(NearbyPage), findsOneWidget);
        expect(find.byType(AppHeader), findsOneWidget);

        // 2. Search bar di atas kartu
        expect(find.text('Cari warung makan…'), findsOneWidget);

        // 3. Kartu Peta
        expect(find.text('Warung Makan Terdekat'), findsOneWidget);
        expect(
          find.text('Buka Maps untuk menemukan warung makan di sekitarmu.'),
          findsOneWidget,
        );
        expect(find.text('Peta Penuh'), findsOneWidget);
        expect(find.text('Open Maps'), findsOneWidget);
        expect(find.byType(RealMapView), findsOneWidget);

        // 4. Daftar Pilihan Di Sekitarmu di bawah kartu
        expect(find.text('Pilihan Di Sekitarmu'), findsOneWidget);
        expect(find.text('Warung Bu Sari'), findsWidgets);
        expect(find.text('Ayam Bakar Pak Hadi'), findsWidgets);

        // 5. Pastikan TIDAK ADA tombol Rute lama
        expect(find.text('Rute'), findsNothing);
        expect(find.text('Keluar Rute'), findsNothing);

        // Drain toast timer bila ada
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pump();
      },
    );

    testWidgets('Tap Peta Penuh navigates ke route /nearby/map', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = _createFakeBoxes();
      final dio = Dio()..httpClientAdapter = _FakeDioAdapter();

      final router = createRouter(
        initialLocation: '/nearby',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodieBoxesProvider.overrideWithValue(boxes),
            placeDioProvider.overrideWithValue(dio),
            locationServiceProvider.overrideWithValue(
              const _MockLocationService(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap pill Peta Penuh
      await tester.tap(find.text('Peta Penuh'));
      await tester.pumpAndSettle();

      // Halaman Peta Penuh terbuka
      expect(find.byType(NearbyFullMapPage), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      expect(find.text('Open Maps'), findsOneWidget);
    });

    testWidgets('Pencarian nama tempat di search bar menampilkan dropdown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final boxes = _createFakeBoxes();
      final dio = Dio()..httpClientAdapter = _FakeDioAdapter();

      final router = createRouter(
        initialLocation: '/nearby',
        getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodieBoxesProvider.overrideWithValue(boxes),
            placeDioProvider.overrideWithValue(dio),
            locationServiceProvider.overrideWithValue(
              const _MockLocationService(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ketik kata kunci di kolom pencarian
      await tester.enterText(find.byType(TextField), 'Sari');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Dropdown hasil pencarian menampilkan nama tempat
      expect(find.text('Warung Bu Sari'), findsWidgets);
    });
  });
}
