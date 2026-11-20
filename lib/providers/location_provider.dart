import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Provider singleton LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return const GeolocatorLocationService();
});

/// State lokasi pengguna lengkap dengan akurasi, status izin, dan mode peta
class LocationState {
  final UserCoordinates? coordinates;
  final LocationStatus status;
  final double? accuracyM;
  final bool isApproximate;
  final bool isMocked;
  final bool isReducedAccuracy;
  final bool askedInSession;
  final bool isRealMap;
  final bool isOfflineFallback;
  final String? message;

  const LocationState({
    this.coordinates,
    this.status = LocationStatus.initial,
    this.accuracyM,
    this.isApproximate = false,
    this.isMocked = false,
    this.isReducedAccuracy = false,
    this.askedInSession = false,
    this.isRealMap = true,
    this.isOfflineFallback = false,
    this.message,
  });

  /// Titik efektif untuk inisialisasi pusat kamera peta (Jl. Kaliurang bila user belum dapat fix)
  /// Catatan: BUKAN untuk menggambar marker pengguna, hanya untuk view kamera peta awal.
  UserCoordinates get effectiveCoordinates =>
      coordinates ?? UserCoordinates.defaultKaliurang;

  LocationState copyWith({
    UserCoordinates? coordinates,
    bool clearCoordinates = false,
    LocationStatus? status,
    double? accuracyM,
    bool? isApproximate,
    bool? isMocked,
    bool? isReducedAccuracy,
    bool? askedInSession,
    bool? isRealMap,
    bool? isOfflineFallback,
    String? message,
  }) {
    return LocationState(
      coordinates: clearCoordinates ? null : (coordinates ?? this.coordinates),
      status: status ?? this.status,
      accuracyM: accuracyM ?? this.accuracyM,
      isApproximate: isApproximate ?? this.isApproximate,
      isMocked: isMocked ?? this.isMocked,
      isReducedAccuracy: isReducedAccuracy ?? this.isReducedAccuracy,
      askedInSession: askedInSession ?? this.askedInSession,
      isRealMap: isRealMap ?? this.isRealMap,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      message: message ?? this.message,
    );
  }
}

/// Notifier untuk mengelola state GPS, perizinan, dan akurasi lokasi
class LocationNotifier extends Notifier<LocationState> {
  LocationService get _service => ref.read(locationServiceProvider);

  StreamSubscription<UserCoordinates>? _positionSub;
  Timer? _timeoutTimer;

  @override
  LocationState build() {
    ref.onDispose(() {
      _cancelPositionSubscription();
    });
    return const LocationState();
  }

  void _cancelPositionSubscription() {
    _positionSub?.cancel();
    _positionSub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Pengecekan status GPS & izin saat membuka halaman Nearby
  /// JANGAN dipanggil saat app startup (§17.7 & PRD §14.12)
  Future<void> checkLocationStatus() async {
    state = state.copyWith(status: LocationStatus.checking);

    final serviceEnabled = await _service.isServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceOff,
        message: 'Layanan GPS dinonaktifkan',
      );
      return;
    }

