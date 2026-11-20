import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
import '../services/location_service.dart';
import '../services/place_service.dart';
import '../services/route_service.dart';
import '../widgets/illustrated_map.dart';
import '../widgets/page_with_header.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/sticky_bottom_bar.dart';

/// Halaman Nearby (/nearby) sesuai PRD §6.8, §14.12, §14.2, §14.5, §17.7:
/// - PETA PENUH (Full-screen map) interaktif OpenStreetMap.
/// - Alur izin lokasi on-demand (saat Nearby dibuka, bukan saat app start).
/// - Kartu penjelasan melayang (rationale), penanganan denied, deniedForever, dan GPS off.
/// - Akurasi tinggi & lingkaran akurasi (CircleLayer radius meter).
/// - JANGAN PERNAH menampilkan pusat default sebagai titik pengguna (§17.7).
/// - Banner akurasi > 100m, banner lokasi belum didapat, badge lokasi tiruan (mock).
/// - Titik-titik tempat makan Overpass nyata (node & way, batas 80 titik, zoom >= 14).
/// - Debounce kamera 600 ms & cache bbox 10 menit.
/// - Search bar melayang di atas ("Cari warung makan…", debounce 400 ms, max 8 hasil).
/// - Kartu info tempat terpilih melayang di atas BottomNav.
/// - Tombol "Pusatkan" dan teks atribusi lisensi OSM.
class NearbyPage extends ConsumerStatefulWidget {
  const NearbyPage({super.key});

  @override
  ConsumerState<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends ConsumerState<NearbyPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Kamera & Data Tempat
  List<Place> _visiblePlaces = [];
  bool _isLoadingPlaces = false;
  bool _isZoomTooLow = false;
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

  // Tempat Terpilih & Rute
  Place? _selectedPlace;
  RouteResult? _routeResult;
  bool _isLoadingRoute = false;
  CancelToken? _routeCancelToken;

