import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/places.dart';
import '../models/models.dart';

/// Provider daftar tempat makan sekitar (Nearby) sesuai PRD §6.8 & §9
final placesProvider = Provider<List<Place>>((ref) {
  return seedPlaces;
});
