import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../models/models.dart';

/// Widget Peta Ilustrasi Statis (IllustratedMap) sesuai PRD §6.8 & design/location.jpg:
/// - Ukuran: lebar fluid (lebar kartu 375–392, tinggi 210, radius 20).
/// - Background mapBg (#E7E9DE), jalan putih, blok mapBlock (#DEE3D8).
/// - Label jalan "Jl. Kaliurang" & "Pratinjau area" (kecil, sage).
/// - Pill putih "Radius 1 km" di kiri atas.
/// - Tombol pill putih "Pusatkan" di kanan bawah.
/// - Titik pengguna (lingkaran olive + halo hijau muda) di tengah jalan.
/// - Garis putus-putus olive dari titik pengguna ke pin terpilih.
/// - Pin bernomor interaktif (aktif = amber, lain = olive, lingkaran 28 putih-border).
class IllustratedMap extends StatelessWidget {
  final List<Place> places;
  final String? selectedPlaceId;
  final ValueChanged<String>? onSelectPlace;
  final VoidCallback? onCenterTap;
  final VoidCallback? onSwitchToRealMap;
  final String radiusLabel;
  final double height;

  const IllustratedMap({
    super.key,
    required this.places,
    this.selectedPlaceId,
    this.onSelectPlace,
    this.onCenterTap,
    this.onSwitchToRealMap,
    this.radiusLabel = 'Radius 1 km',
    this.height = 210.0,
  });

