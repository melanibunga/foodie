import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../core/utils/week_utils.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/ratings_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/skeleton.dart';
import '../widgets/ui/smart_image.dart';

/// Halaman Detail Menu (/recipe/:id) sesuai PRD §6.10, §15.6, dan konsep dynamic scroll floating header:
/// - Saat di posisi paling atas (unscrolled / t=0): header transparan mengambang di atas foto hero,
///   tombol back di kiri, tombol share dan favorit di kanan mengambang di atas gambar.
/// - Saat di-scroll ke bawah (scrolled / t->1): header bertransisi mulus menjadi bar putih solid (AppColors.white)
///   dengan bayangan halus, tombol back, share, dan favorit tetap fixed di top bar.
class RecipeDetailPage extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailPage({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  late final ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      if (offset != _scrollOffset) {
        setState(() {
          _scrollOffset = offset;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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
    final now = ref.read(clockProvider);
    final today = DateTime(now.year, now.month, now.day);
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
                    final targetDate = DateTime(day.year, day.month, day.day);
                    final isPast = targetDate.isBefore(today);
                    final monthName = WeekUtils.monthNamesShort[day.month - 1];

                    return Consumer(
                      builder: (context, ref, child) {
                        final isPlannedOnThisDay = ref
                            .watch(mealPlanProvider)
                            .any(
                              (e) =>
                                  e.date == dateKey && e.recipeId == recipe.id,
                            );

                        VoidCallback? onTapAction;
                        if (isPast) {
                          onTapAction = null;
                        } else if (isPlannedOnThisDay) {
                          onTapAction = () {
                            showAppToast(
                              context,
                              'Menu sudah ada di meal plan',
                            );
                          };
                        } else {
                          onTapAction = () async {
                            final status = await ref
                                .read(mealPlanProvider.notifier)
                                .add(dateKey, recipe.id);
                            if (!sheetContext.mounted) return;
                            if (status == MealPlanAddResult.added) {
                              Navigator.of(sheetContext).pop();
                              if (!context.mounted) return;
                              showAppToast(
                                context,
                                'Menu berhasil ditambahkan ke Meal Plan',
                              );
                            } else if (status == MealPlanAddResult.pastDate) {
                              showAppToast(
                                context,
                                'Tidak dapat memilih hari lampau',
                              );
                            } else {
                              showAppToast(
                                context,
                                'Menu sudah ada di meal plan',
                              );
                            }
                          };
                        }

                        final cardBg = isPast
                            ? AppColors.chipGray.withValues(alpha: 0.5)
                            : (isPlannedOnThisDay
                                  ? AppColors.chipGray
                                  : (isToday
                                        ? AppColors.amberSoft
                                        : AppColors.white));

                        final cardBorder = isPast
                            ? AppColors.border.withValues(alpha: 0.5)
                            : (isPlannedOnThisDay
                                  ? AppColors.border
                                  : (isToday
                                        ? AppColors.amber
                                        : AppColors.border));

                        final titleColor = isPast
                            ? AppColors.sage.withValues(alpha: 0.5)
                            : (isPlannedOnThisDay
                                  ? AppColors.sage
                                  : AppColors.olive);

                        final subColor = isPast
                            ? AppColors.sage.withValues(alpha: 0.4)
                            : AppColors.sage;

                        Widget trailingIcon;
                        if (isPast) {
                          trailingIcon = const SizedBox(width: 20, height: 20);
                        } else if (isPlannedOnThisDay) {
                          trailingIcon = const Icon(
                            Icons.check_circle,
                            color: AppColors.olive,
                            size: 20,
                          );
                        } else {
                          trailingIcon = const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.olive,
                            size: 20,
                          );
                        }

                        return InkWell(
                          onTap: onTapAction,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dayName,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: titleColor,
                                      ),
                                    ),
                                    Text(
                                      '${day.day} $monthName ${day.year}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                                trailingIcon,
                              ],
                            ),
                          ),
                        );
                      },
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
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(widget.recipeId);
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = topInset + 56.0;
    final double t = (_scrollOffset / 120.0).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: t >= 0.5 ? Brightness.dark : Brightness.light,
        statusBarBrightness: t >= 0.5 ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: recipeAsync.when(
          loading: () => Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: barHeight,
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: barHeight,
                child: Container(
                  padding: EdgeInsets.only(top: topInset),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
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
                            width: 40.0,
                            height: 40.0,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              LucideIcons.arrowLeft,
                              color: AppColors.olive,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
                        ref.invalidate(recipeDetailProvider(widget.recipeId)),
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

            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Foto Hero edge-to-edge di atas (lebar penuh, tinggi ≈ 310, radius bawah ≈ 28)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28.0),
                          bottomRight: Radius.circular(28.0),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 310.0,
                          child: SmartImage(
                            src: recipe.image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Space antara foto hero dan judul menu agar tidak terlalu mepet
                            const SizedBox(height: 24.0),

                            // 2. Baris Judul: Nama resep (22/700 olive) + ikon calendar meal plan
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
                                Consumer(
                                  builder: (context, ref, child) {
                                    final isPlanned = ref.watch(
                                      isRecipePlannedProvider(recipe.id),
                                    );
                                    return Semantics(
                                      label: isPlanned
                                          ? 'Menu terjadwal di Meal Plan'
                                          : 'Tambah ke Meal Plan',
                                      button: true,
                                      child: GestureDetector(
                                        onTap: () => _openMealPlanSheet(
                                          context,
                                          ref,
                                          recipe,
                                        ),
                                        child: Container(
                                          width: 40.0,
                                          height: 40.0,
                                          decoration: BoxDecoration(
                                            color: isPlanned
                                                ? AppColors.amberSoft
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              10.0,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            isPlanned
                                                ? LucideIcons.calendarCheck
                                                : LucideIcons.calendarPlus,
                                            color: AppColors.olive,
                                            size: 22.0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            // Deskripsi resep (G5) jika tersedia
                            if (recipe.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 6.0),
                              _ExpandableDescription(text: recipe.description),
                              const SizedBox(height: 8.0),
                            ] else
                              const SizedBox(height: 6.0),

                            // 3. Rating: Bintang amber + nilai rating + (ulasan) (PRD §14.9)
                            Consumer(
                              builder: (context, ref, _) {
                                final effective = ref.watch(
                                  effectiveRatingProvider(recipe),
                                );
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: AppColors.amber,
                                      size: 18.0,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      effective.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textBody,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '(${effective.reviews} ulasan)',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13.0,
                                        color: AppColors.sage,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 16.0),

                            // 4. Dua Tombol Sejajar: Tambah ke keranjang & Tambah ke favorit
                            Row(
                              children: [
                                // Tombol Tambah ke keranjang (lebar ≈ 213, tinggi 44)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final isInCart = ref
                                        .watch(cartProvider)
                                        .any((g) => g.recipeId == recipe.id);

                                    return Expanded(
                                      flex: 213,
                                      child: SizedBox(
                                        height: 44.0,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isInCart
                                                ? AppColors.amberSoft
                                                : AppColors.amber,
                                            foregroundColor: AppColors.olive,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                          ),
                                          onPressed: () async {
                                            if (isInCart) {
                                              await ref
                                                  .read(cartProvider.notifier)
                                                  .removeByRecipe(recipe.id);
                                              if (!context.mounted) return;
                                              showAppToast(
                                                context,
                                                'Dikeluarkan dari keranjang',
                                              );
                                            } else {
                                              await ref
                                                  .read(cartProvider.notifier)
                                                  .addRecipe(recipe);
                                              if (!context.mounted) return;
                                              showAppToast(
                                                context,
                                                'Bahan ditambahkan ke keranjang',
                                              );
                                            }
                                          },
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isInCart) ...[
                                                  const Icon(
                                                    LucideIcons.check,
                                                    size: 16.0,
                                                    color: AppColors.olive,
                                                  ),
                                                  const SizedBox(width: 6.0),
                                                ],
                                                Text(
                                                  isInCart
                                                      ? 'Sudah di keranjang'
                                                      : 'Tambah ke keranjang',
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 12.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.olive,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
                                          borderRadius: BorderRadius.circular(
                                            12.0,
                                          ),
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
                                  Container(
                                    height: 32,
                                    width: 1,
                                    color: AppColors.border,
                                  ),
                                  // Kolom 2: Kalori
                                  Expanded(
                                    child: _SummaryColumn(
                                      icon: LucideIcons.flame,
                                      label: 'Kalori',
                                      value: '${recipe.kcal} kkal',
                                    ),
                                  ),
                                  Container(
                                    height: 32,
                                    width: 1,
                                    color: AppColors.border,
                                  ),
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
                                children: recipe.ingredients
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final index = entry.key;
                                      final ing = entry.value;
                                      final unitStr =
                                          ing.unit != null &&
                                              ing.unit!.isNotEmpty
                                          ? ' ${ing.unit}'
                                          : '';

                                      return Column(
                                        children: [
                                          if (index > 0)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10.0,
                                              ),
                                              child: Divider(
                                                height: 1,
                                                color: AppColors.border,
                                              ),
                                            ),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 10.0,
                                                height: 10.0,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.olive,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 12.0),
                                              Expanded(
                                                child: Text(
                                                  ing.name,
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 15.0,
                                                    fontWeight: FontWeight.w400,
                                                    color: AppColors.textBody,
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
                                    })
                                    .toList(),
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
                                children: recipe.steps.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final step = entry.value;

                                  return Column(
                                    children: [
                                      if (index > 0)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 14.0,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: AppColors.border,
                                          ),
                                        ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                          vertical: 3.0,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.chipGray,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6.0,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '⏱ ${step.durationMin} menit',
                                                      style: const TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontSize: 11.0,
                                                        color: AppColors.sage,
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                onPressed: () =>
                                    context.push('/recipe/${recipe.id}/cook'),
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
                      ),
                    ],
                  ),
                ),

                // Bar DINAMIS lebar penuh di atas halaman (Floating Scroll Header):
                // - Awal (unscrolled / t=0): background transparan di atas foto hero
                // - Saat scroll ke bawah (t -> 1): background fade in ke putih solid (AppColors.white) + shadow halus
                // - Tombol Back di kiri, Share & Favorit di kanan selalu fixed di top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: barHeight,
                  child: Container(
                    key: const Key('recipe-detail-header-bar'),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: t),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16.0 * t),
                        bottomRight: Radius.circular(16.0 * t),
                      ),
                      boxShadow: t > 0.05
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08 * t),
                                blurRadius: 8.0 * t,
                                offset: Offset(0, 2.0 * t),
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.only(top: topInset),
                    child: SizedBox(
                      height: 56.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Tombol Back di kiri
                            Semantics(
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
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: t > 0.6
                                        ? Colors.transparent
                                        : AppColors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    LucideIcons.arrowLeft,
                                    color: AppColors.olive,
                                    size: 20.0,
                                  ),
                                ),
                              ),
                            ),

                            // Tombol Aksi di kanan: Bagikan resep & Tambah ke favorit
                            Row(
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
                                        color: t > 0.6
                                            ? Colors.transparent
                                            : AppColors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        LucideIcons.share2,
                                        color: AppColors.olive,
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8.0),

                                // Heart / Bookmark button
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
                                        color: t > 0.6
                                            ? Colors.transparent
                                            : AppColors.white.withValues(
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Widget deskripsi yang dapat di-expand/collapse (G5)
class _ExpandableDescription extends StatefulWidget {
  final String text;

  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    const textStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13.0,
      fontWeight: FontWeight.w400,
      color: AppColors.sage,
      height: 20.0 / 13.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: textStyle);
        final tp = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);

        final exceedsMaxLines = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: Text(
                widget.text,
                style: textStyle,
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (exceedsMaxLines) ...[
              const SizedBox(height: 4.0),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(
                  _isExpanded ? 'Tutup' : 'Lihat semua',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.maroon,
                  ),
                ),
              ),
            ],
          ],
        );
      },
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
