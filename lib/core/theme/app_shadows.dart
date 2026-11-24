import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadowOlive,
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> bottomNav = [
    BoxShadow(color: AppColors.shadowNav, offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> shellColumn = [
    BoxShadow(
      color: AppColors.shadowShell,
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];

  /// Bayangan tombol CTA (Splash / Primary accent)
  static const List<BoxShadow> cta = [
    BoxShadow(
      color: AppColors.shadowAmber,
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// Bayangan kartu ringkasan detail menu / summary
  static const List<BoxShadow> summary = [
    BoxShadow(color: Color(0x0A263C32), offset: Offset(0, 2), blurRadius: 6),
  ];
}
