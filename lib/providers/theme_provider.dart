import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'storage_provider.dart';

/// Provider mandiri untuk preferensi ThemeMode (PRD §16, Fase E1 & B1).
/// Menyimpan preferensi ke box `settings` per user aktif di Hive.
/// Tema mengikuti user aktif (user A gelap, user B terang) dan tersimpan saat buka-tutup app.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final userId = ref.watch(currentUserIdProvider);
    final settingsBox = ref.watch(settingsBoxProvider);

    if (userId != null) {
      final raw = settingsBox.get(userId);
      if (raw is Map) {
        final isDark = raw['darkMode'] as bool? ?? false;
        return isDark ? ThemeMode.dark : ThemeMode.light;
      }
    } else {
      // Jika belum ada user aktif di memori, coba cek session tersimpan
      try {
        final sessionBox = ref.watch(sessionBoxProvider);
        final savedUserId = sessionBox.get('currentUserId') as String?;
        if (savedUserId != null) {
          final raw = settingsBox.get(savedUserId);
          if (raw is Map) {
            final isDark = raw['darkMode'] as bool? ?? false;
            return isDark ? ThemeMode.dark : ThemeMode.light;
          }
        }
      } catch (_) {}
    }

    return ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      final isDark = mode == ThemeMode.dark;
      final settingsBox = ref.read(settingsBoxProvider);
      final raw = settingsBox.get(userId);
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      map['darkMode'] = isDark;
      await settingsBox.put(userId, map);

      await ref.read(authProvider.notifier).syncSettingsFromBox();
    } catch (_) {}
  }

  Future<void> toggleDarkMode() async {
    if (state == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> toggle() => toggleDarkMode();
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
