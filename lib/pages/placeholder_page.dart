import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';

/// Halaman placeholder sementara untuk route yang belum diimplementasikan di fase ini.
class PlaceholderPage extends StatelessWidget {
  final String title;
  final String routePath;

  const PlaceholderPage({
    super.key,
    required this.title,
    required this.routePath,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: Text(
          title,
          style: AppText.pageTitle.copyWith(color: palette.textStrong),
        ),
        leading: context.canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: palette.textStrong),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: AppRadius.card,
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: palette.onAccentSoft,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppText.sectionTitle.copyWith(color: palette.textStrong),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Route: $routePath',
                style: AppText.caption.copyWith(color: palette.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.actionBg,
                  foregroundColor: palette.onAction,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.button,
                  ),
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: const Text('Kembali', style: AppText.buttonMd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
