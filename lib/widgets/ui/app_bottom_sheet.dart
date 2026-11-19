import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Helper menampilkan Bottom Sheet standar Foodie.id sesuai PRD §5.3, §7.2–§7.4, §14.2
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool showHandle = true,
  bool useRootNavigator = true,
}) async {
  // Sebelum membuka sheet: unfocus field aktif
  FocusManager.instance.primaryFocus?.unfocus(
    disposition: UnfocusDisposition.previouslyFocusedChild,
  );
  FocusScope.of(context)
      .unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

  final result = await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.dialogBarrier,
    elevation: 0,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final mediaQuery = MediaQuery.of(sheetContext);
      final screenHeight = mediaQuery.size.height;
      final topChrome = AppShell.topChrome(sheetContext);
      final viewInsets = mediaQuery.viewInsets.bottom;
      final viewPadding = mediaQuery.viewPadding.bottom;
      final isKeyboardOpen = viewInsets > 0;

      // Tinggi maksimum = tinggi layar − topChrome − viewInsets.bottom
      final maxSheetHeight = math.max(
        0.0,
        screenHeight - topChrome - viewInsets,
      );
      // Padding bawah = viewInsets.bottom bila keyboard terbuka, selain itu viewPadding.bottom + 16
      final bottomPadding = isKeyboardOpen ? viewInsets : (viewPadding + 16.0);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Container(
          key: const Key('app_bottom_sheet_container'),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24.0),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHandle) ...[
                    const SizedBox(height: 12.0),
                    Center(
                      child: Container(
                        width: 40.0,
                        height: 4.0,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.chipGray,
                          borderRadius: AppRadius.pill,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                  builder(sheetContext),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  // Setelah sheet ditutup: unfocus lagi agar kursor tidak melompat ke field sebelumnya
  FocusManager.instance.primaryFocus?.unfocus(
    disposition: UnfocusDisposition.previouslyFocusedChild,
  );
  if (context.mounted) {
    FocusScope.of(context)
        .unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  return result;
}
