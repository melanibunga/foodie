import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_shadows.dart';

/// Container utama aplikasi dengan batasan lebar 440 px (lebar basis desain).
/// Pada layar > 440 (desktop/tablet/web), app berada di tengah dengan latar [AppColors.outerBg].
/// Pada layar <= 440, app memenuhi layar secara responsif.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  /// Helper padding atas pengganti status bar sesuai PRD §12 butir 14.
  /// `topChrome = max(MediaQuery.padding.top, 60)`.
  /// Konten halaman dimulai di `topChrome + 24`.
  static double topChrome(BuildContext context) {
    return math.max(MediaQuery.paddingOf(context).top, 60.0);
  }

  /// Helper padding bawah untuk halaman yang memiliki bottom nav (≈ 120 px)
  /// agar konten tidak tertutup floating bottom nav.
  static const double bottomNavPadding = 120.0;

  /// Lebar maksimum kolom aplikasi (sesuai basis desain)
  static const double maxAppWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > maxAppWidth) {
          return Container(
            color: isDark ? AppColors.outerBgDark : AppColors.outerBg,
            alignment: Alignment.center,
            child: Container(
              width: maxAppWidth,
              height: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bg,
                boxShadow: AppShadows.shellColumn,
              ),
              child: child,
            ),
          );
        }

        return Container(color: AppColors.bg, child: child);
      },
    );
  }
}
