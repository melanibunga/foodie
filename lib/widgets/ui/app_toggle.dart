import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Toggle switch kustom Foodie.id sesuai PRD §5.3.
/// Ukuran track 52 × 30 px. Aktif = Maroon (#800020), Non-aktif = #E0E0DA.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52.0,
        height: 30.0,
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: value ? AppColors.maroon : AppColors.toggleOff,
          borderRadius: AppRadius.pill,
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24.0,
          height: 24.0,
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowThumb,
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
