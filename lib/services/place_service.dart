import 'dart:math' as math;

import '../models/models.dart';

/// Interface abstraksi untuk sumber data tempat makan sekitar (Nearby)
/// sesuai PRD §14.12 & §6.8
abstract class PlaceService {
  Future<List<Place>> list();

  Future<List<Place>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  });
}

/// Implementasi lokal/mock untuk PlaceService.
///
/// MOCK IMPLEMENTATION: Menghasilkan tempat makan mock RELATIF terhadap lokasi pengguna.
/// Offset koordinat dihitung berdasarkan distanceM pada arah yang berbeda
/// sehingga rute jalan kaki selalu dapat dihitung di mana pun pengguna berada.
/// CATATAN: Nanti akan diganti dengan sumber data nyata (backend / Overpass API / Google Places API).
class LocalPlaceService implements PlaceService {
  const LocalPlaceService();

  // Template data tempat makan (diadaptasi dari seed data desain location.jpg)
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
      bearingDegrees: 35.0, // Arah Timur Laut
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
      bearingDegrees: 130.0, // Arah Tenggara
      mockX: 76.0,
      mockY: 44.0,
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
      bearingDegrees: 235.0, // Arah Barat Daya
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
      bearingDegrees: 310.0, // Arah Barat Laut
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
      bearingDegrees: 85.0, // Arah Timur
      mockX: 15.0,
      mockY: 75.0,
    ),
  ];

  @override
  Future<List<Place>> list() async {
    // Pusat default area desain: Jl. Kaliurang KM 5 (-7.7653, 110.3789)
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

  /// Helper sinkron untuk menghasilkan data tempat makan mock
  List<Place> getPlacesSync({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) {
    final places = <Place>[];

    for (final template in _templates) {
      if (template.distanceM > radiusMeters) continue;

      // Hitung koordinat relatif berdasarkan jarak (meter) dan sudut (bearing)
      final rad = template.bearingDegrees * (math.pi / 180.0);
      final latRad = latitude * (math.pi / 180.0);

      // 1 meter lat ~ 1 / 111139 derajat
      // 1 meter lng ~ 1 / (111139 * cos(lat)) derajat
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
