import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../models/models.dart';
import '../services/location_service.dart';

/// Widget Peta Nyata berbasis OpenStreetMap / CartoDB menggunakan flutter_map.
class RealMapView extends StatefulWidget {
  final List<Place> places;
  final String? selectedPlaceId;
  final ValueChanged<String>? onSelectPlace;
  final VoidCallback? onCenterTap;
  final VoidCallback? onSwitchToIllustrated;
  final String radiusLabel;
  final double height;
  final UserCoordinates userCoordinates;

  const RealMapView({
    super.key,
    required this.places,
    this.selectedPlaceId,
    this.onSelectPlace,
    this.onCenterTap,
    this.onSwitchToIllustrated,
    this.radiusLabel = 'Radius 1 km',
    this.height = 210.0,
    this.userCoordinates = UserCoordinates.defaultKaliurang,
  });

  @override
  State<RealMapView> createState() => _RealMapViewState();
}

class _RealMapViewState extends State<RealMapView> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centerToUser() {
    _mapController.move(
      LatLng(widget.userCoordinates.latitude, widget.userCoordinates.longitude),
      15.5,
    );
    widget.onCenterTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Place? selectedPlace;
    if (widget.selectedPlaceId != null) {
      for (final p in widget.places) {
        if (p.id == widget.selectedPlaceId) {
          selectedPlace = p;
          break;
        }
      }
    }
    selectedPlace ??= widget.places.isNotEmpty ? widget.places.first : null;

    final userLatLng = LatLng(
      widget.userCoordinates.latitude,
      widget.userCoordinates.longitude,
    );

    // CartoDB tiles URL: Dark Matter untuk mode gelap, Positron/OSM untuk mode terang
    final tileUrl = isDark
        ? 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

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
          // 1. Peta Nyata FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLatLng,
              initialZoom: 15.5,
              minZoom: 12.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'id.foodie.app',
              ),

              // Rute garis ke tempat terpilih
              if (selectedPlace != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        userLatLng,
                        LatLng(selectedPlace.latitude, selectedPlace.longitude),
                      ],
                      strokeWidth: 3.5,
                      color: isDark ? AppColors.amber : AppColors.olive,
                    ),
                  ],
                ),

              // Marker Titik Pengguna & Tempat Makan
              MarkerLayer(
                markers: [
                  // Marker User (halo hijau/olive)
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

                  // Marker Tempat Makan
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
                        width: 34.0,
                        height: 34.0,
                        child: GestureDetector(
                          onTap: () => widget.onSelectPlace?.call(place.id),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32.0,
                            height: 32.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.amber
                                  : AppColors.olive,
                              border: Border.all(
                                color: AppColors.white,
                                width: 2.5,
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
                                fontSize: 13.0,
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

          // 3. Tombol Kembali ke Peta Ilustrasi (Kanan Atas)
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
                      const Icon(
                        LucideIcons.map,
                        size: 13.0,
                        color: AppColors.olive,
                      ),
                      const SizedBox(width: 4.0),
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

          // 4. Tombol Pusatkan (Kanan Bawah)
          Positioned(
            right: 14.0,
            bottom: 14.0,
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
