import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'storage_provider.dart';

/// Hasil kalkulasi rating efektif resep berdasarkan data dasar dan rating lokal user (PRD §14.9).
class EffectiveRating {
  final double rating;
  final int reviews;
  final bool hasUserRating;
  final int? userRating;

  const EffectiveRating({
    required this.rating,
    required this.reviews,
    this.hasUserRating = false,
    this.userRating,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EffectiveRating &&
        other.rating == rating &&
        other.reviews == reviews &&
        other.hasUserRating == hasUserRating &&
        other.userRating == userRating;
  }

  @override
  int get hashCode => Object.hash(rating, reviews, hasUserRating, userRating);
}

/// Rumus rating efektif PRD §14.9:
/// (ratingDasar * ulasanDasar + ratingUser) / (ulasanDasar + 1), dibulatkan 1 desimal, ulasan + 1.
/// Bila user memberi rating lagi untuk resep yang sama, nilainya menggantikan (dihitung selalu dari nilai dasar).
EffectiveRating calculateEffectiveRating({
  required double baseRating,
  required int baseReviews,
  int? userRating,
}) {
  if (userRating == null || userRating < 1 || userRating > 5) {
    return EffectiveRating(
      rating: baseRating,
      reviews: baseReviews,
      hasUserRating: false,
      userRating: null,
    );
  }

  final double raw =
      ((baseRating * baseReviews) + userRating) / (baseReviews + 1);
  final double rounded = double.parse(raw.toStringAsFixed(1));

  return EffectiveRating(
    rating: rounded,
    reviews: baseReviews + 1,
    hasUserRating: true,
    userRating: userRating,
  );
}

/// Notifier untuk menyimpan dan mengelola rating lokal user (foodie:ratings).
class RatingsNotifier extends Notifier<Map<String, int>> {
  static const String prefKey = 'foodie:ratings';

  @override
  Map<String, int> build() {
    _loadFromStorage();
    return state;
  }

  void _loadFromStorage() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = decoded.map((key, value) => MapEntry(key, value as int));
      } else {
        state = {};
      }
    } catch (_) {
      state = {};
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(prefKey, jsonEncode(state));
    } catch (_) {}
  }

  /// Beri atau ganti rating untuk resep tertentu (1..5).
  Future<void> rate(String recipeId, int rating) async {
    if (rating < 1 || rating > 5) return;
    state = {...state, recipeId: rating};
    await _saveToStorage();
  }

  /// Ambil rating yang pernah diberikan user untuk resep tertentu
  int? getRating(String recipeId) => state[recipeId];

  /// Reset semua rating
  Future<void> clearAll() async {
    state = {};
    await _saveToStorage();
  }
}

final ratingsProvider = NotifierProvider<RatingsNotifier, Map<String, int>>(() {
  return RatingsNotifier();
});

/// Provider family untuk mengambil rating user spesifik untuk satu resep
final recipeUserRatingProvider = Provider.family<int?, String>((ref, recipeId) {
  final ratings = ref.watch(ratingsProvider);
  return ratings[recipeId];
});

/// Provider family untuk menghitung rating efektif satu resep
final effectiveRatingProvider = Provider.family<EffectiveRating, Recipe>((
  ref,
  recipe,
) {
  final userRating = ref.watch(recipeUserRatingProvider(recipe.id));
  return calculateEffectiveRating(
    baseRating: recipe.rating,
    baseReviews: recipe.reviews,
    userRating: userRating,
  );
});
