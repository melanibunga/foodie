import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';

enum AppBadgeVariant {
  squareAmber, // Kotak 42 x 42 radius 12 (Favorites)
  pillOlive, // Pill olive (Header)
  circleAmber, // Lingkaran amber
}

/// Widget badge angka & status sesuai PRD §5.3 dan §16
class AppBadge extends StatelessWidget {
  final String text;
  final AppBadgeVariant variant;
  final Widget? icon;

  const AppBadge({
    super.key,
    required this.text,
    this.variant = AppBadgeVariant.pillOlive,
    this.icon,
  });

  /// Factory untuk badge angka Favorites (42 × 42 radius 12 amber)
  factory AppBadge.square({Key? key, required int count}) {
    return AppBadge(
      key: key,
      text: count.toString(),
      variant: AppBadgeVariant.squareAmber,
    );
  }

  /// Factory untuk pill bookmark header
  factory AppBadge.pill({Key? key, required int count, Widget? icon}) {
    return AppBadge(
      key: key,
      text: count.toString(),
      variant: AppBadgeVariant.pillOlive,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    switch (variant) {
      case AppBadgeVariant.squareAmber:
        return Container(
          width: 42.0,
          height: 42.0,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: AppText.pageTitle.copyWith(
              color: palette.onAccent,
              fontSize: 18.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

      case AppBadgeVariant.pillOlive:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: palette.isDark ? palette.accent : palette.navSurface,
            borderRadius: AppRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 4)],
              Text(
                text,
                style: AppText.caption.copyWith(
                  color: palette.isDark ? palette.onAccent : palette.onAction,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case AppBadgeVariant.circleAmber:
        return Container(
          width: 24.0,
          height: 24.0,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: AppText.caption.copyWith(
              color: palette.onAccent,
              fontWeight: FontWeight.w700,
              fontSize: 11.0,
            ),
          ),
        );
    }
  }
}
