import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';

/// Widget Peta Nyata berbasis OpenStreetMap menggunakan flutter_map sesuai PRD §14.12
class RealMapView extends StatefulWidget {
  final List<Place> places;
  final String? selectedPlaceId;
  final ValueChanged<String>? onSelectPlace;
  final VoidCallback? onCenterTap;
  final VoidCallback? onSwitchToIllustrated;
  final VoidCallback? onTileError;
  final String radiusLabel;
  final double height;
  final UserCoordinates userCoordinates;
  final RouteResult? routeResult;
  final bool isLoadingRoute;

  const RealMapView({
    super.key,
    required this.places,
    this.selectedPlaceId,
    this.onSelectPlace,
    this.onCenterTap,
    this.onSwitchToIllustrated,
    this.onTileError,
    this.radiusLabel = 'Radius 1 km',
    this.height = 210.0,
    this.userCoordinates = UserCoordinates.defaultKaliurang,
    this.routeResult,
    this.isLoadingRoute = false,
  });

  @override
  State<RealMapView> createState() => _RealMapViewState();
}

class _RealMapViewState extends State<RealMapView> {
  late final MapController _mapController;
  int _tileErrorCount = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant RealMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Jika rute baru tiba atau tempat berganti, pusatkan/fit camera ke rute
    if (widget.routeResult != oldWidget.routeResult &&
        widget.routeResult != null &&
        widget.routeResult!.points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBoundsToRoute(widget.routeResult!.points);
      });
    } else if (widget.selectedPlaceId != oldWidget.selectedPlaceId) {
      final selected = _findSelectedPlace();
      if (selected != null) {
        final userLatLng = LatLng(
          widget.userCoordinates.latitude,
          widget.userCoordinates.longitude,
        );
        final placeLatLng = LatLng(selected.latitude, selected.longitude);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitBoundsToRoute([userLatLng, placeLatLng]);
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Place? _findSelectedPlace() {
    if (widget.selectedPlaceId != null) {
      for (final p in widget.places) {
        if (p.id == widget.selectedPlaceId) return p;
      }
    }
    return widget.places.isNotEmpty ? widget.places.first : null;
  }

  void _centerToUser() {
    _mapController.move(
      LatLng(widget.userCoordinates.latitude, widget.userCoordinates.longitude),
      15.5,
    );
    widget.onCenterTap?.call();
  }

  void _fitBoundsToRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 15.5);
        return;
      }
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 36.0),
          maxZoom: 16.5,
        ),
      );
    } catch (e) {
      debugPrint('Error fitting camera bounds: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPlace = _findSelectedPlace();

    final userLatLng = LatLng(
      widget.userCoordinates.latitude,
      widget.userCoordinates.longitude,
    );

    // Titik-titik rute
    List<LatLng> routePoints = [];
    if (widget.routeResult != null && widget.routeResult!.points.isNotEmpty) {
      routePoints = widget.routeResult!.points;
    } else if (selectedPlace != null) {
      // Garis lurus langsung bila rute OSRM belum selesai di-fetch
      routePoints = [
        userLatLng,
        LatLng(selectedPlace.latitude, selectedPlace.longitude),
      ];
    }

    final isStraightLine =
        widget.routeResult == null ||
        widget.routeResult!.isStraightLineFallback;

    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.mapBg,
        borderRadius: AppRadius.cardLarge,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. FlutterMap Peta Nyata OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLatLng,
              initialZoom: 15.0,
              minZoom: 10.0,
              maxZoom: 18.0,
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
                userAgentPackageName: 'id.foodie.app',
                errorTileCallback: (tile, error, stackTrace) {
                  _tileErrorCount++;
                  if (_tileErrorCount >= 4) {
                    widget.onTileError?.call();
                  }
                },
              ),

              // Garis Rute (Solid untuk rute OSRM jalan raya, Dashed untuk fallback garis lurus)
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 3.5,
                      color: isDark ? AppColors.amber : AppColors.olive,
                      pattern: isStraightLine
                          ? StrokePattern.dashed(segments: const [8, 6])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),

              // Marker Layer
              MarkerLayer(
                markers: [
                  // Marker Titik Pengguna (lingkaran olive + halo hijau muda)
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
                            color: AppColors.oliveSoftDark,
                          ),
                        ),
                        Container(
                          width: 16.0,
                          height: 16.0,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.olive,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowShell,
                                blurRadius: 4.0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 6.0,
                              height: 6.0,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pin Tempat Makan Bernomor
                  for (int i = 0; i < widget.places.length; i++) ...[
                    () {
                      final place = widget.places[i];
                      final isSelected = place.id == selectedPlace?.id;
                      final placeLatLng = LatLng(
                        place.latitude,
                        place.longitude,
                      );

                      return Marker(
                        point: placeLatLng,
                        width: 32.0,
                        height: 32.0,
                        child: GestureDetector(
                          key: ValueKey('pin-${place.id}'),
                          onTap: () => widget.onSelectPlace?.call(place.id),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28.0,
                            height: 28.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.amber
                                  : AppColors.olive,
                              border: Border.all(
                                color: AppColors.white,
                                width: 2.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowShell,
                                  blurRadius: 4.0,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
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

          // 2. Pill Radius (Kiri Atas)
          Positioned(
            left: 14.0,
            top: 14.0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 5.0,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.white,
                borderRadius: BorderRadius.circular(999.0),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowShell,
                    blurRadius: 4.0,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                widget.radiusLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textTitleDark : AppColors.olive,
                ),
              ),
            ),
          ),

          // 3. Tombol Beralih ke Peta Ilustrasi / Indikator Loading (Kanan Atas)
          if (widget.onSwitchToIllustrated != null || widget.isLoadingRoute)
            Positioned(
              right: 14.0,
              top: 14.0,
              child: Semantics(
                label: 'Beralih ke Peta Ilustrasi',
                button: true,
                child: GestureDetector(
                  onTap: widget.onSwitchToIllustrated,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 5.0,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.white,
                      borderRadius: BorderRadius.circular(999.0),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowShell,
                          blurRadius: 4.0,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isLoadingRoute) ...[
                          const SizedBox(
                            width: 12.0,
                            height: 12.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: AppColors.olive,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                        ] else ...[
                          const Icon(
                            LucideIcons.map,
                            size: 13.0,
                            color: AppColors.olive,
                          ),
                          const SizedBox(width: 4.0),
                        ],
                        Text(
                          'Ilustrasi',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textTitleDark
                                : AppColors.olive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Atribusi OpenStreetMap (Kiri Bawah, Wajib PRD §14.12)
          Positioned(
            left: 12.0,
            bottom: 8.0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.surfaceDark : AppColors.white)
                    .withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 8.0,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.textTitleDark : AppColors.sage,
                ),
              ),
            ),
          ),

          // 5. Tombol Pusatkan (Kanan Bawah)
          Positioned(
            right: 14.0,
            bottom: 12.0,
            child: Semantics(
              label: 'Pusatkan ke lokasi saya',
              button: true,
              child: GestureDetector(
                onTap: _centerToUser,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.white,
                    borderRadius: BorderRadius.circular(999.0),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowShell,
                        blurRadius: 4.0,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.crosshair,
                        size: 14.0,
                        color: isDark
                            ? AppColors.textTitleDark
                            : AppColors.olive,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Pusatkan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textTitleDark
                              : AppColors.olive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
