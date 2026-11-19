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
import 'package:foodie/services/route_service.dart';
import 'package:foodie/widgets/real_map_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class MockFailingRouteService implements RouteService {
  @override
  Future<RouteResult> getFootRoute({
    required LatLng start,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    // Simulasi kegagalan koneksi / OSRM offline -> fallback garis lurus
    final distance = OsrmRouteService.calculateHaversineDistanceMeters(
      start,
      destination,
    );
    return RouteResult(
      points: [start, destination],
      distanceMeters: distance,
      durationSeconds: distance / 1.33,
      isStraightLineFallback: true,
      errorMessage: 'Network error',
    );
  }
}

class MockSuccessfulRouteService implements RouteService {
  @override
  Future<RouteResult> getFootRoute({
    required LatLng start,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    // Simulasi rute sukses mengikuti jalan (3+ titik)
    final mid1 = LatLng(
      start.latitude + (destination.latitude - start.latitude) * 0.4,
      start.longitude,
    );
    final mid2 = LatLng(
      start.latitude + (destination.latitude - start.latitude) * 0.4,
      destination.longitude,
    );
    return RouteResult(
      points: [start, mid1, mid2, destination],
      distanceMeters: 220.0,
      durationSeconds: 165.0,
      isStraightLineFallback: false,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
      'foodie:favorites': jsonEncode([]),
      'foodie:ratings': jsonEncode({}),
    });
  });

  group('Fase B7 — Unit Test: Parser Respons OSRM (PRD §14.12)', () {
    test('parseOsrmResponse: sukses mengurai GeoJSON LineString, jarak, dan durasi', () {
      final start = const LatLng(-7.7653, 110.3789);
      final dest = const LatLng(-7.7640, 110.3800);

      final sampleJson = {
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [110.3789, -7.7653],
                [110.3795, -7.7648],
                [110.3800, -7.7640],
              ],
              'type': 'LineString',
            },
            'distance': 215.4,
            'duration': 161.5,
          },
        ],
      };

      final result = OsrmRouteService.parseOsrmResponse(
        sampleJson,
        start,
        dest,
      );

      expect(result.isStraightLineFallback, isFalse);
      expect(result.points.length, 3);
      expect(result.points[0].latitude, -7.7653);
      expect(result.points[0].longitude, 110.3789);
      expect(result.points[2].latitude, -7.7640);
      expect(result.points[2].longitude, 110.3800);
      expect(result.distanceMeters, 215.4);
      expect(result.formattedDistance, '215 m');
      expect(result.formattedDuration, '3 menit');
      expect(result.distanceAndDurationString, '215 m · 3 menit');
    });

    test('parseOsrmResponse: fallback garis lurus bila respons OSRM tidak Ok atau kosong', () {
      final start = const LatLng(-7.7653, 110.3789);
      final dest = const LatLng(-7.7640, 110.3800);

      final errorJson = {'code': 'NoRoute', 'routes': []};

      final result = OsrmRouteService.parseOsrmResponse(errorJson, start, dest);

      expect(result.isStraightLineFallback, isTrue);
      expect(result.points.length, 2);
      expect(result.points[0], start);
      expect(result.points[1], dest);
      expect(result.distanceMeters, greaterThan(0));
      expect(result.errorMessage, contains('OSRM status code not Ok'));
    });
  });

  group('Fase B7 — Unit Test: LocalPlaceService Jarak Relatif (PRD §14.12)', () {
    const service = LocalPlaceService();
    const userLat = -7.7653;
    const userLng = 110.3789;

    test('nearby: menghasilkan 3+ tempat makan mock relatif terhadap lokasi pengguna', () async {
      final places = await service.nearby(
        latitude: userLat,
        longitude: userLng,
        radiusMeters: 5000,
      );

      expect(places.length, greaterThanOrEqualTo(3));

      // Verifikasi setiap tempat memiliki koordinat dan jarak yang mendekati distanceM
      for (final place in places) {
        expect(place.lat, isNotNull);
        expect(place.lng, isNotNull);

        final calcDistance = OsrmRouteService.calculateHaversineDistanceMeters(
          const LatLng(userLat, userLng),
          LatLng(place.latitude, place.longitude),
        );

        // Selisih antara jarak kalkulasi Haversine dan distanceM template < 25 meter
        final difference = (calcDistance - place.distanceM).abs();
        expect(
          difference,
          lessThan(25.0),
          reason:
              'Jarak ${place.name} ($calcDistance m) harus mendekati ${place.distanceM} m',
        );
      }
    });

    test('nearby: filter radius bekerja memotong tempat yang berada di luar radius', () async {
      // Radius 500 m hanya mencakup tempat dengan jarak <= 500 m (Warung Bu Sari 180m, Ayam Bakar Pak Hadi 450m)
      final places500 = await service.nearby(
        latitude: userLat,
        longitude: userLng,
        radiusMeters: 500,
      );
      expect(places500.length, 2);
      expect(places500.every((p) => p.distanceM <= 500), isTrue);

      // Radius 1000 m menambah Warung Padang Salero (700m)
      final places1000 = await service.nearby(
        latitude: userLat,
        longitude: userLng,
        radiusMeters: 1000,
      );
      expect(places1000.length, 3);
      expect(places1000.every((p) => p.distanceM <= 1000), isTrue);
    });
  });

  group('Fase B7 — Unit Test: Route Fallback saat Error', () {
    test('MockFailingRouteService: mengembalikan garis lurus saat terjadi error koneksi', () async {
      final routeService = MockFailingRouteService();
      final start = const LatLng(-7.7653, 110.3789);
      final dest = const LatLng(-7.7640, 110.3800);

      final result = await routeService.getFootRoute(
        start: start,
        destination: dest,
      );

      expect(result.isStraightLineFallback, isTrue);
      expect(result.points.length, 2);
      expect(result.points[0], start);
      expect(result.points[1], dest);
      expect(result.distanceMeters, greaterThan(0));
    });
  });

  group('Fase B7 — Widget Tests: RealMapView & NearbyPage', () {
    testWidgets(
      'RealMapView menampilkan atribusi OSM wajib, pill radius, pin bernomor, dan tombol pusatkan',
      (tester) async {
        final places = const LocalPlaceService().getPlacesSync(
          latitude: -7.7653,
          longitude: 110.3789,
        );

        String? selectedPlaceId = places.first.id;
        bool centerTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: RealMapView(
                places: places,
                selectedPlaceId: selectedPlaceId,
                radiusLabel: 'Radius 1 km',
                onSelectPlace: (id) => selectedPlaceId = id,
                onCenterTap: () => centerTapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Atribusi OSM wajib (PRD §14.12)
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

        // 2. Pill Radius
        expect(find.text('Radius 1 km'), findsOneWidget);

        // 3. Tombol Pusatkan
        final centerBtn = find.text('Pusatkan');
        expect(centerBtn, findsOneWidget);
        await tester.tap(centerBtn);
        expect(centerTapped, isTrue);

        // 4. Pin bernomor: pin 1, 2, 3
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        // Tap pin 2
        await tester.tap(find.text('2'));
        expect(selectedPlaceId, places[1].id);
      },
    );

    testWidgets(
      'NearbyPage memuat peta nyata secara default dan menampilkan rute ke tempat makan',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              locationServiceProvider.overrideWithValue(
                const MockLocationService(),
              ),
              routeServiceProvider.overrideWithValue(
                MockSuccessfulRouteService(),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Peta nyata aktif secara default
        expect(find.byType(RealMapView), findsOneWidget);
        expect(find.text('Radius 1 km'), findsOneWidget);

        // 2. Daftar tempat tampil dan dinamis
        expect(find.text('Pilihan Di Sekitarmu'), findsOneWidget);
        expect(find.textContaining('tempat'), findsOneWidget);
        expect(find.text('Warung Bu Sari'), findsOneWidget);

        // 3. Tap tombol "Rute" pada kartu kedua
        final ruteButtons = find.text('Rute');
        expect(ruteButtons, findsWidgets);

        await tester.tap(ruteButtons.at(1));
        await tester.pump();

        // Toast feedback "Membuka rute ke ..."
        expect(
          find.textContaining('Membuka rute ke Ayam Bakar Pak Hadi'),
          findsOneWidget,
        );

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'NearbyPage fallback ke garis lurus dan toast bila rute gagal',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        final router = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              locationServiceProvider.overrideWithValue(
                const MockLocationService(),
              ),
              routeServiceProvider.overrideWithValue(MockFailingRouteService()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(RealMapView), findsOneWidget);

        // Drain initial route toast if any
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();

        // Tap kartu Ayam Bakar Pak Hadi untuk memicu rute fallback
        await tester.tap(find.text('Ayam Bakar Pak Hadi'));
        await tester.pump();

        // Toast rute jalan tidak tersedia muncul
        expect(
          find.text('Rute jalan tidak tersedia, menampilkan garis lurus'),
          findsOneWidget,
        );

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Responsive layouts (360x640, 390x844, 440x956) render NearbyPage without overflow',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final sizes = [
          const Size(360, 640),
          const Size(390, 844),
          const Size(440, 956),
        ];

        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final router = createRouter(
            initialLocation: '/nearby',
            getAuthState: () =>
                const AuthState(isLoggedIn: true, user: seedUser),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                locationServiceProvider.overrideWithValue(
                  const MockLocationService(),
                ),
                routeServiceProvider.overrideWithValue(
                  MockSuccessfulRouteService(),
                ),
              ],
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(NearbyPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
      },
    );
  });
}
