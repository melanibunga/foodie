import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/week_utils.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import 'storage_provider.dart';

/// Status hasil penambahan menu ke Meal Plan sesuai PRD §14.7, §15.6, §15.8
enum MealPlanAddResult { added, exists, pastDate }

/// Injeksi waktu "sekarang" untuk kemudahan pengujian Meal Plan & tanggal lampau (PRD §15.6)
final clockProvider = Provider<DateTime>((ref) => DateTime.now());

/// State Notifier untuk Meal Plan mingguan sesuai PRD §9, §14.7, §15.6
class MealPlanNotifier extends Notifier<List<MealPlanEntry>> {
  static const String prefKey = 'foodie:meal_plan';

  @override
  List<MealPlanEntry> build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        return decoded
            .map((item) => MealPlanEntry.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        final initialSeed = createSeedMealPlan();
        prefs.setString(
          prefKey,
          jsonEncode(initialSeed.map((e) => e.toJson()).toList()),
        );
        return initialSeed;
      }
    } catch (_) {
      return createSeedMealPlan();
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

  /// Cek apakah resep sudah ada pada tanggal tertentu (format YYYY-MM-DD)
  bool has(String date, String recipeId) {
    return state.any((e) => e.date == date && e.recipeId == recipeId);
  }

  /// Cek apakah resep sudah terjadwal untuk hari ini atau hari mendatang (tanggal >= hari ini)
  bool isPlanned(String recipeId) {
    final now = ref.read(clockProvider);
    final todayKey = WeekUtils.formatDateKey(
      DateTime(now.year, now.month, now.day),
    );
    return state.any(
      (e) => e.recipeId == recipeId && e.date.compareTo(todayKey) >= 0,
    );
  }

  /// Daftar semua tanggal YYYY-MM-DD di mana resep dijadwalkan
  List<String> datesFor(String recipeId) {
    return state
        .where((e) => e.recipeId == recipeId)
        .map((e) => e.date)
        .toList();
  }

  /// Tambah resep ke tanggal tertentu (format YYYY-MM-DD)
  /// Mengembalikan MealPlanAddResult (added / exists / pastDate).
  /// - Bila tanggal < hari ini: menolak dengan status pastDate (PRD §15.6)
  /// - Bila exists (resep sama pada tanggal sama), tidak menambah apa pun.
  Future<MealPlanAddResult> add(String date, String recipeId) async {
    final now = ref.read(clockProvider);
    final todayKey = WeekUtils.formatDateKey(
      DateTime(now.year, now.month, now.day),
    );

    if (date.compareTo(todayKey) < 0) {
      return MealPlanAddResult.pastDate;
    }

    if (has(date, recipeId)) {
      return MealPlanAddResult.exists;
    }

    final newEntry = MealPlanEntry(
      id: 'mp-${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      recipeId: recipeId,
    );
    state = [...state, newEntry];
    await _saveToStorage();
    return MealPlanAddResult.added;
  }

  /// Hapus satu entri meal plan berdasarkan id entri
  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _saveToStorage();
  }

  /// Ambil entri untuk 1 minggu penuh yang dimulai pada [weekStart] (Senin)
  List<MealPlanEntry> byWeek(DateTime weekStart) {
    final days = WeekUtils.getWeekDays(weekStart);
    final weekDateKeys = days.map(WeekUtils.formatDateKey).toSet();
    return state.where((e) => weekDateKeys.contains(e.date)).toList();
  }

  /// Reset ke seed demo
  Future<void> resetToSeed() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final initialSeed = createSeedMealPlan();
    await prefs.setString(
      prefKey,
      jsonEncode(initialSeed.map((e) => e.toJson()).toList()),
    );
    state = initialSeed;
  }
}

final mealPlanProvider =
    NotifierProvider<MealPlanNotifier, List<MealPlanEntry>>(() {
      return MealPlanNotifier();
    });

/// Provider entri meal plan per tanggal YYYY-MM-DD
final mealPlanByDateProvider = Provider.family<List<MealPlanEntry>, String>((
  ref,
  dateKey,
) {
  final entries = ref.watch(mealPlanProvider);
  return entries.where((e) => e.date == dateKey).toList();
});

/// Provider pengecekan apakah resep sudah terjadwal di hari ini atau mendatang
final isRecipePlannedProvider = Provider.family<bool, String>((ref, recipeId) {
  final entries = ref.watch(mealPlanProvider);
  final now = ref.watch(clockProvider);
  final todayKey = WeekUtils.formatDateKey(
    DateTime(now.year, now.month, now.day),
  );
  return entries.any(
    (e) => e.recipeId == recipeId && e.date.compareTo(todayKey) >= 0,
  );
});
