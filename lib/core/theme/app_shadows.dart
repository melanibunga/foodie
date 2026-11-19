import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design tokens untuk bayangan (BoxShadow) sesuai PRD §4.
abstract final class AppShadows {
  /// Bayangan kartu: BoxShadow(color: olive @ 6%, offset (0,2), blur 8)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadowOlive,
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  /// Bayangan bottom nav: BoxShadow(color: black @ 18%, offset (0,8), blur 24)
  static const List<BoxShadow> bottomNav = [
    BoxShadow(color: AppColors.shadowNav, offset: Offset(0, 8), blurRadius: 24),
  ];

  /// Bayangan kolom app shell (saat lebar layar > 440 px di web/tablet)
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
