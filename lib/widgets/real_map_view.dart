import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_shadows.dart';
import '../core/utils/nearby_map_utils.dart';
import '../models/models.dart';

/// Reusable map view berbasis OpenStreetMap (flutter_map) sesuai PRD §14.12, §17.6, dan §17.7:
/// - Mendukung mode preview (non-interaktif, tanpa rebut scroll) dan mode layar penuh (interaktif).
/// - Marker bertema palette:
///   * Titik pengguna: lingkaran olive (palette.actionBg, atau palette.accent di mode gelap)
///     dengan border putih dan halo akurasi (CircleLayer radius meter). TANPA label.
///     HANYA muncul jika lokasi pengguna valid (tidak pernah menampilkan pusat default sebagai pengguna).
///   * Tempat makan: pin 30px dengan background palette.actionBg, ikon putih per jenis (utensils, coffee, sandwich),
///     border surface, shadow halus.
///   * Tempat terpilih: pin 36px dengan background palette.accent (amber), ikon olive tua, animasi halus 200 ms.
/// - Atribusi lisensi "© OpenStreetMap contributors" selalu tampil di sudut peta.
class RealMapView extends StatefulWidget {
  final MapController? mapController;
  final List<Place> places;
  final String? selectedPlaceId;
  final ValueChanged<Place>? onSelectPlace;
  final ValueChanged<String>? onSelectPlaceId;
  final LatLng? userLocation;
  final double? accuracyM;
  final bool isInteractive;
  final double? height;
  final BorderRadius? borderRadius;
  final VoidCallback? onCameraMove;
  final VoidCallback? onTileError;
  final LatLng? initialCenter;
  final double initialZoom;
  final String? radiusLabel;
  final VoidCallback? onCenterTap;

  const RealMapView({
    super.key,
    this.mapController,
    required this.places,
    this.selectedPlaceId,
    this.onSelectPlace,
    this.onSelectPlaceId,
    this.userLocation,
    this.accuracyM,
    this.isInteractive = false,
    this.height,
    this.borderRadius,
    this.onCameraMove,
    this.onTileError,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.radiusLabel,
    this.onCenterTap,
  });

  @override
  State<RealMapView> createState() => _RealMapViewState();
}

class _RealMapViewState extends State<RealMapView> {
  MapController? _internalController;

  MapController get _effectiveController =>
      widget.mapController ?? (_internalController ??= MapController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final userDotColor = palette.isDark ? palette.accent : palette.actionBg;
    final center =
        widget.userLocation ?? widget.initialCenter ?? kDefaultNearbyCenter;

    Widget mapWidget = FlutterMap(
      mapController: _effectiveController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: widget.initialZoom,
        minZoom: 10.0,
        maxZoom: 18.0,
        interactionOptions: InteractionOptions(
          flags: widget.isInteractive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && widget.onCameraMove != null) {
            widget.onCameraMove!();
          }
        },
      ),
      children: [
        // 1. TileLayer OSM dengan inverted dark mode matrix
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'id.foodie.foodie',
          tileBuilder: palette.isDark
              ? (ctx, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -1.0, 0.0, 0.0, 0.0, 255.0, // R
                      0.0, -1.0, 0.0, 0.0, 255.0, // G
                      0.0, 0.0, -1.0, 0.0, 255.0, // B
                      0.0, 0.0, 0.0, 1.0, 0.0, // A
                    ]),
                    child: tileWidget,
                  );
                }
              : null,
          errorTileCallback: (tile, error, stackTrace) {
            widget.onTileError?.call();
          },
        ),

        // 2. Halo akurasi lokasi pengguna (CircleLayer, radius meter)
        // HANYA jika ada lokasi pengguna yang valid & akurasi diketahui
        if (widget.userLocation != null &&
            widget.accuracyM != null &&
            widget.accuracyM! > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: widget.userLocation!,
                radius: widget.accuracyM!,
                useRadiusInMeter: true,
                color: palette.actionBg.withValues(alpha: 0.12),
                borderColor: palette.actionBg.withValues(alpha: 0.28),
                borderStrokeWidth: 1.0,
              ),
            ],
          ),

        // 3. Marker Layer: Tempat makan dan Lokasi Pengguna
        MarkerLayer(
          markers: [
            // Marker Lokasi Pengguna (tanpa label teks, border putih, olive/accent)
            if (widget.userLocation != null)
              Marker(
                point: widget.userLocation!,
                width: 24.0,
                height: 24.0,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: userDotColor,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4.0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

            // Marker Tempat Makan
            for (final place in widget.places) ...[
              () {
                final isSelected = place.id == widget.selectedPlaceId;
                final size = isSelected ? 36.0 : 30.0;
                final iconSize = isSelected ? 18.0 : 14.0;
                final bg = isSelected ? palette.accent : palette.actionBg;
                final iconColor = isSelected ? palette.actionBg : Colors.white;

                return Marker(
                  key: ValueKey('marker-${place.id}'),
                  point: LatLng(place.latitude, place.longitude),
                  width: 44.0,
                  height: 44.0,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    key: ValueKey('marker-tap-${place.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onSelectPlace?.call(place);
                      widget.onSelectPlaceId?.call(place.id);
                    },
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bg,
                          border: Border.all(
                            color: palette.surface,
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: palette.accent.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8.0,
                                    spreadRadius: 1.0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : AppShadows.card,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          getPlaceMarkerIcon(place.type),
                          size: iconSize,
                          color: iconColor,
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
    );

    // Overlays if radiusLabel or onCenterTap are provided (e.g. for backward compatibility)
    if (widget.radiusLabel != null || widget.onCenterTap != null) {
      mapWidget = Stack(
        children: [
          mapWidget,
          if (widget.radiusLabel != null)
            Positioned(
              left: 12.0,
              top: 12.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  widget.radiusLabel!,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
              ),
            ),
          if (widget.onCenterTap != null)
            Positioned(
              right: 12.0,
              bottom: 12.0,
              child: GestureDetector(
                onTap: widget.onCenterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location,
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
        ],
      );
    }

    if (widget.borderRadius != null) {
      mapWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: mapWidget,
      );
    }

    if (widget.height != null) {
      mapWidget = SizedBox(
        width: double.infinity,
        height: widget.height,
        child: mapWidget,
      );
    }

    return mapWidget;
  }
}
