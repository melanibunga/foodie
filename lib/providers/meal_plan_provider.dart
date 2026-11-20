import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/week_utils.dart';
import '../data/seed_data.dart';
import '../data/seed_helper.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

/// Status hasil penambahan menu ke Meal Plan sesuai PRD §14.7, §15.6, §15.8
enum MealPlanAddResult { added, exists, pastDate }

/// Injeksi waktu "sekarang" untuk kemudahan pengujian Meal Plan & tanggal lampau (PRD §15.6)
final clockProvider = Provider<DateTime>((ref) => DateTime.now());

/// State Notifier untuk Meal Plan mingguan, diisolasi per akun user (Hive).
class MealPlanNotifier extends Notifier<List<MealPlanEntry>> {
  @override
  List<MealPlanEntry> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    try {
      final box = ref.watch(mealPlanBoxProvider);
      final raw = box.get(userId);
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map(
              (item) => MealPlanEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      } else if (userId == kDemoUserId && raw == null) {
        return createSeedMealPlan();
      }
    } catch (_) {}

    return const [];
  }

  Future<void> _saveToStorage() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final box = ref.read(mealPlanBoxProvider);
      await box.put(userId, state.map((e) => e.toJson()).toList());
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
  Future<MealPlanAddResult> add(String date, String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return MealPlanAddResult.exists;

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

  /// Hapus satu jadwal berdasarkan ID entri
  Future<void> remove(String entryId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.where((e) => e.id != entryId).toList();
    await _saveToStorage();
  }

  /// Hapus seluruh rencana menu pada tanggal tertentu
  Future<void> removeDate(String date) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.where((e) => e.date != date).toList();
    await _saveToStorage();
  }

  /// Hapus rencana yang sudah lewat dari hari ini
  Future<void> clearPastDates() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final now = ref.read(clockProvider);
    final todayKey = WeekUtils.formatDateKey(
      DateTime(now.year, now.month, now.day),
    );

    state = state.where((e) => e.date.compareTo(todayKey) >= 0).toList();
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
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final box = ref.read(mealPlanBoxProvider);
    if (userId == kDemoUserId) {
      state = createSeedMealPlan();
      await box.put(userId, state.map((e) => e.toJson()).toList());
    } else {
      state = const [];
      await box.put(userId, <dynamic>[]);
    }
  }
}

final mealPlanProvider =
    NotifierProvider<MealPlanNotifier, List<MealPlanEntry>>(() {
      return MealPlanNotifier();
    });

/// Provider daftar entri meal plan yang difilter untuk tanggal tertentu (format YYYY-MM-DD)
final mealPlanForDateProvider = Provider.family<List<MealPlanEntry>, String>((
  ref,
  date,
) {
  final entries = ref.watch(mealPlanProvider);
  return entries.where((e) => e.date == date).toList();
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

/// Provider total jadwal aktif minggu berjalan
final mealPlanWeeklyCountProvider = Provider<int>((ref) {
  final entries = ref.watch(mealPlanProvider);
  return entries.length;
});
