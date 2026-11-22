import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
import 'package:foodie/services/place_service.dart';
import 'package:foodie/widgets/app_header.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

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

FoodieBoxes createFakeFoodieBoxes() {
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

class MockLocationService extends LocationService {
  final bool serviceEnabled;
  final LocationPermission permission;
  final UserCoordinates? position;

  const MockLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position = const UserCoordinates(
      latitude: -7.7653,
      longitude: 110.3789,
    ),
  });

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<UserCoordinates?> getCurrentPosition() async => position;
}

class _FakeDioAdapter implements HttpClientAdapter {
  int requestCount = 0;
  final List<RequestOptions> executedRequests = [];
  Map<String, dynamic>? Function(RequestOptions options)? onFetch;

  _FakeDioAdapter({this.onFetch});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    executedRequests.add(options);

    final data = onFetch?.call(options) ?? {'elements': []};
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

  group('Fase G6 — Unit Tests: Parser & OverpassPlaceService (PRD §17.6)', () {
    test('1. Parser Overpass JSON: node & way/center diparsing, elemen tanpa nama diabaikan', () {
      final fixture = {
        'elements': [
          // Node valid dengan nama
          {
            'type': 'node',
            'id': 101,
            'lat': -7.7650,
            'lon': 110.3790,
            'tags': {
              'name': 'Warung Soto Seger',
              'amenity': 'restaurant',
              'cuisine': 'soto;indonesian',
              'opening_hours': '07:00-21:00',
            },
          },
          // Way valid dengan center dan nama
          {
            'type': 'way',
            'id': 202,
            'center': {'lat': -7.7660, 'lon': 110.3800},
            'tags': {
              'name': 'Kopi Klotok Branch',
              'amenity': 'cafe',
              'cuisine': 'coffee_shop',
              'opening_hours': '24/7',
            },
          },
          // Node tanpa nama -> HARUS DIABAIKAN jika ignoreNameless: true
          {
            'type': 'node',
            'id': 303,
            'lat': -7.7670,
            'lon': 110.3810,
            'tags': {'amenity': 'fast_food'},
          },
          // Node dengan nama kosong -> HARUS DIABAIKAN jika ignoreNameless: true
          {
            'type': 'node',
            'id': 404,
            'lat': -7.7680,
            'lon': 110.3820,
            'tags': {'name': '   ', 'amenity': 'restaurant'},
          },
        ],
      };

      final places = OverpassPlaceService.parseOverpassResponse(
        fixture,
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 5000,
        ignoreNameless: true,
      );

      // Hanya 2 elemen valid yang diparsing, elemen tanpa nama diabaikan
      expect(places.length, 2);

      final soto = places.firstWhere((p) => p.id == 'node-101');
      expect(soto.name, 'Warung Soto Seger');
      expect(soto.type, 'restaurant');
      expect(soto.cuisine, 'soto, indonesian');
      expect(soto.lat, -7.7650);
      expect(soto.lng, 110.3790);

      final cafe = places.firstWhere((p) => p.id == 'way-202');
      expect(cafe.name, 'Kopi Klotok Branch');
      expect(cafe.type, 'cafe');
      expect(cafe.open, isTrue);
    });

    test('2. Parser Overpass JSON: batas maksimal 80 titik', () {
      final elements = List.generate(100, (i) {
        return {
          'type': 'node',
          'id': 1000 + i,
          'lat': -7.7650 + (i * 0.0001),
          'lon': 110.3790 + (i * 0.0001),
          'tags': {'name': 'Warung Makan $i', 'amenity': 'restaurant'},
        };
      });

      final fixture = {'elements': elements};

      final places = OverpassPlaceService.parseOverpassResponse(
        fixture,
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 5000,
        ignoreNameless: true,
        limit: 80,
      );

      // Dibatasi tepat 80 titik
      expect(places.length, 80);
    });

    test(
      '3. Cache Bbox: panggilan kedua dalam 10 menit tidak memukul jaringan',
      () async {
        final fakeAdapter = _FakeDioAdapter(
          onFetch: (options) => {
            'elements': [
              {
                'type': 'node',
                'id': 505,
                'lat': -7.7655,
                'lon': 110.3795,
                'tags': {'name': 'Gudeg Sagan Asli', 'amenity': 'restaurant'},
              },
            ],
          },
        );

        final dio = Dio();
        dio.httpClientAdapter = fakeAdapter;

        final service = OverpassPlaceService(dio: dio);

        // Panggilan pertama -> harus memukul jaringan (count = 1)
        final places1 = await service.getPlacesInBbox(
          minLat: -7.770,
          minLon: 110.370,
          maxLat: -7.760,
          maxLon: 110.380,
        );
        expect(places1.length, 1);
        expect(places1.first.name, 'Gudeg Sagan Asli');
        expect(fakeAdapter.requestCount, 1);

        // Panggilan kedua dengan bbox yang sama -> mengambil dari cache in-memory (count tetap 1)
        final places2 = await service.getPlacesInBbox(
          minLat: -7.770,
          minLon: 110.370,
          maxLat: -7.760,
          maxLon: 110.380,
        );
        expect(places2.length, 1);
        expect(places2.first.name, 'Gudeg Sagan Asli');
        expect(fakeAdapter.requestCount, 1);
      },
    );

    test('4. Pencarian nama (searchByName): Overpass regex nama & terurut berdasarkan jarak', () async {
      final fakeAdapter = _FakeDioAdapter(
        onFetch: (options) {
          return {
            'elements': [
              {
                'type': 'node',
                'id': 11,
                'lat': -7.7750, // Lebih jauh
                'lon': 110.3790,
                'tags': {'name': 'Bakso Jauh Enak', 'amenity': 'restaurant'},
              },
              {
                'type': 'node',
                'id': 12,
                'lat': -7.7654, // Sangat dekat (~15 meter dari -7.7653)
                'lon': 110.3789,
                'tags': {'name': 'Bakso Dekat Sedap', 'amenity': 'restaurant'},
              },
            ],
          };
        },
      );

      final dio = Dio();
      dio.httpClientAdapter = fakeAdapter;

      final service = OverpassPlaceService(dio: dio);

      final results = await service.searchByName(
        query: 'Bakso',
        latitude: -7.7653,
        longitude: 110.3789,
      );

      expect(results.length, 2);
      // Terurut jarak: terdekat muncul pertama
      expect(results[0].name, 'Bakso Dekat Sedap');
      expect(results[1].name, 'Bakso Jauh Enak');
      expect(results[0].distanceM, lessThan(results[1].distanceM));

      // Verifikasi query Overpass memuat regex name case-insensitive
      final requestData = fakeAdapter.executedRequests.first.data.toString();
      expect(
        requestData,
        contains(Uri.encodeQueryComponent('["name"~"Bakso",i]')),
      );
    });

    test('5. Pembatalan request usang (CancelToken)', () async {
      final cancelToken = CancelToken();

      final dio = Dio();
      dio.httpClientAdapter = _FakeDioAdapter(
        onFetch: (options) {
          cancelToken.cancel('User moved camera quickly');
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            message: 'User moved camera quickly',
          );
        },
      );

      final service = OverpassPlaceService(dio: dio);

      expect(
        () => service.getPlacesInBbox(
          minLat: -7.770,
          minLon: 110.370,
          maxLat: -7.760,
          maxLon: 110.380,
          cancelToken: cancelToken,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('Fase G6 — Widget Tests: Layout Peta Penuh & Interaksi NearbyPage', () {
    testWidgets(
      'NearbyPage renders AppHeader, search bar melayang, tombol Pusatkan, dan atribusi OSM',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = createFakeFoodieBoxes();

        final router = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        final dio = Dio();
        dio.httpClientAdapter = _FakeDioAdapter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              foodieBoxesProvider.overrideWithValue(boxes),
              placeDioProvider.overrideWithValue(dio),
              locationServiceProvider.overrideWithValue(
                const MockLocationService(),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. AppHeader tetap fixed di atas (§14.3)
        expect(find.byType(AppHeader), findsOneWidget);
        expect(find.byType(NearbyPage), findsOneWidget);

        // 2. Kolom pencarian di atas kartu
        expect(find.text('Cari warung makan…'), findsOneWidget);

        // 3. Kartu Peta
        expect(find.text('Warung Makan Terdekat'), findsOneWidget);
        expect(find.text('Peta Penuh'), findsOneWidget);
        expect(find.text('Open Maps'), findsOneWidget);

        // 4. Atribusi lisensi OpenStreetMap wajib
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

        // 5. Daftar Pilihan Di Sekitarmu
        expect(find.text('Pilihan Di Sekitarmu'), findsOneWidget);

        // Drain toast timer bila ada
        await tester.pump(const Duration(milliseconds: 2300));
      },
    );

    testWidgets(
      'Pencarian nama tempat di search bar menampilkan dropdown melayang',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boxes = createFakeFoodieBoxes();

        // Fake Dio untuk Search & Bbox
        final fakeAdapter = _FakeDioAdapter(
          onFetch: (options) {
            return {
              'elements': [
                {
                  'type': 'node',
                  'id': 888,
                  'lat': -7.7660,
                  'lon': 110.3795,
                  'tags': {
                    'name': 'Sate Klatak Mak Adi',
                    'amenity': 'restaurant',
                    'cuisine': 'sate;indonesian',
                    'opening_hours': '24/7',
                  },
                },
              ],
            };
          },
        );

        final dio = Dio();
        dio.httpClientAdapter = fakeAdapter;

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
                const MockLocationService(),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ketik di kolom search bar
        await tester.enterText(find.byType(TextField), 'Sate');
        // Debounce 400 ms + proses future
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        // Dropdown hasil pencarian muncul dengan nama tempat
        expect(find.text('Sate Klatak Mak Adi'), findsWidgets);
      },
    );
  });
}
