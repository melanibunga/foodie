import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/utils/week_utils.dart';
import '../models/models.dart';
import '../providers/favorites_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/page_with_header.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/skeleton.dart';

/// Halaman Meal Plan (/meal-plan) sesuai PRD §6.7, §7.6, §16 dan design/meal plan.jpg:
/// - AppHeader global di atas.
/// - Pemilih minggu (tengah): tombol bulat actionBg 35px dengan chevron onAction mengapit "This Week" (22/700 textStrong).
/// - 7 section hari Monday–Sunday: judul hari (18/700 textStrong) kiri + tombol plus bulat accentSoft 28px di kanan.
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
    _currentWeekStart = WeekUtils.getWeekStart(ref.read(clockProvider));
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
    Recipe? recipe,
    String dayName,
  ) async {
    final title = recipe?.title ?? 'menu ini';
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Hapus dari meal plan?',
      message:
          'Apakah kamu yakin ingin menghapus "$title" dari jadwal $dayName?',
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
    final palette = context.palette;

    final weekDays = WeekUtils.getWeekDays(_currentWeekStart);
    final weekLabel = WeekUtils.getWeekLabel(_currentWeekStart);

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      subHeader: Container(
        color: palette.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tombol Chevron Kiri (Bulat actionBg 35px)
            Semantics(
              label: 'Minggu sebelumnya',
              button: true,
              child: GestureDetector(
                onTap: _previousWeek,
                child: Container(
                  width: 35.0,
                  height: 35.0,
                  decoration: BoxDecoration(
                    color: palette.actionBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: 18.0,
                    color: palette.onAction,
                  ),
                ),
              ),
            ),

            // Judul Minggu (22/700 textStrong)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                weekLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
              ),
            ),

            // Tombol Chevron Kanan (Bulat actionBg 35px)
            Semantics(
              label: 'Minggu berikutnya',
              button: true,
              child: GestureDetector(
                onTap: _nextWeek,
                child: Container(
                  width: 35.0,
                  height: 35.0,
                  decoration: BoxDecoration(
                    color: palette.actionBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 18.0,
                    color: palette.onAction,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        key: const PageStorageKey<String>('meal_plan_scroll_view'),
        slivers: [
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
  }) {
    final palette = context.palette;
    final entries = ref.watch(mealPlanByDateProvider(dateKey));
    final now = ref.watch(clockProvider);
    final today = DateTime(now.year, now.month, now.day);
    final isPast = DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
    ).isBefore(today);

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
                // Judul Hari (18/700 textStrong)
                Text(
                  dayName,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),

                // Tombol Plus Bulat 28px (accentSoft, ikon plus onAccentSoft; non-aktif redup bila hari lampau)
                Semantics(
                  container: true,
                  label: isPast
                      ? 'Hari lampau ($dayName)'
                      : 'Tambah menu untuk $dayName',
                  button: !isPast,
                  child: GestureDetector(
                    onTap: isPast
                        ? null
                        : () => context.push('/search?pick=$dateKey'),
                    child: Opacity(
                      opacity: isPast ? 0.35 : 1.0,
                      child: Container(
                        width: 28.0,
                        height: 28.0,
                        decoration: BoxDecoration(
                          color: isPast ? palette.chip : palette.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.plus,
                          size: 16.0,
                          color: isPast
                              ? palette.textSecondary
                              : palette.onAccentSoft,
                        ),
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
            // Hari Kosong -> Kartu Putus-Putus "Belum ada menu" + "+ Tambah menu" (lebar tetap 330 rata kiri)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 330.0,
                  child: _buildEmptyDayCard(
                    context,
                    dateKey,
                    dayName,
                    isPast: isPast,
                  ),
                ),
              ),
            )
          else
            // Carousel Horizontal FeaturedRecipeCard (lebar kartu TETAP 330, rata kiri)
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
                  return _MealPlanCardItem(
                    entry: entry,
                    dayName: dayName,
                    onRemove: (recipe) =>
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
    String dayName, {
    required bool isPast,
  }) {
    final palette = context.palette;
    return GestureDetector(
      onTap: isPast ? null : () => context.push('/search?pick=$dateKey'),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: palette.border,
          strokeWidth: 1.5,
          radius: 16.0,
          dashLength: 6.0,
          gapLength: 4.0,
        ),
        child: Container(
          width: double.infinity,
          height: 110.0,
          decoration: BoxDecoration(
            color: isPast
                ? palette.chip.withValues(alpha: 0.3)
                : palette.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16.0),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Belum ada menu',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
              ),
              if (!isPast) ...[
                const SizedBox(height: 6.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14.0, color: palette.actionBg),
                    const SizedBox(width: 4.0),
                    Text(
                      'Tambah menu',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        color: palette.actionBg,
                      ),
                    ),
                  ],
                ),
              ],
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

/// Widget kartu resep pada Meal Plan dengan pola resolusi 3-tahap (PRD §17):
/// 1. Memori / Cache Persist Hive -> tampil instan tanpa flicker.
/// 2. Loading jaringan -> Skeleton 330x315.
/// 3. Gagal / Tanpa Cache -> Kartu Error 330x315 dengan "Coba lagi" & aksi hapus lewat tekan lama.
class _MealPlanCardItem extends ConsumerWidget {
  final MealPlanEntry entry;
  final String dayName;
  final void Function(Recipe? recipe) onRemove;

  const _MealPlanCardItem({
    required this.entry,
    required this.dayName,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final favorites = ref.watch(favoritesProvider);

    // 1. Cek instan di memori (seed + user recipes) dan cache persist Hive (recipeCache box)
    final syncRecipe = resolveRecipeSync(ref, entry.recipeId);
    if (syncRecipe != null) {
      final isFav = favorites.contains(syncRecipe.id);
      return FeaturedRecipeCard(
        recipe: syncRecipe,
        width: 330.0,
        isFavorite: isFav,
        onToggleFav: () => ref
            .read(favoritesProvider.notifier)
            .toggle(syncRecipe.id, recipe: syncRecipe),
        onOpen: () => context.push('/recipe/${syncRecipe.id}'),
        onLongPress: () => onRemove(syncRecipe),
      );
    }

    // 2. Jika belum ada di memori maupun cache, resolve lewat recipeByIdProvider
    final asyncRecipe = ref.watch(recipeByIdProvider(entry.recipeId));

    return asyncRecipe.when(
      loading: () => SizedBox(
        width: 330.0,
        height: 315.0,
        child: Skeleton(
          width: 330.0,
          height: 315.0,
          borderRadius: AppRadius.cardLarge,
        ),
      ),
      error: (error, stack) => _buildErrorCard(context, ref, palette),
      data: (recipe) {
        if (recipe == null) {
          return _buildErrorCard(context, ref, palette);
        }
        final isFav = favorites.contains(recipe.id);
        return FeaturedRecipeCard(
          recipe: recipe,
          width: 330.0,
          isFavorite: isFav,
          onToggleFav: () => ref
              .read(favoritesProvider.notifier)
              .toggle(recipe.id, recipe: recipe),
          onOpen: () => context.push('/recipe/${recipe.id}'),
          onLongPress: () => onRemove(recipe),
        );
      },
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    WidgetRef ref,
    AppPalette palette,
  ) {
    return Container(
      width: 330.0,
      height: 315.0,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.cardLarge,
        border: Border.all(color: palette.border),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardLarge,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: () => onRemove(null),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.alertCircle, size: 38.0, color: palette.danger),
              const SizedBox(height: 12.0),
              Text(
                'Resep tidak dapat dimuat',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.0,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6.0),
              Text(
                'Periksa koneksi internet atau tekan coba lagi. Tekan lama untuk menghapus menu.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(recipeByIdProvider(entry.recipeId)),
                icon: const Icon(LucideIcons.refreshCw, size: 15.0),
                label: const Text('Coba lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.actionBg,
                  foregroundColor: palette.onAction,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
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
