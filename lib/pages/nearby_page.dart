import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../models/models.dart';
import '../providers/location_provider.dart';
import '../providers/places_provider.dart';
import '../providers/ui_helper.dart';
import '../services/route_service.dart';
import '../widgets/illustrated_map.dart';
import '../widgets/page_with_header.dart';
import '../widgets/real_map_view.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/empty_state.dart';

enum NearbyQuickFilter { terdekat, bukaSekarang, hargaHemat }

/// Halaman Nearby (/nearby) sesuai PRD §6.8, §7.2, §16 dan design/location.jpg:
/// - AppHeader global di atas.
/// - Baris pencarian: search bar putih ("Cari resto atau rumah makan") + tombol filter bulat chip.
/// - Chip filter: Terdekat (default aktif), Buka sekarang, Harga hemat.
/// - Kartu peta ilustrasi statis IllustratedMap (375x210 radius 20).
/// - Judul "Pilihan Di Sekitarmu" + "{n} tempat" (dinamis).
/// - Daftar kartu tempat: nomor pin, nama, cuisine & harga, jarak & waktu, status buka/tutup, tombol Rute.
/// - Interaksi: tap kartu/pin = pilih tempat, tombol Rute = toast "Membuka rute ke {nama}".
/// - Filter sheet (PRD §7.2): radius, kisaran harga, status.
/// - AppBottomNav aktif Loc (ShellRoute).
class NearbyPage extends ConsumerStatefulWidget {
  const NearbyPage({super.key});

  @override
  ConsumerState<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends ConsumerState<NearbyPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  NearbyQuickFilter _quickFilter = NearbyQuickFilter.terdekat;
  String? _selectedPlaceId;

  // Route State
  RouteResult? _routeResult;
  bool _isLoadingRoute = false;
  CancelToken? _cancelToken;
  String? _lastRoutedPlaceId;

