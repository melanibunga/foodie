import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_helper.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';
import 'cooked_provider.dart';
import 'favorites_provider.dart';
import 'meal_plan_provider.dart';
import 'ratings_provider.dart';
import 'recipes_provider.dart';
import 'storage_provider.dart';
import 'theme_provider.dart';

/// Flag lingkungan dari `--dart-define=RESET=true`
const bool kResetDataOnStart = bool.fromEnvironment(
  'RESET',
  defaultValue: false,
);

/// Fungsi reset data akun demo ke seed awal demo sesuai PRD §11, §12, dan Aturan Fase B1.
/// HANYA mereset data akun demo (Najmah) kembali ke seed awal;
/// TIDAK menyentuh akun user lain yang didaftarkan lokal.
Future<void> resetAllData(ProviderContainer container) async {
  final boxes = container.read(foodieBoxesProvider);
  await seedDemoAccountForce(boxes);
  final currentUserId = container.read(currentUserIdProvider);
  if (currentUserId == kDemoUserId) {
    await container.read(authProvider.notifier).resetToSeed();
    container.invalidate(favoritesProvider);
    container.invalidate(cartProvider);
    container.invalidate(mealPlanProvider);
    container.invalidate(myRecipesProvider);
    container.invalidate(cookedProvider);
    container.invalidate(ratingsProvider);
    container.invalidate(themeModeProvider);
  }
}

/// Reset data akun demo menggunakan WidgetRef dari context widget Profil
Future<void> resetAllDataRef(WidgetRef ref) async {
  final boxes = ref.read(foodieBoxesProvider);
  await seedDemoAccountForce(boxes);
  final currentUserId = ref.read(currentUserIdProvider);
  if (currentUserId == kDemoUserId) {
    await ref.read(authProvider.notifier).resetToSeed();
    ref.invalidate(favoritesProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(mealPlanProvider);
    ref.invalidate(myRecipesProvider);
    ref.invalidate(cookedProvider);
    ref.invalidate(ratingsProvider);
    ref.invalidate(themeModeProvider);
  }
}
