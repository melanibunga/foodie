import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import '../providers/favorites_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/app_badge.dart';
import '../widgets/ui/app_chip.dart';
import '../widgets/ui/empty_state.dart';

/// Halaman Menu Favoritmu (/favorites) sesuai PRD §6.9, §7.6 dan design/bookmark.jpg:
/// - Tanpa header global dan tanpa bottom nav.
/// - Judul "Menu Favoritmu" (26/700 olive) + badge amber 42x42 berisi jumlah resep di kanan.
/// - Sub: "Simpan idenya, masak kapan saja." (13 sage).
/// - Search putih radius ≈ 14, ikon kaca pembesar, placeholder "Cari nama menu favorit...".
/// - Label "Filter bahan utama" (13/700) + chip: Semua (aktif secara default) + bahan utama dinamis.
/// - Grid 2 kolom FavoriteRecipeCard (aksi trash maroon).
/// - Tombol olive pill "Kembali Ke Beranda" (lebar ≈ 355, tinggi 48, 700) sticky di bawah (bottom ≈ 24).
/// - Dialog konfirmasi hapus favorit sesuai PRD §7.6.
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedIngredient;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRemoveFavorite(Recipe recipe) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Hapus dari favorit?',
      message:
          'Apakah kamu yakin ingin menghapus resep "${recipe.title}" dari menu favoritmu?',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(favoritesProvider.notifier).remove(recipe.id);
      if (mounted) {
        showAppToast(context, 'Resep dihapus dari favorit');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteRecipes = ref.watch(favoriteRecipesProvider);
    final favoriteCount = ref.watch(favoriteCountProvider);

    // Filter dinamis bahan utama dari resep favorit yang ada
    final availableIngredients =
        favoriteRecipes
            .map((r) => r.mainIngredient)
            .where((ing) => ing.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    // Saring resep berdasarkan pencarian & filter bahan utama
    final filteredRecipes = favoriteRecipes.where((r) {
      if (_selectedIngredient != null &&
          r.mainIngredient.toLowerCase() !=
              _selectedIngredient!.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesTitle = r.title.toLowerCase().contains(q);
        final matchesDesc = r.description.toLowerCase().contains(q);
        final matchesCuisine = r.cuisine.toLowerCase().contains(q);
        if (!matchesTitle && !matchesDesc && !matchesCuisine) {
          return false;
        }
      }
      return true;
    }).toList();

    final topInset = AppShell.topChrome(context);
    final bottomInset = math.max(MediaQuery.paddingOf(context).bottom, 24.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Konten Scrollable
          Positioned.fill(
            child: CustomScrollView(
              key: const PageStorageKey<String>('favorites_scroll_view'),
              slivers: [
                // 1. Header Baris Judul & Badge
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      top: topInset + 16.0,
                      bottom: 16.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Menu Favoritmu', style: AppText.pageTitle),
                              const SizedBox(height: 2.0),
                              const Text(
                                'Simpan idenya, masak kapan saja.',
                                style: TextStyle(
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
                        AppBadge.square(count: favoriteCount),
                      ],
                    ),
                  ),
                ),

                // 2. Search Bar Putih Radius ≈ 14
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
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
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: AppColors.textBody,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Cari nama menu favorit...',
                                hintStyle: TextStyle(
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
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
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
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16.0)),

                // 3. Label "Filter bahan utama" & Chip Filter Horizontal
                if (favoriteRecipes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Filter bahan utama',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.olive,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10.0)),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          // Chip Semua
                          AppChip(
                            label: 'Semua',
                            selected: _selectedIngredient == null,
                            onTap: () {
                              setState(() {
                                _selectedIngredient = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8.0),

                          // Chip dinamis dari bahan utama resep favorit
                          ...availableIngredients.map((ingredient) {
                            final isSelected =
                                _selectedIngredient == ingredient;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: AppChip(
                                label: ingredient,
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedIngredient = isSelected
                                        ? null
                                        : ingredient;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
                ],

                // 4. Grid Resep Favorit 2 Kolom atau Empty State
                if (favoriteRecipes.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40.0),
                      child: EmptyState(
                        icon: LucideIcons.bookmark,
                        title: 'Belum Ada Menu Favorit',
                        subtitle: 'Simpan idenya, masak kapan saja dengan menekan ikon hati pada resep.',
                      ),
                    ),
                  )
                else if (filteredRecipes.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: EmptyState(
                        icon: LucideIcons.searchX,
                        title: 'Resep Tidak Ditemukan',
                        subtitle: 'Tidak ada resep favorit yang cocok dengan kata kunci atau filter.',
                        action: TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedIngredient = null;
                            });
                          },
                          child: const Text(
                            'Reset Filter',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: AppColors.maroon,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                            childAspectRatio: 0.68,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final recipe = filteredRecipes[index];
                        return FavoriteRecipeCard(
                          recipe: recipe,
                          onOpen: () => context.push('/recipe/${recipe.id}'),
                          onRemove: () => _handleRemoveFavorite(recipe),
                        );
                      }, childCount: filteredRecipes.length),
                    ),
                  ),

                // 5. Padding Bawah agar konten terakhir tidak tertutup tombol sticky
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomInset + 48.0 + 32.0),
                ),
              ],
            ),
          ),

          // Tombol Sticky "Kembali Ke Beranda" di Bawah Layar (bottom ≈ 24, lebar ≈ 355, tinggi 48, tebal 700)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Center(
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
                  onPressed: () => context.go('/home'),
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
          ),
        ],
      ),
    );
  }
}
