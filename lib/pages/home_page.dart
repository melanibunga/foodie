import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/page_with_header.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/skeleton.dart';

/// Halaman Beranda (Home) Foodie.id sesuai PRD §5.4, §6.4 dan design/home.jpg.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final inspirationAsync = ref.watch(inspirationRecipesProvider);
    final popularAsync = ref.watch(popularRecipesProvider);
    final favorites = ref.watch(favoritesProvider);

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        key: const PageStorageKey<String>('home_scroll_view'),
        slivers: [
          // 1. Judul Section: Daily Inspiration
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 8.0,
                bottom: 12.0,
              ),
              child: Text('Daily Inspiration', style: AppText.sectionTitle),
            ),
          ),

          // 3. Carousel Horizontal FeaturedRecipeCard
          SliverToBoxAdapter(
            child: inspirationAsync.when(
              loading: () => SizedBox(
                height: 315.0,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 4.0,
                  ),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16.0),
                  itemBuilder: (context, index) => const Skeleton(
                    width: 330.0,
                    height: 298.0,
                    borderRadius: AppRadius.cardLarge,
                  ),
                ),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagal memuat Daily Inspiration',
                      style: AppText.caption.copyWith(color: palette.danger),
                    ),
                    const SizedBox(height: 8.0),
                    AppButton(
                      label: 'Coba lagi',
                      variant: AppButtonVariant.soft,
                      size: AppButtonSize.sm,
                      onPressed: () =>
                          ref.invalidate(inspirationRecipesProvider),
                    ),
                  ],
                ),
              ),
              data: (recipes) {
                if (recipes.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  height: 330.0,
                  child: PageView.builder(
                    clipBehavior: Clip.none,
                    padEnds: false,
                    controller: PageController(viewportFraction: 0.82),
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final isFav = favorites.contains(recipe.id);

                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 24.0 : 8.0,
                          right: index == recipes.length - 1 ? 24.0 : 8.0,
                          top: 4.0,
                          bottom: 12.0,
                        ),
                        child: FeaturedRecipeCard(
                          recipe: recipe,
                          width: double.infinity,
                          isFavorite: isFav,
                          onOpen: () => context.push('/recipe/${recipe.id}'),
                          onToggleFav: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(recipe.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // 4. Judul Section: Popular dengan ikon trending-up maroon
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: 14.0,
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.trendingUp,
                    color: palette.danger,
                    size: 22.0,
                  ),
                  const SizedBox(width: 8.0),
                  const Text('Popular', style: AppText.sectionTitle),
                ],
              ),
            ),
          ),

          // 5. Grid 2 kolom GridRecipeCard
          ...popularAsync.when(
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        const Skeleton(borderRadius: AppRadius.card),
                    childCount: 4,
                  ),
                ),
              ),
            ],
            error: (err, stack) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Gagal memuat resep populer',
                        style: AppText.caption.copyWith(color: palette.danger),
                      ),
                      const SizedBox(height: 8.0),
                      AppButton(
                        label: 'Coba lagi',
                        variant: AppButtonVariant.soft,
                        size: AppButtonSize.sm,
                        onPressed: () => ref.invalidate(popularRecipesProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            data: (recipes) => [
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
                    final recipe = recipes[index];
                    final isFav = favorites.contains(recipe.id);

                    return GridRecipeCard(
                      recipe: recipe,
                      isFavorite: isFav,
                      onOpen: () => context.push('/recipe/${recipe.id}'),
                      onToggleFav: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(recipe.id),
                      onQuickAdd: () async {
                        final status = await ref
                            .read(cartProvider.notifier)
                            .addRecipe(recipe);
                        if (!context.mounted) return;

                        if (status == AddRecipeStatus.added) {
                          showAppToast(
                            context,
                            'Bahan ditambahkan ke keranjang',
                          );
                        } else {
                          showAppToast(context, 'Sudah ada di keranjang');
                        }
                      },
                    );
                  }, childCount: recipes.length),
                ),
              ),
            ],
          ),

          // 6. Padding Bawah agar konten tidak tertutup floating bottom nav
          const SliverToBoxAdapter(
            child: SizedBox(height: AppShell.bottomNavPadding),
          ),
        ],
      ),
    );
  }
}
