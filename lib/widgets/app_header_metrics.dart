import 'package:flutter/widgets.dart';

/// Helper bersama untuk metrik header bar aplikasi Foodie.id (PRD §17, Fase G3).
/// Menjamin tinggi area header utama (AppHeader: avatar + pill favorit + keranjang)
/// dan bar atas fixed Detail Menu selalu identik secara presisi.
class AppHeaderMetrics {
  /// Tinggi baris konten utama (avatar 48px pada AppHeader)
  static const double contentHeight = 48.0;

  /// Ukuran tombol back lingkaran olive pada Detail Menu (PRD §15.6)
  static const double backButtonSize = 44.0;

  /// Padding bawah area header bar
  static const double bottomPadding = 12.0;

  /// Jarak vertikal dari atas layar ke baris konten (avatar / tombol back)
  static double rowTop(BuildContext context, {bool includeTopPadding = true}) {
    if (!includeTopPadding) return 0.0;
    final topInset = MediaQuery.paddingOf(context).top;
    return topInset > 0 ? (topInset + 16.0) : 45.0;
  }

  /// Total tinggi tetap area header bar
  static double fixedHeight(
    BuildContext context, {
    bool includeTopPadding = true,
  }) {
    return rowTop(context, includeTopPadding: includeTopPadding) +
        contentHeight +
        bottomPadding;
  }
}
