import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/week_utils.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import 'storage_provider.dart';

/// State Notifier untuk Meal Plan mingguan sesuai PRD §9
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

  /// Tambah resep ke tanggal tertentu (format YYYY-MM-DD)
  Future<void> add(String date, String recipeId) async {
    final newEntry = MealPlanEntry(
      id: 'mp-${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      recipeId: recipeId,
    );
    state = [...state, newEntry];
    await _saveToStorage();
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