  // Filter Sheet State
  String _selectedRadius = '1 km';
  String _selectedPriceRange = 'Semua';
  String _selectedStatus = 'Semua';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationProvider.notifier).initLocation();
      final loc = ref.read(locationProvider);
      if (loc.message != null && mounted) {
        showAppToast(context, loc.message!);
      }
      _triggerInitialRoute();
    });
  }

  void _triggerInitialRoute() {
    final places = _filterAndSortPlaces(ref.read(placesProvider));
    if (places.isNotEmpty) {
      final place = places.firstWhere(
        (p) => p.id == _selectedPlaceId,
        orElse: () => places.first,
      );
      _fetchRouteForPlace(place);
    }
  }

  void _fetchRouteForPlace(Place place) async {
    if (_lastRoutedPlaceId == place.id && _routeResult != null) return;
    _lastRoutedPlaceId = place.id;

    _cancelToken?.cancel('Place changed');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    setState(() {
      _isLoadingRoute = true;
    });

    final loc = ref.read(locationProvider).coordinates;
    final start = LatLng(loc.latitude, loc.longitude);
    final destination = LatLng(place.latitude, place.longitude);

    final routeService = ref.read(routeServiceProvider);
    final result = await routeService.getFootRoute(
      start: start,
      destination: destination,
      cancelToken: cancelToken,
    );

    if (mounted && !cancelToken.isCancelled) {
      setState(() {
        _routeResult = result;
        _isLoadingRoute = false;
      });

      if (result.isStraightLineFallback) {
        showAppToast(context, 'Rute perkiraan');
      }
    }
  }

  void _onSelectPlace(String id) {
    setState(() {
      _selectedPlaceId = id;
    });
    final allPlaces = ref.read(placesProvider);
    final place = allPlaces.firstWhere(
      (p) => p.id == id,
      orElse: () => allPlaces.first,
    );
    _fetchRouteForPlace(place);
  }

  void _onTapRoute(Place place) {
    _onSelectPlace(place.id);
    showAppToast(context, 'Membuka rute ke ${place.name}');
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Disposed');
    _searchController.dispose();
    super.dispose();
  }

  List<Place> _filterAndSortPlaces(List<Place> allPlaces) {
    var result = allPlaces.toList();

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(_searchQuery) ||
            p.cuisine.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Sheet Radius Filter
    if (_selectedRadius == '500 m') {
      result = result.where((p) => p.distanceM <= 500).toList();
    } else if (_selectedRadius == '1 km') {
      result = result.where((p) => p.distanceM <= 1000).toList();
    } else if (_selectedRadius == '2 km') {
      result = result.where((p) => p.distanceM <= 2000).toList();
    } else if (_selectedRadius == '5 km') {
      result = result.where((p) => p.distanceM <= 5000).toList();
    }

    // 3. Sheet Price Range Filter
    if (_selectedPriceRange == '< Rp20 rb') {
      result = result.where((p) => p.priceMin < 20000).toList();
    } else if (_selectedPriceRange == 'Rp20–35 rb') {
      result = result
          .where((p) => p.priceMin >= 20000 && p.priceMax <= 35000)
          .toList();
    } else if (_selectedPriceRange == '> Rp35 rb') {
      result = result.where((p) => p.priceMax > 35000).toList();
    }

    // 4. Sheet Status Filter
    if (_selectedStatus == 'Buka saja') {
      result = result.where((p) => p.open && !p.isUnknownHours).toList();
    }

    // 5. Quick Chip Filter & Sorting
    switch (_quickFilter) {
      case NearbyQuickFilter.terdekat:
        result.sort((a, b) => a.distanceM.compareTo(b.distanceM));
        break;
      case NearbyQuickFilter.bukaSekarang:
        result = result.where((p) => p.open && !p.isUnknownHours).toList();
        result.sort((a, b) => a.distanceM.compareTo(b.distanceM));
        break;
      case NearbyQuickFilter.hargaHemat:
        result.sort((a, b) => a.priceMin.compareTo(b.priceMin));
        break;
    }

    return result;
  }

  void _showFilterSheet() {
    String tempRadius = _selectedRadius;
    String tempPrice = _selectedPriceRange;
    String tempStatus = _selectedStatus;

    showAppBottomSheet(
      context: context,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomPadding = math.max(
              16.0,
              MediaQuery.of(sheetContext).viewPadding.bottom + 16.0,
            );
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 8.0,
                bottom: bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Filter & Reset
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempRadius = '1 km';
                            tempPrice = 'Semua';
                            tempStatus = 'Semua';
                          });
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: palette.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // 1. Bagian Radius
                  Text(
                    'Radius',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: ['500 m', '1 km', '2 km', '5 km'].map((radius) {
                      final isSelected = tempRadius == radius;
                      return ChoiceChip(
                        label: Text(radius),
                        selected: isSelected,
                        selectedColor: palette.actionBg,
                        backgroundColor: palette.surface,
                        labelStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? palette.onAction
                              : palette.textBody,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.0),
                          side: BorderSide(
                            color: isSelected
                                ? palette.actionBg
                                : palette.border,
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() => tempRadius = radius);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18.0),

                  // 2. Bagian Kisaran Harga
                  Text(
                    'Kisaran harga',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: ['Semua', '< Rp20 rb', 'Rp20–35 rb', '> Rp35 rb']
                        .map((price) {
                          final isSelected = tempPrice == price;
                          return ChoiceChip(
                            label: Text(price),
                            selected: isSelected,
                            selectedColor: palette.actionBg,
                            backgroundColor: palette.surface,
                            labelStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? palette.onAction
                                  : palette.textBody,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999.0),
                              side: BorderSide(
                                color: isSelected
                                    ? palette.actionBg
                                    : palette.border,
                              ),
                            ),
                            showCheckmark: false,
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => tempPrice = price);
                              }
                            },
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 18.0),

                  // 3. Bagian Status
                  Text(
                    'Status',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: ['Semua', 'Buka saja'].map((status) {
                      final isSelected = tempStatus == status;
                      return ChoiceChip(
                        label: Text(status),
                        selected: isSelected,
                        selectedColor: palette.actionBg,
                        backgroundColor: palette.surface,
                        labelStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? palette.onAction
                              : palette.textBody,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.0),
                          side: BorderSide(
                            color: isSelected
                                ? palette.actionBg
                                : palette.border,
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() => tempStatus = status);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24.0),

                  // Tombol Terapkan Lebar Penuh
                  AppButton(
                    label: 'Terapkan',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () {
                      setState(() {
                        _selectedRadius = tempRadius;
                        _selectedPriceRange = tempPrice;
                        _selectedStatus = tempStatus;
                      });
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _quickFilter = NearbyQuickFilter.terdekat;
      _selectedRadius = '1 km';
      _selectedPriceRange = 'Semua';
      _selectedStatus = 'Semua';
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(placesFallbackToastProvider, (prev, next) {
      if (next != null && mounted) {
        showAppToast(context, next);
      }
    });

    final palette = context.palette;
    final allPlaces = ref.watch(placesProvider);
    final placesAsync = ref.watch(placesAsyncProvider);
    final locationState = ref.watch(locationProvider);
    final filteredPlaces = _filterAndSortPlaces(allPlaces);

    // Pastikan selectedPlaceId valid
    if (_selectedPlaceId == null ||
        !filteredPlaces.any((p) => p.id == _selectedPlaceId)) {
      _selectedPlaceId = filteredPlaces.isNotEmpty
          ? filteredPlaces.first.id
          : null;
    }

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        key: const PageStorageKey<String>('nearby_scroll_view'),
        slivers: [
          // 1. Baris Pencarian & Tombol Filter Bulat
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  // Search Bar Putih Pill (tinggi ≈ 46)
                  Expanded(
                    child: Container(
                      height: 46.0,
                      decoration: BoxDecoration(
                        color: palette.field,
                        borderRadius: BorderRadius.circular(999.0),
                        border: Border.all(color: palette.fieldBorder),
                        boxShadow: [
                          BoxShadow(
                            color: palette.shadowColor,
                            blurRadius: 4.0,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            color: palette.textSecondary,
                            size: 18.0,
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: palette.textBody,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Cari resto atau rumah makan',
                                hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.0,
                                  color: palette.textSecondary,
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
                              },
                              child: Icon(
                                LucideIcons.x,
                                size: 16.0,
                                color: palette.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12.0),

                  // Tombol Filter Bulat (chip, 46x46)
                  Semantics(
                    label: 'Filter pencarian tempat',
                    button: true,
                    child: GestureDetector(
                      onTap: _showFilterSheet,
                      child: Container(
                        width: 46.0,
                        height: 46.0,
                        decoration: BoxDecoration(
                          color: palette.chip,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.slidersHorizontal,
                          size: 18.0,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14.0)),

          // 3. Chip Filter Cepat: Terdekat, Buka sekarang, Harga hemat
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickChip(
                      palette: palette,
                      label: 'Terdekat',
                      isSelected: _quickFilter == NearbyQuickFilter.terdekat,
                      onTap: () {
                        setState(() {
                          _quickFilter = NearbyQuickFilter.terdekat;
                        });
                      },
                    ),
                    const SizedBox(width: 10.0),
                    _buildQuickChip(
                      palette: palette,
                      label: 'Buka sekarang',
                      isSelected:
                          _quickFilter == NearbyQuickFilter.bukaSekarang,
                      onTap: () {
                        setState(() {
                          _quickFilter = NearbyQuickFilter.bukaSekarang;
                        });
                      },
                    ),
                    const SizedBox(width: 10.0),
                    _buildQuickChip(
                      palette: palette,
                      label: 'Harga hemat',
                      isSelected: _quickFilter == NearbyQuickFilter.hargaHemat,
                      onTap: () {
                        setState(() {
                          _quickFilter = NearbyQuickFilter.hargaHemat;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16.0)),

          // 4. Kartu Peta (Peta Nyata vs Peta Ilustrasi dengan Fallback)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: locationState.isRealMap
                  ? RealMapView(
                      places: filteredPlaces,
                      selectedPlaceId: _selectedPlaceId,
                      userCoordinates: locationState.coordinates,
                      radiusLabel: 'Radius $_selectedRadius',
                      routeResult: _routeResult,
                      isLoadingRoute: _isLoadingRoute,
                      onSelectPlace: _onSelectPlace,
                      onCenterTap: () {
                        if (filteredPlaces.isNotEmpty) {
                          _onSelectPlace(filteredPlaces.first.id);
                        }
                        showAppToast(context, 'Peta dipusatkan ke lokasi kamu');
                      },
                      onTileError: () {
                        ref.read(locationProvider.notifier).useIllustratedMap();
                        showAppToast(
                          context,
                          'Koneksi peta bermasalah, beralih ke peta ilustrasi',
                        );
                      },
                      onSwitchToIllustrated: () {
                        ref.read(locationProvider.notifier).useIllustratedMap();
                      },
                    )
                  : IllustratedMap(
                      places: filteredPlaces,
                      selectedPlaceId: _selectedPlaceId,
                      radiusLabel: 'Radius $_selectedRadius',
                      onSelectPlace: _onSelectPlace,
                      onCenterTap: () {
                        if (filteredPlaces.isNotEmpty) {
                          _onSelectPlace(filteredPlaces.first.id);
                        }
                        showAppToast(context, 'Peta dipusatkan ke lokasi kamu');
                      },
                      onSwitchToRealMap: () {
                        ref.read(locationProvider.notifier).useRealMap();
                      },
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

          // 5. Judul Section: "Pilihan Di Sekitarmu" + "{n} tempat"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      'Pilihan Di Sekitarmu',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: palette.textStrong,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredPlaces.length} tempat',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12.0)),

          // 6. Daftar Kartu Tempat Makan (atau EmptyState bila kosong / error)
          if (placesAsync.hasError &&
              (!placesAsync.hasValue || placesAsync.value!.isEmpty))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: EmptyState(
                  icon: LucideIcons.alertCircle,
                  title: 'Gagal memuat tempat sekitar',
                  subtitle:
                      'Periksa koneksi internet Anda atau coba muat kembali.',
                  action: AppButton(
                    label: 'Coba lagi',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.sm,
                    onPressed: () {
                      ref.invalidate(placesAsyncProvider);
                    },
                  ),
                ),
              ),
            )
          else if (filteredPlaces.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: EmptyState(
                  icon: LucideIcons.mapPin,
                  title: 'Tidak ada tempat ditemukan',
                  subtitle: 'Coba ubah kata kunci pencarian atau reset filter untuk melihat tempat makan terdekat.',
                  action: AppButton(
                    label: 'Reset Filter',
                    variant: AppButtonVariant.soft,
                    size: AppButtonSize.sm,
                    onPressed: _resetAllFilters,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final place = filteredPlaces[index];
                  final isSelected = place.id == _selectedPlaceId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildPlaceCard(
                      palette: palette,
                      place: place,
                      index: index + 1,
                      isSelected: isSelected,
                    ),
                  );
                }, childCount: filteredPlaces.length),
              ),
            ),

          // 7. Padding Bawah agar tidak tertutup floating bottom nav
          const SliverToBoxAdapter(
            child: SizedBox(height: AppShell.bottomNavPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required AppPalette palette,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? palette.actionBg : palette.surface,
          borderRadius: BorderRadius.circular(999.0),
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: palette.shadowColor,
                    blurRadius: 3.0,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? palette.onAction : palette.textBody,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard({
    required AppPalette palette,
    required Place place,
    required int index,
    required bool isSelected,
  }) {
    final priceMinStr = (place.priceMin ~/ 1000).toString();
    final priceMaxStr = (place.priceMax ~/ 1000).toString();

    return GestureDetector(
      onTap: () => _onSelectPlace(place.id),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppRadius.cardLarge,
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            // Lingkaran Nomor (32x32: accent bila terpilih, chip bila lain)
            Container(
              width: 32.0,
              height: 32.0,
              decoration: BoxDecoration(
                color: isSelected ? palette.accent : palette.chip,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? palette.onAccent : palette.textBody,
                ),
              ),
            ),

            const SizedBox(width: 12.0),

            // Kolom Informasi Tempat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Tempat (14/700 textStrong)
                  Text(
                    place.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),

                  // "Cuisine · Rp..–.. rb" (11 textSecondary)
                  Text(
                    '${place.cuisine} · Rp$priceMinStr–$priceMaxStr rb',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),

                  // "Jarak · Menit" (11 textSecondary)
                  Text(
                    isSelected &&
                            _routeResult != null &&
                            !_routeResult!.isStraightLineFallback
                        ? _routeResult!.distanceAndDurationString
                        : '${place.distanceM} m · ${place.walkMin} menit',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8.0),

            // Kolom Kanan: Status & Tombol Rute
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status "Buka" (actionBg) atau "Tutup" (danger)
                Text(
                  place.open ? 'Buka' : 'Tutup',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: place.open ? palette.actionBg : palette.danger,
                  ),
                ),
                const SizedBox(height: 6.0),

                // Tombol "Rute" (terpilih = actionBg teks onAction, lain = chip teks textStrong)
                Semantics(
                  label: 'Rute ke ${place.name}',
                  button: true,
                  child: GestureDetector(
                    onTap: () => _onTapRoute(place),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.actionBg : palette.chip,
                        borderRadius: BorderRadius.circular(999.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Rute',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? palette.onAction
                              : palette.textStrong,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
