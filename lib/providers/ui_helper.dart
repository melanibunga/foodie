import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';

/// Helper Toast pill olive kustom sesuai PRD §7.9 (menggunakan OverlayEntry, bukan SnackBar biasa).
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2200),
  double bottomOffset = 120.0,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        left: 24,
        right: 24,
        bottom: bottomOffset,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.olive,
                borderRadius: AppRadius.pill,
                boxShadow: AppShadows.bottomNav,
              ),
              child: Text(
                message,
                style: AppText.buttonMd.copyWith(color: AppColors.white),
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
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.dialogBarrier,
    builder: (context) {
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
        backgroundColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sectionTitle),
              const SizedBox(height: 10),
              Text(
                message,
                style: AppText.body.copyWith(color: AppColors.sage),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.olive,
                      side: const BorderSide(color: AppColors.olive),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      cancelLabel,
                      style: AppText.buttonMd.copyWith(color: AppColors.olive),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDanger
                          ? AppColors.maroon
                          : AppColors.olive,
                      foregroundColor: AppColors.white,
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
  await showDialog<void>(
    context: context,
    barrierColor: AppColors.dialogBarrier,
    builder: (context) {
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardLarge),
        backgroundColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.olive,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppText.subSectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppText.body.copyWith(color: AppColors.sage),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.olive,
                    foregroundColor: AppColors.white,
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
