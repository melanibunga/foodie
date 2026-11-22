import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_shadows.dart';
import '../core/utils/nearby_map_utils.dart';
import '../models/models.dart';
import '../providers/location_provider.dart';
import '../providers/places_provider.dart';
import '../providers/ui_helper.dart';
import '../services/location_service.dart';
import '../services/place_service.dart';
import '../widgets/page_with_header.dart';
import '../widgets/real_map_view.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman Nearby (/nearby) sesuai PRD §6.8, §14.12, §14.2, §14.5, §17.6, §17.7
/// serta spesifikasi revisi Tampilan Kartu Peta:
/// - AppHeader fixed di atas dan BottomNav fixed di bawah (tab Nearby aktif).
/// - Layout kolom scroll:
///   1. Search bar "Cari warung makan…" di atas kartu (debounce 400 ms, dropdown max 8 hasil).
///   2. KARTU PETA:
///      - Background surface, radius 20, shadow card, padding 16.
///      - Judul "Warung Makan Terdekat" (18/700 textStrong).
///      - Subjudul "Buka Maps untuk menemukan warung makan di sekitarmu." (12 sekunder).
///      - Preview peta tinggi ±220 radius 16 (RealMapView, interaksi nonaktif, tap marker aktif).
///      - Pill "Peta Penuh" di kanan atas preview -> buka route /nearby/map.
///      - Pill status di kiri bawah preview.
///      - Baris tombol: "Open Maps" (lebar sisa) + Tombol persegi kecil "Pusatkan ke lokasi saya".
///   3. Daftar "Pilihan Di Sekitarmu" + "{n} tempat" di bawah kartu:
///      - Kartu tempat terdekat (maks 10, urut terdekat, TANPA tombol Rute).
///      - Tap kartu = pilih tempat & sorot marker.
/// - Marker bertema: olive (pengguna, tanpa label, halo CircleLayer), pin tempat 30px (ikon lucide per tipe), terpilih amber 36px.
/// - Pertahankan: izin lokasi on-demand, rationale card, banner akurasi, aturan tanpa lokasi palsu, Overpass cache.
class NearbyPage extends ConsumerStatefulWidget {
  const NearbyPage({super.key});

  @override
  ConsumerState<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends ConsumerState<NearbyPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _placeCardKeys = {};

  // Kamera & Data Tempat
  List<Place> _visiblePlaces = [];
  bool _isLoadingPlaces = false;
  bool _hasPlacesError = false;
  Timer? _cameraDebounceTimer;
  CancelToken? _bboxCancelToken;

  // Pencarian Tempat
  Timer? _searchDebounceTimer;
  CancelToken? _searchCancelToken;
  List<Place> _searchResults = [];
  bool _isSearching = false;
  bool _searchHasSearched = false;
  bool _showSearchDropdown = false;

