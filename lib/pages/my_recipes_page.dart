import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/app_badge.dart';
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

    final topInset = AppShell.topChrome(context);
    final scrollBottomPadding =
        StickyBottomBar.scrollPadding(context, barHeight: 48.0, extra: 24.0) +
        MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Konten Scrollable
          Positioned.fill(
            child: CustomScrollView(
              key: const PageStorageKey<String>('my_recipes_scroll_view'),
              slivers: [
                // 1. Header: Judul "Resep Saya" & Badge Amber
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
                              Text('Resep Saya', style: AppText.pageTitle),
                              const SizedBox(height: 2.0),
                              const Text(
                                'Koleksi resep buatanmu sendiri.',
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
                        AppBadge.square(count: count),
                      ],
                    ),
                  ),
                ),

                // 2. Search Bar Putih
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
                                hintText: 'Cari resep buatanmu...',
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

                const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                // 3. Grid Resep atau Empty State
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
                        subtitle: 'Tidak ada resep buatanmu yang cocok dengan kata kunci.',
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
                          onRemove: () => _handleDeleteRecipe(recipe),
                        );
                      }, childCount: filteredRecipes.length),
                    ),
                  ),

                // 4. Padding Bawah agar tidak tertutup tombol sticky (+ keyboard)
                SliverToBoxAdapter(
                  child: SizedBox(height: scrollBottomPadding),
                ),
              ],
            ),
          ),

          // Tombol Sticky "Kembali Ke Beranda" di Bawah Layar
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
        ],
      ),
    );
  }
}
