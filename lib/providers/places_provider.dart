import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/models.dart';
import '../services/place_service.dart';
import '../services/route_service.dart';
import 'location_provider.dart';
import 'storage_provider.dart';

/// Provider Dio untuk PlaceService (bisa dioverride di test)
final placeDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'FoodieApp/1.0 (id.foodie.foodie)'},
    ),
  );
});

/// Notifier untuk toast fallback tempat makan (jika terjadi fallback ke data contoh)
class PlacesFallbackToastNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;
  void clear() => state = null;
}

final placesFallbackToastProvider =
    NotifierProvider<PlacesFallbackToastNotifier, String?>(
      PlacesFallbackToastNotifier.new,
    );

/// Notifier untuk radius pencarian tempat makan (dalam meter)
class NearbyRadiusNotifier extends Notifier<int> {
  @override
  int build() => 5000;

  void setRadius(int radius) => state = radius;
}

final nearbyRadiusMetersProvider = NotifierProvider<NearbyRadiusNotifier, int>(
  NearbyRadiusNotifier.new,
);

/// Provider singleton PlaceService
final placeServiceProvider = Provider<PlaceService>((ref) {
  final dio = ref.watch(placeDioProvider);
  return OverpassPlaceService(
    dio: dio,
    localService: const LocalPlaceService(),
    getPlacesCacheBox: () {
      try {
        final box = ref.read(placesCacheBoxProvider);
        return box as Box<Map>?;
      } catch (_) {
        return null;
      }
    },
    onFallbackToast: (message) {
      ref.read(placesFallbackToastProvider.notifier).show(message);
    },
  );
});

/// Provider singleton RouteService
final routeServiceProvider = Provider<RouteService>((ref) {
  return OsrmRouteService();
});

/// Provider asinkron daftar tempat makan sekitar
final placesAsyncProvider = FutureProvider<List<Place>>((ref) async {
  final locationState = ref.watch(locationProvider);
  final service = ref.watch(placeServiceProvider);
  final radius = ref.watch(nearbyRadiusMetersProvider);

  final coords = locationState.effectiveCoordinates;

  return service.nearby(
    latitude: coords.latitude,
    longitude: coords.longitude,
    radiusMeters: radius,
  );
});

/// Provider daftar tempat makan sekitar (Nearby) relatif terhadap lokasi pengguna
/// Memberikan data sinkron dari cache / fallback jika async sedang loading
final placesProvider = Provider<List<Place>>((ref) {
  final asyncValue = ref.watch(placesAsyncProvider);
  if (asyncValue.hasValue) {
    return asyncValue.value!;
  }

  // Fallback cepat saat inisialisasi awal agar UI tidak kosong melompong
  final locationState = ref.watch(locationProvider);
  final coords = locationState.effectiveCoordinates;
  return const LocalPlaceService().getPlacesSync(
    latitude: coords.latitude,
    longitude: coords.longitude,
    radiusMeters: 5000,
  );
});
