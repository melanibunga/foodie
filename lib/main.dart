import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'data/seed_helper.dart';
import 'providers/reset_data.dart';
import 'providers/storage_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mode edge-to-edge Android dengan system bar transparan sesuai PRD §14.2
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Kunci orientasi portrait sesuai PRD §11 & §12
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inisialisasi Hive & buka seluruh box sebelum runApp
  await Hive.initFlutter();
  final boxes = await FoodieBoxes.open();

  // Reset otomatis bila dijalankan dengan flag --dart-define=RESET=true
  if (kResetDataOnStart) {
    await boxes.clearAll();
    await seedDemoAccountForce(boxes);
  } else {
    // Seed akun demo SEKALI jika belum pernah di-seed
    await seedDemoAccountIfNeeded(boxes);
  }

  // Inisialisasi notifikasi lokal (Fase B4)
  final notifService = LocalNotificationService();
  await notifService.init(
    onSelectNotification: (payload) {
      if (payload != null && payload.isNotEmpty) {
        appRouter.push(payload);
      }
    },
  );
  final initialPayload = await notifService.getInitialPayload();
  if (initialPayload != null && initialPayload.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.push(initialPayload);
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        foodieBoxesProvider.overrideWithValue(boxes),
        notificationServiceProvider.overrideWithValue(notifService),
      ],
      child: const FoodieApp(),
    ),
  );
}
