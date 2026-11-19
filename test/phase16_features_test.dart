import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/app/app.dart';
import 'package:foodie/app/router.dart';
import 'package:foodie/core/theme/app_colors.dart';
import 'package:foodie/core/theme/app_theme.dart';
import 'package:foodie/data/places.dart';
import 'package:foodie/data/user.dart';
import 'package:foodie/pages/nearby_page.dart';
import 'package:foodie/providers/auth_provider.dart';
import 'package:foodie/providers/location_provider.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:foodie/services/location_service.dart';
import 'package:foodie/widgets/illustrated_map.dart';
import 'package:foodie/widgets/real_map_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocationService extends LocationService {
  final bool serviceEnabled;
  final LocationPermission permission;
  final UserCoordinates? position;

  const MockLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position = const UserCoordinates(
      latitude: -7.7650,
      longitude: 110.3790,
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'foodie:auth': jsonEncode(
        const AuthState(isLoggedIn: true, user: seedUser).toJson(),
      ),
    });
  });

  group('Fase 16 — Dark Mode & Real Map Tests', () {
    test('Dark theme tokens & ThemeData are properly configured', () {
      final darkTheme = AppTheme.darkTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.primary, AppColors.oliveDark);
      expect(darkTheme.colorScheme.surface, AppColors.surfaceDark);
      expect(darkTheme.colorScheme.outline, AppColors.borderDark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.bgDark);
    });

    testWidgets(
      'FoodieApp applies Dark Theme when user settings has darkMode true',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();

        final darkUser = seedUser.copyWith(
          settings: seedUser.settings.copyWith(darkMode: true),
        );
        await prefs.setString(
          'foodie:auth',
          jsonEncode(AuthState(isLoggedIn: true, user: darkUser).toJson()),
        );

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const FoodieApp(),
          ),
        );

        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.dark);
      },
    );

    test(
      'LocationNotifier handles permission denied gracefully with fallback',
      () async {
        const mockService = MockLocationService(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        );

        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(mockService)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(locationProvider.notifier);
        expect(container.read(locationProvider).isRealMap, isTrue);

        await notifier.initLocation();

        final state = container.read(locationProvider);
        expect(state.isRealMap, isTrue);
        expect(state.status, LocationStatus.denied);
        expect(state.message, contains('Izin lokasi'));
        expect(
          state.coordinates.latitude,
          UserCoordinates.defaultKaliurang.latitude,
        );
      },
    );

    test(
      'LocationNotifier switches to real map when permission is granted',
      () async {
        const mockService = MockLocationService(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          position: UserCoordinates(latitude: -7.7650, longitude: 110.3790),
        );

        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(mockService)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(locationProvider.notifier);
        await notifier.initLocation();

        final state = container.read(locationProvider);
        expect(state.isRealMap, isTrue);
        expect(state.status, LocationStatus.granted);
        expect(state.coordinates.latitude, -7.7650);

        // Can switch back to illustrated map
        notifier.useIllustratedMap();
        expect(container.read(locationProvider).isRealMap, isFalse);
      },
    );

    testWidgets(
      'NearbyPage allows toggling between IllustratedMap and RealMapView',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();

        const mockService = MockLocationService(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
        );

        final router = createRouter(
          initialLocation: '/nearby',
          getAuthState: () => const AuthState(isLoggedIn: true, user: seedUser),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              locationServiceProvider.overrideWithValue(mockService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially renders RealMapView (PRD §14.12)
        expect(find.byType(NearbyPage), findsOneWidget);
        expect(find.byType(RealMapView), findsOneWidget);
        expect(find.text('Ilustrasi'), findsOneWidget);

        // Tap "Ilustrasi" button
        await tester.tap(find.text('Ilustrasi'));
        await tester.pumpAndSettle();

        // Switches to IllustratedMap
        expect(find.byType(IllustratedMap), findsOneWidget);
        expect(find.text('Peta Nyata'), findsOneWidget);

        // Tap "Peta Nyata" to switch back
        await tester.tap(find.text('Peta Nyata'));
        await tester.pumpAndSettle();

        expect(find.byType(RealMapView), findsOneWidget);

        // Drain pending toast timer
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('RealMapView renders place markers and responds to selection', (
      tester,
    ) async {
      String? selectedId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RealMapView(
              places: seedPlaces,
              selectedPlaceId: 'warung-bu-sari',
              onSelectPlace: (id) => selectedId = id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(RealMapView), findsOneWidget);
      expect(find.text('Radius 1 km'), findsOneWidget);
      expect(find.text('Pusatkan'), findsOneWidget);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(selectedId, 'ayam-bakar-pak-hadi');
    });
  });
}
