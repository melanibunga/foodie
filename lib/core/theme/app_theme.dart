import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_radius.dart';
import 'app_text.dart';

/// Tema aplikasi Foodie.id yang terpusat dan konsisten dengan token palet semantik.
abstract final class AppTheme {
  static ThemeData get lightTheme {
    const palette = AppPalette.light;

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: palette.actionBg,
      onPrimary: palette.onAction,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.danger,
      onError: palette.onDanger,
      surface: palette.surface,
      onSurface: palette.textBody,
      outline: palette.border,
      surfaceContainerHighest: palette.chip,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: palette.bg,
      colorScheme: colorScheme,
      extensions: const [palette],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashColor: palette.shadowColor,
      highlightColor: palette.shadowColor,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppText.pageTitle.copyWith(color: palette.textStrong),
      ),
      cardTheme: CardThemeData(
        color: Color.fromARGB(255, 131, 23, 23),
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Color.fromARGB(255, 145, 20, 20),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        showDragHandle: false,
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    const palette = AppPalette.dark;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: palette.actionBg,
      onPrimary: palette.onAction,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.danger,
      onError: palette.onDanger,
      surface: palette.surface,
      onSurface: palette.textBody,
      outline: palette.border,
      surfaceContainerHighest: palette.chip,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: palette.bg,
      colorScheme: colorScheme,
      extensions: const [palette],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashColor: palette.shadowColor,
      highlightColor: palette.shadowColor,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppText.fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: palette.textStrong,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        showDragHandle: false,
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
