import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/models.dart';

/// Hasil parsing status jam operasional OSM
class OpeningHoursResult {
  final bool isOpen;
  final bool isUnknown;

  const OpeningHoursResult({required this.isOpen, required this.isUnknown});

  @override
  String toString() =>
      'OpeningHoursResult(isOpen: $isOpen, isUnknown: $isUnknown)';
}

/// Parser untuk format tag opening_hours OpenStreetMap
class OpeningHoursParser {
  OpeningHoursParser._();

  static const Map<String, int> _weekdayMap = {
    'mo': 1,
    'tu': 2,
    'we': 3,
    'th': 4,
    'fr': 5,
    'sa': 6,
    'su': 7,
  };

  /// Parse format opening_hours string OSM
  static OpeningHoursResult parse(String? raw, {DateTime? now}) {
    if (raw == null) {
      return const OpeningHoursResult(isOpen: false, isUnknown: true);
    }

    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return const OpeningHoursResult(isOpen: false, isUnknown: true);
    }

    if (trimmed == '24/7') {
      return const OpeningHoursResult(isOpen: true, isUnknown: false);
    }

    if (trimmed == 'off' || trimmed == 'closed') {
      return const OpeningHoursResult(isOpen: false, isUnknown: false);
    }

    final current = now ?? DateTime.now();
    final currentWeekday = current.weekday; // 1 = Monday, 7 = Sunday
    final currentMinutes = current.hour * 60 + current.minute;

    final rules = trimmed.split(';');
    bool matchedDay = false;
    bool isAnyDayRule = false;
    bool hasAnyValidTimeRule = false;
    bool hasDaySpecification = false;

