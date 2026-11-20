import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Provider singleton LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

/// State lokasi pengguna
class LocationState {
  final UserCoordinates coordinates;
  final LocationStatus status;
  final bool isRealMap;
  final bool isOfflineFallback;
  final String? message;

  const LocationState({
    this.coordinates = UserCoordinates.defaultKaliurang,
    this.status = LocationStatus.initial,
    this.isRealMap = true,
    this.isOfflineFallback = false,
    this.message,
  });

  LocationState copyWith({
    UserCoordinates? coordinates,
    LocationStatus? status,
    bool? isRealMap,
    bool? isOfflineFallback,
    String? message,
  }) {
    return LocationState(
      coordinates: coordinates ?? this.coordinates,
      status: status ?? this.status,
      isRealMap: isRealMap ?? this.isRealMap,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      message: message ?? this.message,
    );
  }
}

/// Notifier untuk mengelola state GPS dan switching peta
class LocationNotifier extends Notifier<LocationState> {
  LocationService get _service => ref.read(locationServiceProvider);

  @override
  LocationState build() {
    return const LocationState();
  }

  /// Meminta dan memuat lokasi pengguna secara otomatis
  /// Bila izin ditolak atau GPS mati: fallback ke lokasi default (Jl. Kaliurang) + pesan
  Future<void> initLocation() async {
    state = state.copyWith(status: LocationStatus.loading);

    final serviceEnabled = await _service.isServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceDisabled,
        coordinates: UserCoordinates.defaultKaliurang,
        isRealMap: true,
        message: 'Lokasi tidak tersedia, memakai lokasi contoh',
      );
      return;
    }

    var permission = await _service.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _service.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: permission == LocationPermission.deniedForever
            ? LocationStatus.deniedForever
            : LocationStatus.denied,
        coordinates: UserCoordinates.defaultKaliurang,
        isRealMap: true,
        message: 'Lokasi tidak tersedia, memakai lokasi contoh',
      );
      return;
    }

    // Izin diberikan
    final coords = await _service.getCurrentPosition();
    state = state.copyWith(
      coordinates: coords ?? UserCoordinates.defaultKaliurang,
      status: LocationStatus.granted,
      isRealMap: true,
      message: null,
    );
  }

  /// Beralih ke peta nyata atau peta ilustrasi
  Future<void> toggleMapMode() async {
    if (state.isRealMap) {
      state = state.copyWith(isRealMap: false);
      return;
    }

    await initLocation();
  }

  /// Menggunakan peta ilustrasi (mis. saat offline atau fallback tile)
  void useIllustratedMap() {
    state = state.copyWith(isRealMap: false, isOfflineFallback: true);
  }

  /// Menggunakan peta nyata
  void useRealMap() {
    state = state.copyWith(isRealMap: true, isOfflineFallback: false);
  }

  /// Menandai offline fallback
  void setOfflineFallback(bool offline) {
    state = state.copyWith(isOfflineFallback: offline, isRealMap: !offline);
  }
}

/// Provider state lokasi
final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);
