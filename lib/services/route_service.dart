import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Hasil perhitungan rute jalan kaki
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final bool isStraightLineFallback;
  final String? errorMessage;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isStraightLineFallback = false,
    this.errorMessage,
  });

  /// Format jarak manusiawi (mis. "180 m" atau "1.2 km")
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Format durasi manusiawi (mis. "3 menit")
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    final effectiveMin = minutes < 1 ? 1 : minutes;
    return '$effectiveMin menit';
  }

  /// Ringkasan jarak & waktu (mis. "180 m · 3 menit")
  String get distanceAndDurationString =>
      '$formattedDistance · $formattedDuration';
}

/// Interface abstraksi service rute jalan kaki
abstract class RouteService {
  Future<RouteResult> getFootRoute({
    required LatLng start,
    required LatLng destination,
    CancelToken? cancelToken,
  });
}

/// Implementasi RouteService menggunakan Open Source Routing Machine (OSRM)
/// Endpoint: https://router.project-osrm.org/route/v1/foot/{startLng},{startLat};{endLng},{endLat}?overview=full&geometries=geojson
class OsrmRouteService implements RouteService {
  final Dio _dio;

  OsrmRouteService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
            ),
          );

  @override
  Future<RouteResult> getFootRoute({
    required LatLng start,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    final url =
        'https://router.project-osrm.org/route/v1/foot/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        return parseOsrmResponse(response.data!, start, destination);
      } else {
        return _fallbackStraightLine(
          start: start,
          destination: destination,
          error: 'OSRM returned status code: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        // Request dibatalkan karena pengguna berganti tujuan
        debugPrint('OSRM route request cancelled: ${e.message}');
        return _fallbackStraightLine(
          start: start,
          destination: destination,
          error: 'Request cancelled',
        );
      }
      debugPrint('OSRM DioException: ${e.message}');
      return _fallbackStraightLine(
        start: start,
        destination: destination,
        error: e.message ?? 'Network error',
      );
    } catch (e) {
      debugPrint('Unexpected error fetching OSRM route: $e');
      return _fallbackStraightLine(
        start: start,
        destination: destination,
        error: e.toString(),
      );
    }
  }

  /// Parser terpisah untuk response JSON OSRM agar dapat diuji secara unit test
  static RouteResult parseOsrmResponse(
    Map<String, dynamic> data,
    LatLng start,
    LatLng destination,
  ) {
    try {
      final code = data['code'] as String?;
      if (code != 'Ok') {
        return _fallbackStraightLine(
          start: start,
          destination: destination,
          error: 'OSRM status code not Ok: $code',
        );
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return _fallbackStraightLine(
          start: start,
          destination: destination,
          error: 'No route found in response',
        );
      }

      final primaryRoute = routes.first as Map<String, dynamic>;
      final distance = (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

      final geometry = primaryRoute['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;

      if (coordinates == null || coordinates.isEmpty) {
        return _fallbackStraightLine(
          start: start,
          destination: destination,
          error: 'Missing coordinates in geometry',
        );
      }

      final points = <LatLng>[];
      for (final coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          final lng = (coord[0] as num).toDouble();
          final lat = (coord[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        }
      }

      if (points.isEmpty) {
        return _fallbackStraightLine(
          start: start,
          destination: destination,
          error: 'Parsed coordinates list is empty',
        );
      }

      return RouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
        isStraightLineFallback: false,
      );
    } catch (e) {
      return _fallbackStraightLine(
        start: start,
        destination: destination,
        error: 'Error parsing OSRM response: $e',
      );
    }
  }

  /// Helper fallback garis lurus ketika rute gagal dimuat
  static RouteResult _fallbackStraightLine({
    required LatLng start,
    required LatLng destination,
    String? error,
  }) {
    final straightDistance = calculateHaversineDistanceMeters(
      start,
      destination,
    );
    // Asumsi kecepatan jalan kaki 4.8 km/jam (~1.33 m/s)
    final estimatedSeconds = straightDistance / 1.33;

    return RouteResult(
      points: [start, destination],
      distanceMeters: straightDistance,
      durationSeconds: estimatedSeconds,
      isStraightLineFallback: true,
      errorMessage: error,
    );
  }

  /// Menghitung jarak geodesi garis lurus (Haversine formula) dalam meter
  static double calculateHaversineDistanceMeters(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final dLng = (p2.longitude - p1.longitude) * (math.pi / 180.0);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * (math.pi / 180.0)) *
            math.cos(p2.latitude * (math.pi / 180.0)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