  // Tempat Terpilih
  Place? _selectedPlace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchInputChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationProvider.notifier).checkLocationStatus();
      final loc = ref.read(locationProvider);
      if (loc.message != null && mounted) {
        showAppToast(context, loc.message!);
      }

      // Muat tempat di area awal setelah peta terinisialisasi
      _fetchPlacesForCurrentCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _bboxCancelToken?.cancel('Disposed');
    _searchCancelToken?.cancel('Disposed');
    _searchController.dispose();
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationProvider.notifier).resumeStream();
      final locStatus = ref.read(locationProvider).status;
      if (locStatus == LocationStatus.serviceOff ||
          locStatus == LocationStatus.deniedForever ||
          locStatus == LocationStatus.denied) {
        ref.read(locationProvider.notifier).checkLocationStatus();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(locationProvider.notifier).pauseStream();
    }
  }

  // ==========================================
  // Data Tempat (Overpass POI & Cache)
  // ==========================================

  void _fetchPlacesForCurrentCamera() {
    final camera = _mapController.camera;
    final loc = ref.read(locationProvider).coordinates;
    final center = loc != null
        ? LatLng(loc.latitude, loc.longitude)
        : (camera.center.latitude != 0 && camera.center.longitude != 0
              ? camera.center
              : kDefaultNearbyCenter);

    final bounds = LatLngBounds(
      LatLng(center.latitude - 0.015, center.longitude - 0.015),
      LatLng(center.latitude + 0.015, center.longitude + 0.015),
    );

    _fetchPlacesForBounds(bounds);
  }

  Future<void> _fetchPlacesForBounds(LatLngBounds bounds) async {
    _bboxCancelToken?.cancel('New camera position');
    final cancelToken = CancelToken();
    _bboxCancelToken = cancelToken;

    setState(() {
      _isLoadingPlaces = true;
      _hasPlacesError = false;
    });

    final loc = ref.read(locationProvider).coordinates;
    final cameraCenter = _mapController.camera.center;
    final placeService = ref.read(placeServiceProvider);

    try {
      final places = await placeService.getPlacesInBbox(
        minLat: bounds.south,
        minLon: bounds.west,
        maxLat: bounds.north,
        maxLon: bounds.east,
        userLat: loc?.latitude ?? cameraCenter.latitude,
        userLng: loc?.longitude ?? cameraCenter.longitude,
        cancelToken: cancelToken,
      );

      if (mounted && !cancelToken.isCancelled) {
        setState(() {
          _visiblePlaces = places.isNotEmpty
              ? places
              : LocalPlaceService().getPlacesSync(
                  latitude: loc?.latitude ?? cameraCenter.latitude,
                  longitude: loc?.longitude ?? cameraCenter.longitude,
                );
          _isLoadingPlaces = false;
          _hasPlacesError = false;
        });

        _fitPreviewBounds();
      }
    } on DioException catch (e) {
      if (cancelToken.isCancelled) return;
      if (mounted) {
        final fallback = LocalPlaceService().getPlacesSync(
          latitude: loc?.latitude ?? cameraCenter.latitude,
          longitude: loc?.longitude ?? cameraCenter.longitude,
        );
        setState(() {
          _visiblePlaces = fallback;
          _isLoadingPlaces = false;
          _hasPlacesError = fallback.isEmpty;
        });
        _fitPreviewBounds();
      }
      debugPrint('Overpass bbox error: ${e.message}');
    } catch (e) {
      if (cancelToken.isCancelled) return;
      if (mounted) {
        final fallback = LocalPlaceService().getPlacesSync(
          latitude: loc?.latitude ?? cameraCenter.latitude,
          longitude: loc?.longitude ?? cameraCenter.longitude,
        );
        setState(() {
          _visiblePlaces = fallback;
          _isLoadingPlaces = false;
          _hasPlacesError = fallback.isEmpty;
        });
        _fitPreviewBounds();
      }
      debugPrint('Overpass error: $e');
    }
  }

  void _fitPreviewBounds() {
    final loc = ref.read(locationProvider).coordinates;
    final points = <LatLng>[];
    if (loc != null) {
      points.add(LatLng(loc.latitude, loc.longitude));
    }
    final previewPlaces = limitPlacesForPreview(_visiblePlaces, max: 12);
    for (final p in previewPlaces) {
      points.add(LatLng(p.latitude, p.longitude));
    }

    if (points.isNotEmpty) {
      if (points.length == 1) {
        _mapController.move(points.first, 15.0);
      } else {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(32.0),
            maxZoom: 16.5,
          ),
        );
      }
    }
  }

  // ==========================================
  // Pencarian Tempat Berdasarkan Nama
  // ==========================================

  void _onSearchInputChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _searchDebounceTimer?.cancel();
      _searchCancelToken?.cancel('Empty query');
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchHasSearched = false;
        _showSearchDropdown = false;
      });
      return;
    }

    setState(() {
      _showSearchDropdown = true;
      _isSearching = true;
    });

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearchByName(query);
    });
  }

  Future<void> _executeSearchByName(String query) async {
    _searchCancelToken?.cancel('New query');
    final cancelToken = CancelToken();
    _searchCancelToken = cancelToken;

    final loc = ref.read(locationProvider).coordinates;
    final centerLat = _mapController.camera.center.latitude;
    final centerLng = _mapController.camera.center.longitude;
    final placeService = ref.read(placeServiceProvider);

    try {
      final results = await placeService.searchByName(
        query: query,
        latitude: centerLat != 0
            ? centerLat
            : (loc?.latitude ?? UserCoordinates.defaultKaliurang.latitude),
        longitude: centerLng != 0
            ? centerLng
            : (loc?.longitude ?? UserCoordinates.defaultKaliurang.longitude),
        radiusMeters: 5000,
        cancelToken: cancelToken,
      );

      if (mounted && !cancelToken.isCancelled) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _searchHasSearched = true;
        });
      }
    } catch (e) {
      if (cancelToken.isCancelled) return;
      if (mounted) {
        final localFallback = await LocalPlaceService().searchByName(
          query: query,
          latitude: centerLat != 0
              ? centerLat
              : (loc?.latitude ?? UserCoordinates.defaultKaliurang.latitude),
          longitude: centerLng != 0
              ? centerLng
              : (loc?.longitude ?? UserCoordinates.defaultKaliurang.longitude),
        );
        setState(() {
          _searchResults = localFallback;
          _isSearching = false;
          _searchHasSearched = true;
        });
      }
      debugPrint('Search Overpass error: $e');
    }
  }

  void _onSelectSearchedPlace(Place place) {
    setState(() {
      _showSearchDropdown = false;
      _selectedPlace = place;
    });
    FocusScope.of(context).unfocus();

    if (!_visiblePlaces.any((p) => p.id == place.id)) {
      _visiblePlaces.insert(0, place);
    }

    _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
    _scrollToPlaceCard(place.id);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSearchDropdown = false;
      _isSearching = false;
      _searchHasSearched = false;
    });
  }

  // ==========================================
  // Interaksi Tempat & Peta
  // ==========================================

  void _selectPlace(Place place) {
    setState(() {
      _selectedPlace = place;
    });
    _scrollToPlaceCard(place.id);
  }

  void _scrollToPlaceCard(String placeId) {
    final key = _placeCardKeys[placeId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  void _centerToUserLocation() {
    final loc = ref.read(locationProvider).coordinates;
    if (loc != null) {
      _mapController.move(LatLng(loc.latitude, loc.longitude), 16.0);
    } else {
      _mapController.move(kDefaultNearbyCenter, 15.0);
      showAppToast(context, 'Lokasi pengguna belum didapat');
    }
  }

  Future<void> _handleOpenMaps(BuildContext context) async {
    final loc = ref.read(locationProvider).coordinates;
    final centerLat = _mapController.camera.center.latitude;
    final centerLng = _mapController.camera.center.longitude;
    final fallbackCenter = centerLat != 0 && centerLng != 0
        ? LatLng(centerLat, centerLng)
        : kDefaultNearbyCenter;

    final success = await openGoogleMaps(
      selectedPlace: _selectedPlace,
      userLocation: loc != null ? LatLng(loc.latitude, loc.longitude) : null,
      fallbackCenter: fallbackCenter,
    );

    if (!success && context.mounted) {
      showAppToast(context, 'Tidak bisa membuka Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locState = ref.watch(locationProvider);
    final bottomInset = bottomGap(context);

    // Filter daftar tempat terurut jarak (maks 10 untuk daftar bawah)
    final sortedPlaces = List<Place>.from(_visiblePlaces)
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    final displayedPlaces = sortedPlaces.take(10).toList();

    return PageWithHeader(
      body: Stack(
        children: [
          // Kolom Scroll Utama
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(top: 16.0, bottom: bottomInset + 88.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. Banner Status / Akurasi Lokasi
                _buildAccuracyBanner(palette, locState),

                // 1. Search Bar "Cari warung makan…" di atas kartu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildSearchBar(palette),
                ),

                // Dropdown Hasil Pencarian
                if (_showSearchDropdown)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildSearchDropdown(palette),
                  ),

                const SizedBox(height: 16.0),

                // 2. KARTU PETA (Preview, Pill Peta Penuh, Pill Status, Tombol Open Maps & Pusatkan)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildMapCard(palette, locState),
                ),

                const SizedBox(height: 24.0),

                // 3. DAFTAR "Pilihan Di Sekitarmu" + "{n} tempat"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildPlacesListSection(palette, displayedPlaces),
                ),
              ],
            ),
          ),

          // Overlay Dialog Rationale / Izin Lokasi Melayang (jika aktif)
          _buildPermissionOverlay(context, palette, locState),
        ],
      ),
    );
  }

  // ==========================================
  // Komponen Kartu Peta (Preview + Controls)
  // ==========================================

  Widget _buildMapCard(AppPalette palette, LocationState locState) {
    final previewPlaces = limitPlacesForPreview(_visiblePlaces, max: 12);
    final userLoc = locState.coordinates != null
        ? LatLng(
            locState.coordinates!.latitude,
            locState.coordinates!.longitude,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: AppShadows.card,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul "Warung Makan Terdekat" (18/700 textStrong)
          Text(
            'Warung Makan Terdekat',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.0,
              fontWeight: FontWeight.w700,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 2.0),

          // Subjudul (12 sekunder)
          Text(
            'Buka Maps untuk menemukan warung makan di sekitarmu.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14.0),

          // Preview Peta Tinggi ±220 Radius 16 (Interaksi gesture/zoom nonaktif)
          ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: SizedBox(
              height: 220.0,
              width: double.infinity,
              child: Stack(
                children: [
                  RealMapView(
                    mapController: _mapController,
                    places: previewPlaces,
                    selectedPlaceId: _selectedPlace?.id,
                    onSelectPlace: _selectPlace,
                    userLocation: userLoc,
                    accuracyM: locState.accuracyM,
                    isInteractive:
                        false, // Nonaktif agar tidak mengganggu scroll halaman
                  ),

                  // Atribusi OSM di sudut kanan bawah preview
                  Positioned(
                    right: 8.0,
                    bottom: 8.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 8.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Pill Putih "Peta Penuh" di Kanan Atas
                  Positioned(
                    top: 10.0,
                    right: 10.0,
                    child: Semantics(
                      label: 'Buka Peta Penuh',
                      button: true,
                      child: GestureDetector(
                        key: const ValueKey('btn-peta-penuh'),
                        onTap: () {
                          context.push('/nearby/map', extra: _selectedPlace);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(999.0),
                            boxShadow: AppShadows.card,
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.maximize2,
                                size: 13.0,
                                color: palette.textStrong,
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                'Peta Penuh',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pill Status di Kiri Bawah Preview
                  Positioned(
                    left: 10.0,
                    bottom: 10.0,
                    child: _buildStatusPill(palette),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14.0),

          // Baris Tombol: "Open Maps" + Tombol Ikon Persegi "Pusatkan ke lokasi saya"
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Open Maps',
                  icon: const Icon(LucideIcons.externalLink, size: 18),
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  onPressed: () => _handleOpenMaps(context),
                ),
              ),
              const SizedBox(width: 10.0),
              Semantics(
                label: 'Pusatkan ke lokasi saya',
                button: true,
                child: Tooltip(
                  message: 'Pusatkan ke lokasi saya',
                  child: InkWell(
                    key: const ValueKey('btn-pusatkan'),
                    onTap: _centerToUserLocation,
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      width: 48.0,
                      height: 48.0,
                      decoration: BoxDecoration(
                        color: palette.chip,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: palette.border),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.crosshair,
                        size: 20.0,
                        color: palette.textStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(AppPalette palette) {
    Widget content;
    if (_isLoadingPlaces) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12.0,
            height: 12.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(palette.actionBg),
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            'Mencari warung makan…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
              color: palette.textStrong,
            ),
          ),
        ],
      );
    } else if (_hasPlacesError) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Gagal memuat · ',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.0,
              color: palette.danger,
            ),
          ),
          GestureDetector(
            onTap: _fetchPlacesForCurrentCamera,
            child: Text(
              'Coba lagi',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                color: palette.accent,
              ),
            ),
          ),
        ],
      );
    } else if (_visiblePlaces.isEmpty) {
      content = Text(
        'Tidak ada warung makan di sekitar sini',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11.0,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
      );
    } else {
      content = Text(
        '${_visiblePlaces.length} warung makan ditemukan',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: palette.textStrong,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999.0),
        boxShadow: AppShadows.card,
        border: Border.all(color: palette.border),
      ),
      child: content,
    );
  }

  // ==========================================
  // Daftar "Pilihan Di Sekitarmu"
  // ==========================================

  Widget _buildPlacesListSection(AppPalette palette, List<Place> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul Section & Jumlah Tempat
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Pilihan Di Sekitarmu',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              '${places.length} tempat',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // Daftar Kartu Tempat
        if (places.isEmpty)
          Container(
            padding: const EdgeInsets.all(24.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              _isLoadingPlaces
                  ? 'Memuat tempat makan terdekat…'
                  : 'Belum ada warung makan yang ditemukan di area ini.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.0,
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: places.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10.0),
            itemBuilder: (context, index) {
              final place = places[index];
              return _buildPlaceCard(place, palette);
            },
          ),
      ],
    );
  }

  Widget _buildPlaceCard(Place place, AppPalette palette) {
    final isSelected = place.id == _selectedPlace?.id;
    final cardKey = _placeCardKeys.putIfAbsent(place.id, () => GlobalKey());

    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isSelected ? palette.accent : palette.border,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () => _selectPlace(place),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Ikon Badge Jenis Tempat
                Container(
                  width: 42.0,
                  height: 42.0,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.accent
                        : palette.actionBg.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    getPlaceMarkerIcon(place.type),
                    size: 20.0,
                    color: isSelected ? palette.actionBg : palette.actionBg,
                  ),
                ),
                const SizedBox(width: 12.0),

                // Kolom Informasi Tempat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text(
                        '${place.cuisine} · Rp${place.priceMin}–${place.priceMax} rb',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: palette.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        '${place.distanceM} m · ${place.walkMin} menit',
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

                // Badge Buka / Tutup (TANPA TOMBOL RUTE)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: place.open
                        ? palette.actionBg.withValues(alpha: 0.1)
                        : palette.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    place.open ? 'Buka' : 'Tutup',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: place.open ? palette.actionBg : palette.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Search Bar & Floating Results
  // ==========================================

  Widget _buildSearchBar(AppPalette palette) {
    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: AppShadows.card,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14.0),
          Icon(LucideIcons.search, size: 18.0, color: palette.textSecondary),
          const SizedBox(width: 10.0),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: palette.textStrong,
              ),
              decoration: InputDecoration(
                hintText: 'Cari warung makan…',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                LucideIcons.x,
                size: 16.0,
                color: palette.textSecondary,
              ),
              onPressed: _clearSearch,
            )
          else
            const SizedBox(width: 10.0),
        ],
      ),
    );
  }

  Widget _buildSearchDropdown(AppPalette palette) {
    return Container(
      margin: const EdgeInsets.only(top: 6.0),
      constraints: const BoxConstraints(maxHeight: 280.0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: AppShadows.card,
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: _isSearching
            ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.actionBg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      'Mencari tempat makan…',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.0,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : (_searchResults.isEmpty && _searchHasSearched)
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tempat makan tidak ditemukan',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Coba kata kunci lain atau periksa koneksi',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    AppButton(
                      label: 'Coba lagi',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      onPressed: () {
                        _executeSearchByName(_searchController.text.trim());
                      },
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                shrinkWrap: true,
                itemCount: _searchResults.length.clamp(0, 8),
                separatorBuilder: (context, index) => Divider(
                  height: 1.0,
                  color: palette.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        getPlaceMarkerIcon(place.type),
                        size: 18.0,
                        color: palette.actionBg,
                      ),
                      title: Text(
                        place.name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: palette.textStrong,
                        ),
                      ),
                      subtitle: Text(
                        '${place.cuisine} · ${place.distanceM} m',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.0,
                          color: palette.textSecondary,
                        ),
                      ),
                      onTap: () => _onSelectSearchedPlace(place),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ==========================================
  // Banner Akurasi / Lokasi Belum Didapat
  // ==========================================

  Widget _buildAccuracyBanner(AppPalette palette, LocationState locState) {
    if (locState.status == LocationStatus.checking ||
        locState.status == LocationStatus.requesting) {
      return const SizedBox.shrink();
    }

    if (locState.isMocked) {
      return Container(
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: palette.accent),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.alertCircle, size: 16.0, color: palette.actionBg),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Lokasi tiruan terdeteksi. Posisi mungkin tidak mencerminkan lokasi nyata Anda.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.0,
                  color: palette.textStrong,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (locState.askedInSession) {
      return Container(
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: palette.chip,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.mapPinOff,
              size: 16.0,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Lokasi belum aktif.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  color: palette.textSecondary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                ref.read(locationProvider.notifier).requestLocationPermission();
              },
              child: Text(
                'Aktifkan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: palette.actionBg,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (locState.status == LocationStatus.granted &&
        locState.accuracyM != null &&
        locState.accuracyM! > 100.0) {
      return Container(
        margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: palette.chip,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 16.0, color: palette.textSecondary),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Akurasi perkiraan ±${locState.accuracyM!.round()} m. Pindah ke area terbuka untuk akurasi lebih baik.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.0,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ==========================================
  // Dialog/Overlay Izin Lokasi Melayang
  // ==========================================

  Widget _buildPermissionOverlay(
    BuildContext context,
    AppPalette palette,
    LocationState locState,
  ) {
    if (locState.askedInSession) return const SizedBox.shrink();

    if (locState.status == LocationStatus.needsRationale) {
      return _buildFloatingPermissionCard(
        context: context,
        palette: palette,
        icon: LucideIcons.mapPin,
        title: 'Izinkan akses lokasi',
        description: 'Foodie.id memakai lokasimu untuk menampilkan tempat makan terdekat dan rute jalan. Lokasimu tidak disimpan.',
        primaryButtonLabel: 'Izinkan lokasi',
        onPrimaryPressed: () {
          ref.read(locationProvider.notifier).requestLocationPermission();
        },
        secondaryButtonLabel: 'Nanti saja',
        onSecondaryPressed: () {
          ref.read(locationProvider.notifier).dismissRationale();
        },
      );
    }

    if (locState.status == LocationStatus.denied) {
      return _buildFloatingPermissionCard(
        context: context,
        palette: palette,
        icon: LucideIcons.mapPinOff,
        title: 'Izin lokasi ditolak',
        description: 'Aplikasi membutuhkan izin lokasi untuk menampilkan warung makan terdekat secara akurat.',
        primaryButtonLabel: 'Coba lagi',
        onPrimaryPressed: () {
          ref.read(locationProvider.notifier).requestLocationPermission();
        },
        secondaryButtonLabel: 'Nanti saja',
        onSecondaryPressed: () {
          ref.read(locationProvider.notifier).dismissRationale();
        },
      );
    }

    if (locState.status == LocationStatus.deniedForever) {
      return _buildFloatingPermissionCard(
        context: context,
        palette: palette,
        icon: LucideIcons.mapPinOff,
        title: 'Izin lokasi ditolak permanen',
        description: 'Izin lokasi telah dinonaktifkan secara permanen. Buka Pengaturan aplikasi untuk mengizinkan akses lokasi.',
        primaryButtonLabel: 'Buka Pengaturan',
        onPrimaryPressed: () {
          ref.read(locationProvider.notifier).openAppSettings();
        },
        secondaryButtonLabel: 'Nanti saja',
        onSecondaryPressed: () {
          ref.read(locationProvider.notifier).dismissRationale();
        },
      );
    }

    if (locState.status == LocationStatus.serviceOff) {
      return _buildFloatingPermissionCard(
        context: context,
        palette: palette,
        icon: LucideIcons.mapPinOff,
        title: 'Layanan GPS dinonaktifkan',
        description: 'Aktifkan GPS pada perangkat Anda untuk menemukan rekomendasi warung makan di sekitarmu.',
        primaryButtonLabel: 'Aktifkan GPS',
        onPrimaryPressed: () {
          ref.read(locationProvider.notifier).openLocationSettings();
        },
        secondaryButtonLabel: 'Nanti saja',
        onSecondaryPressed: () {
          ref.read(locationProvider.notifier).dismissRationale();
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFloatingPermissionCard({
    required BuildContext context,
    required AppPalette palette,
    required IconData icon,
    required String title,
    required String description,
    required String primaryButtonLabel,
    required VoidCallback onPrimaryPressed,
    required String secondaryButtonLabel,
    required VoidCallback onSecondaryPressed,
  }) {
    final navBarTop = bottomGap(context) + 75.0;
    return Positioned(
      left: 16.0,
      right: 16.0,
      bottom: navBarTop + 18.0,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: AppShadows.card,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: palette.actionBg, size: 24.0),
            ),
            const SizedBox(height: 12.0),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                height: 1.4,
                color: palette.textBody,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: secondaryButtonLabel,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.md,
                    onPressed: onSecondaryPressed,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: AppButton(
                    label: primaryButtonLabel,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.md,
                    onPressed: onPrimaryPressed,
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
