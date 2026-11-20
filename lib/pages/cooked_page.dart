import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../core/utils/week_utils.dart';
import '../models/models.dart';
import '../providers/cooked_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/ratings_provider.dart';
import '../providers/recipes_provider.dart';
import '../widgets/fixed_header_scaffold.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/photo_overlay.dart';
import '../widgets/ui/smart_image.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman Riwayat Masak (/cooked) sesuai PRD §14.10:
/// - Tanpa AppHeader global dan tanpa BottomNav.
/// - Judul "Riwayat Masak" (26/700) + badge amber (42x42) jumlah resep unik.
/// - Sub: "Resep yang sudah kamu masak."
/// - Search bar "Cari riwayat masak...".
/// - Grid 2 kolom kartu resep (tanpa trash):
///   - Caption "Dimasak N× · {tanggal terakhir}".
///   - "Rating kamu ★N" bila ada.
/// - Tombol sticky "Kembali Ke Beranda" (aturan B1).
/// - Empty state "Belum ada yang dimasak. Yuk mulai masak!".
class CookedPage extends ConsumerStatefulWidget {
  const CookedPage({super.key});

  @override
  ConsumerState<CookedPage> createState() => _CookedPageState();
}

class _CookedPageState extends ConsumerState<CookedPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatLatestDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final monthName = WeekUtils.monthNamesShort[month - 1];
        return '$day $monthName $year';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(cookedSummaryProvider);
    final uniqueCount = ref.watch(cookedUniqueCountProvider);
    final allRecipes = ref.watch(recipesProvider);
    final favorites = ref.watch(favoritesProvider);
    final ratings = ref.watch(ratingsProvider);

    final recipeMap = {for (final r in allRecipes) r.id: r};

    // Filter berdasarkan pencarian nama resep
    final filteredSummaries = summaries.where((s) {
      final recipe = recipeMap[s.recipeId];
      if (recipe == null) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return recipe.title.toLowerCase().contains(q);
    }).toList();

    final scrollBottomPadding =
        StickyBottomBar.scrollPadding(context, barHeight: 48.0, extra: 24.0) +
        MediaQuery.viewInsetsOf(context).bottom;

    return FixedHeaderScaffold(
      title: 'Riwayat Masak',
      subtitle: 'Resep yang sudah kamu masak.',
      badgeCount: uniqueCount,
      searchController: _searchController,
      searchHint: 'Cari riwayat masak...',
      onSearchChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      body: CustomScrollView(
        key: const PageStorageKey<String>('cooked_scroll_view'),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8.0)),

          // 1. Konten Grid / Empty State
          if (summaries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: LucideIcons.chefHat,
                title: 'Belum ada yang dimasak',
                subtitle: 'Yuk mulai masak resep pertamamu!',
              ),
            )
          else if (filteredSummaries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: LucideIcons.search,
                title: 'Resep tidak ditemukan',
                subtitle: 'Coba kata kunci riwayat lain',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14.0,
                  mainAxisSpacing: 14.0,
                  childAspectRatio: 0.60,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final summary = filteredSummaries[index];
                  final recipe = recipeMap[summary.recipeId];
                  if (recipe == null) return const SizedBox.shrink();

                  final isFav = favorites.contains(recipe.id);
                  final userRating = ratings[recipe.id];
                  final formattedDate = _formatLatestDate(summary.latestDate);

                  return _buildCookedCard(
                    context,
                    recipe: recipe,
                    summary: summary,
                    formattedDate: formattedDate,
                    isFavorite: isFav,
                    userRating: userRating,
                  );
                }, childCount: filteredSummaries.length),
              ),
            ),

          // Padding Bawah agar tidak tertutup sticky bar
          SliverToBoxAdapter(child: SizedBox(height: scrollBottomPadding)),
        ],
      ),
    );
  }

  Widget _buildCookedCard(
    BuildContext context, {
    required Recipe recipe,
    required CookedRecipeSummary summary,
    required String formattedDate,
    required bool isFavorite,
    required int? userRating,
  }) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/recipe/${recipe.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto kotak (1:1)
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(
                      src: recipe.image,
                      borderRadius: AppRadius.cardTop,
                      fit: BoxFit.cover,
                    ),
                    const PhotoDarkGradient(),
                    Positioned(
                      top: 8.0,
                      right: 8.0,
                      child: HeartButton(
                        isFavorite: isFavorite,
                        onToggle: () => ref
                            .read(favoritesProvider.notifier)
                            .toggle(recipe.id),
                        size: 28.0,
                      ),
                    ),
                    Positioned(
                      left: 8.0,
                      bottom: 8.0,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final effective = ref.watch(
                            effectiveRatingProvider(recipe),
                          );
                          return RatingChip(rating: effective.rating);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Konten bawah: Caption Dimasak Nx + Title + Rating Kamu (jika ada)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dimasak ${summary.count}× · $formattedDate',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.0,
                              fontWeight: FontWeight.w500,
                              color: palette.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            recipe.title,
                            style: AppText.cardSmallTitle.copyWith(
                              color: palette.textStrong,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      if (userRating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            'Rating kamu ★$userRating',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: palette.onAccentSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
