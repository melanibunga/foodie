import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth_provider.dart';
import 'recipes_provider.dart';
import 'storage_provider.dart';

/// Hasil kalkulasi rating efektif resep berdasarkan data dasar dan rating lokal user (PRD §14.9 & Fase B3).
class RatingSummary {
  final double rating;
  final int reviews;
  final bool hasUserRating;
  final int? userRating;

  const RatingSummary({
    required this.rating,
    required this.reviews,
    this.hasUserRating = false,
    this.userRating,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RatingSummary &&
        other.rating == rating &&
        other.reviews == reviews &&
        other.hasUserRating == hasUserRating &&
        other.userRating == userRating;
  }

  @override
  int get hashCode => Object.hash(rating, reviews, hasUserRating, userRating);
}

typedef EffectiveRating = RatingSummary;

/// Rumus rating tampil Fase B3:
/// avg = (base*dummyCount + sum)/(dummyCount + n); reviews = dummyCount + n
/// Di mana:
/// - base = rating dasar resep (derived dari hash id)
/// - dummyCount = ulasan dasar resep (derived dari hash id)
/// - sum = total bintang dari semua user di box ratings untuk resep ini
/// - n = jumlah user yang memberi rating untuk resep ini
RatingSummary calculateRatingSummary({
  required double baseRating,
  required int baseReviews,
  required Map<String, int> allRatingsForRecipe,
  String? currentUserId,
}) {
  final userRating =
      currentUserId != null ? allRatingsForRecipe[currentUserId] : null;
  final hasUser = userRating != null;

  final n = allRatingsForRecipe.length;
  if (n == 0) {
    return RatingSummary(
      rating: baseRating,
      reviews: baseReviews,
      hasUserRating: false,
      userRating: null,
    );
  }

  final int sum = allRatingsForRecipe.values.fold<int>(
    0,
    (prev, val) => prev + val,
  );
  final double raw = ((baseRating * baseReviews) + sum) / (baseReviews + n);
  final double rounded = double.parse(raw.toStringAsFixed(1));

  return RatingSummary(
    rating: rounded,
    reviews: baseReviews + n,
    hasUserRating: hasUser,
    userRating: userRating,
  );
}

/// Helper backward-compatible untuk calculateEffectiveRating lama
EffectiveRating calculateEffectiveRating({
  required double baseRating,
  required int baseReviews,
  int? userRating,
}) {
  return calculateRatingSummary(
    baseRating: baseRating,
    baseReviews: baseReviews,
    allRatingsForRecipe:
        userRating != null ? {'default_user': userRating} : const {},
    currentUserId: userRating != null ? 'default_user' : null,
  );
}

/// Notifier untuk menyimpan dan mengelola rating lokal user di box `ratings`.
/// Struktur box: {recipeId: {userId: bintang 1-5}}, diisolasi per akun user.
class RatingsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};

    try {
      final box = ref.watch(ratingsBoxProvider);
      final Map<String, int> userRatings = {};
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          final map = Map<dynamic, dynamic>.from(raw);
          if (map.containsKey(userId)) {
            userRatings[key.toString()] = (map[userId] as num).toInt();
          }
        }
      }
      return userRatings;
    } catch (_) {
      return const {};
    }
  }

  /// Beri atau ganti rating untuk resep tertentu (1..5) oleh user aktif.
  Future<void> rate(String recipeId, int rating) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (rating < 1 || rating > 5) return;

    final box = ref.read(ratingsBoxProvider);
    final raw = box.get(recipeId);
    final map = raw is Map
        ? Map<dynamic, dynamic>.from(raw)
        : <dynamic, dynamic>{};
    map[userId] = rating;

    await box.put(recipeId, map);
    state = {...state, recipeId: rating};
  }

  /// Ambil rating yang pernah diberikan user aktif untuk resep tertentu
  int? getRating(String recipeId) => state[recipeId];

  /// Reset rating milik user aktif
  Future<void> resetToSeed() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final box = ref.read(ratingsBoxProvider);
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map && raw.containsKey(userId)) {
        final map = Map<dynamic, dynamic>.from(raw)..remove(userId);
        await box.put(key, map);
      }
    }
    state = const {};
  }
}

final ratingsProvider = NotifierProvider<RatingsNotifier, Map<String, int>>(() {
  return RatingsNotifier();
});

/// Provider untuk mengambil semua rating dari seluruh user untuk resep tertentu {userId: rating}
final allRecipeRatingsProvider =
    Provider.family<Map<String, int>, String>((ref, recipeId) {
      // Watch ratingsProvider agar otomatis reaktif saat user aktif memberi rating
      ref.watch(ratingsProvider);
      final box = ref.watch(ratingsBoxProvider);
      final raw = box.get(recipeId);
      if (raw is Map) {
        final Map<String, int> result = {};
        raw.forEach((k, v) {
          if (v is num) {
            result[k.toString()] = v.toInt();
          }
        });
        return result;
      }
      return const {};
    });

/// Provider family untuk mengambil rating user aktif untuk satu resep
final userRatingProvider = Provider.family<int?, String>((ref, recipeId) {
  final ratings = ref.watch(ratingsProvider);
  return ratings[recipeId];
});

final recipeUserRatingProvider = userRatingProvider;

/// Provider rating ringkasan gabungan Fase B3:
/// avg = (base*dummyCount + sum)/(dummyCount + n); reviews = dummyCount + n
final ratingSummaryProvider = Provider.family<RatingSummary, dynamic>((
  ref,
  recipeOrId,
) {
  final Recipe recipe;
  if (recipeOrId is Recipe) {
    recipe = recipeOrId;
  } else {
    final recipes = ref.watch(recipesProvider);
    recipe = recipes.firstWhere(
      (r) => r.id == recipeOrId.toString(),
      orElse: () => const Recipe(
        id: '',
        title: '',
        description: '',
        category: '',
        cuisine: '',
        meal: MealType.lunch,
        mainIngredient: '',
        rating: 4.5,
        reviews: 10,
        timeMin: 30,
        servings: 2,
        kcal: 250,
        difficulty: Difficulty.mudah,
        ingredients: [],
        steps: [],
      ),
    );
  }

  final allRatings = ref.watch(allRecipeRatingsProvider(recipe.id));
  final currentUserId = ref.watch(currentUserIdProvider);

  return calculateRatingSummary(
    baseRating: recipe.rating,
    baseReviews: recipe.reviews,
    allRatingsForRecipe: allRatings,
    currentUserId: currentUserId,
  );
});

final effectiveRatingProvider = ratingSummaryProvider;
