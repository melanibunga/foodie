import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../models/models.dart';
import '../providers/favorites_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/fixed_header_scaffold.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/app_chip.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

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
    final palette = context.palette;
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

    final scrollBottomPadding =
        StickyBottomBar.scrollPadding(context, barHeight: 48.0, extra: 24.0) +
        MediaQuery.viewInsetsOf(context).bottom;

    return FixedHeaderScaffold(
      title: 'Menu Favoritmu',
      subtitle: 'Simpan idenya, masak kapan saja.',
      badgeCount: favoriteCount,
      searchController: _searchController,
      searchHint: 'Cari nama menu favorit...',
      onSearchChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      body: CustomScrollView(
        key: const PageStorageKey<String>('favorites_scroll_view'),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8.0)),

          // 1. Label "Filter bahan utama" & Chip Filter Horizontal
          if (favoriteRecipes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Filter bahan utama',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
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
                      final isSelected = _selectedIngredient == ingredient;
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
                  icon: LucideIcons.heart,
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
                    child: Text(
                      'Reset Filter',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: palette.danger,
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

          // 3. Padding Bawah agar konten terakhir tidak tertutup tombol sticky (+ keyboard)
          SliverToBoxAdapter(child: SizedBox(height: scrollBottomPadding)),
        ],
      ),
    );
  }
}
