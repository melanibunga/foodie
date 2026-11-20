import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/week_utils.dart';
import '../data/seed_data.dart';
import '../data/seed_helper.dart';
import '../models/models.dart';
import '../services/recipe_cache_service.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

/// Ringkasan statistik per resep yang sudah dimasak (PRD §14.10)
class CookedRecipeSummary {
  final String recipeId;
  final int count;
  final String latestDate; // Format YYYY-MM-DD
  final int? latestRating; // Rating bintang terakhir yang diberikan

  const CookedRecipeSummary({
    required this.recipeId,
    required this.count,
    required this.latestDate,
    this.latestRating,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CookedRecipeSummary &&
        other.recipeId == recipeId &&
        other.count == count &&
        other.latestDate == latestDate &&
        other.latestRating == latestRating;
  }

  @override
  int get hashCode => Object.hash(recipeId, count, latestDate, latestRating);
}

/// Notifier untuk mengelola daftar riwayat memasak, diisolasi per akun user (Hive).
class CookedNotifier extends Notifier<List<CookedEntry>> {
  @override
  List<CookedEntry> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    try {
      final box = ref.watch(cookedBoxProvider);
      final raw = box.get(userId);
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map(
              (item) =>
                  CookedEntry.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      } else if (userId == kDemoUserId && raw == null) {
        return List<CookedEntry>.from(seedCookedEntries);
      }
    } catch (_) {}

    return const [];
  }

  Future<void> _saveToStorage() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final box = ref.read(cookedBoxProvider);
      await box.put(userId, state.map((e) => e.toJson()).toList());
    } catch (_) {}
  }

  /// Tambahkan 1 entri selesai memasak untuk suatu resep
  Future<void> add(
    String recipeId, [
    String? dateKey,
    int? rating,
    Recipe? recipe,
  ]) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    if (recipe != null) {
      try {
        final cacheBox = ref.read(recipeCacheBoxProvider);
        await RecipeCacheService.saveSummary(cacheBox, recipe);
      } catch (_) {}
    }

    final date = dateKey ?? WeekUtils.formatDateKey(DateTime.now());
    final newEntry = CookedEntry(
      id: 'cooked-${DateTime.now().millisecondsSinceEpoch}',
      recipeId: recipeId,
      date: date,
      rating: rating,
    );

    state = [newEntry, ...state];
    await _saveToStorage();
  }

  /// Update rating pada entri masak terbaru untuk resep tersebut
  Future<void> updateLatestRating(String recipeId, int rating) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final index = state.indexWhere((e) => e.recipeId == recipeId);
    if (index != -1) {
      final updated = List<CookedEntry>.from(state);
      updated[index] = updated[index].copyWith(rating: rating);
      state = updated;
      await _saveToStorage();
    }
  }

  /// Ringkasan grouped per resep: jumlah kali dimasak & tanggal terakhir.
  /// Diurutkan berdasarkan tanggal terakhir memasak (terbaru di atas).
  List<CookedRecipeSummary> byRecipe() {
    final Map<String, List<CookedEntry>> grouped = {};
    for (final entry in state) {
      grouped.putIfAbsent(entry.recipeId, () => []).add(entry);
    }

    final summaries = <CookedRecipeSummary>[];
    for (final entry in grouped.entries) {
      final recipeId = entry.key;
      final entries = entry.value;

      String maxDate = entries.first.date;
      int? latestRating;
      for (final e in entries) {
        if (e.date.compareTo(maxDate) >= 0) {
          maxDate = e.date;
          if (e.rating != null) {
            latestRating = e.rating;
          }
        }
      }
      latestRating ??= entries
          .firstWhere((e) => e.rating != null, orElse: () => entries.first)
          .rating;

      summaries.add(
        CookedRecipeSummary(
          recipeId: recipeId,
          count: entries.length,
          latestDate: maxDate,
          latestRating: latestRating,
        ),
      );
    }

    summaries.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return summaries;
  }

  /// Kosongkan riwayat
  Future<void> clearAll() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = [];
    await _saveToStorage();
  }

  /// Reset ke seed demo
  Future<void> resetToSeed() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final box = ref.read(cookedBoxProvider);
    if (userId == kDemoUserId) {
      state = List<CookedEntry>.from(seedCookedEntries);
      await box.put(userId, state.map((e) => e.toJson()).toList());
    } else {
      state = const [];
      await box.put(userId, <dynamic>[]);
    }
  }
}

final cookedProvider = NotifierProvider<CookedNotifier, List<CookedEntry>>(() {
  return CookedNotifier();
});

/// Total berapa kali user telah memasak (panjang riwayat cooked user aktif)
final cookedCountProvider = Provider<int>((ref) {
  final entries = ref.watch(cookedProvider);
  return entries.length;
});

/// Ringkasan resep unik yang sudah dimasak beserta frekuensi & tanggal terakhir
final cookedSummaryProvider = Provider<List<CookedRecipeSummary>>((ref) {
  ref.watch(cookedProvider);
  return ref.read(cookedProvider.notifier).byRecipe();
});

/// Jumlah resep unik yang sudah dimasak (untuk badge header)
final cookedUniqueCountProvider = Provider<int>((ref) {
  final summaries = ref.watch(cookedSummaryProvider);
  return summaries.length;
});
