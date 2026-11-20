import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';

/// Widget Peta Nyata berbasis OpenStreetMap menggunakan flutter_map sesuai PRD §14.12 dan §16
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
    if (points.length == 1) {
      _mapController.move(points.first, 15.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(36.0),
        maxZoom: 16.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final userLatLng = LatLng(
      widget.userCoordinates.latitude,
      widget.userCoordinates.longitude,
    );

    final selectedPlace = _findSelectedPlace();

    // Rute dari user ke selectedPlace
    List<LatLng> routePoints = const [];
    bool isStraightLine = false;

    if (widget.routeResult != null && widget.routeResult!.points.isNotEmpty) {
      routePoints = widget.routeResult!.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      isStraightLine = widget.routeResult!.isStraightLineFallback;
    } else if (selectedPlace != null) {
      // Fallback garis lurus bila routeResult belum siap
      routePoints = [
        userLatLng,
        LatLng(selectedPlace.latitude, selectedPlace.longitude),
      ];
      isStraightLine = true;
    }

    final userPrimary = palette.isDark ? palette.accent : palette.actionBg;

    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: palette.surface,
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
                      color: userPrimary,
                      pattern: isStraightLine
                          ? StrokePattern.dashed(segments: const [8, 6])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),

              // Marker Layer
              MarkerLayer(
                markers: [
                  // Marker Titik Pengguna
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

                  // Pin Tempat Makan Bernomor
                  for (int i = 0; i < widget.places.length; i++) ...[
                    () {
                      final place = widget.places[i];
                      final isSelected = place.id == selectedPlace?.id;
                      final placeLatLng = LatLng(
                        place.latitude,
                        place.longitude,
                      );

                      final pinBg = isSelected
                          ? palette.accent
                          : (palette.isDark
                                ? palette.surfaceAlt
                                : palette.actionBg);
                      final pinFg = isSelected
                          ? palette.onAccent
                          : (palette.isDark
                                ? palette.textStrong
                                : palette.onAction);

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
                              color: pinBg,
                              border: Border.all(
                                color: palette.surface,
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.shadowColor,
                                  blurRadius: 4.0,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: pinFg,
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
                color: palette.surface,
                borderRadius: BorderRadius.circular(999.0),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowColor,
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                widget.radiusLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: palette.textStrong,
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
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999.0),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadowColor,
                          blurRadius: 4.0,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isLoadingRoute) ...[
                          SizedBox(
                            width: 12.0,
                            height: 12.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: palette.actionBg,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                        ] else ...[
                          Icon(
                            LucideIcons.map,
                            size: 13.0,
                            color: palette.textStrong,
                          ),
                          const SizedBox(width: 4.0),
                        ],
                        Text(
                          'Ilustrasi',
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
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(999.0),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadowColor,
                        blurRadius: 4.0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.crosshair,
                        size: 14.0,
                        color: palette.textStrong,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Pusatkan',
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
            ),
          ),
        ],
      ),
    );
  }
}
