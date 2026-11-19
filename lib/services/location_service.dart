import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Status perizinan dan ketersediaan lokasi pengguna
enum LocationStatus {
  initial,
  loading,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}

/// Representasi koordinat pengguna
class UserCoordinates {
  final double latitude;
  final double longitude;

  const UserCoordinates({required this.latitude, required this.longitude});

  /// Default koordinat (Jl. Kaliurang KM 5, Yogyakarta)
  static const UserCoordinates defaultKaliurang = UserCoordinates(
    latitude: -7.7653,
    longitude: 110.3789,
  );
}

/// Service untuk menangani GPS & perizinan geolocator secara aman
class LocationService {
  const LocationService();

  /// Mengecek apakah GPS / location service perangkat aktif
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Geolocator service check error: $e');
      return false;
    }
  }

  /// Mengecek perizinan lokasi saat ini
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Geolocator permission check error: $e');
      return LocationPermission.denied;
    }
  }

  /// Meminta perizinan lokasi ke pengguna
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('Geolocator request permission error: $e');
      return LocationPermission.denied;
    }
  }

  /// Mengambil posisi terkini pengguna
  Future<UserCoordinates?> getCurrentPosition() async {
    try {
      final hasService = await isServiceEnabled();
      if (!hasService) return null;

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return UserCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }
}
