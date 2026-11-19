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
  final String? message;

  const LocationState({
    this.coordinates = UserCoordinates.defaultKaliurang,
    this.status = LocationStatus.initial,
    this.isRealMap = false,
    this.message,
  });

  LocationState copyWith({
    UserCoordinates? coordinates,
    LocationStatus? status,
    bool? isRealMap,
    String? message,
  }) {
    return LocationState(
      coordinates: coordinates ?? this.coordinates,
      status: status ?? this.status,
      isRealMap: isRealMap ?? this.isRealMap,
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

  /// Beralih ke peta nyata atau peta ilustrasi
  Future<void> toggleMapMode() async {
    if (state.isRealMap) {
      // Kembali ke peta ilustrasi
      state = state.copyWith(isRealMap: false);
      return;
    }

    // Coba aktifkan peta nyata dengan meminta izin lokasi
    state = state.copyWith(status: LocationStatus.loading);

    final serviceEnabled = await _service.isServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceDisabled,
        isRealMap: false,
        message:
            'Layanan lokasi (GPS) tidak aktif. Menampilkan peta ilustrasi.',
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
        isRealMap: false,
        message: 'Izin lokasi ditolak. Menampilkan peta ilustrasi.',
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

  /// Memaksa kembali ke peta ilustrasi
  void useIllustratedMap() {
    state = state.copyWith(isRealMap: false);
  }
}

/// Provider state lokasi
final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);
