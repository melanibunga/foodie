import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Placeholder gambar warna abu-abu (#D9D9D4) sesuai PRD §10.
/// Mewarisi ukuran dan radius dari wadahnya.
/// Ikon garpu-sendok (#BDBDB5) di tengah HANYA ditampilkan jika area >= 64 px.
/// Memiliki varian avatar bulat yang menampilkan inisial nama (olive, 600).
class ImagePlaceholder extends StatelessWidget {
  final BorderRadius? borderRadius;
  final bool isCircle;
  final String? initials;
  final double? width;
  final double? height;

  const ImagePlaceholder({
    super.key,
    this.borderRadius,
    this.isCircle = false,
    this.initials,
    this.width,
    this.height,
  });

  /// Factory untuk avatar profil bulat berinisial
  factory ImagePlaceholder.avatar({
    Key? key,
    required String initials,
    double size = 48.0,
  }) {
    return ImagePlaceholder(
      key: key,
      isCircle: true,
      initials: initials,
      width: size,
      height: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content(double w, double h) {
      if (initials != null && initials!.isNotEmpty) {
        final fontSize = (w * 0.4).clamp(12.0, 32.0);
        return Center(
          child: Text(
            initials!.toUpperCase(),
            style: TextStyle(
              fontFamily: AppText.fontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.olive,
            ),
          ),
        );
      }

      // Ikon garpu-sendok hanya muncul jika area >= 64 px
      final minDimension = w < h ? w : h;
      if (minDimension >= 64.0) {
        final iconSize = (minDimension * 0.35).clamp(24.0, 48.0);
        return Center(
          child: Icon(
            Icons.restaurant,
            color: AppColors.photoGrayIcon,
            size: iconSize,
          ),
        );
      }

      return const SizedBox.shrink();
    }

    final decoration = BoxDecoration(
      color: AppColors.photoGray,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : borderRadius,
    );

    if (width != null && height != null) {
      return Container(
        width: width,
        height: height,
        decoration: decoration,
        child: content(width!, height!),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w =
            width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : 64.0);
        final h =
            height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : 64.0);

        return Container(
          width: width,
          height: height,
          decoration: decoration,
          child: content(w, h),
        );
      },
    );
  }
}