  // Fallback Peta
  int _tileErrorCount = 0;
  bool _isFallbackIllustrated = false;

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
    _routeCancelToken?.cancel('Disposed');
    _searchController.dispose();
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
        // Cek ulang otomatis saat kembali ke foreground (§17.7)
        ref.read(locationProvider.notifier).checkLocationStatus();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(locationProvider.notifier).pauseStream();
    }
  }

  // ==========================================
  // Kamera Peta & Bounding Box (Overpass POI)
  // ==========================================

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (camera.zoom < 14.0) {
      if (!_isZoomTooLow) {
        setState(() {
          _isZoomTooLow = true;
        });
      }
      _cameraDebounceTimer?.cancel();
      return;
    }

    if (_isZoomTooLow) {
      setState(() {
        _isZoomTooLow = false;
      });
    }

    // Debounce 600 ms saat kamera berhenti bergerak
    _cameraDebounceTimer?.cancel();
    _cameraDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _fetchPlacesForBounds(camera.visibleBounds);
      }
    });
  }

  void _fetchPlacesForCurrentCamera() {
    final zoom = _mapController.camera.zoom;
    if (zoom < 14.0) {
      setState(() => _isZoomTooLow = true);
      return;
    }
    setState(() => _isZoomTooLow = false);
    _fetchPlacesForBounds(_mapController.camera.visibleBounds);
  }

  Future<void> _fetchPlacesForBounds(LatLngBounds bounds) async {
    // Batalkan request bbox yang sedang berjalan
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
      }
      debugPrint('Overpass error: $e');
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

    // Debounce 400 ms untuk pencarian nama
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
      _routeResult = null;
    });
    FocusScope.of(context).unfocus();

    // Pastikan tempat masuk ke marker visible bila belum ada
    if (!_visiblePlaces.any((p) => p.id == place.id)) {
      _visiblePlaces.add(place);
    }

    // Pindahkan kamera ke tempat terpilih
    _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
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
  // Pemilihan Tempat & Routing OSRM
  // ==========================================

  void _selectPlace(Place place) {
    setState(() {
      _selectedPlace = place;
      _routeResult = null;
    });
  }

  void _deselectPlace() {
    setState(() {
      _selectedPlace = null;
      _routeResult = null;
      _showSearchDropdown = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchRouteForPlace(Place place) async {
    final locState = ref.read(locationProvider);
    if (locState.coordinates == null) {
      showAppToast(context, 'Aktifkan lokasi untuk melihat rute');
      await ref.read(locationProvider.notifier).requestLocationPermission();
      return;
    }

    _routeCancelToken?.cancel('New route requested');
    final cancelToken = CancelToken();
    _routeCancelToken = cancelToken;

    setState(() {
      _isLoadingRoute = true;
    });

    final loc = locState.coordinates!;
    final start = LatLng(loc.latitude, loc.longitude);
    final destination = LatLng(place.latitude, place.longitude);

    showAppToast(context, 'Membuka rute ke ${place.name}');

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

      // Fit bounds kamera ke jalur rute
      if (result.points.length >= 2) {
        final bounds = LatLngBounds.fromPoints(result.points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(
              left: 48.0,
              right: 48.0,
              top: 100.0,
              bottom: AppShell.bottomNavPadding + 140.0,
            ),
            maxZoom: 17.0,
          ),
        );
      }
    }
  }

  Future<void> _centerToUser() async {
    final locState = ref.read(locationProvider);
    if (locState.coordinates != null) {
      _mapController.move(
        LatLng(locState.coordinates!.latitude, locState.coordinates!.longitude),
        15.5,
      );
      showAppToast(context, 'Peta dipusatkan ke lokasi kamu');
    } else {
      showAppToast(context, 'Mencari lokasi kamu…');
      await ref.read(locationProvider.notifier).refreshLocation();
      if (!mounted) return;
      final updated = ref.read(locationProvider);
      if (updated.coordinates != null) {
        _mapController.move(
          LatLng(updated.coordinates!.latitude, updated.coordinates!.longitude),
          15.5,
        );
        showAppToast(context, 'Peta dipusatkan ke lokasi kamu');
      } else {
        showAppToast(context, 'Lokasi belum didapat');
      }
    }
  }

  // ==========================================
  // Build Widget
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final navBarTop = bottomGap(context) + 75.0;
    final locState = ref.watch(locationProvider);
    final userCoords = locState.coordinates;
    final userLatLng = userCoords != null
        ? LatLng(userCoords.latitude, userCoords.longitude)
        : const LatLng(-7.7653, 110.3789);
    final userPrimary = palette.isDark ? palette.accent : palette.actionBg;

    return PageWithHeader(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Layer Peta Penuh
          if (_isFallbackIllustrated)
            IllustratedMap(
              places: const [],
              height: double.infinity,
              onCenterTap: _centerToUser,
              onSwitchToRealMap: () {
                setState(() {
                  _isFallbackIllustrated = false;
                  _tileErrorCount = 0;
                });
              },
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userLatLng,
                initialZoom: 15.0,
                minZoom: 10.0,
                maxZoom: 18.0,
                onTap: (tapPosition, point) => _deselectPlace(),
                onPositionChanged: _onPositionChanged,
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.foodie.foodie',
                  tileBuilder: (context, tileWidget, tile) {
                    if (palette.isDark) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          -0.75,
                          0,
                          0,
                          0,
                          255,
                          0,
                          -0.75,
                          0,
                          0,
                          255,
                          0,
                          0,
                          -0.75,
                          0,
                          255,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: tileWidget,
                      );
                    }
                    return tileWidget;
                  },
                  errorTileCallback: (tile, error, stackTrace) {
                    _tileErrorCount++;
                    if (_tileErrorCount >= 4 && !_isFallbackIllustrated) {
                      setState(() => _isFallbackIllustrated = true);
                      showAppToast(
                        context,
                        'Koneksi peta bermasalah, beralih ke peta ilustrasi',
                      );
                    }
                  },
                ),

                // Layer Lingkaran Akurasi (CircleLayer) sesuai PRD §17.7
                if (locState.status == LocationStatus.granted &&
                    userCoords != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: userLatLng,
                        radius: (locState.accuracyM ?? 30.0).clamp(10.0, 500.0),
                        useRadiusInMeter: true,
                        color: palette.accent.withValues(alpha: 0.15),
                        borderColor: palette.accent.withValues(alpha: 0.4),
                        borderStrokeWidth: 1.0,
                      ),
                    ],
                  ),

                // Layer Rute Polyline
                if (_routeResult != null && _routeResult!.points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeResult!.points,
                        strokeWidth: 4.0,
                        color: userPrimary,
                        pattern: _routeResult!.isStraightLineFallback
                            ? StrokePattern.dashed(segments: const [8, 6])
                            : const StrokePattern.solid(),
                      ),
                    ],
                  ),

                // Layer Marker
                MarkerLayer(
                  markers: [
                    // Marker Lokasi Pengguna
                    // PENTING: JANGAN PERNAH me-render marker pengguna bila tidak ada fix GPS nyata (§17.7)
                    if (locState.status == LocationStatus.granted &&
                        userCoords != null)
                      Marker(
                        point: userLatLng,
                        width: 32.0,
                        height: 32.0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 30.0,
                              height: 30.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: userPrimary.withValues(alpha: 0.25),
                              ),
                            ),
                            Container(
                              width: 16.0,
                              height: 16.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: userPrimary,
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.shadowColor,
                                    blurRadius: 4.0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 6.0,
                                  height: 6.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: palette.surface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Marker Tempat Makan (Penanda Titik Lingkaran Kecil)
                    for (final place in _visiblePlaces) ...[
                      () {
                        final isSelected = _selectedPlace?.id == place.id;
                        final pinColor = isSelected
                            ? palette.accent
                            : (palette.isDark
                                  ? palette.surfaceAlt
                                  : palette.actionBg);

                        return Marker(
                          point: LatLng(place.latitude, place.longitude),
                          width: 26.0,
                          height: 26.0,
                          child: GestureDetector(
                            key: ValueKey('pin-${place.id}'),
                            onTap: () => _selectPlace(place),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 26.0 : 20.0,
                              height: isSelected ? 26.0 : 20.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: pinColor,
                                border: Border.all(
                                  color: palette.surface,
                                  width: isSelected ? 2.5 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.shadowColor,
                                    blurRadius: 4.0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: isSelected ? 8.0 : 6.0,
                                  height: isSelected ? 8.0 : 6.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: palette.surface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ],
            ),

          // 2. Overlay: Kolom Pencarian Melayang di Atas (Pill ±44px)
          Positioned(
            top: 14.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input Search Bar
                Container(
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(999.0),
                    border: Border.all(color: palette.border),
                    boxShadow: AppShadows.card,
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
                            hintText: 'Cari warung makan…',
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
                      if (_isSearching)
                        SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.actionBg,
                            ),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: Icon(
                            LucideIcons.x,
                            size: 16.0,
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),

                // Dropdown Hasil Pencarian Melayang
                if (_showSearchDropdown) ...[
                  const SizedBox(height: 6.0),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280.0),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: AppRadius.cardLarge,
                      boxShadow: AppShadows.card,
                      border: Border.all(color: palette.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14.0,
                                    height: 14.0,
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
                                      fontSize: 12.0,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _searchResults.isEmpty && _searchHasSearched
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tempat makan tidak ditemukan',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Coba kata kunci lain atau periksa koneksi',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.0,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10.0),
                                AppButton(
                                  label: 'Coba lagi',
                                  variant: AppButtonVariant.soft,
                                  size: AppButtonSize.sm,
                                  onPressed: () {
                                    _executeSearchByName(
                                      _searchController.text.trim(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1.0,
                              thickness: 1.0,
                              color: palette.border,
                            ),
                            itemBuilder: (context, index) {
                              final p = _searchResults[index];
                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    p.name,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textStrong,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${p.cuisine} · ${p.distanceM} m',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.0,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                  trailing: Icon(
                                    LucideIcons.chevronRight,
                                    size: 16.0,
                                    color: palette.textSecondary,
                                  ),
                                  onTap: () => _onSelectSearchedPlace(p),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Overlay: Petunjuk Zoom < 14 / Loading Tempat
          if (_isZoomTooLow && !_showSearchDropdown)
            Positioned(
              top: 68.0,
              left: 16.0,
              right: 16.0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999.0),
                    border: Border.all(color: palette.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.zoomIn,
                        size: 15.0,
                        color: palette.actionBg,
                      ),
                      const SizedBox(width: 6.0),
                      Flexible(
                        child: Text(
                          'Perbesar peta untuk melihat tempat makan',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            color: palette.textStrong,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isLoadingPlaces && !_showSearchDropdown)
            Positioned(
              top: 68.0,
              left: 16.0,
              right: 16.0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999.0),
                    border: Border.all(color: palette.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12.0,
                        height: 12.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.actionBg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Text(
                          'Memuat tempat makan…',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                            color: palette.textStrong,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Overlay: Banner Error Overpass & Coba Lagi
          if (_hasPlacesError && !_isZoomTooLow && !_showSearchDropdown)
            Positioned(
              top: 68.0,
              left: 16.0,
              right: 16.0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: palette.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999.0),
                    border: Border.all(color: palette.danger),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Gagal memuat tempat makan',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            color: palette.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      GestureDetector(
                        onTap: _fetchPlacesForCurrentCamera,
                        child: Text(
                          'Coba lagi',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: palette.actionBg,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Overlay Banners Status Akurasi & Izin Lokasi (§17.7)
          if (!_isZoomTooLow &&
              !_isLoadingPlaces &&
              !_hasPlacesError &&
              !_showSearchDropdown) ...[
            // Banner Lokasi Belum Aktif (setelah klik "Nanti saja")
            if (locState.status != LocationStatus.granted &&
                locState.askedInSession)
              Positioned(
                top: 68.0,
                left: 16.0,
                right: 16.0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(color: palette.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.mapPinOff,
                          size: 14.0,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          'Lokasi belum aktif · ',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            color: palette.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          key: const ValueKey('activate-location-banner-btn'),
                          onTap: () {
                            ref
                                .read(locationProvider.notifier)
                                .requestLocationPermission();
                          },
                          child: Text(
                            'Aktifkan',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: palette.actionBg,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            // Banner Lokasi Belum Didapat
            else if (locState.status == LocationStatus.granted &&
                userCoords == null)
              Positioned(
                top: 68.0,
                left: 16.0,
                right: 16.0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(color: palette.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12.0,
                          height: 12.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.actionBg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          'Lokasi belum didapat',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            color: palette.textStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            // Banner Lokasi Kurang Akurat (> 100m)
            else if (userCoords != null && (locState.accuracyM ?? 0.0) > 100.0)
              Positioned(
                top: 68.0,
                left: 16.0,
                right: 16.0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(color: Colors.amber.shade700),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 13.0,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 6.0),
                        Flexible(
                          child: Text(
                            'Lokasi kurang akurat - keluar ruangan atau aktifkan lokasi presisi',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Badge Debug Lokasi Tiruan (isMocked)
            if (userCoords != null && userCoords.isMocked)
              Positioned(
                top: 104.0,
                right: 16.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: palette.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: palette.danger),
                  ),
                  child: Text(
                    'Lokasi tiruan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      color: palette.danger,
                    ),
                  ),
                ),
              ),
          ],

          // 6. Overlay: Atribusi OpenStreetMap (Kiri Bawah)
          Positioned(
            left: 16.0,
            bottom: _selectedPlace != null
                ? (_routeResult != null ? navBarTop + 88.0 : navBarTop + 196.0)
                : navBarTop + 24.0,
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
                  fontSize: 8.0,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),

          // 7. Overlay: Tombol "Pusatkan" (Kanan Bawah)
          Positioned(
            right: 16.0,
            bottom: _selectedPlace != null
                ? (_routeResult != null ? navBarTop + 88.0 : navBarTop + 196.0)
                : navBarTop + 24.0,
            child: Semantics(
              label: 'Pusatkan ke lokasi saya',
              button: true,
              child: GestureDetector(
                onTap: _centerToUser,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(999.0),
                    border: Border.all(color: palette.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.crosshair,
                        size: 15.0,
                        color: palette.textStrong,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'Pusatkan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
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

          // 8. Overlay: Kartu Info Tempat Terpilih (Melayang di atas BottomNav)
          if (_selectedPlace != null)
            Positioned(
              left: 16.0,
              right: 16.0,
              bottom: navBarTop + 18.0,
              child: _routeResult != null
                  ? _buildMinimalistRouteCard(
                      context,
                      palette,
                      _selectedPlace!,
                      _routeResult!,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: AppShadows.card,
                        border: Border.all(color: palette.border),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Baris Atas: Nama Tempat & Tombol Tutup (x)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPlace!.name,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textStrong,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      _selectedPlace!.cuisine,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                key: const ValueKey('close-place-card'),
                                onTap: _deselectPlace,
                                child: Container(
                                  width: 28.0,
                                  height: 28.0,
                                  decoration: BoxDecoration(
                                    color: palette.chip,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 16.0,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8.0),

                          // Info Jam Buka & Jarak
                          Row(
                            children: [
                              // Status Buka / Jam
                              Text(
                                _selectedPlace!.open
                                    ? 'Buka'
                                    : (_selectedPlace!.isUnknownHours
                                          ? 'Jam belum tercatat'
                                          : 'Tutup'),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedPlace!.open
                                      ? palette.actionBg
                                      : (_selectedPlace!.isUnknownHours
                                            ? palette.textSecondary
                                            : palette.danger),
                                ),
                              ),
                              if (_selectedPlace!.openingHours != null &&
                                  _selectedPlace!.openingHours!.isNotEmpty) ...[
                                Flexible(
                                  child: Text(
                                    ' · ${_selectedPlace!.openingHours}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.0,
                                      color: palette.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Jarak & Waktu
                              Text(
                                '${_selectedPlace!.distanceM} m · ${_selectedPlace!.walkMin} menit',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w500,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12.0),

                          // Tombol Rute
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              label: _isLoadingRoute ? 'Memuat rute…' : 'Rute',
                              icon: const Icon(
                                LucideIcons.navigation,
                                size: 16.0,
                              ),
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.md,
                              isLoading: _isLoadingRoute,
                              onPressed: _isLoadingRoute
                                  ? null
                                  : () => _fetchRouteForPlace(_selectedPlace!),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

          // 9. Overlay: Kartu Penjelasan / Rationale & Status Izin (§17.7 & PRD §14.12)
          if (!locState.askedInSession && _selectedPlace == null) ...[
            // (a) Rationale: Belum diizinkan
            if (locState.status == LocationStatus.needsRationale)
              _buildFloatingPermissionCard(
                context: context,
                palette: palette,
                icon: LucideIcons.mapPin,
                title: 'Izinkan akses lokasi',
                description: 'Foodie.id memakai lokasimu untuk menampilkan tempat makan terdekat dan rute jalan. Lokasimu tidak disimpan.',
                primaryButtonLabel: 'Izinkan lokasi',
                onPrimaryPressed: () {
                  ref
                      .read(locationProvider.notifier)
                      .requestLocationPermission();
                },
                secondaryButtonLabel: 'Nanti saja',
                onSecondaryPressed: () {
                  ref.read(locationProvider.notifier).dismissRationale();
                },
              )
            // (b) Denied: Izin ditolak biasa
            else if (locState.status == LocationStatus.denied)
              _buildFloatingPermissionCard(
                context: context,
                palette: palette,
                icon: LucideIcons.alertCircle,
                title: 'Izin lokasi ditolak',
                description: 'Foodie.id memerlukan izin lokasi untuk mengukur jarak dan menunjukkan rute ke warung makan terdekat.',
                primaryButtonLabel: 'Coba lagi',
                onPrimaryPressed: () {
                  ref
                      .read(locationProvider.notifier)
                      .requestLocationPermission();
                },
                secondaryButtonLabel: 'Nanti saja',
                onSecondaryPressed: () {
                  ref.read(locationProvider.notifier).dismissRationale();
                },
              )
            // (c) DeniedForever: Izin ditolak permanen
            else if (locState.status == LocationStatus.deniedForever)
              _buildFloatingPermissionCard(
                context: context,
                palette: palette,
                icon: LucideIcons.settings,
                title: 'Izin lokasi dimatikan',
                description: 'Akses lokasi dimatikan permanen di pengaturan sistem. Buka Pengaturan aplikasi untuk mengizinkannya.',
                primaryButtonLabel: 'Buka Pengaturan',
                onPrimaryPressed: () {
                  ref.read(locationProvider.notifier).openAppSettings();
                },
                secondaryButtonLabel: 'Nanti saja',
                onSecondaryPressed: () {
                  ref.read(locationProvider.notifier).dismissRationale();
                },
              )
            // (d) ServiceOff: GPS Mati
            else if (locState.status == LocationStatus.serviceOff)
              _buildFloatingPermissionCard(
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
              )
            // (e) Reduced Accuracy (Android 12+ / iOS 14+)
            else if (locState.isReducedAccuracy &&
                locState.status == LocationStatus.granted)
              _buildFloatingPermissionCard(
                context: context,
                palette: palette,
                icon: LucideIcons.alertTriangle,
                title: 'Lokasi presisi dimatikan',
                description: 'Aplikasi hanya menerima perkiraan lokasi. Aktifkan lokasi presisi di Pengaturan untuk panduan rute yang akurat.',
                primaryButtonLabel: 'Aktifkan lokasi presisi',
                onPrimaryPressed: () {
                  ref.read(locationProvider.notifier).openAppSettings();
                },
                secondaryButtonLabel: 'Nanti saja',
                onSecondaryPressed: () {
                  ref.read(locationProvider.notifier).dismissRationale();
                },
              ),
          ],
        ],
      ),
    );
  }

  /// Helper untuk membangun kartu melayang dialog izin/status lokasi
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

  /// Helper untuk membangun kartu alert minimalis saat rute sedang aktif
  Widget _buildMinimalistRouteCard(
    BuildContext context,
    AppPalette palette,
    Place place,
    RouteResult route,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: AppShadows.card,
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: [
          // Icon rute navigasi
          Container(
            width: 38.0,
            height: 38.0,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.navigation,
              size: 18.0,
              color: palette.actionBg,
            ),
          ),
          const SizedBox(width: 12.0),

          // Info Tujuan & Jarak / Durasi
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  route.isStraightLineFallback
                      ? '${place.distanceM} m · garis lurus'
                      : route.distanceAndDurationString,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10.0),

          // Tombol Keluar Rute
          GestureDetector(
            key: const ValueKey('exit-route-btn'),
            onTap: () {
              setState(() {
                _routeResult = null;
              });
              showAppToast(context, 'Keluar dari panduan rute');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: palette.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: palette.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.xCircle, size: 13.0, color: palette.danger),
                  const SizedBox(width: 4.0),
                  Text(
                    'Keluar Rute',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: palette.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6.0),

          // Tombol Tutup (x)
          GestureDetector(
            key: const ValueKey('close-place-card'),
            onTap: _deselectPlace,
            child: Container(
              width: 28.0,
              height: 28.0,
              decoration: BoxDecoration(
                color: palette.chip,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.x,
                size: 15.0,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
