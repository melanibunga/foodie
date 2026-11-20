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
import '../data/regions.dart';
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

/// Halaman Pencarian & Filter Resep sesuai PRD §6.5 & §7.2, §17.4 (Fase G4):
/// - Grid "Search by Region" menggantikan Search by Meal, dikelompokkan berdasarkan pulau/wilayah.
/// - Tap kartu asal daerah memfilter resep dari daerah tersebut.
/// - Filter Sheet hanya menampilkan filter nyata yang didukung API (Kategori, Wilayah, Bahan Utama).
/// - Request token sequence untuk pencegahan race condition / respons lama.
/// - Debounce 250 ms untuk pengetikan pencarian.
class SearchPage extends ConsumerStatefulWidget {
  final String? pickDate;

  const SearchPage({super.key, this.pickDate});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 250));
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  List<Recipe>? _searchResults;
  String? _errorMessage;

  // Request sequence id untuk mencegah race condition / data usang
  int _searchRequestId = 0;

  // Filter nyata yang didukung API
  RegionItem? _selectedRegion; // Dipilih dari tile kartu daerah
  String? _selectedCategory; // Dipilih dari Filter Sheet
  String? _selectedRegionGroup; // Dipilih dari Filter Sheet
  String? _selectedMainIngredient; // Dipilih dari Filter Sheet

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPastPickDate();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
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
    _scrollController.dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _searchResults == null ||
        !_isSearching) {
      return;
    }

    setState(() => _isLoadingMore = true);

    final query = _searchController.text.trim();
    final nextPage = _currentPage + 1;

    try {
      final newResults = await ref
          .read(recipeServiceProvider)
          .list(
            q: query.isEmpty ? null : query,
            category: _selectedCategory,
            cuisine: _selectedRegion?.name ?? _selectedRegionGroup,
            mainIngredient: _selectedMainIngredient,
            page: nextPage,
          );

      if (!mounted) return;

      if (newResults.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
          _currentPage = nextPage;
          _searchResults = [...?_searchResults, ...newResults];
          if (newResults.length < 10) {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  bool get _hasActiveFilters =>
      _selectedCategory != null ||
      _selectedRegionGroup != null ||
      _selectedMainIngredient != null;

  int get _activeFilterCount =>
      (_selectedCategory != null ? 1 : 0) +
      (_selectedRegionGroup != null ? 1 : 0) +
      (_selectedMainIngredient != null ? 1 : 0);

  bool get _isSearching =>
      _searchController.text.trim().isNotEmpty ||
      _selectedRegion != null ||
      _hasActiveFilters;

  Future<void> _executeSearch() async {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;

    if (!_isSearching) {
      setState(() {
        _isLoading = false;
        _searchResults = null;
        _errorMessage = null;
      });
      return;
    }

    final currentToken = ++_searchRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final query = _searchController.text.trim();

    try {
      final results = await ref
          .read(recipeServiceProvider)
          .list(
            q: query.isEmpty ? null : query,
            category: _selectedCategory,
            cuisine: _selectedRegion?.name ?? _selectedRegionGroup,
            mainIngredient: _selectedMainIngredient,
          );

      if (!mounted || currentToken != _searchRequestId) {
        // Mengabaikan respons usang dari request lama!
        return;
      }

      setState(() {
        _isLoading = false;
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted || currentToken != _searchRequestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat resep. Silakan periksa koneksi internet.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debouncer.run(() {
      _executeSearch();
    });
  }

  void _selectRegion(RegionItem region) {
    setState(() {
      if (_selectedRegion?.id == region.id) {
        _selectedRegion = null;
      } else {
        _selectedRegion = region;
      }
    });
    _executeSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedRegion = null;
      _selectedCategory = null;
      _selectedRegionGroup = null;
      _selectedMainIngredient = null;
      _searchResults = null;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _openFilterSheet() async {
    String? tempCategory = _selectedCategory;
    String? tempRegionGroup = _selectedRegionGroup;
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
                          'Filter Resep',
                          style: AppText.sectionTitle.copyWith(
                            color: sheetPalette.textStrong,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempCategory = null;
                            tempRegionGroup = null;
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

                  // Section 1: Kategori Resep (11 Kategori Nyata dari API)
                  Text(
                    'Kategori Resep',
                    style: AppText.formLabel.copyWith(
                      color: sheetPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: kApiRecipeCategories.map((cat) {
                      final isSelected = tempCategory == cat;
                      return AppChip(
                        label: cat,
                        selected: isSelected,
                        onTap: () {
                          setSheetState(() {
                            tempCategory = isSelected ? null : cat;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Wilayah Asal (Grup Pulau / Mancanegara dari API)
                  Text(
                    'Wilayah / Asal Daerah',
                    style: AppText.formLabel.copyWith(
                      color: sheetPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: kRegionGroups
                        .where((g) => g.name != 'Lainnya')
                        .map((g) {
                          final isSelected = tempRegionGroup == g.name;
                          return AppChip(
                            label: g.name,
                            selected: isSelected,
                            onTap: () {
                              setSheetState(() {
                                tempRegionGroup = isSelected ? null : g.name;
                              });
                            },
                          );
                        })
                        .toList(),
                  ),

                  const SizedBox(height: 20),

                  // Section 3: Bahan Utama (Daftar Bahan Nyata dari API)
                  Text(
                    'Bahan Utama',
                    style: AppText.formLabel.copyWith(
                      color: sheetPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: kApiMainIngredients.map((ing) {
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
                    label: 'Terapkan Filter',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () {
                      setState(() {
                        _selectedCategory = tempCategory;
                        _selectedRegionGroup = tempRegionGroup;
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

    if (_selectedRegion != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: 'Daerah: ${_selectedRegion!.name}',
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedRegion = null);
              _executeSearch();
            },
          ),
        ),
      );
    }

    if (_selectedCategory != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: 'Kategori: $_selectedCategory',
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedCategory = null);
              _executeSearch();
            },
          ),
        ),
      );
    }

    if (_selectedRegionGroup != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: AppChip(
            label: 'Wilayah: $_selectedRegionGroup',
            selected: true,
            icon: Icon(Icons.close, size: 14, color: palette.onChipSelected),
            onTap: () {
              setState(() => _selectedRegionGroup = null);
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
            label: 'Bahan: $_selectedMainIngredient',
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
        controller: _scrollController,
        key: const PageStorageKey<String>('search_scroll_view'),
        slivers: [
          // Banner Pick Mode (bila datang dari Meal Plan)
          SliverToBoxAdapter(child: _buildPickBanner(palette)),

          // Baris Pencarian: Search Bar Putih Pill + Tombol Filter Bulat chip
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
                  // Search Bar Putih Pill
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

                  // Tombol Filter Bulat chip dengan Badge Jumlah Filter Aktif
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
                            if (_activeFilterCount > 0)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2.0),
                                  decoration: BoxDecoration(
                                    color: palette.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14,
                                    minHeight: 14,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_activeFilterCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                    ),
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

          // Konten Utama: Default ("Search by Region") atau Hasil Pencarian
          if (!_isSearching) ...[
            // Judul Section Utama "Search by Region"
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 4.0,
                  bottom: 8.0,
                ),
                child: Text('Search by Region', style: AppText.sectionTitle),
              ),
            ),

            // Render setiap grup daerah beserta grid kartu daerahnya
            for (final group in kRegionGroups) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 16.0,
                    bottom: 10.0,
                  ),
                  child: Text(
                    group.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                ),
              ),
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
                    final region = group.items[index];
                    final isSelected = _selectedRegion?.id == region.id;

                    return Semantics(
                      label: region.name,
                      button: true,
                      child: GestureDetector(
                        onTap: () => _selectRegion(region),
                        child: Container(
                          height: 90.0,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.cardLarge,
                            color: isSelected
                                ? palette.accentSoft
                                : palette.photo,
                            border: isSelected
                                ? Border.all(color: palette.accent, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            region.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? palette.onAccentSoft
                                  : palette.textStrong,
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: group.items.length),
                ),
              ),
            ],
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
                    Expanded(
                      child: Text(
                        _selectedRegion != null
                            ? 'Hasil: ${_selectedRegion!.name}'
                            : (_searchResults != null
                                  ? 'Hasil pencarian (${_searchResults!.length} resep)'
                                  : 'Hasil pencarian'),
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

            // Loading / Error / Empty / Grid Results
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
            else if (_errorMessage != null)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: LucideIcons.alertCircle,
                  title: 'Terjadi Kendala',
                  subtitle: _errorMessage!,
                  action: AppButton(
                    label: 'Coba lagi',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.md,
                    onPressed: _executeSearch,
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
                              .add(widget.pickDate!, recipe.id, recipe: recipe);
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
                              .add(widget.pickDate!, recipe.id, recipe: recipe);
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
                          .toggle(recipe.id, recipe: recipe),
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

          // Padding bawah agar konten tidak tertutup floating bottom nav + keyboard
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
