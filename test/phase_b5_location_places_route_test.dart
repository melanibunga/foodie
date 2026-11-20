import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodie/models/models.dart';
import 'package:foodie/services/place_service.dart';
import 'package:foodie/services/route_service.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('foodie_b5_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1. OpeningHoursParser', () {
    test('Format 24/7 selalu buka dan bukan unknown', () {
      final res = OpeningHoursParser.parse('24/7');
      expect(res.isOpen, isTrue);
      expect(res.isUnknown, isFalse);
    });

    test('Format off / closed selalu tutup dan bukan unknown', () {
      final res = OpeningHoursParser.parse('closed');
      expect(res.isOpen, isFalse);
      expect(res.isUnknown, isFalse);

      final resOff = OpeningHoursParser.parse('off');
      expect(resOff.isOpen, isFalse);
      expect(resOff.isUnknown, isFalse);
    });

    test('Null atau string kosong menghasilkan isUnknown = true dan isOpen = false', () {
      final resNull = OpeningHoursParser.parse(null);
      expect(resNull.isOpen, isFalse);
      expect(resNull.isUnknown, isTrue);

      final resEmpty = OpeningHoursParser.parse('   ');
      expect(resEmpty.isOpen, isFalse);
      expect(resEmpty.isUnknown, isTrue);
    });

    test(
      'Format jam harian 08:00-21:00 buka di siang hari, tutup di malam hari',
      () {
        final siang = DateTime(2026, 11, 20, 14, 30); // 14:30
        final resSiang = OpeningHoursParser.parse('08:00-21:00', now: siang);
        expect(resSiang.isOpen, isTrue);
        expect(resSiang.isUnknown, isFalse);

        final malam = DateTime(2026, 11, 20, 22, 15); // 22:15
        final resMalam = OpeningHoursParser.parse('08:00-21:00', now: malam);
        expect(resMalam.isOpen, isFalse);
        expect(resMalam.isUnknown, isFalse);
      },
    );

    test('Format spesifik hari Mo-Fr 09:00-17:00', () {
      // 2026-11-20 adalah hari Jumat (weekday 5)
      final jumatSiang = DateTime(2026, 11, 20, 11, 0);
      final resJumat = OpeningHoursParser.parse(
        'Mo-Fr 09:00-17:00',
        now: jumatSiang,
      );
      expect(resJumat.isOpen, isTrue);
      expect(resJumat.isUnknown, isFalse);

      // 2026-11-22 adalah hari Minggu (weekday 7)
      final mingguSiang = DateTime(2026, 11, 22, 11, 0);
      final resMinggu = OpeningHoursParser.parse(
        'Mo-Fr 09:00-17:00',
        now: mingguSiang,
      );
      expect(resMinggu.isOpen, isFalse);
      expect(resMinggu.isUnknown, isFalse);
    });

    test('Format buka melewati tengah malam 18:00-02:00', () {
      final jam23 = DateTime(2026, 11, 20, 23, 30);
      final res23 = OpeningHoursParser.parse('18:00-02:00', now: jam23);
      expect(res23.isOpen, isTrue);

      final jam01 = DateTime(2026, 11, 20, 1, 30);
      final res01 = OpeningHoursParser.parse('18:00-02:00', now: jam01);
      expect(res01.isOpen, isTrue);

      final jam10 = DateTime(2026, 11, 20, 10, 0);
      final res10 = OpeningHoursParser.parse('18:00-02:00', now: jam10);
      expect(res10.isOpen, isFalse);
    });

    test('Format tidak dikenal / acak menghasilkan isUnknown = true', () {
      final res = OpeningHoursParser.parse('sunrise to sunset');
      expect(res.isOpen, isFalse);
      expect(res.isUnknown, isTrue);
    });
  });

  group('2. Mapping Overpass JSON ke Place', () {
    test('Mapping node dan way dari Overpass JSON fixture', () {
      final fixture = {
        'elements': [
          {
            'type': 'node',
            'id': 12345,
            'lat': -7.7650,
            'lon': 110.3790,
            'tags': {
              'name': 'Gudeg Sagan',
              'cuisine': 'indonesian;traditional',
              'amenity': 'restaurant',
              'opening_hours': '08:00-23:00',
            },
          },
          {
            'type': 'way',
            'id': 67890,
            'center': {'lat': -7.7660, 'lon': 110.3780},
            'tags': {
              'amenity': 'cafe',
              // name tidak ada -> fallback name
              'opening_hours': '24/7',
            },
          },
        ],
      };

      final places = OverpassPlaceService.parseOverpassResponse(
        fixture,
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 5000,
      );

      expect(places.length, equals(2));

      // Node item
      final gudeg = places.firstWhere((p) => p.id == 'node-12345');
      expect(gudeg.name, equals('Gudeg Sagan'));
      expect(gudeg.cuisine, equals('indonesian, traditional'));
      expect(gudeg.lat, closeTo(-7.7650, 0.0001));
      expect(gudeg.lng, closeTo(110.3790, 0.0001));
      expect(gudeg.distanceM, greaterThan(0));
      expect(gudeg.walkMin, equals((gudeg.distanceM / 80).ceil()));
      expect(gudeg.priceMin, greaterThanOrEqualTo(12000));
      expect(gudeg.priceMax, greaterThan(gudeg.priceMin));

      // Way item dengan fallback nama dan cuisine
      final cafe = places.firstWhere((p) => p.id == 'way-67890');
      expect(cafe.name, equals('Kafe Sekitar'));
      expect(cafe.cuisine, equals('Kafe & Kopi'));
      expect(cafe.open, isTrue);
      expect(cafe.isUnknownHours, isFalse);
    });

    test('Perhitungan walkMin minimal 1 menit', () {
      final fixture = {
        'elements': [
          {
            'type': 'node',
            'id': 999,
            'lat': -7.765301,
            'lon': 110.378901,
            'tags': {'name': 'Warung Sangat Dekat', 'amenity': 'restaurant'},
          },
        ],
      };

      final places = OverpassPlaceService.parseOverpassResponse(
        fixture,
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 1000,
      );

      expect(places.first.distanceM, lessThan(10));
      expect(places.first.walkMin, equals(1));
    });
  });

  group('3. Fallback Berantai Overpass -> Cache Hive -> LocalPlaceService', () {
    test('Overpass sukses menyimpan data ke cache Hive', () async {
      final cacheBox = await Hive.openBox<Map>('placesCacheTest1');

      final fixture = {
        'elements': [
          {
            'type': 'node',
            'id': 1001,
            'lat': -7.7655,
            'lon': 110.3795,
            'tags': {'name': 'Resto Baru', 'amenity': 'restaurant'},
          },
        ],
      };

      // Mock Dio adapter
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode(fixture),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = OverpassPlaceService(
        dio: dio,
        getPlacesCacheBox: () => cacheBox,
      );

      final places = await service.nearby(
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 1000,
      );

      expect(places.length, equals(1));
      expect(places.first.name, equals('Resto Baru'));

      // Verifikasi tersimpan di cacheBox
      final key = '${(-7.7653 * 100).round()}_${(110.3789 * 100).round()}_1000';
      final cached = cacheBox.get(key);
      expect(cached, isNotNull);
      expect(cached!['places'], isNotEmpty);
    });

    test('Overpass gagal tapi cache Hive ada -> fallback ke cache', () async {
      final cacheBox = await Hive.openBox<Map>('placesCacheTest2');
      final key = '${(-7.7653 * 100).round()}_${(110.3789 * 100).round()}_1000';

      final savedPlace = Place(
        id: 'cached-1',
        name: 'Warung Dari Cache',
        cuisine: 'Jawa',
        priceMin: 15000,
        priceMax: 25000,
        distanceM: 200,
        walkMin: 3,
        open: true,
        x: 50.0,
        y: 50.0,
      );

      await cacheBox.put(key, {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'places': [savedPlace.toJson()],
      });

      // Dio yang selalu melempar error
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        throw DioException(
          requestOptions: options,
          error: 'Connection timeout',
          type: DioExceptionType.connectionTimeout,
        );
      });

      String? toastMsg;
      final service = OverpassPlaceService(
        dio: dio,
        getPlacesCacheBox: () => cacheBox,
        onFallbackToast: (msg) => toastMsg = msg,
      );

      final places = await service.nearby(
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 1000,
      );

      expect(places.length, equals(1));
      expect(places.first.name, equals('Warung Dari Cache'));
      expect(
        toastMsg,
        isNull,
      ); // Karena cache berhasil, tidak perlu toast fallback mock
    });

    test('Overpass gagal dan cache kosong -> fallback ke LocalPlaceService + toast', () async {
      final cacheBox = await Hive.openBox<Map>('placesCacheTest3');

      // Dio yang selalu error
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        throw DioException(
          requestOptions: options,
          error: 'Network unreachable',
          type: DioExceptionType.connectionError,
        );
      });

      String? toastMsg;
      final service = OverpassPlaceService(
        dio: dio,
        getPlacesCacheBox: () => cacheBox,
        onFallbackToast: (msg) => toastMsg = msg,
      );

      final places = await service.nearby(
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 5000,
      );

      expect(places, isNotEmpty);
      expect(places.any((p) => p.name == 'Warung Bu Sari'), isTrue);
      expect(toastMsg, equals('Memakai data contoh'));
    });

    test('Debounce: pergeseran < 100m mengembalikan in-memory cache', () async {
      int requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        requestCount++;
        return ResponseBody.fromString(
          '{"elements": [{"type":"node","id":1,"lat":-7.7653,"lon":110.3789,"tags":{"name":"Resto Debounce"}}]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = OverpassPlaceService(dio: dio);

      // Fetch 1
      final p1 = await service.nearby(
        latitude: -7.7653,
        longitude: 110.3789,
        radiusMeters: 1000,
      );
      expect(requestCount, equals(1));
      expect(p1.first.name, equals('Resto Debounce'));

      // Fetch 2 dengan pergeseran hanya ~10 meter (-7.7653 vs -7.76538)
      final p2 = await service.nearby(
        latitude: -7.76538,
        longitude: 110.37892,
        radiusMeters: 1000,
      );
      expect(requestCount, equals(1)); // Tidak request lagi
      expect(p2.first.name, equals('Resto Debounce'));
    });
  });

  group('4. OsrmRouteService & Straight Line Fallback', () {
    test('Parse respon OSRM GeoJSON berhasil', () {
      final start = const LatLng(-7.7653, 110.3789);
      final dest = const LatLng(-7.7640, 110.3800);

      final osrmJson = {
        'code': 'Ok',
        'routes': [
          {
            'distance': 250.0,
            'duration': 180.0,
            'geometry': {
              'coordinates': [
                [110.3789, -7.7653],
                [110.3795, -7.7648],
                [110.3800, -7.7640],
              ],
            },
          },
        ],
      };

      final result = OsrmRouteService.parseOsrmResponse(osrmJson, start, dest);
      expect(result.isStraightLineFallback, isFalse);
      expect(result.distanceMeters, equals(250.0));
      expect(result.durationSeconds, equals(180.0));
      expect(result.points.length, equals(3));
      expect(result.formattedDistance, equals('250 m'));
      expect(result.formattedDuration, equals('3 menit'));
      expect(result.distanceAndDurationString, equals('250 m · 3 menit'));
    });

    test(
      'Respon OSRM gagal atau tidak Ok mengembalikan straight line fallback',
      () {
        final start = const LatLng(-7.7653, 110.3789);
        final dest = const LatLng(-7.7640, 110.3800);

        final errorJson = {'code': 'NoRoute', 'routes': []};

        final result = OsrmRouteService.parseOsrmResponse(
          errorJson,
          start,
          dest,
        );
        expect(result.isStraightLineFallback, isTrue);
        expect(result.points.length, equals(2));
        expect(result.points.first.latitude, equals(start.latitude));
        expect(result.points.last.latitude, equals(dest.latitude));
        expect(result.distanceMeters, greaterThan(0));
      },
    );
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) _handler;

  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
