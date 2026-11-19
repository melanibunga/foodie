import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/week_utils.dart';
import '../models/models.dart';
import 'storage_provider.dart';

/// Ringkasan statistik per resep yang sudah dimasak (PRD §14.10)
class CookedRecipeSummary {
  final String recipeId;
  final int count;
  final String latestDate; // Format YYYY-MM-DD

  const CookedRecipeSummary({
    required this.recipeId,
    required this.count,
    required this.latestDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CookedRecipeSummary &&
        other.recipeId == recipeId &&
        other.count == count &&
        other.latestDate == latestDate;
  }

  @override
  int get hashCode => Object.hash(recipeId, count, latestDate);
}

/// 12 entri seed riwayat masak sesuai PRD §9 & §14.10 ("dimasak 12")
final List<CookedEntry> seedCookedEntries = [
  const CookedEntry(
    id: 'cooked-seed-1',
    recipeId: 'ayam-kecap-bawang',
    date: '2026-11-18',
  ),
  const CookedEntry(
    id: 'cooked-seed-2',
    recipeId: 'soto-ayam',
    date: '2026-11-17',
  ),
  const CookedEntry(
    id: 'cooked-seed-3',
    recipeId: 'nasi-goreng-nusantara',
    date: '2026-11-16',
  ),
  const CookedEntry(
    id: 'cooked-seed-4',
    recipeId: 'rendang-sapi-minang',
    date: '2026-11-14',
  ),
  const CookedEntry(
    id: 'cooked-seed-5',
    recipeId: 'gado-gado-siram',
    date: '2026-11-12',
  ),
  const CookedEntry(
    id: 'cooked-seed-6',
    recipeId: 'salmon-teriyaki',
    date: '2026-11-10',
  ),
  const CookedEntry(
    id: 'cooked-seed-7',
    recipeId: 'sate-ayam',
    date: '2026-11-08',
  ),
  const CookedEntry(
    id: 'cooked-seed-8',
    recipeId: 'telur-balado',
    date: '2026-11-05',
  ),
  const CookedEntry(
    id: 'cooked-seed-9',
    recipeId: 'tumis-kangkung',
    date: '2026-11-02',
  ),
  const CookedEntry(
    id: 'cooked-seed-10',
    recipeId: 'bihun-goreng',
    date: '2026-10-30',
  ),
  const CookedEntry(
    id: 'cooked-seed-11',
    recipeId: 'nasi-goreng-spesial',
    date: '2026-10-26',
  ),
  const CookedEntry(
    id: 'cooked-seed-12',
    recipeId: 'ayam-kecap-bawang',
    date: '2026-10-20',
  ),
];

/// Notifier untuk mengelola daftar riwayat memasak (foodie:cooked).
class CookedNotifier extends Notifier<List<CookedEntry>> {
  static const String prefKey = 'foodie:cooked';

  @override
  List<CookedEntry> build() {
    _loadFromStorage();
    return state;
  }

  void _loadFromStorage() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        state = decoded
            .map((item) => CookedEntry.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        state = seedCookedEntries;
      }
    } catch (_) {
      state = seedCookedEntries;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(
        prefKey,
        jsonEncode(state.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Tambahkan 1 entri selesai memasak untuk suatu resep
  Future<void> add(String recipeId, [String? dateKey]) async {
    final date = dateKey ?? WeekUtils.formatDateKey(DateTime.now());
    final newEntry = CookedEntry(
      id: 'cooked-${DateTime.now().millisecondsSinceEpoch}',
      recipeId: recipeId,
      date: date,
    );

    state = [newEntry, ...state];
    await _saveToStorage();
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

      // Cari tanggal terbaru
      String maxDate = entries.first.date;
      for (final e in entries) {
        if (e.date.compareTo(maxDate) > 0) {
          maxDate = e.date;
        }
      }

      summaries.add(
        CookedRecipeSummary(
          recipeId: recipeId,
          count: entries.length,
          latestDate: maxDate,
        ),
      );
    }

    // Urutkan dari tanggal terbaru ke terlama
    summaries.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return summaries;
  }

  /// Kosongkan riwayat
  Future<void> clearAll() async {
    state = [];
    await _saveToStorage();
  }

  /// Reset ke seed demo
  Future<void> resetToSeed() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(prefKey);
    state = seedCookedEntries;
  }
}

final cookedProvider = NotifierProvider<CookedNotifier, List<CookedEntry>>(() {
  return CookedNotifier();
});

/// Total berapa kali user telah memasak (menggantikan user.cooked)
final cookedCountProvider = Provider<int>((ref) {
  final entries = ref.watch(cookedProvider);
  return entries.length;
});

/// Ringkasan resep unik yang sudah dimasak beserta frekuensi & tanggal terakhir
final cookedSummaryProvider = Provider<List<CookedRecipeSummary>>((ref) {
  // Watch cookedProvider state to rebuild when entries change
  ref.watch(cookedProvider);
  return ref.read(cookedProvider.notifier).byRecipe();
});

/// Jumlah resep unik yang sudah dimasak (untuk badge header)
final cookedUniqueCountProvider = Provider<int>((ref) {
  final summaries = ref.watch(cookedSummaryProvider);
  return summaries.length;
});
