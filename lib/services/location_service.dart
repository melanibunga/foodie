import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Status alur izin dan ketersediaan lokasi sesuai PRD §14.12, §14.5, §17.7
enum LocationStatus {
  initial,
  checking,
  needsRationale,
  requesting,
  granted,
  denied,
  deniedForever,
  serviceOff,
  error,
}

/// Representasi koordinat & akurasi pengguna
class UserCoordinates {
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime? timestamp;
  final bool isMocked;
  final bool isApproximate;

  const UserCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.timestamp,
    this.isMocked = false,
    this.isApproximate = false,
  });

  /// Default koordinat kamera (Jl. Kaliurang KM 5, Yogyakarta)
  /// Catatan: Hanya digunakan sebagai titik awal pusat kamera peta bila lokasi pengguna
  /// belum tersedia, BUKAN sebagai titik/marker lokasi pengguna (§17.7).
  static const UserCoordinates defaultKaliurang = UserCoordinates(
    latitude: -7.7653,
    longitude: 110.3789,
    accuracyM: 20.0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCoordinates &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracyM == other.accuracyM &&
          isMocked == other.isMocked &&
          isApproximate == other.isApproximate;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      accuracyM.hashCode ^
      isMocked.hashCode ^
      isApproximate.hashCode;
}

/// Interface / Base class LocationService untuk memudahkan unit & widget testing
abstract class LocationService {
  const LocationService();

  /// Mengecek apakah layanan GPS perangkat aktif
  Future<bool> isServiceEnabled();

  /// Mengecek status izin lokasi saat ini tanpa memunculkan dialog
  Future<LocationPermission> checkPermission();

  /// Meminta izin lokasi ke sistem dialog
  Future<LocationPermission> requestPermission();

  /// Mendeteksi akurasi presisi (precise vs reduced pada Android 12+/iOS 14+)
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;

  /// Mengambil lokasi terakhir yang tersimpan di sistem
  Future<UserCoordinates?> getLastKnownPosition() async => null;

  /// Mengambil posisi saat ini secara one-shot
  Future<UserCoordinates?> getCurrentPosition() async => null;

  /// Stream posisi pengguna secara real-time
  Stream<UserCoordinates> getPositionStream({
    LocationSettings? locationSettings,
  }) async* {
    final current = await getCurrentPosition();
    if (current != null) {
      yield current;
    }
  }

  /// Membuka pengaturan aplikasi (AppSettings)
  Future<bool> openAppSettings() async => true;

  /// Membuka pengaturan lokasi perangkat (LocationSettings/GPS)
  Future<bool> openLocationSettings() async => true;
}

/// Implementasi nyata LocationService berbasis package geolocator
class GeolocatorLocationService extends LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Geolocator service check error: $e');
      return false;
    }
  }

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Geolocator checkPermission error: $e');
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('Geolocator requestPermission error: $e');
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } catch (e) {
      debugPrint('Geolocator getLocationAccuracy error: $e');
      return LocationAccuracyStatus.unknown;
    }
  }

  @override
  Future<UserCoordinates?> getLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return UserCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy,
        timestamp: pos.timestamp,
        isMocked: pos.isMocked,
      );
    } catch (e) {
      debugPrint('Geolocator getLastKnownPosition error: $e');
      return null;
    }
  }

  @override
  Future<UserCoordinates?> getCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: defaultLocationSettings(),
      );
      return UserCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy,
        timestamp: pos.timestamp,
        isMocked: pos.isMocked,
      );
    } catch (e) {
      debugPrint('Geolocator getCurrentPosition error: $e');
      return null;
    }
  }

  @override
  Stream<UserCoordinates> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    final settings = locationSettings ?? defaultLocationSettings();
    return Geolocator.getPositionStream(locationSettings: settings).map((pos) {
      return UserCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy,
        timestamp: pos.timestamp,
        isMocked: pos.isMocked,
      );
    });
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Geolocator openAppSettings error: $e');
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Geolocator openLocationSettings error: $e');
      return false;
    }
  }

  /// Pengaturan akurasi tinggi: Android high/best & 5m filter; iOS best & 5m filter
  static LocationSettings defaultLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 5),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }
}

/// FakeLocationService untuk memudahkan testing unit & widget tanpa emulator GPS
class FakeLocationService implements LocationService {
  bool serviceEnabled;
  LocationPermission permission;
  LocationAccuracyStatus accuracyStatus;
  UserCoordinates? lastKnownPosition;
  List<UserCoordinates> streamPositions;
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;
  StreamController<UserCoordinates>? _streamController;

  FakeLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.accuracyStatus = LocationAccuracyStatus.precise,
    this.lastKnownPosition,
    this.streamPositions = const [],
  });

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracyStatus;

  @override
  Future<UserCoordinates?> getLastKnownPosition() async => lastKnownPosition;

  @override
  Future<UserCoordinates?> getCurrentPosition() async {
    if (streamPositions.isNotEmpty) return streamPositions.first;
    return lastKnownPosition;
  }

  @override
  Stream<UserCoordinates> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    _streamController = StreamController<UserCoordinates>.broadcast();
    if (streamPositions.isNotEmpty) {
      Future.microtask(() {
        for (final pos in streamPositions) {
          if (_streamController != null && !_streamController!.isClosed) {
            _streamController!.add(pos);
          }
        }
      });
    }
    return _streamController!.stream;
  }

  void emitPosition(UserCoordinates pos) {
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.add(pos);
    }
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }
}
