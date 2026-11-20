import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';

/// Toggle switch kustom Foodie.id sesuai PRD §5.3 dan §16.
/// Ukuran track 52 × 30 px.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52.0,
        height: 30.0,
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: value ? palette.danger : palette.toggleOff,
          borderRadius: AppRadius.pill,
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24.0,
          height: 24.0,
          decoration: BoxDecoration(
            color: palette.toggleKnob,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
