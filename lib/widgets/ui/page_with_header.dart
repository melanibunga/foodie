import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../app_header.dart';

/// Struktur layout bersama untuk halaman dengan header fixed (Home, Search, Add, Meal Plan, Nearby)
/// sesuai PRD §14.3:
/// - AppHeader berada di LUAR area scroll (di atas Expanded), tidak ikut ter-scroll.
/// - Background solid `bg` supaya konten yang bergulir di bawahnya tidak tembus.
/// - Posisi & ukuran header tetap identik dengan desain (PRD §5.1, §12 butir 14).
class PageWithHeader extends StatelessWidget {
  final Widget body;
  final Widget? subHeader;
  final bool resizeToAvoidBottomInset;
  final Color? backgroundColor;

  const PageWithHeader({
    super.key,
    required this.body,
    this.subHeader,
    this.resizeToAvoidBottomInset = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.bg);

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: bg,
      body: Column(
        children: [
          AppHeader(includeTopPadding: true, backgroundColor: bg),
          ?subHeader,
          Expanded(child: body),
        ],
      ),
    );
  }
}
