import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

/// Provider mandiri untuk preferensi ThemeMode (PRD §16, Fase E1).
/// Menyimpan preferensi ke SharedPreferences (key "foodie:themeMode").
/// Nilai yang didukung: "light", "dark", "system". Default: "light".
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String prefKey = 'foodie:themeMode';

  @override
  ThemeMode build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final saved = prefs.getString(prefKey);
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'system') return ThemeMode.system;
      return ThemeMode.light;
    } catch (_) {
      return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final String val;
      switch (mode) {
        case ThemeMode.dark:
          val = 'dark';
          break;
        case ThemeMode.system:
          val = 'system';
          break;
        case ThemeMode.light:
          val = 'light';
          break;
      }
      await prefs.setString(prefKey, val);
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
