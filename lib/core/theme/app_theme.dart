import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text.dart';

/// Tema aplikasi Foodie.id yang terpusat dan konsisten dengan token desain.
abstract final class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.olive,
      onPrimary: AppColors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.olive,
      error: AppColors.maroon,
      onError: AppColors.white,
      surface: AppColors.bg,
      onSurface: AppColors.textBody,
      outline: AppColors.border,
      surfaceContainerHighest: AppColors.chipGray,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashColor: const Color(0x14263C32),
      highlightColor: const Color(0x0A263C32),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.olive,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppText.pageTitle,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        showDragHandle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.oliveDark,
      onPrimary: AppColors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.bgDark,
      error: AppColors.maroonDark,
      onError: AppColors.white,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textBodyDark,
      outline: AppColors.borderDark,
      surfaceContainerHighest: AppColors.chipGrayDark,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashColor: AppColors.shadowOlive,
      highlightColor: AppColors.shadowOlive,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textTitleDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppText.fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textTitleDark,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        showDragHandle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
