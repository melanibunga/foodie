import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../models/models.dart';
import '../providers/location_provider.dart';
import '../providers/places_provider.dart';
import '../providers/ui_helper.dart';
import '../widgets/illustrated_map.dart';
import '../widgets/page_with_header.dart';
import '../widgets/real_map_view.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/empty_state.dart';

enum NearbyQuickFilter { terdekat, bukaSekarang, hargaHemat }

/// Halaman Nearby (/nearby) sesuai PRD §6.8, §7.2 dan design/location.jpg:
/// - AppHeader global di atas.
/// - Baris pencarian: search bar putih ("Cari resto atau rumah makan") + tombol filter bulat chipGray.
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
  }

  @override
  void dispose() {
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
      result = result.where((p) => p.open).toList();
    }

    // 5. Quick Chip Filter & Sorting
    switch (_quickFilter) {
      case NearbyQuickFilter.terdekat:
        result.sort((a, b) => a.distanceM.compareTo(b.distanceM));
        break;
      case NearbyQuickFilter.bukaSekarang:
        result = result.where((p) => p.open).toList();
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
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 8.0,
                bottom: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Filter & Reset
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.olive,
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
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.maroon,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // 1. Bagian Radius
                  const Text(
                    'Radius',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.olive,
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
                        selectedColor: AppColors.olive,
                        backgroundColor: AppColors.white,
                        labelStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textBody,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.0),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.olive
                                : AppColors.border,
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
                  const Text(
                    'Kisaran harga',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.olive,
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
                            selectedColor: AppColors.olive,
                            backgroundColor: AppColors.white,
                            labelStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.textBody,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999.0),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.olive
                                    : AppColors.border,
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
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.olive,
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
                        selectedColor: AppColors.olive,
                        backgroundColor: AppColors.white,
                        labelStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textBody,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.0),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.olive
                                : AppColors.border,
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
    final allPlaces = ref.watch(placesProvider);
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
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(999.0),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowShell,
                            blurRadius: 4.0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.search,
                            color: AppColors.sage,
                            size: 18.0,
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.0,
                                color: AppColors.textBody,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Cari resto atau rumah makan',
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

                  const SizedBox(width: 12.0),

                  // Tombol Filter Bulat (chipGray, 46x46)
                  Semantics(
                    label: 'Filter pencarian tempat',
                    button: true,
                    child: GestureDetector(
                      onTap: _showFilterSheet,
                      child: Container(
                        width: 46.0,
                        height: 46.0,
                        decoration: const BoxDecoration(
                          color: AppColors.chipGray,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          LucideIcons.slidersHorizontal,
                          size: 18.0,
                          color: AppColors.olive,
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
                      onSelectPlace: (id) {
                        setState(() {
                          _selectedPlaceId = id;
                        });
                      },
                      onCenterTap: () {
                        if (filteredPlaces.isNotEmpty) {
                          setState(() {
                            _selectedPlaceId = filteredPlaces.first.id;
                          });
                        }
                        showAppToast(context, 'Peta dipusatkan ke lokasi kamu');
                      },
                      onSwitchToIllustrated: () {
                        ref.read(locationProvider.notifier).useIllustratedMap();
                      },
                    )
                  : IllustratedMap(
                      places: filteredPlaces,
                      selectedPlaceId: _selectedPlaceId,
                      radiusLabel: 'Radius $_selectedRadius',
                      onSelectPlace: (id) {
                        setState(() {
                          _selectedPlaceId = id;
                        });
                      },
                      onCenterTap: () {
                        if (filteredPlaces.isNotEmpty) {
                          setState(() {
                            _selectedPlaceId = filteredPlaces.first.id;
                          });
                        }
                        showAppToast(context, 'Peta dipusatkan ke lokasi kamu');
                      },
                      onSwitchToRealMap: () async {
                        await ref
                            .read(locationProvider.notifier)
                            .toggleMapMode();
                        final loc = ref.read(locationProvider);
                        if (!loc.isRealMap &&
                            loc.message != null &&
                            context.mounted) {
                          showAppToast(context, loc.message!);
                        }
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
                  const Expanded(
                    child: Text(
                      'Pilihan Di Sekitarmu',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.olive,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredPlaces.length} tempat',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12.0)),

          // 6. Daftar Kartu Tempat Makan (atau EmptyState bila kosong)
          if (filteredPlaces.isEmpty)
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
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.olive : AppColors.white,
          borderRadius: BorderRadius.circular(999.0),
          boxShadow: isSelected
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.shadowShell,
                    blurRadius: 3.0,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard({
    required Place place,
    required int index,
    required bool isSelected,
  }) {
    final priceMinStr = (place.priceMin ~/ 1000).toString();
    final priceMaxStr = (place.priceMax ~/ 1000).toString();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlaceId = place.id;
        });
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.cardLarge,
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            // Lingkaran Nomor (32x32: amber bila terpilih, chipGray bila lain)
            Container(
              width: 32.0,
              height: 32.0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.amber : AppColors.chipGray,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBody,
                ),
              ),
            ),

            const SizedBox(width: 12.0),

            // Kolom Informasi Tempat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Tempat (14/700 olive)
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.olive,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),

                  // "Cuisine · Rp..–.. rb" (11 sage)
                  Text(
                    '${place.cuisine} · Rp$priceMinStr–$priceMaxStr rb',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      color: AppColors.sage,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),

                  // "Jarak · Menit" (11 sage)
                  Text(
                    '${place.distanceM} m · ${place.walkMin} menit',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      color: AppColors.sage,
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
                // Status "Buka" (olive) atau "Tutup" (maroon)
                Text(
                  place.open ? 'Buka' : 'Tutup',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: place.open ? AppColors.olive : AppColors.maroon,
                  ),
                ),
                const SizedBox(height: 6.0),

                // Tombol "Rute" (terpilih = olive teks putih, lain = chipGray teks olive)
                Semantics(
                  label: 'Rute ke ${place.name}',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPlaceId = place.id;
                      });
                      showAppToast(context, 'Membuka rute ke ${place.name}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.olive
                            : AppColors.chipGray,
                        borderRadius: BorderRadius.circular(999.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Rute',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.white : AppColors.olive,
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
