import 'dart:convert';

import 'package:flutter/material.dart';

import 'image_placeholder.dart';

/// Widget wrapper gambar tunggal aplikasi sesuai PRD §10.
/// SEMUA gambar di app WAJIB melalui widget ini.
/// - Bila [src] kosong / null / gagal dimuat -> me-render [ImagePlaceholder].
/// - Bila [src] berawalan "data:" -> [Image.memory].
/// - Bila [src] berupa URL -> [Image.network] dengan fit: cover dan errorBuilder.
class SmartImage extends StatelessWidget {
  final String? src;
  final String? semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final String? initials;

  const SmartImage({
    super.key,
    required this.src,
    this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isCircle = false,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = ImagePlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
      isCircle: isCircle,
      initials: initials,
    );

    if (src == null || src!.trim().isEmpty) {
      return placeholder;
    }

    Widget imageWidget;
    final trimmedSrc = src!.trim();

    if (trimmedSrc.startsWith('data:')) {
      try {
        final commaIndex = trimmedSrc.indexOf(',');
        final base64Data = commaIndex >= 0
            ? trimmedSrc.substring(commaIndex + 1)
            : trimmedSrc;
        final bytes = base64Decode(base64Data);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          semanticLabel: semanticLabel,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    } else {
      imageWidget = Image.network(
        trimmedSrc,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    if (isCircle) {
      return ClipOval(child: imageWidget);
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }
}
