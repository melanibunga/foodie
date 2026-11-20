import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/services/notification_service.dart';

void main() {
  group('Fase B4 — Fungsi Penyusun Jadwal Notifikasi Pengingat Makan', () {
    final recipeTitleMap = {
      'ayam-kecap-bawang': 'Ayam Kecap Bawang',
      'soto-ayam': 'Soto Ayam',
      'rendang-sapi-minang': 'Rendang Sapi Minang',
      'telur-balado': 'Telur Balado',
    };

    test('1. Tanggal/jam yang sudah lewat dari waktu acuan saat ini tidak dijadwalkan', () {
      // Sekarang: 2026-11-20 pukul 08:30 (jam pengingat 07:00 hari ini sudah lewat)
      final now = DateTime(2026, 11, 20, 8, 30);

      final mealPlan = [
        // Hari ini (07:00 sudah lewat)
        const MealPlanEntry(
          id: 'mp-1',
          date: '2026-11-20',
          recipeId: 'ayam-kecap-bawang',
        ),
        // Besok (07:00 belum lewat)
        const MealPlanEntry(
          id: 'mp-2',
          date: '2026-11-21',
          recipeId: 'soto-ayam',
        ),
      ];

      final schedules = buildMealReminderSchedules(
        mealPlan: mealPlan,
        recipeTitleMap: recipeTitleMap,
        now: now,
      );

      // Hanya tanggal besok (2026-11-21) yang dijadwalkan
      expect(schedules.length, 1);
      expect(schedules.first.dateKey, '2026-11-21');
      expect(schedules.first.scheduledDateTime, DateTime(2026, 11, 21, 7, 0));
      expect(schedules.first.title, 'Waktunya masak! 🍳');
      expect(schedules.first.body, 'Hari ini: Soto Ayam');
      expect(schedules.first.payload, '/recipe/soto-ayam');
    });

    test('2. Hari ini sebelum pukul 07:00 tetap dijadwalkan', () {
      // Sekarang: 2026-11-20 pukul 06:15 (jam pengingat 07:00 hari ini belum lewat)
      final now = DateTime(2026, 11, 20, 6, 15);

      final mealPlan = [
        const MealPlanEntry(
          id: 'mp-1',
          date: '2026-11-20',
          recipeId: 'ayam-kecap-bawang',
        ),
      ];

      final schedules = buildMealReminderSchedules(
        mealPlan: mealPlan,
        recipeTitleMap: recipeTitleMap,
        now: now,
      );

      expect(schedules.length, 1);
      expect(schedules.first.dateKey, '2026-11-20');
      expect(schedules.first.scheduledDateTime, DateTime(2026, 11, 20, 7, 0));
    });

    test('3. Tanggal tanpa menu di meal plan tidak dijadwalkan', () {
      final now = DateTime(2026, 11, 20, 5, 0);

      // Meal plan kosong
      final schedules = buildMealReminderSchedules(
        mealPlan: const [],
        recipeTitleMap: recipeTitleMap,
        now: now,
      );

      expect(schedules, isEmpty);
    });

    test('4. Format notifikasi 1 menu, 2 menu, dan >2 menu', () {
      final now = DateTime(2026, 11, 20, 5, 0);

      final mealPlan = [
        // 1 menu di 2026-11-21
        const MealPlanEntry(
          id: 'mp-1',
          date: '2026-11-21',
          recipeId: 'ayam-kecap-bawang',
        ),

        // 2 menu di 2026-11-22
        const MealPlanEntry(
          id: 'mp-2',
          date: '2026-11-22',
          recipeId: 'ayam-kecap-bawang',
        ),
        const MealPlanEntry(
          id: 'mp-3',
          date: '2026-11-22',
          recipeId: 'soto-ayam',
        ),

        // 3 menu di 2026-11-23 (>2 menu)
        const MealPlanEntry(
          id: 'mp-4',
          date: '2026-11-23',
          recipeId: 'ayam-kecap-bawang',
        ),
        const MealPlanEntry(
          id: 'mp-5',
          date: '2026-11-23',
          recipeId: 'soto-ayam',
        ),
        const MealPlanEntry(
          id: 'mp-6',
          date: '2026-11-23',
          recipeId: 'rendang-sapi-minang',
        ),

        // 4 menu di 2026-11-24
        const MealPlanEntry(
          id: 'mp-7',
          date: '2026-11-24',
          recipeId: 'ayam-kecap-bawang',
        ),
        const MealPlanEntry(
          id: 'mp-8',
          date: '2026-11-24',
          recipeId: 'soto-ayam',
        ),
        const MealPlanEntry(
          id: 'mp-9',
          date: '2026-11-24',
          recipeId: 'rendang-sapi-minang',
        ),
        const MealPlanEntry(
          id: 'mp-10',
          date: '2026-11-24',
          recipeId: 'telur-balado',
        ),
      ];

      final schedules = buildMealReminderSchedules(
        mealPlan: mealPlan,
        recipeTitleMap: recipeTitleMap,
        now: now,
      );

      expect(schedules.length, 4);

      // 1 menu
      final s1 = schedules.firstWhere((s) => s.dateKey == '2026-11-21');
      expect(s1.body, 'Hari ini: Ayam Kecap Bawang');
      expect(s1.payload, '/recipe/ayam-kecap-bawang');

      // 2 menu
      final s2 = schedules.firstWhere((s) => s.dateKey == '2026-11-22');
      expect(s2.body, 'Hari ini: Ayam Kecap Bawang, Soto Ayam');
      expect(s2.payload, '/meal-plan');

      // 3 menu
      final s3 = schedules.firstWhere((s) => s.dateKey == '2026-11-23');
      expect(s3.body, 'Hari ini: Ayam Kecap Bawang, Soto Ayam dan 1 lainnya');
      expect(s3.payload, '/meal-plan');

      // 4 menu
      final s4 = schedules.firstWhere((s) => s.dateKey == '2026-11-24');
      expect(s4.body, 'Hari ini: Ayam Kecap Bawang, Soto Ayam dan 2 lainnya');
      expect(s4.payload, '/meal-plan');
    });

    test('5. Isolasi jadwal antar user berbeda', () {
      final now = DateTime(2026, 11, 20, 5, 0);

      final mealPlanUserA = [
        const MealPlanEntry(
          id: 'mp-a1',
          date: '2026-11-22',
          recipeId: 'ayam-kecap-bawang',
        ),
      ];

      final mealPlanUserB = [
        const MealPlanEntry(
          id: 'mp-b1',
          date: '2026-11-25',
          recipeId: 'soto-ayam',
        ),
      ];

      final schedulesA = buildMealReminderSchedules(
        mealPlan: mealPlanUserA,
        recipeTitleMap: recipeTitleMap,
        now: now,
      );

      final schedulesB = buildMealReminderSchedules(
        mealPlan: mealPlanUserB,
        recipeTitleMap: recipeTitleMap,
        now: now,
      );

      expect(schedulesA.length, 1);
      expect(schedulesA.first.dateKey, '2026-11-22');
      expect(schedulesA.first.body, contains('Ayam Kecap Bawang'));

      expect(schedulesB.length, 1);
      expect(schedulesB.first.dateKey, '2026-11-25');
      expect(schedulesB.first.body, contains('Soto Ayam'));
    });

    test('6. NoOpNotificationService berjalan tanpa error/crash', () async {
      final noOp = NoOpNotificationService();
      await noOp.init();
      expect(await noOp.requestPermissions(), isTrue);
      await noOp.scheduleMealReminders(mealPlan: [], recipeTitleMap: {});
      await noOp.cancelAll();
      await noOp.sendTestNotification(delay: Duration.zero);
      expect(await noOp.getInitialPayload(), isNull);
    });
  });
}