    for (final rule in rules) {
      final r = rule.trim();
      if (r.isEmpty) continue;

      if (r == 'off' || r == 'closed') {
        continue;
      }

      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})')
          .firstMatch(r);
      if (timeMatch == null) {
        continue;
      }

      hasAnyValidTimeRule = true;
      final startHour = int.tryParse(timeMatch.group(1)!) ?? 0;
      final startMin = int.tryParse(timeMatch.group(2)!) ?? 0;
      final endHour = int.tryParse(timeMatch.group(3)!) ?? 0;
      final endMin = int.tryParse(timeMatch.group(4)!) ?? 0;

      final startMinutes = startHour * 60 + startMin;
      final endMinutes = endHour * 60 + endMin;

      final dayPart = r.substring(0, timeMatch.start).trim();
      bool dayApplies = false;

      if (dayPart.isEmpty) {
        dayApplies = true;
        isAnyDayRule = true;
      } else {
        hasDaySpecification = true;
        dayApplies = _isDayApplicable(dayPart, currentWeekday);
        if (dayApplies) {
          matchedDay = true;
        }
      }

      if (dayApplies) {
        final isOpenNow = endMinutes <= startMinutes
            ? (currentMinutes >= startMinutes || currentMinutes < endMinutes)
            : (currentMinutes >= startMinutes && currentMinutes < endMinutes);

        return OpeningHoursResult(isOpen: isOpenNow, isUnknown: false);
      }
    }

    if (matchedDay ||
        isAnyDayRule ||
        (hasAnyValidTimeRule && hasDaySpecification)) {
      return const OpeningHoursResult(isOpen: false, isUnknown: false);
    }

    return const OpeningHoursResult(isOpen: false, isUnknown: true);
  }

  static bool _isDayApplicable(String dayPart, int targetWeekday) {
    final tokens = dayPart.split(RegExp(r'[\s,]+'));

    for (final token in tokens) {
      final t = token.trim();
      if (t.contains('-')) {
        final parts = t.split('-');
        if (parts.length == 2) {
          final start = _weekdayMap[parts[0].trim()];
          final end = _weekdayMap[parts[1].trim()];
          if (start != null && end != null) {
            if (start <= end) {
              if (targetWeekday >= start && targetWeekday <= end) return true;
            } else {
              if (targetWeekday >= start || targetWeekday <= end) return true;
            }
          }
        }
      } else {
        final single = _weekdayMap[t];
        if (single != null && single == targetWeekday) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Entri cache bounding box dengan waktu simpan
class _BboxCacheEntry {
  final List<Place> places;
  final DateTime timestamp;

  _BboxCacheEntry(this.places, this.timestamp);
}

/// Interface abstraksi untuk sumber data tempat makan sekitar (Nearby)
/// sesuai PRD §14.12, §6.8, dan §17.6
abstract class PlaceService {
  Future<List<Place>> list();

  Future<List<Place>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  });

  /// Mengambil daftar tempat makan dalam area terlihat (bounding box)
  Future<List<Place>> getPlacesInBbox({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? userLat,
    double? userLng,
    CancelToken? cancelToken,
  });

  /// Mencari tempat makan berdasarkan nama di sekitar lokasi
  Future<List<Place>> searchByName({
    required String query,
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    CancelToken? cancelToken,
  });
}

/// Implementasi PlaceService menggunakan Overpass API (OpenStreetMap)
/// dengan cache per-bbox 10 menit, pembatalan request lama, dan batas kuota publik.
class OverpassPlaceService implements PlaceService {
  final Dio _dio;
  final LocalPlaceService _localService;
  final Box<Map>? Function()? _getPlacesCacheBox;
  final void Function(String message)? _onFallbackToast;

  // In-memory cache & debounce
  double? _lastLat;
  double? _lastLng;
  int? _lastRadius;
  List<Place>? _inMemoryPlaces;
  bool _hasShownFallbackToast = false;

  // Bounding box in-memory cache (TTL: 10 menit)
  final Map<String, _BboxCacheEntry> _bboxCache = {};

  OverpassPlaceService({
    Dio? dio,
    LocalPlaceService? localService,
    Box<Map>? Function()? getPlacesCacheBox,
    void Function(String message)? onFallbackToast,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
               headers: {'User-Agent': 'FoodieApp/1.0 (id.foodie.foodie)'},
             ),
           ),
       _localService = localService ?? const LocalPlaceService(),
       // ignore: prefer_initializing_formals
       _getPlacesCacheBox = getPlacesCacheBox,
       // ignore: prefer_initializing_formals
       _onFallbackToast = onFallbackToast;

  /// Hitung jarak haversine sederhana (meter)
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Future<List<Place>> list() async {
    return nearby(latitude: -7.7653, longitude: 110.3789, radiusMeters: 5000);
  }

  @override
  Future<List<Place>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async {
    // 1. Debounce check: pergeseran < 100m dengan radius yang sama
    if (_lastLat != null &&
        _lastLng != null &&
        _lastRadius == radiusMeters &&
        _inMemoryPlaces != null) {
      final shiftedDist = distanceBetween(
        latitude,
        longitude,
        _lastLat!,
        _lastLng!,
      );
      if (shiftedDist < 100.0) {
        return _inMemoryPlaces!;
      }
    }

    final cacheKey =
        '${(latitude * 100).round()}_${(longitude * 100).round()}_$radiusMeters';

    // 2. Coba ambil data dari Overpass API
    try {
      final places = await _fetchOverpass(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );

      if (places.isNotEmpty) {
        _lastLat = latitude;
        _lastLng = longitude;
        _lastRadius = radiusMeters;
        _inMemoryPlaces = places;
        _hasShownFallbackToast = false;

        _saveToCache(cacheKey, places);
        return places;
      }
    } catch (e) {
      debugPrint('Overpass API error: $e');
    }

    // 3. Fallback ke Hive Cache
    final cachedPlaces = _loadFromCache(cacheKey);
    if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
      debugPrint('Overpass failed, using Hive places cache ($cacheKey)');
      _lastLat = latitude;
      _lastLng = longitude;
      _lastRadius = radiusMeters;
      _inMemoryPlaces = cachedPlaces;
      return cachedPlaces;
    }

    // 4. Fallback ke LocalPlaceService
    debugPrint(
      'Overpass & cache unavailable, falling back to LocalPlaceService',
    );
    final localPlaces = await _localService.nearby(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    if (!_hasShownFallbackToast) {
      _hasShownFallbackToast = true;
      _onFallbackToast?.call('Memakai data contoh');
    }

    _lastLat = latitude;
    _lastLng = longitude;
    _lastRadius = radiusMeters;
    _inMemoryPlaces = localPlaces;
    return localPlaces;
  }

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
    final centerLat = userLat ?? ((minLat + maxLat) / 2);
    final centerLng = userLng ?? ((minLon + maxLon) / 2);

    // Kunci cache rounded bbox (~100 meter akurasi grid)
    final cacheKey =
        '${(minLat * 100).round()}_${(minLon * 100).round()}_${(maxLat * 100).round()}_${(maxLon * 100).round()}';

    // Cek cache in-memory 10 menit
    final cached = _bboxCache[cacheKey];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age < const Duration(minutes: 10)) {
        return cached.places;
      } else {
        _bboxCache.remove(cacheKey);
      }
    }

    final query =
        '''
[out:json][timeout:10];
(
  node["amenity"~"restaurant|fast_food|cafe|food_court"]($minLat,$minLon,$maxLat,$maxLon);
  way["amenity"~"restaurant|fast_food|cafe|food_court"]($minLat,$minLon,$maxLat,$maxLon);
);
out center 80;
''';

    // Daftar mirror endpoint Overpass publik
    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    for (final endpoint in endpoints) {
      if (cancelToken != null && cancelToken.isCancelled) break;
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          endpoint,
          data: 'data=${Uri.encodeQueryComponent(query)}',
          cancelToken: cancelToken,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {'User-Agent': 'FoodieApp/1.0 (id.foodie.foodie)'},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final places = parseOverpassResponse(
            response.data!,
            latitude: centerLat,
            longitude: centerLng,
            radiusMeters: 5000,
            ignoreNameless: true,
            limit: 80,
          );

          if (places.isNotEmpty) {
            _bboxCache[cacheKey] = _BboxCacheEntry(places, DateTime.now());
            return places;
          }
        }
      } catch (e) {
        if (cancelToken != null && cancelToken.isCancelled) rethrow;
        debugPrint('Overpass bbox endpoint $endpoint failed: $e');
      }
    }

    // Jika seluruh mirror Overpass gagal atau diblokir provider: fallback aman ke data lokal
    debugPrint(
      'Overpass bbox failed/unavailable, falling back to LocalPlaceService',
    );
    final fallbackPlaces = _localService.getPlacesSync(
      latitude: centerLat,
      longitude: centerLng,
      radiusMeters: 5000,
    );
    _bboxCache[cacheKey] = _BboxCacheEntry(fallbackPlaces, DateTime.now());
    return fallbackPlaces;
  }

  @override
  Future<List<Place>> searchByName({
    required String query,
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    CancelToken? cancelToken,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    // Cari dulu kecocokan pada data lokal/template secara instan
    final localMatches = _localService
        .getPlacesSync(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        )
        .where(
          (p) =>
              p.name.toLowerCase().contains(cleanQuery.toLowerCase()) ||
              p.cuisine.toLowerCase().contains(cleanQuery.toLowerCase()),
        )
        .toList();

    // Escape regex characters untuk Overpass QL
    final escaped = cleanQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('/', r'\/');

    final overpassQuery =
        '''
[out:json][timeout:10];
(
  node["amenity"~"restaurant|fast_food|cafe|food_court"]["name"~"$escaped",i](around:$radiusMeters,$latitude,$longitude);
  way["amenity"~"restaurant|fast_food|cafe|food_court"]["name"~"$escaped",i](around:$radiusMeters,$latitude,$longitude);
);
out center 8;
''';

    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    List<Place> overpassResults = [];

    for (final endpoint in endpoints) {
      if (cancelToken != null && cancelToken.isCancelled) break;
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          endpoint,
          data: 'data=${Uri.encodeQueryComponent(overpassQuery)}',
          cancelToken: cancelToken,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {'User-Agent': 'FoodieApp/1.0 (id.foodie.foodie)'},
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final results = parseOverpassResponse(
            response.data!,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            ignoreNameless: true,
            limit: 8,
          );

          if (results.isNotEmpty) {
            overpassResults = results;
            break;
          }
        }
      } catch (e) {
        if (cancelToken != null && cancelToken.isCancelled) rethrow;
        debugPrint('Overpass search endpoint $endpoint failed: $e');
      }
    }

    if (overpassResults.isNotEmpty) {
      overpassResults.sort((a, b) => a.distanceM.compareTo(b.distanceM));
      return overpassResults.take(8).toList();
    }

    // Jika Overpass tidak mengembalikan hasil atau offline/gagal: gunakan hasil template lokal
    localMatches.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return localMatches.take(8).toList();
  }

  Future<List<Place>> _fetchOverpass({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    final query =
        '''
[out:json][timeout:15];
(
  node["amenity"~"restaurant|cafe|fast_food"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"~"restaurant|cafe|fast_food"](around:$radiusMeters,$latitude,$longitude);
);
out center 40;
''';

    final response = await _dio.post<Map<String, dynamic>>(
      'https://overpass-api.de/api/interpreter',
      data: 'data=${Uri.encodeQueryComponent(query)}',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'User-Agent': 'FoodieApp/1.0 (id.foodie.foodie)'},
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      return parseOverpassResponse(
        response.data!,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    }

    return const [];
  }

  /// Parser terpisah untuk response Overpass JSON
  static List<Place> parseOverpassResponse(
    Map<String, dynamic> data, {
    required double latitude,
    required double longitude,
    required int radiusMeters,
    bool ignoreNameless = false,
    int limit = 80,
  }) {
    final elements = data['elements'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) return const [];

    final places = <Place>[];
    final radLat = latitude * (math.pi / 180.0);
    final effectiveCosLat = math.cos(radLat).abs().clamp(0.01, 1.0);
    final maxDist = radiusMeters > 0 ? radiusMeters.toDouble() : 5000.0;

    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;

      final type = el['type'] as String? ?? 'node';
      final idNum = el['id']?.toString() ?? 'unknown';
      final placeId = '$type-$idNum';

      double? placeLat;
      double? placeLng;

      if (type == 'way') {
        final center = el['center'] as Map<String, dynamic>?;
        if (center != null) {
          placeLat = (center['lat'] as num?)?.toDouble();
          placeLng = (center['lon'] as num?)?.toDouble();
        }
      } else {
        placeLat = (el['lat'] as num?)?.toDouble();
        placeLng = (el['lon'] as num?)?.toDouble();
      }

      if (placeLat == null || placeLng == null) continue;

      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
      final rawName = tags['name'] as String?;
      final brand = tags['brand'] as String?;

      if (ignoreNameless &&
          (rawName == null || rawName.trim().isEmpty) &&
          (brand == null || brand.trim().isEmpty)) {
        continue;
      }

      final amenity =
          (tags['amenity'] as String?)?.toLowerCase() ?? 'restaurant';

      final name =
          rawName ??
          brand ??
          (amenity == 'cafe'
              ? 'Kafe Sekitar'
              : amenity == 'fast_food'
              ? 'Kedai Cepat Saji'
              : 'Rumah Makan');

      final rawCuisine = tags['cuisine'] as String?;
      final cuisine = rawCuisine != null && rawCuisine.isNotEmpty
          ? rawCuisine.split(';').map((s) => s.trim()).join(', ')
          : (amenity == 'cafe'
                ? 'Kafe & Kopi'
                : amenity == 'fast_food'
                ? 'Makanan Cepat Saji'
                : 'Restoran & Kuliner');

      final distanceM = distanceBetween(
        latitude,
        longitude,
        placeLat,
        placeLng,
      ).round();
      final rawWalkMin = (distanceM / 80).ceil();
      final walkMin = rawWalkMin < 1 ? 1 : rawWalkMin;

      final hash = (placeId.hashCode).abs();
      final baseMin = 12000 + (hash % 15) * 1000;
      final span = 10000 + ((hash ~/ 15) % 15) * 2000;
      final priceMin = baseMin;
      final priceMax = baseMin + span;

      final openingHoursRaw = tags['opening_hours'] as String?;
      final openingResult = OpeningHoursParser.parse(openingHoursRaw);

      final deltaMetersLat = (placeLat - latitude) * 111139.0;
      final deltaMetersLng =
          (placeLng - longitude) * (111139.0 * effectiveCosLat);
      final mockX = (50.0 + (deltaMetersLng / maxDist) * 45.0).clamp(5.0, 95.0);
      final mockY = (50.0 - (deltaMetersLat / maxDist) * 45.0).clamp(5.0, 95.0);

      places.add(
        Place(
          id: placeId,
          name: name,
          cuisine: cuisine,
          type: amenity,
          openingHours: openingHoursRaw,
          tags: tags,
          priceMin: priceMin,
          priceMax: priceMax,
          distanceM: distanceM,
          walkMin: walkMin,
          open: openingResult.isOpen,
          isUnknownHours: openingResult.isUnknown,
          x: mockX,
          y: mockY,
          lat: placeLat,
          lng: placeLng,
        ),
      );

      if (places.length >= limit) {
        break;
      }
    }

    places.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return places;
  }

  void _saveToCache(String key, List<Place> places) {
    try {
      final box = _getPlacesCacheBox?.call();
      if (box == null) return;

      final entry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'places': places.map((p) => p.toJson()).toList(),
      };
      box.put(key, entry);
    } catch (e) {
      debugPrint('Error saving places to Hive cache: $e');
    }
  }

  List<Place>? _loadFromCache(String key) {
    try {
      final box = _getPlacesCacheBox?.call();
      if (box == null) return null;

      final raw = box.get(key);
      if (raw == null) return null;

      final timestamp = raw['timestamp'] as num?;
      if (timestamp == null) return null;

      final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      if (DateTime.now().difference(savedTime) > const Duration(hours: 1)) {
        return null;
      }

      final rawList = raw['places'] as List<dynamic>?;
      if (rawList == null) return null;

      return rawList
          .map((item) => Place.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading places from Hive cache: $e');
      return null;
    }
  }
}

