import '../core/utils/auth_utils.dart';
import '../data/seed_data.dart';
import '../providers/storage_provider.dart';

const String kDemoUserId = 'user-demo-default';
const String kDemoEmail = 'benjolmwahh@gmail.com';
const String kDemoPassword = 'demo12345';
const String kDemoName = 'Najmah Cleosaa Tokek';
const String kDemoSalt = 'foodie_demo_salt_2026';

/// Seed data akun demo ke dalam Hive boxes jika belum di-seed
Future<void> seedDemoAccountIfNeeded(FoodieBoxes boxes) async {
  final isSeeded = boxes.meta.get('demo_seeded') as bool? ?? false;
  if (!isSeeded) {
    await seedDemoAccountForce(boxes);
  }
}

/// Paksa seed ulang akun demo (misalnya saat Reset All Data)
Future<void> seedDemoAccountForce(FoodieBoxes boxes) async {
  final passwordHash = AuthUtils.hashPassword(kDemoPassword, kDemoSalt);

  final demoUserMap = {
    'id': kDemoUserId,
    'name': kDemoName,
    'email': kDemoEmail,
    'avatar': null,
    'cooked': 12,
    'salt': kDemoSalt,
    'passwordHash': passwordHash,
    'settings': {'mealReminder': true, 'darkMode': false},
  };

  await boxes.users.put(kDemoUserId, demoUserMap);
  await boxes.settings.put(kDemoUserId, {
    'mealReminder': true,
    'darkMode': false,
  });
  await boxes.favorites.put(kDemoUserId, List<String>.from(seedFavorites));
  await boxes.cart.put(
    kDemoUserId,
    seedCartGroups.map((g) => g.toJson()).toList(),
  );
  await boxes.mealPlan.put(
    kDemoUserId,
    createSeedMealPlan().map((e) => e.toJson()).toList(),
  );
  await boxes.myRecipes.put(kDemoUserId, <dynamic>[]);
  await boxes.cooked.put(
    kDemoUserId,
    seedCookedEntries.map((e) => e.toJson()).toList(),
  );
  await boxes.meta.put('demo_seeded', true);
}
