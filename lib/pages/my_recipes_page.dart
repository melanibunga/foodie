import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../models/models.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/fixed_header_scaffold.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman Resep Saya (/my-recipes) sesuai PRD §7.8:
/// - Meniru halaman Favorites:
///   - Judul "Resep Saya" (26/700 olive) + badge amber 42x42 berisi jumlah resep buatan pengguna.
///   - Search bar putih "Cari resep buatanmu...".
///   - Grid 2 kolom FavoriteRecipeCard (ikon trash maroon untuk menghapus resep).
///   - Tombol sticky "Kembali Ke Beranda" di bawah.
///   - Empty state: ikon koki + "Belum ada resep. Yuk buat yang pertama!" + tombol amber "Buat Resep" -> /add.
///   - Resep buatan user dapat dibuka di /recipe/:id dan cover data URI tampil via SmartImage.
class MyRecipesPage extends ConsumerStatefulWidget {
  const MyRecipesPage({super.key});

  @override
  ConsumerState<MyRecipesPage> createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends ConsumerState<MyRecipesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteRecipe(Recipe recipe) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Hapus resep?',
      message:
          'Apakah kamu yakin ingin menghapus "${recipe.title}" dari Resep Saya?',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(recipesProvider.notifier).removeCustomRecipe(recipe.id);
      if (mounted) {
        showAppToast(context, 'Resep berhasil dihapus');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRecipes = ref.watch(myRecipesProvider);
    final count = myRecipes.length;

    final filteredRecipes = myRecipes.where((r) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        return r.title.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final scrollBottomPadding =
        StickyBottomBar.scrollPadding(context, barHeight: 48.0, extra: 24.0) +
        MediaQuery.viewInsetsOf(context).bottom;

    return FixedHeaderScaffold(
      title: 'Resep Saya',
      subtitle: 'Koleksi resep buatanmu sendiri.',
      badgeCount: count,
      searchController: _searchController,
      searchHint: 'Cari resep buatanmu...',
      onSearchChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      body: CustomScrollView(
        key: const PageStorageKey<String>('my_recipes_scroll_view'),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8.0)),

          // 1. Grid Resep atau Empty State
          if (myRecipes.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: EmptyState(
                  icon: LucideIcons.chefHat,
                  title: 'Belum Ada Resep',
                  subtitle: 'Belum ada resep. Yuk buat yang pertama!',
                  action: AppButton(
                    label: 'Buat Resep',
                    variant: AppButtonVariant.accent,
                    size: AppButtonSize.md,
                    onPressed: () => context.push('/add'),
                  ),
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
                  subtitle:
                      'Tidak ada resep buatanmu yang cocok dengan kata kunci.',
                  action: TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Text(
                      'Bersihkan Pencarian',
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
                    onRemove: () => _handleDeleteRecipe(recipe),
                  );
                }, childCount: filteredRecipes.length),
              ),
            ),

          // 2. Padding Bawah agar tidak tertutup tombol sticky (+ keyboard)
          SliverToBoxAdapter(child: SizedBox(height: scrollBottomPadding)),
        ],
      ),
    );
  }
}
