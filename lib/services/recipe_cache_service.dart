import 'package:hive/hive.dart';

import '../models/models.dart';

/// Service untuk mengelola cache ringkasan resep (RecipeSummary) di Hive persist box (mis. `recipeCache`),
/// dengan batas ±300 entri dan penggusuran LRU (Least Recently Used) sesuai PRD §6.7, §9.1, §17.
class RecipeCacheService {
  static const String kRecipeSummaryPrefix = 'summary:';
  static const int kMaxCacheEntries = 300;

  /// Simpan satu ringkasan resep ke persist cache box dengan timestamp akses sekarang.
  static Future<void> saveSummary(
    Box box,
    Recipe recipe, {
    int maxEntries = kMaxCacheEntries,
  }) async {
    final map = {
      ...recipe.toJson(),
      '_lastAccessed': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put('$kRecipeSummaryPrefix${recipe.id}', map);
    await evictOldest(box, maxEntries: maxEntries);
  }

  /// Simpan kumpulan ringkasan resep ke persist cache box (batch).
  static Future<void> saveSummaries(
    Box box,
    Iterable<Recipe> recipes, {
    int maxEntries = kMaxCacheEntries,
  }) async {
    if (recipes.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <dynamic, dynamic>{};
    for (final r in recipes) {
      entries['$kRecipeSummaryPrefix${r.id}'] = {
        ...r.toJson(),
        '_lastAccessed': now,
      };
    }
    await box.putAll(entries);
    await evictOldest(box, maxEntries: maxEntries);
  }

  /// Ambil ringkasan resep dari persist cache box secara instan (synchronous).
  /// Memperbarui timestamp `_lastAccessed` untuk pemeliharaan LRU.
  static Recipe? getSummary(Box box, String recipeId) {
    try {
      dynamic raw = box.get('$kRecipeSummaryPrefix$recipeId');
      raw ??= box.get(recipeId);

      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        // Perbarui timestamp last accessed secara non-blocking
        map['_lastAccessed'] = DateTime.now().millisecondsSinceEpoch;
        box.put('$kRecipeSummaryPrefix$recipeId', map);

        return Recipe.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  /// Cek apakah ringkasan resep ada di persist cache box.
  static bool hasSummary(Box box, String recipeId) {
    return box.containsKey('$kRecipeSummaryPrefix$recipeId') ||
        box.containsKey(recipeId);
  }

  /// Penggusuran LRU: Hapus entri yang paling lama tidak diakses jika total melebihi `maxEntries`.
  static Future<void> evictOldest(
    Box box, {
    int maxEntries = kMaxCacheEntries,
  }) async {
    try {
      final summaryKeys = <dynamic>[];
      for (final key in box.keys) {
        if (key.toString().startsWith(kRecipeSummaryPrefix)) {
          summaryKeys.add(key);
        }
      }

      if (summaryKeys.length <= maxEntries) return;

      final list = <MapEntry<dynamic, int>>[];
      for (final k in summaryKeys) {
        final val = box.get(k);
        int lastAccessed = 0;
        if (val is Map) {
          lastAccessed = (val['_lastAccessed'] as num?)?.toInt() ?? 0;
        }
        list.add(MapEntry(k, lastAccessed));
      }

      // Urutkan dari akses tertua
      list.sort((a, b) => a.value.compareTo(b.value));

      final deleteCount = list.length - maxEntries;
      for (int i = 0; i < deleteCount; i++) {
        await box.delete(list[i].key);
      }
    } catch (_) {}
  }
}
