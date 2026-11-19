import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../core/utils/week_utils.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_checkbox.dart';
import '../widgets/ui/skeleton.dart';
import '../widgets/ui/smart_image.dart';

/// Halaman Detail Menu (/recipe/:id) sesuai PRD §6.10 dan design/detail_menu.jpg.
class RecipeDetailPage extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailPage({super.key, required this.recipeId});

  Future<void> _shareRecipe(BuildContext context, Recipe recipe) async {
    final shareText =
        'Lihat resep ${recipe.title} di Foodie.id! https://foodie.id/recipe/${recipe.id}';
    try {
      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (context.mounted) {
        showAppToast(context, 'Tautan resep disalin ke clipboard');
      }
    }
  }

  void _openMealPlanSheet(BuildContext context, WidgetRef ref, Recipe recipe) {
    final now = DateTime.now();
    final currentMonday = WeekUtils.getWeekStart(now);
    final thisWeekDays = WeekUtils.getWeekDays(currentMonday);
    final nextWeekMonday = currentMonday.add(const Duration(days: 7));
    final nextWeekDays = WeekUtils.getWeekDays(nextWeekMonday);
    final allDays = [...thisWeekDays, ...nextWeekDays];

    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tambah ke Meal Plan',
                      style: AppText.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih hari untuk memasak resep ini',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.sage,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allDays.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final day = allDays[index];
                    final dateKey = WeekUtils.formatDateKey(day);
                    final dayName = WeekUtils.dayNames[day.weekday - 1];
                    final isToday =
                        day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;
                    final monthName = WeekUtils.monthNamesShort[day.month - 1];

                    return InkWell(
                      onTap: () async {
                        await ref
                            .read(mealPlanProvider.notifier)
                            .add(dateKey, recipe.id);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        if (!context.mounted) return;
                        showAppToast(
                          context,
                          'Menu berhasil ditambahkan ke Meal Plan',
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.amberSoft
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isToday ? AppColors.amber : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dayName,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.olive,
                                  ),
                                ),
                                Text(
                                  '${day.day} $monthName ${day.year}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.sage,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.olive,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeDetailProvider(recipeId));
    final favorites = ref.watch(favoritesProvider);
    final checkedIngredients = ref.watch(
      recipeCheckedIngredientsProvider(recipeId),
    );
    final isFavorite = favorites.contains(recipeId);
    final topPadding = AppShell.topChrome(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: recipeAsync.when(
        loading: () => SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding,
            left: 25,
            right: 25,
            bottom: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(
                width: double.infinity,
                height: 270,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              SizedBox(height: 20),
              Skeleton(width: 240, height: 28),
              SizedBox(height: 12),
              Skeleton(width: 140, height: 20),
              SizedBox(height: 16),
              Skeleton(width: double.infinity, height: 44),
              SizedBox(height: 16),
              Skeleton(width: double.infinity, height: 75),
              SizedBox(height: 20),
              Skeleton(
                width: double.infinity,
                height: 200,
                borderRadius: BorderRadius.all(Radius.circular(32)),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.maroon,
                ),
                const SizedBox(height: 16),
                const Text('Gagal memuat resep', style: AppText.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.sage),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Coba lagi',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.md,
                  onPressed: () =>
                      ref.invalidate(recipeDetailProvider(recipeId)),
                ),
              ],
            ),
          ),
        ),
        data: (recipe) {
          if (recipe == null) {
            // Halaman 404 ramah bila id resep tidak ditemukan
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.chefHat,
                      size: 56,
                      color: AppColors.sage,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Resep Tidak Ditemukan',
                      style: AppText.sectionTitle,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Resep yang kamu cari mungkin telah dihapus atau tidak tersedia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.sage,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Kembali ke Beranda',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.md,
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              top: topPadding + 8.0,
              left: 25.0,
              right: 25.0,
              bottom: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Foto Hero (lebar 390, tinggi ≈ 270, radius ≈ 28) dengan tombol back, share, heart
                SizedBox(
                  width: double.infinity,
                  height: 270.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SmartImage(
                        src: recipe.image,
                        borderRadius: BorderRadius.circular(28.0),
                        fit: BoxFit.cover,
                      ),

                      // Tombol Back lingkaran olive 44 (panah putih) di kiri atas
                      Positioned(
                        top: 14.0,
                        left: 14.0,
                        child: Semantics(
                          label: 'Kembali',
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                            child: Container(
                              width: 44.0,
                              height: 44.0,
                              decoration: const BoxDecoration(
                                color: AppColors.olive,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                LucideIcons.arrowLeft,
                                color: AppColors.white,
                                size: 20.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Dua tombol putih semi-transparan (share + heart) di kanan atas
                      Positioned(
                        top: 14.0,
                        right: 14.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Share button
                            Semantics(
                              label: 'Bagikan resep',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _shareRecipe(context, recipe),
                                child: Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(
                                      alpha: 0.85,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    LucideIcons.share2,
                                    color: AppColors.olive,
                                    size: 18.0,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8.0),

                            // Heart button
                            Semantics(
                              label: isFavorite
                                  ? 'Hapus dari favorit'
                                  : 'Tambah ke favorit',
                              button: true,
                              child: GestureDetector(
                                onTap: () => ref
                                    .read(favoritesProvider.notifier)
                                    .toggle(recipe.id),
                                child: Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(
                                      alpha: 0.85,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFavorite
                                        ? AppColors.maroon
                                        : AppColors.olive,
                                    size: 20.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18.0),

                // 2. Baris Judul: Nama resep (22/700 olive) + ikon calendar-plus
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.olive,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Semantics(
                      label: 'Tambah ke Meal Plan',
                      button: true,
                      child: GestureDetector(
                        onTap: () => _openMealPlanSheet(context, ref, recipe),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          child: const Icon(
                            LucideIcons.calendarPlus,
                            color: AppColors.olive,
                            size: 24.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6.0),

                // 3. Rating: Bintang amber + nilai rating + (ulasan)
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.amber, size: 18.0),
                    const SizedBox(width: 4.0),
                    Text(
                      recipe.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '(${recipe.reviews} ulasan)',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.0,
                        color: AppColors.sage,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16.0),

                // 4. Dua Tombol Sejajar: Tambah ke keranjang & Tambah ke favorit
                Row(
                  children: [
                    // Tombol Tambah ke keranjang (amber, lebar ≈ 213, tinggi 44)
                    Expanded(
                      flex: 213,
                      child: SizedBox(
                        height: 44.0,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: AppColors.olive,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                            ),
                          ),
                          onPressed: () async {
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
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Tambah ke keranjang',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.olive,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14.0),

                    // Tombol Tambah ke favorit (olive, lebar ≈ 163, tinggi 44)
                    Expanded(
                      flex: 163,
                      child: SizedBox(
                        height: 44.0,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.olive,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                            ),
                          ),
                          onPressed: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(recipe.id),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isFavorite
                                  ? 'Tersimpan di favorit'
                                  : 'Tambah ke favorit',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20.0),

                // 5. Kartu Ringkasan (bg summaryBg, 3 kolom)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.summaryBg,
                    borderRadius: BorderRadius.circular(14.0),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: 8.0,
                  ),
                  child: Row(
                    children: [
                      // Kolom 1: Porsi
                      Expanded(
                        child: _SummaryColumn(
                          icon: LucideIcons.utensilsCrossed,
                          label: 'Porsi',
                          value: '${recipe.servings} Orang',
                        ),
                      ),
                      Container(height: 32, width: 1, color: AppColors.border),
                      // Kolom 2: Kalori
                      Expanded(
                        child: _SummaryColumn(
                          icon: LucideIcons.flame,
                          label: 'Kalori',
                          value: '${recipe.kcal} kkal',
                        ),
                      ),
                      Container(height: 32, width: 1, color: AppColors.border),
                      // Kolom 3: Tingkat
                      Expanded(
                        child: _SummaryColumn(
                          icon: LucideIcons.gauge,
                          label: 'Tingkat',
                          value: recipe.difficulty.label,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24.0),

                // 6. Judul "Bahan-Bahan" + Kartu Putih Besar (radius 32)
                const Text(
                  'Bahan-Bahan',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.olive,
                  ),
                ),

                const SizedBox(height: 12.0),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(32.0),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: recipe.ingredients.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ing = entry.value;
                      final isChecked = checkedIngredients.contains(ing.id);
                      final unitStr = ing.unit != null && ing.unit!.isNotEmpty
                          ? ' ${ing.unit}'
                          : '';

                      return Column(
                        children: [
                          if (index > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AppCheckbox.circle(
                                value: isChecked,
                                onChanged: (_) => ref
                                    .read(checkedIngredientsProvider.notifier)
                                    .toggle(recipe.id, ing.id),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  ing.name,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w400,
                                    color: isChecked
                                        ? AppColors.maroon
                                        : AppColors.textBody,
                                    decoration: isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppColors.maroon,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                '${ing.qty}$unitStr',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textBody,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24.0),

                // 7. Baris Judul "Langkah Memasak" + Kartu Putih Besar (radius 32)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Langkah Memasak',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.olive,
                      ),
                    ),
                    Text(
                      '${recipe.timeMin} menit',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                        color: AppColors.sage,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12.0),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(32.0),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: recipe.steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;

                      return Column(
                        children: [
                          if (index > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14.0),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28.0,
                                height: 28.0,
                                decoration: const BoxDecoration(
                                  color: AppColors.amber,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.olive,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.olive,
                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      step.description,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.sage,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (step.durationMin != null &&
                                        step.durationMin! > 0) ...[
                                      const SizedBox(height: 6.0),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 3.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.chipGray,
                                          borderRadius: BorderRadius.circular(
                                            6.0,
                                          ),
                                        ),
                                        child: Text(
                                          '⏱ ${step.durationMin} menit',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11.0,
                                            color: AppColors.sage,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 28.0),

                // 8. Tombol olive pill "Start Cooking >" (lebar 390, tinggi 52)
                SizedBox(
                  width: double.infinity,
                  height: 52.0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.olive,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                    onPressed: () => context.push('/recipe/${recipe.id}/cook'),
                    child: const Text(
                      'Start Cooking >',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14.0),

                // 9. Catatan kecil di bawah
                const Center(
                  child: Text(
                    'Kalori merupakan estimasi per porsi, tanpa nasi.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      color: AppColors.sage,
                    ),
                  ),
                ),

                const SizedBox(height: 32.0),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22.0, color: AppColors.maroon),
          const SizedBox(width: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.0,
                  color: AppColors.sage,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
