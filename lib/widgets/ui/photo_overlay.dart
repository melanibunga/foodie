import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';

/// Gradien gelap di bagian bawah foto agar teks putih terbaca jelas di atas abu-abu (PRD §10 dan §16)
class PhotoDarkGradient extends StatelessWidget {
  const PhotoDarkGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.5, 1.0],
          colors: [
            Colors.transparent,
            Color(0x59000000), // black @ 35%
          ],
        ),
      ),
    );
  }
}

/// Tombol hati favorit di pojok kanan atas kartu resep (PRD §5.4 dan §16)
class HeartButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;

  const HeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bgColor = palette.heartButtonBg;
    final iconColor = isFavorite
        ? palette.danger
        : (palette.isDark ? palette.textStrong : palette.actionBg);

    return Semantics(
      label: isFavorite ? 'Hapus dari favorit' : 'Tambah ke favorit',
      button: true,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: iconColor,
            size: size * 0.56,
          ),
        ),
      ),
    );
  }
}

/// Chip rating bintang amber + angka rating putih di pojok kiri bawah kartu resep (PRD §5.4 B dan §16)
class RatingChip extends StatelessWidget {
  final double rating;

  const RatingChip({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: palette.overlayScrim,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: palette.accent, size: 12),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: AppText.caption.copyWith(
              color: palette.onOverlay,
              fontWeight: FontWeight.w600,
              fontSize: 10.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip waktu masak di pojok kiri bawah foto kartu featured (PRD §5.4 A dan §16)
class TimeChip extends StatelessWidget {
  final int timeMin;

  const TimeChip({super.key, required this.timeMin});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: palette.overlayScrim,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_filled, color: palette.danger, size: 13),
          const SizedBox(width: 4),
          Text(
            '$timeMin Menit',
            style: AppText.caption.copyWith(
              color: palette.onOverlay,
              fontWeight: FontWeight.w700,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }
}
