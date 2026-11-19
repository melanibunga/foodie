import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'app_shell.dart';
import 'router.dart';

/// Root widget FoodieApp yang mengonfigurasi router, theme, dan AppShell responsif.
class FoodieApp extends ConsumerWidget {
  const FoodieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(currentUserProvider);
    final isDarkMode = user?.settings.darkMode ?? false;

    return MaterialApp.router(
      title: 'Foodie.id',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return AppShell(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
