import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';

/// Komponen list ringkas bersama untuk daftar Ingredients & Cooking Instructions pada form Add
/// sesuai PRD §14.8, §15.5:
/// - Judul kecil "Title (N)" (13/700 olive)
/// - Kartu putih radius 12, border AppColors.border, bayangan AppShadows.card
/// - Menampilkan [initialLimit] item pertama (default: 3)
/// - Bila item > 3: tombol maroon 12/600 "Lihat semua (N)" untuk expand inline, lalu "Sembunyikan"
class ExpandableCardList extends StatefulWidget {
  final String title;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int initialLimit;

  const ExpandableCardList({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.initialLimit = 3,
  });

  @override
  State<ExpandableCardList> createState() => _ExpandableCardListState();
}

class _ExpandableCardListState extends State<ExpandableCardList> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    final isExpandedEffective =
        _isExpanded && widget.itemCount > widget.initialLimit;
    final displayedCount = isExpandedEffective
        ? widget.itemCount
        : (widget.itemCount > widget.initialLimit
              ? widget.initialLimit
              : widget.itemCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12.0),
        Text(
          widget.title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.0,
            fontWeight: FontWeight.w700,
            color: AppColors.olive,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < displayedCount; i++)
                widget.itemBuilder(context, i),
              if (widget.itemCount > widget.initialLimit) ...[
                const SizedBox(height: 4.0),
                const Divider(height: 1.0, color: AppColors.border),
                const SizedBox(height: 8.0),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Text(
                      isExpandedEffective
                          ? 'Sembunyikan'
                          : 'Lihat semua (${widget.itemCount})',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.maroon,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
