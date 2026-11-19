import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import 'ui/photo_overlay.dart';
import 'ui/smart_image.dart';

/// Varian A: FeaturedRecipeCard untuk carousel horizontal Home (Daily Inspiration) & Meal Plan.
/// Lebar ≈ 330, tinggi foto ≈ 175, radius 20, tombol maroon "Lihat Resep →" (122 × 40).
class FeaturedRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleFav;
  final VoidCallback? onLongPress;
  final bool isFavorite;
  final double? width;

  const FeaturedRecipeCard({
    super.key,
    required this.recipe,
    this.onOpen,
    this.onToggleFav,
    this.onLongPress,
    this.isFavorite = false,
    this.width = 330.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.cardLarge,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardLarge,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Foto Atas (tinggi ≈ 175) + Overlays
              SizedBox(
                height: 175.0,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(
                      src: recipe.image,
                      borderRadius: AppRadius.cardLargeTop,
                      fit: BoxFit.cover,
                    ),
                    const PhotoDarkGradient(),
                    // Tombol Hati (Kanan Atas)
                    if (onToggleFav != null)
                      Positioned(
                        top: 12.0,
                        right: 12.0,
                        child: HeartButton(
                          isFavorite: isFavorite,
                          onToggle: onToggleFav!,
                          size: 32.0,
                        ),
                      ),
                    // Chip Waktu (Kiri Bawah)
                    Positioned(
                      left: 12.0,
                      bottom: 12.0,
                      child: TimeChip(timeMin: recipe.timeMin),
                    ),
                  ],
                ),
              ),

              // Konten Bawah (padding 14)
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: AppText.cardHeroTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: AppText.caption.copyWith(color: AppColors.sage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Rating & Ulasan
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.amber,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                recipe.rating.toStringAsFixed(1),
                                style: AppText.caption.copyWith(
                                  color: AppColors.textBody,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '(${recipe.reviews} ulasan)',
                                  style: AppText.captionSmall.copyWith(
                                    color: AppColors.sage,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Tombol "Lihat Resep →" (122 × 40, maroon)
                        GestureDetector(
                          onTap: onOpen,
                          child: Container(
                            width: 122.0,
                            height: 40.0,
                            decoration: const BoxDecoration(
                              color: AppColors.maroon,
                              borderRadius: BorderRadius.all(
                                Radius.circular(10.0),
                              ),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Lihat Resep',
                                    style: TextStyle(
                                      fontFamily: AppText.fontFamily,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 14,
                                    color: AppColors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Varian B: GridRecipeCard untuk grid 2 kolom di Home (Popular) & Search results.
/// Foto kotak (1:1), radius 16, hati kanan atas, rating kiri bawah, ikon plusCircle maroon kanan bawah.
class GridRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleFav;
  final VoidCallback? onQuickAdd;
  final Widget? customAction;
  final bool isFavorite;

  const GridRecipeCard({
    super.key,
    required this.recipe,
    this.onOpen,
    this.onToggleFav,
    this.onQuickAdd,
    this.customAction,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final captionText = '${recipe.category} • ${recipe.cuisine}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Foto kotak (1:1) + Overlay
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
                    // Hati kanan atas
                    if (onToggleFav != null)
                      Positioned(
                        top: 8.0,
                        right: 8.0,
                        child: HeartButton(
                          isFavorite: isFavorite,
                          onToggle: onToggleFav!,
                          size: 28.0,
                        ),
                      ),
                    // Rating kiri bawah
                    Positioned(
                      left: 8.0,
                      bottom: 8.0,
                      child: RatingChip(rating: recipe.rating),
                    ),
                  ],
                ),
              ),

              // Konten bawah
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captionText,
                      style: AppText.captionSmall.copyWith(
                        color: AppColors.sage,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            style: AppText.cardSmallTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (customAction != null) ...[
                          const SizedBox(width: 4),
                          customAction!,
                        ] else if (onQuickAdd != null) ...[
                          const SizedBox(width: 4),
                          Semantics(
                            label: 'Tambah bahan ke keranjang',
                            button: true,
                            child: IconButton(
                              icon: const Icon(
                                LucideIcons.plusCircle,
                                color: AppColors.maroon,
                                size: 20.0,
                              ),
                              tooltip: 'Tambah bahan ke keranjang',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: onQuickAdd,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Varian C: FavoriteRecipeCard untuk halaman Favorites & My Recipes.
/// Sama seperti varian B, namun aksi kanan bawah berupa ikon trash maroon.
class FavoriteRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final bool isFavorite;

  const FavoriteRecipeCard({
    super.key,
    required this.recipe,
    this.onOpen,
    this.onRemove,
    this.isFavorite = true,
  });

  @override
  Widget build(BuildContext context) {
    final captionText = '${recipe.category} • ${recipe.cuisine}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                      left: 8.0,
                      bottom: 8.0,
                      child: RatingChip(rating: recipe.rating),
                    ),
                  ],
                ),
              ),

              // Konten bawah
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captionText,
                      style: AppText.captionSmall.copyWith(
                        color: AppColors.sage,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            style: AppText.cardSmallTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRemove != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.trash2,
                              color: AppColors.maroon,
                              size: 18.0,
                            ),
                            tooltip: 'Hapus resep',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: onRemove,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
