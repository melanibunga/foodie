import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../app/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import 'app_badge.dart';
import 'sticky_bottom_bar.dart';

/// Struktur layout bersama untuk halaman dengan header fixed non-dashboard
/// (Favorites, Cooked / Riwayat Masak, My Recipes) sesuai PRD §15.3:
/// - Area atas (judul + badge + sub-judul + search bar) berada di LUAR scroll sehingga FIXED.
/// - Background solid `AppColors.bg` agar konten yang bergulir di bawahnya tidak tembus.
/// - Konten di bawahnya (chip filter, grid resep, empty state) ikut scroll di dalam [Expanded].
/// - Tombol sticky "Kembali Ke Beranda" tetap diposisikan di bawah dengan [StickyBottomBar]
///   dan Scaffold(resizeToAvoidBottomInset: false) agar tidak bergerak saat keyboard terbuka.
class FixedHeaderScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final int badgeCount;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onSearchClear;
  final Widget body;
  final VoidCallback? onBackToHome;
  final Color? backgroundColor;

  const FixedHeaderScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    this.onSearchClear,
    required this.body,
    this.onBackToHome,
    this.backgroundColor,
  });

  @override
  State<FixedHeaderScaffold> createState() => _FixedHeaderScaffoldState();
}

class _FixedHeaderScaffoldState extends State<FixedHeaderScaffold> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant FixedHeaderScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onTextChange);
      widget.searchController.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        widget.backgroundColor ??
        (isDark ? AppColors.surfaceDark : AppColors.bg);
    final topInset = AppShell.topChrome(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bg,
      body: Stack(
        children: [
          Column(
            children: [
              // Area Header Fixed (Judul, Sub-judul, Badge, dan Search Bar)
              Container(
                color: bg,
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: topInset + 16.0,
                  bottom: 12.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Baris Judul & Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.title, style: AppText.pageTitle),
                              const SizedBox(height: 2.0),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.sage,
                                  height: 18.0 / 13.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        AppBadge.square(count: widget.badgeCount),
                      ],
                    ),

                    const SizedBox(height: 12.0),

                    // Search Bar Putih Radius ≈ 14
                    Container(
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.search,
                            size: 18.0,
                            color: AppColors.sage,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: TextField(
                              controller: widget.searchController,
                              onChanged: widget.onSearchChanged,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: AppColors.textBody,
                              ),
                              decoration: InputDecoration(
                                hintText: widget.searchHint,
                                hintStyle: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  color: AppColors.sage,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (widget.searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                widget.searchController.clear();
                                widget.onSearchChanged('');
                                widget.onSearchClear?.call();
                              },
                              child: const Icon(
                                LucideIcons.x,
                                size: 16.0,
                                color: AppColors.sage,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Area Konten Scrollable
              Expanded(child: widget.body),
            ],
          ),

          // Tombol Sticky "Kembali Ke Beranda"
          StickyBottomBar(
            child: SizedBox(
              width: 355.0,
              height: 48.0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.olive,
                  foregroundColor: AppColors.white,
                  elevation: 6.0,
                  shadowColor: AppColors.olive.withValues(alpha: 0.35),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pill,
                  ),
                ),
                onPressed: widget.onBackToHome ?? () => context.go('/home'),
                child: const Text(
                  'Kembali Ke Beranda',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
