import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/theme/app_palette.dart';

double _linearize(double component) {
  final c = component / 255.0;
  if (c <= 0.04045) {
    return c / 12.92;
  }
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = _linearize(color.r * 255.0);
  final g = _linearize(color.g * 255.0);
  final b = _linearize(color.b * 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color foreground, Color background) {
  final l1 = relativeLuminance(foreground);
  final l2 = relativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG 2.1 Contrast Ratio Tests', () {
    test('Light Mode Contrast Ratios', () {
      final p = AppPalette.light;

      // textStrong vs bg >= 4.5:1
      final textStrongVsBg = contrastRatio(p.textStrong, p.bg);
      expect(textStrongVsBg, greaterThanOrEqualTo(4.5));

      // textBody vs surface >= 4.5:1
      final textBodyVsSurface = contrastRatio(p.textBody, p.surface);
      expect(textBodyVsSurface, greaterThanOrEqualTo(4.5));

      // onAction vs actionBg >= 3.0:1 (large text / UI component)
      final onActionVsActionBg = contrastRatio(p.onAction, p.actionBg);
      expect(onActionVsActionBg, greaterThanOrEqualTo(3.0));

      // dangerText vs surface >= 4.5:1
      final dangerTextVsSurface = contrastRatio(p.dangerText, p.surface);
      expect(dangerTextVsSurface, greaterThanOrEqualTo(4.5));
    });

    test('Dark Mode Contrast Ratios', () {
      final p = AppPalette.dark;

      // textStrong vs bg >= 4.5:1
      final textStrongVsBg = contrastRatio(p.textStrong, p.bg);
      expect(textStrongVsBg, greaterThanOrEqualTo(4.5));

      // textBody vs surface >= 4.5:1
      final textBodyVsSurface = contrastRatio(p.textBody, p.surface);
      expect(textBodyVsSurface, greaterThanOrEqualTo(4.5));

      // onAction vs actionBg >= 3.0:1 (UI button / component)
      final onActionVsActionBg = contrastRatio(p.onAction, p.actionBg);
      expect(onActionVsActionBg, greaterThanOrEqualTo(3.0));

      // dangerText vs surface >= 4.5:1
      // PRD/Prompt: #D6455F vs #E8667C. #E8667C is used for dangerText to guarantee >= 4.5:1
      final dangerTextVsSurface = contrastRatio(p.dangerText, p.surface);
      expect(dangerTextVsSurface, greaterThanOrEqualTo(4.5));

      // accentSoftTextAlt vs accentSoft >= 4.5:1 (Groceries pin card detail text)
      final accentSoftTextAltVsAccentSoft = contrastRatio(
        p.accentSoftTextAlt,
        p.accentSoft,
      );
      expect(accentSoftTextAltVsAccentSoft, greaterThanOrEqualTo(4.5));
    });

    test('Laporan Perbandingan danger (#D6455F) vs dangerText (#E8667C)', () {
      final p = AppPalette.dark;
      final d6455fVsSurface = contrastRatio(const Color(0xFFD6455F), p.surface);
      final e8667cVsSurface = contrastRatio(const Color(0xFFE8667C), p.surface);

      // Verify #D6455F is < 4.5:1 against surface, explaining why dangerText #E8667C is needed
      expect(d6455fVsSurface, lessThan(4.5));
      expect(e8667cVsSurface, greaterThanOrEqualTo(4.5));
    });
  });
}