/// Fallback minimal LocalPlaceService
class LocalPlaceService implements PlaceService {
  const LocalPlaceService();

  static const List<_PlaceTemplate> _templates = [
    _PlaceTemplate(
      id: 'warung-bu-sari',
      name: 'Warung Bu Sari',
      cuisine: 'Masakan Jawa',
      priceMin: 15000,
      priceMax: 30000,
      distanceM: 180,
      walkMin: 3,
      open: true,
      bearingDegrees: 35.0,
      mockX: 47.0,
      mockY: 35.0,
    ),
    _PlaceTemplate(
      id: 'ayam-bakar-pak-hadi',
      name: 'Ayam Bakar Pak Hadi',
      cuisine: 'Ayam bakar',
      priceMin: 20000,
      priceMax: 35000,
      distanceM: 450,
      walkMin: 6,
      open: true,
      bearingDegrees: 130.0,
      mockX: 76.0,
      mockY: 44.0,
    ),
    _PlaceTemplate(
      id: 'ayam-geprek-bu-rum',
      name: 'Ayam Geprek Bu Rum',
      cuisine: 'Ayam Geprek & Sambal Bawang',
      priceMin: 14000,
      priceMax: 25000,
      distanceM: 320,
      walkMin: 4,
      open: true,
      bearingDegrees: 60.0,
      mockX: 55.0,
      mockY: 28.0,
    ),
    _PlaceTemplate(
      id: 'olive-fried-chicken',
      name: 'Olive Fried Chicken',
      cuisine: 'Ayam Goreng Crispy',
      priceMin: 15000,
      priceMax: 28000,
      distanceM: 520,
      walkMin: 7,
      open: true,
      bearingDegrees: 175.0,
      mockX: 68.0,
      mockY: 60.0,
    ),
    _PlaceTemplate(
      id: 'warung-padang-salero',
      name: 'Warung Padang Salero',
      cuisine: 'Masakan Padang',
      priceMin: 18000,
      priceMax: 35000,
      distanceM: 700,
      walkMin: 10,
      open: false,
      bearingDegrees: 235.0,
      mockX: 21.0,
      mockY: 46.0,
    ),
    _PlaceTemplate(
      id: 'sate-madura-cak-sholeh',
      name: 'Sate Madura Cak Sholeh',
      cuisine: 'Sate & Gule',
      priceMin: 22000,
      priceMax: 40000,
      distanceM: 1200,
      walkMin: 16,
      open: true,
      bearingDegrees: 310.0,
      mockX: 85.0,
      mockY: 20.0,
    ),
    _PlaceTemplate(
      id: 'gudeg-yu-djum',
      name: 'Gudeg Yu Djum',
      cuisine: 'Gudeg Khas Jogja',
      priceMin: 25000,
      priceMax: 45000,
      distanceM: 2200,
      walkMin: 30,
      open: true,
      bearingDegrees: 85.0,
      mockX: 15.0,
      mockY: 75.0,
    ),
    _PlaceTemplate(
      id: 'bakso-pak-min',
      name: 'Bakso & Mie Ayam Pak Min',
      cuisine: 'Bakso & Mie Ayam',
      priceMin: 15000,
      priceMax: 25000,
      distanceM: 620,
      walkMin: 8,
      open: true,
      bearingDegrees: 200.0,
      mockX: 40.0,
      mockY: 65.0,
    ),
    _PlaceTemplate(
      id: 'warmindo-berkah',
      name: 'Warmindo Berkah',
      cuisine: 'Mie & Nasi Telur',
      priceMin: 10000,
      priceMax: 20000,
      distanceM: 260,
      walkMin: 3,
      open: true,
      bearingDegrees: 15.0,
      mockX: 52.0,
      mockY: 38.0,
    ),
    _PlaceTemplate(
      id: 'bebek-goreng-h-slamet',
      name: 'Bebek Goreng H. Slamet',
      cuisine: 'Bebek Goreng & Sambal Korek',
      priceMin: 28000,
      priceMax: 50000,
      distanceM: 880,
      walkMin: 12,
      open: true,
      bearingDegrees: 290.0,
      mockX: 30.0,
      mockY: 25.0,
    ),
    _PlaceTemplate(
      id: 'soto-ayam-pak-dalbe',
      name: 'Soto Ayam Pak Dalbe',
      cuisine: 'Soto Ayam Kampung',
      priceMin: 16000,
      priceMax: 28000,
      distanceM: 950,
      walkMin: 13,
      open: true,
      bearingDegrees: 110.0,
      mockX: 72.0,
      mockY: 52.0,
    ),
    _PlaceTemplate(
      id: 'kopi-klotok-kaliurang',
      name: 'Warung Kopi Klotok',
      cuisine: 'Kopi & Pisang Goreng',
      priceMin: 12000,
      priceMax: 30000,
      distanceM: 1800,
      walkMin: 24,
      open: true,
      bearingDegrees: 10.0,
      mockX: 50.0,
      mockY: 15.0,
    ),
  ];

