import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'providers/reset_data.dart';
import 'providers/storage_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi portrait sesuai PRD §11 & §12
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inisialisasi SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Reset otomatis bila dijalankan dengan flag --dart-define=RESET=true
  if (kResetDataOnStart) {
    await clearAllFoodiePrefs(prefs);
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FoodieApp(),
    ),
  );
}
