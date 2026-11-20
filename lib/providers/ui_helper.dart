import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Anchor posisi Toast sesuai PRD §14.5
enum ToastAnchor { auto, bottomNav, stickyButton, bottom }

/// Menghitung jarak bawah toast secara otomatis:
/// - Di halaman ber-nav: bottomGap(context) + 75 + 16
/// - Di halaman ber-tombol-sticky: bottomGap(context) + stickyHeight + 16
/// - Tanpa keduanya: bottomGap(context)
double calculateToastBottomOffset(
  BuildContext context, {
  ToastAnchor anchor = ToastAnchor.auto,
  double? customOffset,
  double stickyHeight = 55.0,
}) {
  if (customOffset != null) return customOffset;

  final gap = bottomGap(context);

  if (anchor == ToastAnchor.bottomNav) {
    return gap + 75.0 + 16.0;
  }
  if (anchor == ToastAnchor.stickyButton) {
    return gap + stickyHeight + 16.0;
  }
  if (anchor == ToastAnchor.bottom) {
    return gap;
  }

  // ToastAnchor.auto: deteksi otomatis berdasarkan route
  try {
    final route = GoRouterState.of(context).matchedLocation;
    // Halaman dengan BottomNav: /home, /search, /add, /meal-plan, /nearby (PRD §15.5)
    if (route.startsWith('/home') ||
        route.startsWith('/search') ||
        route.startsWith('/add') ||
        route.startsWith('/meal-plan') ||
        route.startsWith('/nearby')) {
      return gap + 75.0 + 16.0;
    }
    // Halaman dengan tombol sticky "Kembali Ke Beranda" (Favorites, My Recipes, Cooked: tinggi 52)
    if (route.startsWith('/favorites') ||
        route.startsWith('/my-recipes') ||
        route.startsWith('/cooked')) {
      return gap + 52.0 + 16.0;
    }
    // Halaman Groceries (panel ringkasan: tinggi ≈ 90)
    if (route.startsWith('/groceries')) {
      return gap + 90.0 + 16.0;
    }
    // Detail resep: tombol aksi bawah (tinggi ≈ 55)
    if (route.startsWith('/recipe/')) {
      return gap + 55.0 + 16.0;
    }
  } catch (_) {}

  return gap;
}

/// Helper Toast pill kustom sesuai PRD §7.9, §14.5, §15.1:
/// - Background danger, teks putih 12/600, radius pill, bayangan kartu
/// - Posisi 16 px di atas elemen fixed paling bawah halaman itu
/// - Durasi 2.2 detik (2200 ms)
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2200),
  ToastAnchor anchor = ToastAnchor.auto,
  double? bottomOffset,
  double stickyHeight = 55.0,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final resolvedBottom =
      bottomOffset ??
      calculateToastBottomOffset(
        context,
        anchor: anchor,
        stickyHeight: stickyHeight,
      );

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final palette = context.palette;
      return Positioned(
        left: 24,
        right: 24,
        bottom: resolvedBottom,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: palette.danger,
                borderRadius: AppRadius.pill,
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowColor,
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: palette.onDanger,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Timer(duration, () {
    entry.remove();
  });
}

/// Helper Dialog Konfirmasi (Alert Hapus) sesuai PRD §7.6
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel = 'Batal',
  bool isDanger = true,
}) async {
  final palette = context.palette;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: palette.dialogBarrier,
    builder: (context) {
      final p = context.palette;
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
        backgroundColor: p.surface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.sectionTitle.copyWith(color: p.textStrong),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: AppText.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textStrong,
                      side: BorderSide(color: p.border),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      cancelLabel,
                      style: AppText.buttonMd.copyWith(color: p.textStrong),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDanger ? p.danger : p.actionBg,
                      foregroundColor: isDanger ? p.onDanger : p.onAction,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel, style: AppText.buttonMd),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}

/// Helper Dialog Sukses Simpan Resep sesuai PRD §7.5
Future<void> showAppSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final palette = context.palette;
  await showDialog<void>(
    context: context,
    barrierColor: palette.dialogBarrier,
    builder: (context) {
      final p = context.palette;
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
        backgroundColor: p.surface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: p.onAccentSoft, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppText.subSectionTitle.copyWith(color: p.textStrong),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppText.body.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.actionBg,
                    foregroundColor: p.onAction,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Oke', style: AppText.buttonLg),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
