import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/week_utils.dart';
import '../models/models.dart';
import '../providers/favorites_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/app_header.dart';
import '../widgets/recipe_cards.dart';

/// Halaman Meal Plan (/meal-plan) sesuai PRD §6.7, §7.6 dan design/meal plan.jpg:
/// - AppHeader global di atas.
/// - Pemilih minggu (tengah): tombol bulat olive 35px dengan chevron putih mengapit "This Week" (22/700 olive).
/// - 7 section hari Monday–Sunday: judul hari (18/700 olive) kiri + tombol plus bulat amberSoft 28px di kanan.
/// - Carousel horizontal FeaturedRecipeCard (kartu pertama lebar penuh, kartu berikutnya mengintip).
/// - Hari kosong -> kartu putus-putus "Belum ada menu" + "+ Tambah menu".
/// - Plus -> /search?pick=YYYY-MM-DD.
/// - Tekan lama kartu (onLongPress ≈500ms) -> dialog "Hapus dari meal plan?" -> hapus + toast.
/// - Tap biasa kartu -> /recipe/:id.
/// - AppBottomNav aktif Plan (berada di dalam ShellRoute).
class MealPlanPage extends ConsumerStatefulWidget {
  const MealPlanPage({super.key});

  @override
  ConsumerState<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends ConsumerState<MealPlanPage> {
  late DateTime _currentWeekStart;

  static const List<String> _dayNamesEn = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _currentWeekStart = WeekUtils.getWeekStart(DateTime.now());
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
  }

  Future<void> _confirmRemoveEntry(
    MealPlanEntry entry,
    Recipe recipe,
    String dayName,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Hapus dari meal plan?',
      message:
          'Apakah kamu yakin ingin menghapus "${recipe.title}" dari jadwal $dayName?',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(mealPlanProvider.notifier).remove(entry.id);
      if (mounted) {
        showAppToast(context, 'Menu dihapus dari Meal Plan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRecipes = ref.watch(recipesProvider);
    final favorites = ref.watch(favoritesProvider);
    final recipeMap = {for (final r in allRecipes) r.id: r};

    final weekDays = WeekUtils.getWeekDays(_currentWeekStart);
    final weekLabel = WeekUtils.getWeekLabel(_currentWeekStart);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        key: const PageStorageKey<String>('meal_plan_scroll_view'),
        slivers: [
          // 1. AppHeader global
          const SliverToBoxAdapter(child: AppHeader(includeTopPadding: true)),

          // 2. Pemilih Minggu (Tombol bulat olive 35px + Judul 22/700)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tombol Chevron Kiri (Bulat olive 35px)
                  Semantics(
                    label: 'Minggu sebelumnya',
                    button: true,
                    child: GestureDetector(
                      onTap: _previousWeek,
                      child: Container(
                        width: 35.0,
                        height: 35.0,
                        decoration: const BoxDecoration(
                          color: AppColors.olive,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          LucideIcons.chevronLeft,
                          size: 18.0,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),

                  // Judul Minggu (22/700 olive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      weekLabel,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.olive,
                      ),
                    ),
                  ),

                  // Tombol Chevron Kanan (Bulat olive 35px)
                  Semantics(
                    label: 'Minggu berikutnya',
                    button: true,
                    child: GestureDetector(
                      onTap: _nextWeek,
                      child: Container(
                        width: 35.0,
                        height: 35.0,
                        decoration: const BoxDecoration(
                          color: AppColors.olive,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          LucideIcons.chevronRight,
                          size: 18.0,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8.0)),

          // 3. 7 Section Hari (Monday–Sunday)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final dayDate = weekDays[index];
              final dateKey = WeekUtils.formatDateKey(dayDate);
              final dayName = _dayNamesEn[index];

              return _buildDaySection(
                context,
                dayDate: dayDate,
                dateKey: dateKey,
                dayName: dayName,
                recipeMap: recipeMap,
                favorites: favorites,
              );
            }, childCount: weekDays.length),
          ),

          // 4. Padding Bawah agar konten tidak tertutup floating bottom nav
          const SliverToBoxAdapter(
            child: SizedBox(height: AppShell.bottomNavPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(
    BuildContext context, {
    required DateTime dayDate,
    required String dateKey,
    required String dayName,
    required Map<String, Recipe> recipeMap,
    required List<String> favorites,
  }) {
    final entries = ref.watch(mealPlanByDateProvider(dateKey));

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Judul Hari & Tombol Plus
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Judul Hari (18/700 olive)
                Text(
                  dayName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.olive,
                  ),
                ),

                // Tombol Plus Bulat 28px (amberSoft, ikon plus olive)
                Semantics(
                  label: 'Tambah menu untuk $dayName',
                  button: true,
                  child: GestureDetector(
                    onTap: () => context.push('/search?pick=$dateKey'),
                    child: Container(
                      width: 28.0,
                      height: 28.0,
                      decoration: const BoxDecoration(
                        color: AppColors.amberSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        LucideIcons.plus,
                        size: 16.0,
                        color: AppColors.olive,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12.0),

          // Konten Menu Hari Ini
          if (entries.isEmpty)
            // Hari Kosong -> Kartu Putus-Putus "Belum ada menu" + "+ Tambah menu"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildEmptyDayCard(context, dateKey, dayName),
            )
          else
            // Carousel Horizontal FeaturedRecipeCard
            SizedBox(
              height: 330.0,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 4.0,
                ),
                itemCount: entries.length,
                separatorBuilder: (context, idx) => const SizedBox(width: 14.0),
                itemBuilder: (context, idx) {
                  final entry = entries[idx];
                  final recipe = recipeMap[entry.recipeId];

                  if (recipe == null) {
                    return const SizedBox.shrink();
                  }

                  final isFav = favorites.contains(recipe.id);

                  return FeaturedRecipeCard(
                    recipe: recipe,
                    width: entries.length == 1 ? 392.0 : 330.0,
                    isFavorite: isFav,
                    onToggleFav: () =>
                        ref.read(favoritesProvider.notifier).toggle(recipe.id),
                    onOpen: () => context.push('/recipe/${recipe.id}'),
                    onLongPress: () =>
                        _confirmRemoveEntry(entry, recipe, dayName),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayCard(
    BuildContext context,
    String dateKey,
    String dayName,
  ) {
    return GestureDetector(
      onTap: () => context.push('/search?pick=$dateKey'),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.border,
          strokeWidth: 1.5,
          radius: 16.0,
          dashLength: 6.0,
          gapLength: 4.0,
        ),
        child: Container(
          width: double.infinity,
          height: 110.0,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16.0),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Belum ada menu',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sage,
                ),
              ),
              const SizedBox(height: 6.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.plus, size: 14.0, color: AppColors.olive),
                  SizedBox(width: 4.0),
                  Text(
                    'Tambah menu',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.olive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter untuk menggambar garis putus-putus pada kartu hari kosong
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 16.0,
    this.dashLength = 6.0,
    this.gapLength = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashLength, metric.length - distance);
        dashPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashLength + gapLength;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
