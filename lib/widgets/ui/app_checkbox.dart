import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

enum AppCheckboxType {
  square, // 22 px, radius 6
  circle, // 28 px, bulat
}

/// Checkbox kustom Foodie.id sesuai PRD §5.3
class AppCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final AppCheckboxType type;

  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.type = AppCheckboxType.square,
  });

  factory AppCheckbox.circle({
    Key? key,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return AppCheckbox(
      key: key,
      value: value,
      onChanged: onChanged,
      type: AppCheckboxType.circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = type == AppCheckboxType.circle;
    final size = isCircle ? 28.0 : 22.0;
    final iconSize = isCircle ? 18.0 : 16.0;

    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: onChanged != null ? () => onChanged!(!value) : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: value ? AppColors.olive : AppColors.white,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : AppRadius.checkbox,
            border: Border.all(
              color: value ? AppColors.olive : AppColors.border,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: value
              ? Icon(Icons.check, size: iconSize, color: AppColors.white)
              : null,
        ),
      ),
    );
  }
}
