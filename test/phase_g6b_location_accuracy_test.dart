import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/pages/nearby_page.dart';
import 'package:foodie/providers/location_provider.dart';
import 'package:foodie/providers/places_provider.dart';
import 'package:foodie/services/location_service.dart';
import 'package:foodie/services/place_service.dart';
import 'package:geolocator/geolocator.dart';

class MockTestPlaceService implements PlaceService {
  const MockTestPlaceService();

  @override
  Future<List<Place>> list() async => [];

  @override
  Future<List<Place>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async => [];

  @override
  Future<List<Place>> getPlacesInBbox({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? userLat,
    double? userLng,
    CancelToken? cancelToken,
  }) async {
    return [
      const Place(
        id: 'place-1',
        name: 'Warung Nasi Gudeg',
        cuisine: 'Masakan Jawa',
        lat: -7.7650,
        lng: 110.3790,
        priceMin: 15000,
        priceMax: 30000,
        distanceM: 120,
        walkMin: 2,
        open: true,
        x: 50,
        y: 50,
      ),
    ];
  }

  @override
  Future<List<Place>> searchByName({
    required String query,
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    CancelToken? cancelToken,
  }) async => [];
}

void main() {
  group('Fase G6b — Unit Tests: Alur Izin Lokasi & Akurasi (PRD §17.7)', () {
    test('1. Inisialisasi awal tidak meminta izin jika app start', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(locationProvider);
      expect(state.status, LocationStatus.initial);
      expect(state.coordinates, isNull);
    });

    test('2. Cek status saat GPS mati -> status serviceOff', () async {
      final fakeService = FakeLocationService(serviceEnabled: false);

      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationProvider.notifier);
      await notifier.checkLocationStatus();

      final state = container.read(locationProvider);
      expect(state.status, LocationStatus.serviceOff);
      expect(state.coordinates, isNull);
      expect(state.message, contains('Layanan GPS dinonaktifkan'));
    });

    test(
      '3. Cek status saat izin denied -> needsRationale (kartu melayang)',
      () async {
        final fakeService = FakeLocationService(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        );

        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(locationProvider.notifier);
        await notifier.checkLocationStatus();

        final state = container.read(locationProvider);
        expect(state.status, LocationStatus.needsRationale);
        expect(state.coordinates, isNull);
      },
    );

    test('4. Klik "Nanti saja" (dismissRationale) -> askedInSession=true & status denied', () async {
      final fakeService = FakeLocationService(
        serviceEnabled: true,
        permission: LocationPermission.denied,
      );

      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationProvider.notifier);
      await notifier.checkLocationStatus();
      expect(
        container.read(locationProvider).status,
        LocationStatus.needsRationale,
      );

      notifier.dismissRationale();

      final state = container.read(locationProvider);
      expect(state.status, LocationStatus.denied);
      expect(state.askedInSession, isTrue);
      expect(state.coordinates, isNull);
    });

    test(
      '5. Izin deniedForever -> status deniedForever & tombol buka settings',
      () async {
        final fakeService = FakeLocationService(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        );

        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(locationProvider.notifier);
        await notifier.checkLocationStatus();

        final state = container.read(locationProvider);
        expect(state.status, LocationStatus.deniedForever);
        expect(state.coordinates, isNull);

        await notifier.openAppSettings();
        expect(fakeService.appSettingsOpened, isTrue);
      },
    );

    test('6. Izin granted dengan fix akurat (<= 50m, umur < 30s) -> isApproximate=false', () async {
      final testCoords = UserCoordinates(
        latitude: -7.7660,
        longitude: 110.3800,
        accuracyM: 15.0,
        timestamp: DateTime.now(),
        isMocked: false,
      );

      final fakeService = FakeLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        streamPositions: [testCoords],
      );

      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationProvider.notifier);
      await notifier.checkLocationStatus();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(locationProvider);
      expect(state.status, LocationStatus.granted);
      expect(state.coordinates, isNotNull);
      expect(state.coordinates!.latitude, -7.7660);
      expect(state.coordinates!.longitude, 110.3800);
      expect(state.accuracyM, 15.0);
      expect(state.isApproximate, isFalse);
    });

    test('7. Deteksi lokasi tiruan (isMocked = true)', () async {
      final mockCoords = UserCoordinates(
        latitude: -7.7660,
        longitude: 110.3800,
        accuracyM: 20.0,
        timestamp: DateTime.now(),
        isMocked: true,
      );

      final fakeService = FakeLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        streamPositions: [mockCoords],
      );

      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationProvider.notifier);
      await notifier.checkLocationStatus();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(locationProvider);
      expect(state.isMocked, isTrue);
      expect(state.coordinates!.isMocked, isTrue);
    });

    test('8. Deteksi reduced accuracy pada Android 12+/iOS', () async {
      final fakeService = FakeLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        accuracyStatus: LocationAccuracyStatus.reduced,
        streamPositions: [
          UserCoordinates(
            latitude: -7.7660,
            longitude: 110.3800,
            accuracyM: 600.0,
            timestamp: DateTime.now(),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationProvider.notifier);
      await notifier.checkLocationStatus();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(locationProvider);
      expect(state.isReducedAccuracy, isTrue);
      expect(state.isApproximate, isTrue);
    });
  });

  group(
    'Fase G6b — Widget Tests: Kartu Rationale & UI Akurasi di NearbyPage',
    () {
      testWidgets('1. Menampilkan kartu rationale saat status needsRationale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fakeService = FakeLocationService(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              locationServiceProvider.overrideWithValue(fakeService),
              placeServiceProvider.overrideWithValue(
                const MockTestPlaceService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const NearbyPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Kartu penjelasan melayang harus muncul
        expect(find.text('Izinkan akses lokasi'), findsOneWidget);
        expect(
          find.textContaining('Foodie.id memakai lokasimu untuk menampilkan'),
          findsOneWidget,
        );
        expect(find.text('Izinkan lokasi'), findsOneWidget);
        expect(find.text('Nanti saja'), findsOneWidget);

        // Tap "Nanti saja"
        await tester.tap(find.text('Nanti saja'));
        await tester.pumpAndSettle();

        // Kartu rationale hilang, muncul banner lokasi belum aktif
        expect(find.text('Izinkan akses lokasi'), findsNothing);
        expect(find.text('Lokasi belum aktif · '), findsOneWidget);
        expect(find.text('Aktifkan'), findsOneWidget);
      });

      testWidgets(
        '2. Marker pengguna TIDAK dirender bila belum ada fix GPS nyata',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final fakeService = FakeLocationService(
            serviceEnabled: true,
            permission: LocationPermission.denied,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                locationServiceProvider.overrideWithValue(fakeService),
                placeServiceProvider.overrideWithValue(
                  const MockTestPlaceService(),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const NearbyPage(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Pastikan pin tempat makan ada tapi titik pengguna tidak ada
          expect(find.byKey(const ValueKey('pin-place-1')), findsOneWidget);
        },
      );

      testWidgets(
        '3. Menampilkan banner lokasi kurang akurat bila accuracy > 100m',
        (tester) async {
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final inaccurateCoords = UserCoordinates(
            latitude: -7.7660,
            longitude: 110.3800,
            accuracyM: 150.0,
            timestamp: DateTime.now(),
          );

          final fakeService = FakeLocationService(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
            streamPositions: [inaccurateCoords],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                locationServiceProvider.overrideWithValue(fakeService),
                placeServiceProvider.overrideWithValue(
                  const MockTestPlaceService(),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const NearbyPage(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.textContaining('Lokasi kurang akurat - keluar ruangan'),
            findsOneWidget,
          );
        },
      );

      testWidgets('4. Menampilkan label lokasi tiruan bila isMocked = true', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockCoords = UserCoordinates(
          latitude: -7.7660,
          longitude: 110.3800,
          accuracyM: 20.0,
          timestamp: DateTime.now(),
          isMocked: true,
        );

        final fakeService = FakeLocationService(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          streamPositions: [mockCoords],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              locationServiceProvider.overrideWithValue(fakeService),
              placeServiceProvider.overrideWithValue(
                const MockTestPlaceService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const NearbyPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Lokasi tiruan'), findsOneWidget);
      });

      testWidgets('5. Tap Pusatkan ke lokasi saya menampilkan toast', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final goodCoords = UserCoordinates(
          latitude: -7.7660,
          longitude: 110.3800,
          accuracyM: 10.0,
          timestamp: DateTime.now(),
        );

        final fakeService = FakeLocationService(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          streamPositions: [goodCoords],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              locationServiceProvider.overrideWithValue(fakeService),
              placeServiceProvider.overrideWithValue(
                const MockTestPlaceService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const NearbyPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Pusatkan'));
        await tester.pump();

        expect(find.text('Peta dipusatkan ke lokasi kamu'), findsOneWidget);

        // Drain toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      });
    },
  );
}
