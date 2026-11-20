import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../core/utils/debouncer.dart';
import '../core/utils/week_utils.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/ui_helper.dart';
import '../services/recipe_service.dart';
import '../widgets/page_with_header.dart';
import '../widgets/recipe_cards.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_chip.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/skeleton.dart';
import '../widgets/ui/smart_image.dart';

class MealCategoryItem {
  final String name;
  final MealType meal;
  final String? image;

  const MealCategoryItem({required this.name, required this.meal, this.image});
}

/// Halaman Pencarian & Filter Resep sesuai PRD §6.5 & §7.2, §16 dan design/search.jpg.
class SearchPage extends ConsumerStatefulWidget {
  final String? pickDate;

  const SearchPage({super.key, this.pickDate});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 250));

  bool _isLoading = false;
  List<Recipe>? _searchResults;

  MealType? _selectedMeal;
  Difficulty? _selectedDifficulty;
  String? _selectedTimeRange; // '< 15', '15-30', '> 30'
  String? _selectedMainIngredient;

  static const List<MealCategoryItem> _categories = [
    MealCategoryItem(name: 'Breakfast', meal: MealType.breakfast),
    MealCategoryItem(name: 'Lunch', meal: MealType.lunch),
    MealCategoryItem(name: 'Dinner', meal: MealType.dinner),
    MealCategoryItem(name: 'Snack', meal: MealType.snack),
    MealCategoryItem(name: 'Dessert', meal: MealType.dessert),
    MealCategoryItem(name: 'Drinks', meal: MealType.drinks),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPastPickDate();
    });
  }

  void _checkPastPickDate() {
    if (!mounted || widget.pickDate == null) return;
    final now = ref.read(clockProvider);
    final todayKey = WeekUtils.formatDateKey(
      DateTime(now.year, now.month, now.day),
    );
    if (widget.pickDate!.compareTo(todayKey) < 0) {
      showAppToast(context, 'Tidak dapat memilih tanggal yang sudah lewat');
      context.go('/meal-plan');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _selectedDifficulty != null ||
      _selectedTimeRange != null ||
      _selectedMainIngredient != null;

  bool get _isSearching =>
      _searchController.text.trim().isNotEmpty ||
      _selectedMeal != null ||
      _hasActiveFilters;

  Future<void> _executeSearch() async {
    if (!_isSearching) {
      setState(() {
        _isLoading = false;
        _searchResults = null;
      });
      return;
    }

    setState(() => _isLoading = true);

    int? minTime;
    int? maxTime;
    if (_selectedTimeRange == '< 15') {
      maxTime = 15;
    } else if (_selectedTimeRange == '15-30') {
      minTime = 15;
      maxTime = 30;
    } else if (_selectedTimeRange == '> 30') {
      minTime = 31;
    }

    final query = _searchController.text.trim();
    final results = await ref
        .read(recipeServiceProvider)
        .list(
          q: query.isEmpty ? null : query,
          meal: _selectedMeal,
          difficulty: _selectedDifficulty,
          mainIngredient: _selectedMainIngredient,
          minTimeMin: minTime,
          maxTimeMin: maxTime,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _searchResults = results;
    });
  }

  void _onSearchChanged(String value) {
    _debouncer.run(() {
      _executeSearch();
    });
  }

  void _selectCategory(MealCategoryItem category) {
    setState(() {
      if (_selectedMeal == category.meal) {
        _selectedMeal = null;
      } else {
        _selectedMeal = category.meal;
      }
    });
    _executeSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedMeal = null;
      _selectedDifficulty = null;
      _selectedTimeRange = null;
      _selectedMainIngredient = null;
      _searchResults = null;
      _isLoading = false;
    });
  }

  Future<void> _openFilterSheet() async {
    Difficulty? tempDifficulty = _selectedDifficulty;
    String? tempTimeRange = _selectedTimeRange;
    String? tempMainIngredient = _selectedMainIngredient;

    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showHandle: true,
      builder: (sheetContext) {
        final sheetPalette = sheetContext.palette;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Filter & Reset
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter',
                          style: AppText.sectionTitle.copyWith(
                            color: sheetPalette.textStrong,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempDifficulty = null;
                            tempTimeRange = null;
                            tempMainIngredient = null;
                          });
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: sheetPalette.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section: Tingkat Kesulitan
                  Text(
                    'Tingkat kesulitan',
                    style: AppText.formLabel.copyWith(
                      color: sheetPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      AppChip(
                        label: 'Mudah',
                        selected: tempDifficulty == Difficulty.mudah,
                        onTap: () {
                          setSheetState(() {
                            tempDifficulty = tempDifficulty == Difficulty.mudah
                                ? null
                                : Difficulty.mudah;
                          });
                        },
                      ),
                      AppChip(
                        label: 'Sedang',
                        selected: tempDifficulty == Difficulty.sedang,
                        onTap: () {
                          setSheetState(() {
                            tempDifficulty = tempDifficulty == Difficulty.sedang
                                ? null
                                : Difficulty.sedang;
                          });
                        },
                      ),
                      AppChip(
                        label: 'Sulit',
                        selected: tempDifficulty == Difficulty.sulit,
                        onTap: () {
                          setSheetState(() {
                            tempDifficulty = tempDifficulty == Difficulty.sulit
                                ? null
                                : Difficulty.sulit;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section: Waktu Masak
                  Text(
                    'Waktu masak',
                    style: AppText.formLabel.copyWith(
                      color: sheetPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      AppChip(
                        label: '< 15 menit',
                        selected: tempTimeRange == '< 15',
                        onTap: () {
                          setSheetState(() {
                            tempTimeRange = tempTimeRange == '< 15'
                                ? null
                                : '< 15';
                          });
                        },
                      ),
                      AppChip(
                        label: '15–30 menit',
                        selected: tempTimeRange == '15-30',
                        onTap: () {
                          setSheetState(() {
                            tempTimeRange = tempTimeRange == '15-30'
                                ? null
                                : '15-30';
                          });
                        },
                      ),
                      AppChip(
                        label: '> 30 menit',
                        selected: tempTimeRange == '> 30',
                        onTap: () {
                          setSheetState(() {
                            tempTimeRange = tempTimeRange == '> 30'
                                ? null
                                : '> 30';
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section: Bahan Utama
                  Text(
                    'Bahan utama',
                    style: AppText.formLabel.copyWith(
                      color: sheetPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children:
                        [
                          'Ayam',
                          'Telur',
                          'Sapi',
                          'Ikan',
                          'Sayur',
                          'Kangkung',
                        ].map((ing) {
                          final isSelected = tempMainIngredient == ing;
                          return AppChip(
                            label: ing,
                            selected: isSelected,
                            onTap: () {
                              setSheetState(() {
                                tempMainIngredient = isSelected ? null : ing;
                              });
                            },
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Tombol Terapkan
                  AppButton(
                    label: 'Terapkan',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () {
                      setState(() {
                        _selectedDifficulty = tempDifficulty;
                        _selectedTimeRange = tempTimeRange;
                        _selectedMainIngredient = tempMainIngredient;
                      });
                      Navigator.of(sheetContext).pop();
                      _executeSearch();
                    },
                  ),

                  const SizedBox(height: 8.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPickBanner(AppPalette palette) {
    if (widget.pickDate == null) return const SizedBox.shrink();

    final parsedDate = WeekUtils.parseDateKey(widget.pickDate!);
    final dayName = WeekUtils.dayNames[parsedDate.weekday - 1];

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.calendarDays,
              color: palette.onAccentSoft,
              size: 18.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Pilih menu untuk $dayName',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: palette.onAccentSoft,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/meal-plan'),
              child: Icon(Icons.close, size: 16.0, color: palette.onAccentSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(AppPalette palette) {
    final chips = <Widget>[];

    if (_selectedMeal != null) {
      final category = _categories.firstWhere((c) => c.meal == _selectedMeal);
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: category.name,
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedMeal = null);
              _executeSearch();
            },
          ),
        ),
      );
    }

    if (_selectedDifficulty != null) {
      final diffLabel = _selectedDifficulty == Difficulty.mudah
          ? 'Mudah'
          : (_selectedDifficulty == Difficulty.sedang ? 'Sedang' : 'Sulit');
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: diffLabel,
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedDifficulty = null);
              _executeSearch();
            },
          ),
        ),
      );
    }

    if (_selectedTimeRange != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: _selectedTimeRange == '< 15'
                ? '< 15 menit'
                : (_selectedTimeRange == '15-30'
                      ? '15–30 menit'
                      : '> 30 menit'),
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedTimeRange = null);
              _executeSearch();
            },
          ),
        ),
      );
    }

    if (_selectedMainIngredient != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: _selectedMainIngredient!,
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedMainIngredient = null);
              _executeSearch();
            },
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final favorites = ref.watch(favoritesProvider);

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        key: const PageStorageKey<String>('search_scroll_view'),
        slivers: [
          // Banner Pick Mode (bila datang dari Meal Plan)
          SliverToBoxAdapter(child: _buildPickBanner(palette)),

          // 2. Baris Pencarian: Search Bar Putih Pill (tinggi ≈ 40) + Tombol Filter Bulat chip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 4.0,
                bottom: 16.0,
              ),
              child: Row(
                children: [
                  // Search Bar Putih Pill (tinggi ≈ 40)
                  Expanded(
                    child: Container(
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: palette.field,
                        borderRadius: AppRadius.pill,
                        border: Border.all(color: palette.fieldBorder),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 18.0,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: AppText.body.copyWith(
                                fontSize: 13.0,
                                color: palette.textBody,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Search Recipes...',
                                hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: palette.textSecondary,
                                  fontSize: 13.0,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _executeSearch();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6.0),
                                child: Icon(
                                  Icons.close,
                                  size: 16.0,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10.0),

                  // Tombol Filter Bulat chip (ikon slidersHorizontal)
                  Semantics(
                    label: 'Filter pencarian',
                    button: true,
                    child: GestureDetector(
                      onTap: _openFilterSheet,
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          color: _hasActiveFilters
                              ? palette.accentSoft
                              : palette.chip,
                          shape: BoxShape.circle,
                          border: _hasActiveFilters
                              ? Border.all(color: palette.accent, width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              LucideIcons.slidersHorizontal,
                              size: 18.0,
                              color: _hasActiveFilters
                                  ? palette.onAccentSoft
                                  : palette.textStrong,
                            ),
                            if (_hasActiveFilters)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: palette.danger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chips filter yang sedang aktif
          SliverToBoxAdapter(child: _buildActiveFilterChips(palette)),

          // Konten Utama: Default ("Search by Meal") atau Hasil Pencarian
          if (!_isSearching) ...[
            // 3. Judul "Search by Meal"
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 24.0, right: 24.0, bottom: 14.0),
                child: Text('Search by Meal', style: AppText.sectionTitle),
              ),
            ),

            // 4. Grid 2 kolom tile foto kategori (tinggi ≈ 90, radius ≈ 20)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  mainAxisExtent: 90.0,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final cat = _categories[index];
                  return Semantics(
                    label: cat.name,
                    button: true,
                    child: GestureDetector(
                      onTap: () => _selectCategory(cat),
                      child: Container(
                        height: 90.0,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.cardLarge,
                          color: palette.photo,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SmartImage(
                              src: cat.image,
                              borderRadius: AppRadius.cardLarge,
                              fit: BoxFit.cover,
                            ),
                            // Selama foto masih placeholder, tampilkan nama kategori
                            if (cat.image == null || cat.image!.isEmpty)
                              Center(
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textStrong,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: _categories.length),
              ),
            ),
          ] else ...[
            // Header Hasil Pencarian & Tombol Bersihkan
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  bottom: 12.0,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Hasil pencarian',
                        style: AppText.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Text(
                        'Bersihkan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: palette.danger,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading / Empty / Grid Results
            if (_isLoading)
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
              )
            else if (_searchResults == null || _searchResults!.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: LucideIcons.searchX,
                  title: 'Tidak ada resep ditemukan',
                  subtitle: 'Coba gunakan kata kunci lain atau ubah filter pencarian.',
                  action: AppButton(
                    label: 'Bersihkan pencarian',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.md,
                    onPressed: _clearSearch,
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
                    final recipe = _searchResults![index];
                    final isFav = favorites.contains(recipe.id);
                    final isPickMode = widget.pickDate != null;
                    final isAlreadyPlanned =
                        isPickMode &&
                        ref
                            .watch(mealPlanProvider)
                            .any(
                              (e) =>
                                  e.date == widget.pickDate! &&
                                  e.recipeId == recipe.id,
                            );

                    Widget? customAction;
                    if (isPickMode) {
                      customAction = GestureDetector(
                        onTap: () async {
                          if (isAlreadyPlanned) {
                            showAppToast(
                              context,
                              'Menu sudah ada di meal plan',
                            );
                            return;
                          }
                          final status = await ref
                              .read(mealPlanProvider.notifier)
                              .add(widget.pickDate!, recipe.id);
                          if (!context.mounted) return;
                          if (status == MealPlanAddResult.added) {
                            showAppToast(
                              context,
                              'Menu berhasil ditambahkan ke Meal Plan',
                            );
                            context.go('/meal-plan');
                          } else if (status == MealPlanAddResult.pastDate) {
                            showAppToast(
                              context,
                              'Tidak dapat memilih tanggal yang sudah lewat',
                            );
                            context.go('/meal-plan');
                          } else {
                            showAppToast(
                              context,
                              'Menu sudah ada di meal plan',
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: isAlreadyPlanned
                                ? palette.chip
                                : palette.actionBg,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            isAlreadyPlanned ? 'Sudah ada' : 'Tambahkan',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: isAlreadyPlanned
                                  ? palette.textSecondary
                                  : palette.onAction,
                            ),
                          ),
                        ),
                      );
                    }

                    return GridRecipeCard(
                      recipe: recipe,
                      isFavorite: isFav,
                      customAction: customAction,
                      onOpen: () async {
                        if (isPickMode) {
                          if (isAlreadyPlanned) {
                            showAppToast(
                              context,
                              'Menu sudah ada di meal plan',
                            );
                            return;
                          }
                          final status = await ref
                              .read(mealPlanProvider.notifier)
                              .add(widget.pickDate!, recipe.id);
                          if (!context.mounted) return;
                          if (status == MealPlanAddResult.added) {
                            showAppToast(
                              context,
                              'Menu berhasil ditambahkan ke Meal Plan',
                            );
                            context.go('/meal-plan');
                          } else if (status == MealPlanAddResult.pastDate) {
                            showAppToast(
                              context,
                              'Tidak dapat memilih tanggal yang sudah lewat',
                            );
                            context.go('/meal-plan');
                          } else {
                            showAppToast(
                              context,
                              'Menu sudah ada di meal plan',
                            );
                          }
                        } else {
                          context.push('/recipe/${recipe.id}');
                        }
                      },
                      onToggleFav: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(recipe.id),
                      onQuickAdd: isPickMode
                          ? null
                          : () async {
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
                  }, childCount: _searchResults!.length),
                ),
              ),
          ],

          // Padding bawah agar konten tidak tertutup floating bottom nav (120 px) + keyboard
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  AppShell.bottomNavPadding +
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}