  @override
  Widget build(BuildContext context) {
    Place? selectedPlace;
    if (selectedPlaceId != null) {
      for (final p in places) {
        if (p.id == selectedPlaceId) {
          selectedPlace = p;
          break;
        }
      }
    }
    selectedPlace ??= places.isNotEmpty ? places.first : null;

    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.mapBg,
        borderRadius: AppRadius.cardLarge,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final mapHeight = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Gambar peta ilustrasi (Jalan, blok, label jalan, titik user, rute putus-putus)
              CustomPaint(
                size: Size(width, mapHeight),
                painter: _IllustratedMapPainter(selectedPlace: selectedPlace),
              ),

              // 2. Pill "Radius 1 km" di kiri atas
              Positioned(
                top: 12.0,
                left: 12.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 6.0,
                  ),
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
                  child: Text(
                    radiusLabel,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ),

              // 2b. Tombol Beralih ke Peta Nyata (Kanan Atas, jika ada handler)
              if (onSwitchToRealMap != null)
                Positioned(
                  right: 14.0,
                  top: 14.0,
                  child: Semantics(
                    label: 'Beralih ke Peta Nyata',
                    button: true,
                    child: GestureDetector(
                      onTap: onSwitchToRealMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 5.0,
                        ),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.mapPin,
                              size: 13.0,
                              color: AppColors.olive,
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              'Peta Nyata',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.olive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Tombol "Pusatkan" di kanan bawah
              Positioned(
                bottom: 12.0,
                right: 12.0,
                child: Semantics(
                  label: 'Pusatkan peta ke lokasi pengguna',
                  button: true,
                  child: GestureDetector(
                    onTap: onCenterTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 6.0,
                      ),
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
                      child: const Text(
                        'Pusatkan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.olive,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Pin bernomor interaktif pada posisi (x, y)
              for (int i = 0; i < places.length; i++) ...[
                _buildPin(
                  place: places[i],
                  index: i + 1,
                  isSelected: places[i].id == selectedPlace?.id,
                  mapWidth: width,
                  mapHeight: mapHeight,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPin({
    required Place place,
    required int index,
    required bool isSelected,
    required double mapWidth,
    required double mapHeight,
  }) {
    // Koordinat pin berbasis persentase (0–100)
    final pinX = (place.x / 100.0) * mapWidth;
    final pinY = (place.y / 100.0) * mapHeight;

    return Positioned(
      left: pinX - 14.0,
      top: pinY - 14.0,
      child: Semantics(
        label: 'Pin ${place.name} nomor $index',
        button: true,
        child: GestureDetector(
          key: ValueKey('pin-${place.id}'),
          onTap: () => onSelectPlace?.call(place.id),
          child: Container(
            width: 28.0,
            height: 28.0,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.amber : AppColors.olive,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowShell,
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.textBody : AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter untuk menggambar peta ilustrasi, jalan, blok, dan rute putus-putus
class _IllustratedMapPainter extends CustomPainter {
  final Place? selectedPlace;

  _IllustratedMapPainter({required this.selectedPlace});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Background map
    final bgPaint = Paint()..color = AppColors.mapBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Blok-blok bangunan (mapBlock: #DEE3D8)
    final blockPaint = Paint()..color = AppColors.mapBlock;
    const blockRadius = Radius.circular(14.0);

    // Baris Atas (3 blok)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.24, h * 0.26),
        blockRadius,
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.08, w * 0.25, h * 0.26),
        blockRadius,
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.69, h * 0.08, w * 0.25, h * 0.26),
        blockRadius,
      ),
      blockPaint,
    );

    // Baris Bawah (3 blok)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.46, w * 0.24, h * 0.44),
        blockRadius,
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.46, w * 0.25, h * 0.44),
        blockRadius,
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.69, h * 0.46, w * 0.25, h * 0.44),
        blockRadius,
      ),
      blockPaint,
    );

    // 3. Jalan-jalan putih (#FFFFFF)
    final roadPaint = Paint()..color = AppColors.white;

    // Jalan Horizontal Utama (tengah)
    canvas.drawRect(Rect.fromLTWH(0, h * 0.37, w, h * 0.07), roadPaint);

    // Jalan Vertikal 1 (kiri)
    canvas.drawRect(Rect.fromLTWH(w * 0.34, 0, w * 0.035, h), roadPaint);

    // Jalan Vertikal 2 (kanan)
    canvas.drawRect(Rect.fromLTWH(w * 0.645, 0, w * 0.035, h), roadPaint);

    // 4. Label teks jalan & area (sage 10)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // "Jl. Kaliurang" di atas jalan horizontal kiri
    textPainter.text = const TextSpan(
      text: 'Jl. Kaliurang',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        color: AppColors.sage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(w * 0.09, h * 0.395));

    // "Pratinjau area" di bagian bawah blok kiri
    textPainter.text = const TextSpan(
      text: 'Pratinjau area',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        color: AppColors.sage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(w * 0.09, h * 0.85));

    // 5. Titik Lokasi Pengguna (User Location)
    final userX = w * 0.505;
    final userY = h * 0.465;

    // Halo hijau muda / soft olive
    final haloPaint = Paint()
      ..color = AppColors.olive.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(userX, userY), 16.0, haloPaint);

    // Titik pusat olive
    final userDotPaint = Paint()
      ..color = AppColors.olive
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(userX, userY), 6.0, userDotPaint);

    // 6. Garis putus-putus olive ke pin terpilih
    if (selectedPlace != null) {
      final targetX = (selectedPlace!.x / 100.0) * w;
      final targetY = (selectedPlace!.y / 100.0) * h;

      _drawDashedRoute(
        canvas: canvas,
        start: Offset(userX, userY),
        end: Offset(targetX, targetY),
        w: w,
        h: h,
      );
    }
  }

  void _drawDashedRoute({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double w,
    required double h,
  }) {
    final routePaint = Paint()
      ..color = AppColors.olive
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Rute jalan ortogonal (mengikuti grid jalan kota sesuai location.jpg)
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Tentukan jalan vertikal terdekat (jalan 1 di ~0.355w atau jalan 2 di ~0.66w)
    final streetX = (end.dx < w * 0.55) ? w * 0.358 : w * 0.662;

    // 1. Ke jalan vertikal
    path.lineTo(streetX, start.dy);
    // 2. Sepanjang jalan vertikal ke level pin
    path.lineTo(streetX, end.dy);
    // 3. Ke target pin
    path.lineTo(end.dx, end.dy);

    // Ubah garis menjadi putus-putus
    const dashLength = 5.0;
    const gapLength = 4.0;

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashLength, metric.length - distance);
        dashPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashLength + gapLength;
      }
    }

    canvas.drawPath(dashPath, routePaint);
  }

  @override
  bool shouldRepaint(_IllustratedMapPainter oldDelegate) {
    return oldDelegate.selectedPlace?.id != selectedPlace?.id;
  }
}
