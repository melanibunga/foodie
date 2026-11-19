import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';

enum AppButtonVariant {
  primary,
  accent,
  danger,
  outlineDanger,
  outline,
  soft,
  ghost,
}

enum AppButtonSize {
  lg, // height 52, radius 14
  md, // height 44, radius 12
  sm, // height 36/40, radius 10
}

/// Widget tombol standar Foodie.id sesuai PRD §5.3
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? icon;
  final bool fullWidth;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.fullWidth = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    BorderSide? borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = AppColors.olive;
        textColor = AppColors.white;
        break;
      case AppButtonVariant.accent:
        bgColor = AppColors.amber;
        textColor = AppColors.olive;
        break;
      case AppButtonVariant.danger:
        bgColor = AppColors.maroon;
        textColor = AppColors.white;
        break;
      case AppButtonVariant.outlineDanger:
        bgColor = Colors.transparent;
        textColor = AppColors.maroon;
        borderSide = const BorderSide(color: AppColors.maroon, width: 1.5);
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = AppColors.olive;
        borderSide = const BorderSide(color: AppColors.olive, width: 1.5);
        break;
      case AppButtonVariant.soft:
        bgColor = AppColors.chipGray;
        textColor = AppColors.textBody;
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = AppColors.olive;
        break;
    }

    double height;
    BorderRadius borderRadius;
    TextStyle textStyle;

    switch (size) {
      case AppButtonSize.lg:
        height = 52.0;
        borderRadius = AppRadius.button;
        textStyle = AppText.buttonLg.copyWith(color: textColor);
        break;
      case AppButtonSize.md:
        height = 44.0;
        borderRadius = const BorderRadius.all(Radius.circular(12.0));
        textStyle = AppText.buttonMd.copyWith(color: textColor);
        break;
      case AppButtonSize.sm:
        height = 36.0;
        borderRadius = AppRadius.buttonSmall;
        textStyle = AppText.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        );
        break;
    }

    Widget content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            icon!,
            const SizedBox(width: 6),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: borderSide ?? BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
