import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/place_service.dart';
import '../services/route_service.dart';
import 'location_provider.dart';

/// Provider singleton PlaceService
final placeServiceProvider = Provider<PlaceService>((ref) {
  return const LocalPlaceService();
});

/// Provider singleton RouteService
final routeServiceProvider = Provider<RouteService>((ref) {
  return OsrmRouteService();
});

/// Provider daftar tempat makan sekitar (Nearby) relatif terhadap lokasi pengguna
final placesProvider = Provider<List<Place>>((ref) {
  final locationState = ref.watch(locationProvider);
  final service = ref.watch(placeServiceProvider);

  if (service is LocalPlaceService) {
    return service.getPlacesSync(
      latitude: locationState.coordinates.latitude,
      longitude: locationState.coordinates.longitude,
      radiusMeters: 5000,
    );
  }

  // Fallback untuk implementasi lain
  return const LocalPlaceService().getPlacesSync(
    latitude: locationState.coordinates.latitude,
    longitude: locationState.coordinates.longitude,
    radiusMeters: 5000,
  );
});