    final permission = await _service.checkPermission();
    if (permission == LocationPermission.denied) {
      if (state.askedInSession) {
        state = state.copyWith(
          status: LocationStatus.denied,
          message: 'Izin lokasi belum diberikan',
        );
      } else {
        state = state.copyWith(
          status: LocationStatus.needsRationale,
          message: null,
        );
      }
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: LocationStatus.deniedForever,
        message: 'Izin lokasi ditolak permanen',
      );
      return;
    }

    // Permission granted: whileInUse / always
    await _acquireAccuratePosition();
  }

  /// Meminta perizinan langsung dari dialog sistem
  Future<void> requestLocationPermission() async {
    state = state.copyWith(status: LocationStatus.requesting);

    final serviceEnabled = await _service.isServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceOff,
        message: 'Layanan GPS dinonaktifkan',
      );
      return;
    }

    final permission = await _service.requestPermission();
    if (permission == LocationPermission.denied) {
      state = state.copyWith(
        status: LocationStatus.denied,
        message: 'Izin lokasi ditolak',
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: LocationStatus.deniedForever,
        message: 'Izin lokasi ditolak permanen',
      );
      return;
    }

    await _acquireAccuratePosition();
  }

  /// Pengguna menekan tombol "Nanti saja" pada dialog/kartu rationale
  void dismissRationale() {
    state = state.copyWith(
      status: LocationStatus.denied,
      askedInSession: true,
      message: null,
    );
  }

  /// Mengambil posisi berakurasi tinggi menggunakan getPositionStream
  /// Kriteria:
  /// - Fix pertama diterima jika accuracy <= 50m dan umur fix < 30 detik
  /// - Timeout maksimal 15 detik: jika belum fix <= 50m, gunakan fix terbaik (isApproximate = true)
  /// - Tanpa fix: koordinat tetap null, marker tidak digambar
  Future<void> _acquireAccuratePosition() async {
    _cancelPositionSubscription();

    // Periksa status akurasi presisi (Android 12+ / iOS 14+)
    final accuracyStatus = await _service.getLocationAccuracy();
    final isReduced = accuracyStatus == LocationAccuracyStatus.reduced;

    // Ambil last known position sebagai data sementara awal (bukan final)
    final lastKnown = await _service.getLastKnownPosition();
    if (lastKnown != null) {
      state = state.copyWith(
        status: LocationStatus.granted,
        coordinates: lastKnown,
        accuracyM: lastKnown.accuracyM,
        isApproximate: true,
        isMocked: lastKnown.isMocked,
        isReducedAccuracy: isReduced,
      );
    } else {
      state = state.copyWith(
        status: LocationStatus.granted,
        isReducedAccuracy: isReduced,
      );
    }

    UserCoordinates? bestFix = lastKnown;

    // Timeout 15 detik
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (bestFix != null) {
        state = state.copyWith(
          status: LocationStatus.granted,
          coordinates: bestFix,
          accuracyM: bestFix?.accuracyM,
          isApproximate: (bestFix?.accuracyM ?? 100.0) > 50.0,
          isMocked: bestFix?.isMocked ?? false,
          isReducedAccuracy: isReduced,
        );
      } else if (state.coordinates == null) {
        state = state.copyWith(
          status: LocationStatus.granted,
          clearCoordinates: true,
          message: 'Lokasi belum didapat',
          isReducedAccuracy: isReduced,
        );
      }
    });

    try {
      _positionSub = _service.getPositionStream().listen(
        (pos) {
          final now = DateTime.now();
          final fixAge = pos.timestamp != null
              ? now.difference(pos.timestamp!)
              : Duration.zero;

          // Bandingkan untuk mencari fix terbaik
          if (bestFix == null ||
              (pos.accuracyM ?? 9999) < (bestFix?.accuracyM ?? 9999)) {
            bestFix = pos;
          }

          // Kriteria fix akurat: akurasi <= 50 meter dan umur < 30 detik
          if ((pos.accuracyM ?? 100.0) <= 50.0 && fixAge.inSeconds < 30) {
            _timeoutTimer?.cancel();
            _timeoutTimer = null;

            state = state.copyWith(
              status: LocationStatus.granted,
              coordinates: pos,
              accuracyM: pos.accuracyM,
              isApproximate: false,
              isMocked: pos.isMocked,
              isReducedAccuracy: isReduced,
              message: null,
            );
          } else {
            // Update posisi sementara
            state = state.copyWith(
              status: LocationStatus.granted,
              coordinates: pos,
              accuracyM: pos.accuracyM,
              isApproximate: true,
              isMocked: pos.isMocked,
              isReducedAccuracy: isReduced,
            );
          }
        },
        onError: (e) {
          debugPrint('Location stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Error starting position stream: $e');
    }
  }

  /// Memperbarui posisi pengguna saat menekan tombol Pusatkan
  Future<void> refreshLocation() async {
    if (state.status == LocationStatus.granted) {
      await _acquireAccuratePosition();
    } else {
      await requestLocationPermission();
    }
  }

  /// Pause stream posisi untuk menghemat baterai saat halaman tidak aktif
  void pauseStream() {
    _positionSub?.pause();
  }

  /// Resume stream posisi saat halaman kembali aktif
  void resumeStream() {
    if (_positionSub != null && _positionSub!.isPaused) {
      _positionSub!.resume();
    }
  }

  /// Buka pengaturan aplikasi
  Future<bool> openAppSettings() => _service.openAppSettings();

  /// Buka pengaturan GPS perangkat
  Future<bool> openLocationSettings() => _service.openLocationSettings();

  /// Alias initLocation untuk kompatibilitas kode & test lama
  Future<void> initLocation() => checkLocationStatus();

  /// Beralih ke peta nyata atau ilustrasi (kompatibilitas Fase 16)
  void toggleMapMode() {
    state = state.copyWith(isRealMap: !state.isRealMap);
  }

  void useIllustratedMap() {
    state = state.copyWith(isRealMap: false);
  }

  void useRealMap() {
    state = state.copyWith(isRealMap: true);
  }
}

/// Provider state notifier lokasi pengguna
final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);
