import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';

/// Default koordinat (Yogyakarta / Seturan) sesuai PRD §14.12 bila lokasi belum didapat
const LatLng kDefaultNearbyCenter = LatLng(-7.7554, 110.3800);

/// Pembuat URL Google Maps eksternal sesuai PRD & spesifikasi Nearby:
/// - Bila ada tempat terpilih: `https://www.google.com/maps/search/?api=1&query=<nama+tempat>%20<lat>,<lng>` (encode benar)
/// - Bila tidak ada pilihan: `https://www.google.com/maps/search/rumah+makan/@<lat>,<lng>,16z`
String buildGoogleMapsUrl({
  Place? selectedPlace,
  LatLng? userLocation,
  LatLng? fallbackCenter,
}) {
  if (selectedPlace != null) {
    final encodedName = Uri.encodeQueryComponent(selectedPlace.name);
    return 'https://www.google.com/maps/search/?api=1&query=$encodedName%20${selectedPlace.latitude},${selectedPlace.longitude}';
  }

  final center = userLocation ?? fallbackCenter ?? kDefaultNearbyCenter;
  return 'https://www.google.com/maps/search/rumah+makan/@${center.latitude},${center.longitude},16z';
}

/// Buka Google Maps secara eksternal via url_launcher
Future<bool> openGoogleMaps({
  Place? selectedPlace,
  LatLng? userLocation,
  LatLng? fallbackCenter,
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  final urlStr = buildGoogleMapsUrl(
    selectedPlace: selectedPlace,
    userLocation: userLocation,
    fallbackCenter: fallbackCenter,
  );
  final uri = Uri.parse(urlStr);
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}

/// Pemilihan ikon marker Lucide per jenis tempat makan:
/// - utensils untuk restaurant & food_court
/// - coffee untuk cafe
/// - sandwich (atau store) untuk fast_food
IconData getPlaceMarkerIcon(String? type) {
  final clean = type?.toLowerCase().trim() ?? '';
  if (clean == 'cafe' || clean == 'kafe' || clean == 'kopi') {
    return LucideIcons.coffee;
  }
  if (clean == 'fast_food' ||
      clean == 'fastfood' ||
      clean == 'cepat_saji' ||
      clean == 'cepat saji') {
    return LucideIcons.sandwich;
  }
  return LucideIcons.utensils;
}

/// Batasi daftar tempat untuk preview peta (maksimal 12 tempat terdekat)
List<Place> limitPlacesForPreview(List<Place> places, {int max = 12}) {
  if (places.length <= max) return places;
  return places.sublist(0, max);
}
