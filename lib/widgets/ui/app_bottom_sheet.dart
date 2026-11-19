import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Helper menampilkan Bottom Sheet standar Foodie.id sesuai PRD §5.3, §7.2–§7.4
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool showHandle = true,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    barrierColor: AppColors.dialogBarrier,
    builder: (context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              const SizedBox(height: 12),
              Container(
                width: 40.0,
                height: 4.0,
                decoration: const BoxDecoration(
                  color: AppColors.chipGray,
                  borderRadius: AppRadius.pill,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Flexible(child: builder(context)),
          ],
        ),
      );
    },
  );
}
