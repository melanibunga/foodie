import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';

/// Header grup menu belanjaan (PRD §4, §15.7, Fase E1):
/// - Menampilkan nama menu (maks 2 baris, ellipsis, 15/700).
/// - Tombol "Hapus menu" (11/600) di kanan, rata kanan sejajar kolom harga di bawahnya.
/// - Tinggi baris pertama tombol disamakan dengan baris pertama judul sehingga
///   sejajar baris pertama judul (bukan melayang di tengah) untuk judul 1 maupun 2 baris.
/// - Tombol dibuat tanpa padding horizontal tambahan agar rata kanan persis dengan teks harga.
class GroceryGroupHeader extends StatelessWidget {
  final String title;
  final VoidCallback onRemove;
  final Color? titleColor;
  final Color? buttonColor;

  const GroceryGroupHeader({
    super.key,
    required this.title,
    required this.onRemove,
    this.titleColor,
    this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveTitleColor = titleColor ?? palette.textStrong;
    final effectiveButtonColor = buttonColor ?? palette.danger;

    final titleStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 15.0,
      fontWeight: FontWeight.w700,
      color: effectiveTitleColor,
    );

    final buttonStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 11.0,
      fontWeight: FontWeight.w600,
      color: effectiveButtonColor,
    );

    final textScaler = MediaQuery.textScalerOf(context);
    final tp = TextPainter(
      text: TextSpan(text: 'A', style: titleStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final firstLineHeight = tp.height;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        const SizedBox(width: 12.0),
        Semantics(
          label: 'Hapus menu',
          button: true,
          child: InkWell(
            onTap: onRemove,
            child: SizedBox(
              height: firstLineHeight,
              child: Center(child: Text('Hapus menu', style: buttonStyle)),
            ),
          ),
        ),
      ],
    );
  }
}
