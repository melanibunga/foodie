import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/nearby_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/location_provider.dart';
import 'package:foodie/providers/places_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/location_service.dart';
import 'package:foodie/services/route_service.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:foodie/widgets/illustrated_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

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

class _MockRouteService implements RouteService {
  @override
  Future<RouteResult> getFootRoute({
    required LatLng start,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    return RouteResult(
      points: [start, destination],
      distanceMeters: 300.0,
      durationSeconds: 240.0,
      isStraightLineFallback: false,
    );
  }
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

  group('Nearby Page (/nearby) Tests — PRD §17.6 Peta Penuh', () {
    testWidgets(
      'NearbyPage renders AppHeader, search bar, full map, tombol Pusatkan, dan atribusi OSM',
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
              routeServiceProvider.overrideWithValue(_MockRouteService()),
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

        // 2. Kolom pencarian melayang
        expect(find.text('Cari warung makan…'), findsOneWidget);

        // 3. Peta nyata (FlutterMap) mengisi layar
        expect(
          find.byWidgetPredicate((w) => w is FlutterMap || w is IllustratedMap),
          findsOneWidget,
        );

        // 4. Tombol Pusatkan & Atribusi lisensi
        expect(find.text('Pusatkan'), findsOneWidget);
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

        // 5. Elemen lama sudah dibersihkan
        expect(find.text('Pilihan Di Sekitarmu'), findsNothing);
        expect(find.text('Buka sekarang'), findsNothing);
        expect(find.text('Harga hemat'), findsNothing);

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pump();
      },
    );

    testWidgets(
      'Pencarian nama tempat di search bar menampilkan dropdown melayang dan kartu info',
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
              routeServiceProvider.overrideWithValue(_MockRouteService()),
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
        expect(find.text('Warung Bu Sari'), findsOneWidget);

        // Tap hasil
        await tester.tap(find.text('Warung Bu Sari'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Kartu info tempat terpilih melayang muncul di bawah
        expect(find.text('Warung Bu Sari'), findsOneWidget);
        expect(find.text('Rute'), findsOneWidget);
        expect(find.byKey(const ValueKey('close-place-card')), findsOneWidget);

        // Tap tombol Rute
        await tester.tap(find.text('Rute'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Membuka rute ke Warung Bu Sari'), findsOneWidget);

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pump();

        // Tap tutup kartu
        await tester.tap(find.byKey(const ValueKey('close-place-card')));
        await tester.pump();

        expect(find.byKey(const ValueKey('close-place-card')), findsNothing);
      },
    );
  });
}
