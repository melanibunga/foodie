import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';
import 'cart_provider.dart';
import 'favorites_provider.dart';
import 'meal_plan_provider.dart';
import 'recipes_provider.dart';

/// Flag lingkungan dari `--dart-define=RESET=true`
const bool kResetDataOnStart = bool.fromEnvironment(
  'RESET',
  defaultValue: false,
);

/// Fungsi reset data penuh ke seed awal sesuai PRD §11 & §12.
Future<void> resetAllData(ProviderContainer container) async {
  await container.read(recipesProvider.notifier).resetToSeed();
  await container.read(favoritesProvider.notifier).resetToSeed();
  await container.read(cartProvider.notifier).resetToSeed();
  await container.read(mealPlanProvider.notifier).resetToSeed();
  await container.read(authProvider.notifier).resetToSeed();
}

/// Reset data menggunakan WidgetRef dari context widget
Future<void> resetAllDataRef(WidgetRef ref) async {
  await ref.read(recipesProvider.notifier).resetToSeed();
  await ref.read(favoritesProvider.notifier).resetToSeed();
  await ref.read(cartProvider.notifier).resetToSeed();
  await ref.read(mealPlanProvider.notifier).resetToSeed();
  await ref.read(authProvider.notifier).resetToSeed();
}

/// Hapus semua cache shared preferences dengan prefix `foodie:`
Future<void> clearAllFoodiePrefs(SharedPreferences prefs) async {
  final keys = prefs.getKeys().where((k) => k.startsWith('foodie:')).toList();
  for (final key in keys) {
    await prefs.remove(key);
  }
}
