import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipes_provider.dart';

/// Jam pengingat makan tetap 07:00 (Fase B4)
const int kMealReminderHour = 7;
const int kMealReminderMinute = 0;

/// Channel ID dan nama untuk Android
const String kNotificationChannelId = 'meal_reminder';
const String kNotificationChannelName = 'Pengingat Makan';

/// Representasi satu jadwal notifikasi pengingat
class ScheduledNotificationItem {
  final int id;
  final String dateKey;
  final DateTime scheduledDateTime;
  final String title;
  final String body;
  final String payload;
  final List<String> recipeTitles;

  const ScheduledNotificationItem({
    required this.id,
    required this.dateKey,
    required this.scheduledDateTime,
    required this.title,
    required this.body,
    required this.payload,
    required this.recipeTitles,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduledNotificationItem &&
        other.id == id &&
        other.dateKey == dateKey &&
        other.scheduledDateTime == scheduledDateTime &&
        other.title == title &&
        other.body == body &&
        other.payload == payload;
  }

  @override
  int get hashCode =>
      Object.hash(id, dateKey, scheduledDateTime, title, body, payload);
}

/// Fungsi murni (pure function) untuk menyusun jadwal notifikasi pengingat makan.
/// Input:
/// - mealPlan: daftar menu meal plan milik user aktif
/// - recipeTitleMap: mapping recipeId -> title
/// - now: waktu acuan saat ini
/// - reminderHour: jam pengingat (default: 7)
/// - reminderMinute: menit pengingat (default: 0)
/// - daysAhead: rentang hari ke depan (default: 14 hari)
List<ScheduledNotificationItem> buildMealReminderSchedules({
  required List<MealPlanEntry> mealPlan,
  required Map<String, String> recipeTitleMap,
  required DateTime now,
  int reminderHour = kMealReminderHour,
  int reminderMinute = kMealReminderMinute,
  int daysAhead = 14,
}) {
  final List<ScheduledNotificationItem> result = [];

  for (int i = 0; i <= daysAhead; i++) {
    final targetDate = DateTime(now.year, now.month, now.day + i);
    final dateKey =
        '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final scheduledTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      reminderHour,
      reminderMinute,
    );

    // Tanggal/jam yang sudah lewat tidak dijadwalkan
    if (scheduledTime.isBefore(now)) {
      continue;
    }

    // Ambil semua menu di meal plan untuk tanggal ini
    final dayEntries = mealPlan.where((e) => e.date == dateKey).toList();
    if (dayEntries.isEmpty) {
      continue;
    }

    // Judul sesuai PRD Fase B4
    const title = 'Waktunya masak! 🍳';

    final titles = dayEntries
        .map((e) => recipeTitleMap[e.recipeId] ?? 'Resep')
        .toList();

    final String body;
    final String payload;

    if (titles.length == 1) {
      body = 'Hari ini: ${titles[0]}';
      payload = '/recipe/${dayEntries[0].recipeId}';
    } else if (titles.length == 2) {
      body = 'Hari ini: ${titles[0]}, ${titles[1]}';
      payload = '/meal-plan';
    } else {
      final others = titles.length - 2;
      body = 'Hari ini: ${titles[0]}, ${titles[1]} dan $others lainnya';
      payload = '/meal-plan';
    }

    // ID unik stabil per tanggal
    final notifId =
        (targetDate.year % 100) * 10000 +
        targetDate.month * 100 +
        targetDate.day;

    result.add(
      ScheduledNotificationItem(
        id: notifId,
        dateKey: dateKey,
        scheduledDateTime: scheduledTime,
        title: title,
        body: body,
        payload: payload,
        recipeTitles: titles,
      ),
    );
  }

  return result;
}

/// Kontrak abstraksi layanan notifikasi aplikasi
abstract class NotificationService {
  Future<void> init({void Function(String? payload)? onSelectNotification});
  Future<bool> requestPermissions();
  Future<void> scheduleMealReminders({
    required List<MealPlanEntry> mealPlan,
    required Map<String, String> recipeTitleMap,
    DateTime? now,
  });
  Future<void> cancelAll();
  Future<void> sendTestNotification({
    Duration delay = const Duration(seconds: 5),
  });
  Future<String?> getInitialPayload();
}