  @override
  Future<List<Place>> list() async {
    return nearby(latitude: -7.7653, longitude: 110.3789, radiusMeters: 5000);
  }

  @override
  Future<List<Place>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async {
    return getPlacesSync(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

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
    return getPlacesSync(
      latitude: userLat ?? ((minLat + maxLat) / 2),
      longitude: userLng ?? ((minLon + maxLon) / 2),
    );
  }

  @override
  Future<List<Place>> searchByName({
    required String query,
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    CancelToken? cancelToken,
  }) async {
    final lower = query.toLowerCase();
    final all = getPlacesSync(latitude: latitude, longitude: longitude);
    return all.where((p) => p.name.toLowerCase().contains(lower)).toList();
  }

  List<Place> getPlacesSync({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) {
    final places = <Place>[];

    for (final template in _templates) {
      if (template.distanceM > radiusMeters) continue;

      final rad = template.bearingDegrees * (math.pi / 180.0);
      final latRad = latitude * (math.pi / 180.0);
      final cosLat = math.cos(latRad).abs();
      final effectiveCosLat = cosLat < 0.01 ? 0.01 : cosLat;

      final deltaLat = (template.distanceM * math.cos(rad)) / 111139.0;
      final deltaLng =
          (template.distanceM * math.sin(rad)) / (111139.0 * effectiveCosLat);

      final placeLat = latitude + deltaLat;
      final placeLng = longitude + deltaLng;

      places.add(
        Place(
          id: template.id,
          name: template.name,
          cuisine: template.cuisine,
          priceMin: template.priceMin,
          priceMax: template.priceMax,
          distanceM: template.distanceM,
          walkMin: template.walkMin,
          open: template.open,
          x: template.mockX,
          y: template.mockY,
          lat: placeLat,
          lng: placeLng,
        ),
      );
    }

    return places;
  }
}

class _PlaceTemplate {
  final String id;
  final String name;
  final String cuisine;
  final int priceMin;
  final int priceMax;
  final int distanceM;
  final int walkMin;
  final bool open;
  final double bearingDegrees;
  final double mockX;
  final double mockY;

  const _PlaceTemplate({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.priceMin,
    required this.priceMax,
    required this.distanceM,
    required this.walkMin,
    required this.open,
    required this.bearingDegrees,
    required this.mockX,
    required this.mockY,
  });
}
