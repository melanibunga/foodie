import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Helper jarak bawah sesuai PRD §14.2:
/// `bottomGap(context) = max(24, MediaQuery.viewPadding.bottom + 16)`.
/// Menjamin elemen sticky bawah tidak tertutup gesture bar / 3 tombol navigasi HP.
double bottomGap(BuildContext context) {
  final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
  return math.max(24.0, viewPaddingBottom + 16.0);
}

/// Widget untuk memposisikan tombol/panel sticky di bagian bawah layar secara konsisten.
/// Diposisikan di dalam [Stack] dengan [bottomMargin] = [bottomGap(context)] secara default.
/// Bersama dengan `Scaffold(resizeToAvoidBottomInset: false)`, widget ini TIDAK bergerak
/// saat keyboard muncul di layar.
class StickyBottomBar extends StatelessWidget {
  final Widget child;
  final double? bottomMargin;
  final bool center;

  const StickyBottomBar({
    super.key,
    required this.child,
    this.bottomMargin,
    this.center = true,
  });

  /// Helper menghitung padding bawah untuk scroll view di belakang tombol sticky
  /// agar konten paling bawah tidak tertutup oleh tombol sticky dan tetap terlihat saat keyboard terbuka.
  static double scrollPadding(
    BuildContext context, {
    double barHeight = 48.0,
    double extra = 24.0,
  }) {
    return bottomGap(context) + barHeight + extra;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottom = bottomMargin ?? bottomGap(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: effectiveBottom,
      child: center ? Center(child: child) : child,
    );
  }
}