/// Implementasi No-Op untuk Web, pengujian unit, atau platform yang tidak didukung
class NoOpNotificationService implements NotificationService {
  void Function(String? payload)? _onSelect;
  String? _lastPayload;

  @override
  Future<void> init({
    void Function(String? payload)? onSelectNotification,
  }) async {
    _onSelect = onSelectNotification;
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleMealReminders({
    required List<MealPlanEntry> mealPlan,
    required Map<String, String> recipeTitleMap,
    DateTime? now,
  }) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> sendTestNotification({
    Duration delay = const Duration(seconds: 5),
  }) async {
    _lastPayload = '/meal-plan';
    Future.delayed(delay, () {
      _onSelect?.call(_lastPayload);
    });
  }

  @override
  Future<String?> getInitialPayload() async => null;
}

/// Implementasi nyata menggunakan FlutterLocalNotificationsPlugin
class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(String? payload)? _onSelectNotification;

  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> init({
    void Function(String? payload)? onSelectNotification,
  }) async {
    if (_initialized) return;
    _onSelectNotification = onSelectNotification;

    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback ke UTC / Asia/Jakarta jika timezone gagal dideteksi
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onSelectNotification?.call(response.payload);
      },
    );

    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (_) {}

    return true;
  }

  @override
  Future<void> scheduleMealReminders({
    required List<MealPlanEntry> mealPlan,
    required Map<String, String> recipeTitleMap,
    DateTime? now,
  }) async {
    if (kIsWeb) return;
    await cancelAll();

    final schedules = buildMealReminderSchedules(
      mealPlan: mealPlan,
      recipeTitleMap: recipeTitleMap,
      now: now ?? DateTime.now(),
    );

    for (final item in schedules) {
      try {
        final scheduledTz = tz.TZDateTime.from(
          item.scheduledDateTime,
          tz.local,
        );
        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: scheduledTz,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              kNotificationChannelId,
              kNotificationChannelName,
              channelDescription: 'Pengingat menu harian meal plan Foodie',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: item.payload,
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<void> sendTestNotification({
    Duration delay = const Duration(seconds: 5),
  }) async {
    if (kIsWeb) return;
    final scheduledTz = tz.TZDateTime.now(tz.local).add(delay);

    try {
      await _plugin.zonedSchedule(
        id: 99999,
        title: 'Waktunya masak! 🍳',
        body: 'Notifikasi pengingat berhasil dikirim (uji coba)',
        scheduledDate: scheduledTz,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kNotificationChannelId,
            kNotificationChannelName,
            channelDescription: 'Pengingat menu harian meal plan Foodie',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/meal-plan',
      );
    } catch (_) {}
  }

  @override
  Future<String?> getInitialPayload() async {
    if (kIsWeb) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }
}

/// Provider instance NotificationService utama
final notificationServiceProvider = Provider<NotificationService>((ref) {
  if (kIsWeb) {
    return NoOpNotificationService();
  }
  return LocalNotificationService();
});

/// Notifier pengawas jadwal notifikasi otomatis
/// Memantau perubahan currentUserId, user.settings.mealReminder, dan mealPlanProvider
class NotificationSchedulerNotifier extends Notifier<void> {
  @override
  void build() {
    final userId = ref.watch(currentUserIdProvider);
    final user = ref.watch(currentUserProvider);
    final mealPlan = ref.watch(mealPlanProvider);
    final recipes = ref.watch(recipesProvider);

    final notificationService = ref.read(notificationServiceProvider);

    if (userId == null) {
      // User logout -> batalkan semua notifikasi
      notificationService.cancelAll();
      return;
    }

    final isReminderEnabled = user?.settings.mealReminder ?? false;
    if (!isReminderEnabled) {
      // Toggle nonaktif -> batalkan semua notifikasi
      notificationService.cancelAll();
      return;
    }

    // Bangun ulang jadwal notifikasi
    final recipeMap = {for (final r in recipes) r.id: r.title};
    notificationService.scheduleMealReminders(
      mealPlan: mealPlan,
      recipeTitleMap: recipeMap,
    );
  }
}

final notificationSchedulerProvider =
    NotifierProvider<NotificationSchedulerNotifier, void>(
      NotificationSchedulerNotifier.new,
    );
