import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_shadows.dart';
import '../core/utils/nearby_map_utils.dart';
import '../models/models.dart';
import '../providers/location_provider.dart';
import '../providers/places_provider.dart';
import '../providers/ui_helper.dart';
import '../services/place_service.dart';
import '../widgets/real_map_view.dart';
import '../widgets/ui/app_button.dart';

/// Halaman Peta Penuh Interaktif (/nearby/map) di luar Shell (tanpa bottom nav)
/// sesuai PRD §14.12, §17.6 dan instruksi spesifikasi Nearby:
/// - Peta interaktif layar penuh (geser & zoom aktif).
/// - Komponen marker yang sama bertema palet Foodie.id.
/// - Tombol tutup / back di kiri atas (bg surface ber-shadow).
/// - Tombol Pusatkan ke lokasi saya di kanan bawah.
/// - Kartu info tempat terpilih (bila ada yang dipilih).
/// - Tombol "Open Maps" lebar penuh di bagian bawah (menghormati safe area / gesture bar).
/// - Memakai ulang logika fetch tempat/cache Overpass (bbox, debounce kamera 600 ms, cache).
class NearbyFullMapPage extends ConsumerStatefulWidget {
  final Place? initialSelectedPlace;

  const NearbyFullMapPage({super.key, this.initialSelectedPlace});

  @override
  ConsumerState<NearbyFullMapPage> createState() => _NearbyFullMapPageState();
}

class _NearbyFullMapPageState extends ConsumerState<NearbyFullMapPage> {
  final MapController _mapController = MapController();

  List<Place> _places = [];
  Place? _selectedPlace;
  bool _isLoadingPlaces = false;
  Timer? _cameraDebounceTimer;
  CancelToken? _bboxCancelToken;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.initialSelectedPlace;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = ref.read(locationProvider).coordinates;
      final initialCenter = _selectedPlace != null
          ? LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude)
          : (loc != null
                ? LatLng(loc.latitude, loc.longitude)
                : kDefaultNearbyCenter);

      _mapController.move(initialCenter, 15.5);
      _fetchPlacesForCurrentBounds();
    });
  }

  @override
  void dispose() {
    _cameraDebounceTimer?.cancel();
    _bboxCancelToken?.cancel('Page disposed');
    _mapController.dispose();
    super.dispose();
  }

  void _onCameraMove() {
    _cameraDebounceTimer?.cancel();
    _cameraDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchPlacesForCurrentBounds();
    });
  }

  void _fetchPlacesForCurrentBounds() {
    final zoom = _mapController.camera.zoom;
    if (zoom < 14.0) return;
    _fetchPlacesInBounds(_mapController.camera.visibleBounds);
  }

  Future<void> _fetchPlacesInBounds(LatLngBounds bounds) async {
    _bboxCancelToken?.cancel('New camera position');
    final cancelToken = CancelToken();
    _bboxCancelToken = cancelToken;

    setState(() => _isLoadingPlaces = true);

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
          _places = places.isNotEmpty
              ? places
              : LocalPlaceService().getPlacesSync(
                  latitude: loc?.latitude ?? cameraCenter.latitude,
                  longitude: loc?.longitude ?? cameraCenter.longitude,
                );
          _isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (cancelToken.isCancelled) return;
      if (mounted) {
        final fallback = LocalPlaceService().getPlacesSync(
          latitude: loc?.latitude ?? cameraCenter.latitude,
          longitude: loc?.longitude ?? cameraCenter.longitude,
        );
        setState(() {
          _places = fallback;
          _isLoadingPlaces = false;
        });
      }
    }
  }

  void _centerToUser() {
    final loc = ref.read(locationProvider).coordinates;
    if (loc != null) {
      _mapController.move(LatLng(loc.latitude, loc.longitude), 16.0);
    } else {
      _mapController.move(kDefaultNearbyCenter, 15.5);
    }
  }

  Future<void> _handleOpenMaps() async {
    final loc = ref.read(locationProvider).coordinates;
    final center = _mapController.camera.center;
    final success = await openGoogleMaps(
      selectedPlace: _selectedPlace,
      userLocation: loc != null ? LatLng(loc.latitude, loc.longitude) : null,
      fallbackCenter: center.latitude != 0 && center.longitude != 0
          ? LatLng(center.latitude, center.longitude)
          : kDefaultNearbyCenter,
    );

    if (!success && mounted) {
      showAppToast(context, 'Tidak bisa membuka Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locState = ref.watch(locationProvider);
    final userLoc = locState.coordinates != null
        ? LatLng(
            locState.coordinates!.latitude,
            locState.coordinates!.longitude,
          )
        : null;

    final allPlaces = List<Place>.from(_places);
    if (_selectedPlace != null &&
        !allPlaces.any((p) => p.id == _selectedPlace!.id)) {
      allPlaces.add(_selectedPlace!);
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: Stack(
        children: [
          // 1. Peta Layar Penuh
          Positioned.fill(
            child: RealMapView(
              mapController: _mapController,
              places: allPlaces,
              selectedPlaceId: _selectedPlace?.id,
              onSelectPlace: (place) {
                setState(() => _selectedPlace = place);
              },
              userLocation: userLoc,
              accuracyM: locState.accuracyM,
              isInteractive: true,
              onCameraMove: _onCameraMove,
            ),
          ),

          // 2. Atribusi OSM
          Positioned(
            right: 10.0,
            bottom: _selectedPlace != null ? 180.0 : 96.0,
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

          // 3. Tombol Kembali di Kiri Atas
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 12.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Semantics(
                  label: 'Kembali',
                  button: true,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: palette.border),
                        boxShadow: AppShadows.card,
                      ),
                      alignment: Alignment.center,
                      child: _isLoadingPlaces
                          ? SizedBox(
                              width: 18.0,
                              height: 18.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.actionBg,
                                ),
                              ),
                            )
                          : Icon(
                              LucideIcons.arrowLeft,
                              size: 20.0,
                              color: palette.textStrong,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Tombol Pusatkan ke Lokasi Saya (Kanan Bawah)
          Positioned(
            right: 16.0,
            bottom: _selectedPlace != null ? 190.0 : 106.0,
            child: Semantics(
              label: 'Pusatkan ke lokasi saya',
              button: true,
              child: InkWell(
                onTap: _centerToUser,
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: palette.border),
                    boxShadow: AppShadows.card,
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

          // 5. Panel Bawah: Kartu Tempat Terpilih & Tombol "Open Maps"
          Positioned(
            left: 16.0,
            right: 16.0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kartu Info Tempat Terpilih
                    if (_selectedPlace != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: palette.accent, width: 1.5),
                          boxShadow: AppShadows.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: palette.accent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                getPlaceMarkerIcon(_selectedPlace!.type),
                                size: 18.0,
                                color: palette.actionBg,
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedPlace!.name,
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
                                    '${_selectedPlace!.cuisine} · ${_selectedPlace!.distanceM} m',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: palette.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                size: 18.0,
                                color: palette.textSecondary,
                              ),
                              onPressed: () {
                                setState(() => _selectedPlace = null);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10.0),
                    ],

                    // Tombol Open Maps
                    AppButton(
                      label: 'Open Maps',
                      icon: const Icon(LucideIcons.externalLink, size: 18),
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      onPressed: _handleOpenMaps,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
