import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/core/utils/nearby_map_utils.dart';
import 'package:foodie/models/models.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('Nearby Map Utils Unit Tests (PRD §4, §7)', () {
    test('1. URL Google Maps bila ada tempat terpilih (nama berspasi & karakter khusus)', () {
      const place = Place(
        id: 'place-test-1',
        name: "Warung 'Sate' & Soto (Pak Bejo)",
        cuisine: 'Jawa',
        type: 'restaurant',
        priceMin: 15,
        priceMax: 35,
        distanceM: 250,
        walkMin: 3,
        open: true,
        x: 50,
        y: 50,
        lat: -7.7654,
        lng: 110.3812,
      );

      final url = buildGoogleMapsUrl(selectedPlace: place);

      expect(
        url.startsWith('https://www.google.com/maps/search/?api=1&query='),
        isTrue,
      );
      // Nama ter-encode query dan berakhiran koordinat
      expect(url, contains('-7.7654,110.3812'));
      expect(url, contains('%20-7.7654,110.3812'));
      expect(url, contains('Warung'));
      expect(url, contains('Bejo'));
    });

    test(
      '2. URL Google Maps tanpa tempat terpilih memakai lokasi pengguna',
      () {
        final userLoc = const LatLng(-7.7500, 110.3700);
        final url = buildGoogleMapsUrl(
          selectedPlace: null,
          userLocation: userLoc,
        );

        expect(
          url,
          'https://www.google.com/maps/search/rumah+makan/@-7.75,110.37,16z',
        );
      },
    );

    test('3. URL Google Maps tanpa pilihan dan tanpa lokasi pengguna memakai pusat default', () {
      final url = buildGoogleMapsUrl(
        selectedPlace: null,
        userLocation: null,
        fallbackCenter: null,
      );

      expect(
        url,
        'https://www.google.com/maps/search/rumah+makan/@${kDefaultNearbyCenter.latitude},${kDefaultNearbyCenter.longitude},16z',
      );
    });

    test('4. Pemilihan ikon marker Lucide per jenis tempat makan', () {
      expect(getPlaceMarkerIcon('restaurant'), LucideIcons.utensils);
      expect(getPlaceMarkerIcon('food_court'), LucideIcons.utensils);
      expect(getPlaceMarkerIcon('warung'), LucideIcons.utensils);
      expect(getPlaceMarkerIcon('cafe'), LucideIcons.coffee);
      expect(getPlaceMarkerIcon('kafe'), LucideIcons.coffee);
      expect(getPlaceMarkerIcon('kopi'), LucideIcons.coffee);
      expect(getPlaceMarkerIcon('fast_food'), LucideIcons.sandwich);
      expect(getPlaceMarkerIcon('fastfood'), LucideIcons.sandwich);
      expect(getPlaceMarkerIcon('cepat saji'), LucideIcons.sandwich);
      expect(getPlaceMarkerIcon(null), LucideIcons.utensils);
    });

    test('5. Pembatasan maksimal 12 marker di preview', () {
      final places20 = List.generate(
        20,
        (i) => Place(
          id: 'p-$i',
          name: 'Warung $i',
          cuisine: 'Lokal',
          priceMin: 10,
          priceMax: 20,
          distanceM: i * 50,
          walkMin: 1,
          open: true,
          x: 50,
          y: 50,
          lat: -7.7 + (i * 0.001),
          lng: 110.3 + (i * 0.001),
        ),
      );

      final limited = limitPlacesForPreview(places20);
      expect(limited.length, 12);
      expect(limited.first.id, 'p-0');
      expect(limited.last.id, 'p-11');

      final places5 = places20.take(5).toList();
      expect(limitPlacesForPreview(places5).length, 5);
    });
  });
}
