# QA Audit Fase B5: Lokasi, Tempat Makan Sekitar (Overpass API), & Rute Jalan (OSRM)

**Tanggal:** 2026-11-20  
**Target:** Integrasi lokasi nyata GPS, querying Overpass API untuk tempat makan sekitar, rute jalan kaki OSRM, caching Hive, fallback berantai, dan parser opening_hours.

---

## 1. Audit Komponen yang Sudah Berjalan vs Belum Berjalan

### A. Location Service & Provider (`lib/services/location_service.dart`, `lib/providers/location_provider.dart`)
- **Sudah Jalan:**
  - Pengecekan `Geolocator.isLocationServiceEnabled()` dan izin `checkPermission()` / `requestPermission()`.
  - Fallback ke `UserCoordinates.defaultKaliurang` (-7.7653, 110.3789) saat izin ditolak atau GPS nonaktif.
  - Penanganan state `LocationStatus` (initial, loading, granted, denied, deniedForever, serviceDisabled, error).
  - Android Manifest (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) dan iOS Info.plist (`NSLocationWhenInUseUsageDescription`) sudah terdaftar.
- **Perlu Dipastikan / Ditingkatkan:**
  - Menampilkan toast `Lokasi tidak tersedia, memakai lokasi contoh` saat fallback lokasi terjadi.
  - Memastikan tombol "Pusatkan" selalu memusatkan peta ke koordinat aktif pengguna dengan toast yang tepat tanpa crash saat GPS mati.

### B. Place Service & Provider (`lib/services/place_service.dart`, `lib/providers/places_provider.dart`)
- **Sudah Jalan:**
  - `PlaceService` interface (`list()`, `nearby(...)`).
  - `LocalPlaceService` (mock data relatif terhadap koordinat pengguna).
- **Masih Mock / Perlu Diimplementasikan:**
  - `OverpassPlaceService implements PlaceService`:
    - Mengirim POST query Overpass QL ke `https://overpass-api.de/api/interpreter` untuk `amenity~"restaurant|cafe|fast_food"` (node & way, `out center 40`).
    - Timeout 15s dan User-Agent `FoodieApp/1.0 (id.foodie.foodie)`.
    - Parser respons JSON Overpass ke model `Place` (nama, cuisine fallback, koordinat lat/lng, distanceM, walkMin, derived harga).
    - `OpeningHoursParser`: memparsing format jam operasional OSM (mis. `24/7`, `Mo-Su 08:00-21:00`, `08:00-22:00`), menandai `isUnknownHours = true` dan `open = false` untuk format tidak dikenal/kosong agar tidak lolos filter "Buka sekarang".
    - Caching di Hive box `placesCache` (key koordinat + radius, TTL 1 jam).
    - Rantai Fallback: Overpass API -> Hive Cache -> LocalPlaceService (dengan toast `Memakai data contoh`).
    - Debounce fetch jika posisi user bergerak < 100m dan radius sama.
    - Integrasi provider asinkron / state loading & error di Riverpod.

### C. Route Service (`lib/services/route_service.dart`)
- **Sudah Jalan:**
  - `OsrmRouteService` memanggil endpoint jalan kaki OSRM `https://router.project-osrm.org/route/v1/foot/...`.
  - Parsing rute GeoJSON (jarak, durasi, titik polyline).
  - Pembatalan request lama dengan `CancelToken`.
  - Fallback garis lurus (straight line) jika OSRM gagal atau offline dengan flag `isStraightLineFallback: true`.
- **Perlu Dipastikan:**
  - Toast `Rute perkiraan` saat fallback garis lurus aktif.
  - Polyline di `RealMapView` digambar solid untuk rute OSRM dan dashed untuk garis perkiraan.

### D. Peta & Halaman Nearby (`lib/widgets/real_map_view.dart`, `lib/pages/nearby_page.dart`)
- **Sudah Jalan:**
  - `RealMapView` berbasis OpenStreetMap FlutterMap dengan pin bernomor, titik pengguna, dan rute polyline.
  - Atribusi `© OpenStreetMap contributors` sudah ada di sudut kiri bawah peta.
  - Filter chip cepat: Terdekat, Buka sekarang, Harga hemat.
  - Bottom sheet filter: Radius (500m, 1km, 2km, 5km), Kisaran harga, Status buka.
- **Perlu Disesuaikan:**
  - Mengubah `userAgentPackageName` dari `id.foodie.app` menjadi `id.foodie.foodie`.
  - Filter "Buka sekarang" mengecualikan tempat dengan `isUnknownHours == true`.
  - Integrasi async state (loading skeleton, empty state, retry saat error).

---

## 2. Rencana Eksekusi & Validasi

1. Implementasi `OpeningHoursParser` dan `OverpassPlaceService` di `lib/services/place_service.dart`.
2. Integrasi provider dan cache Hive di `lib/providers/places_provider.dart`.
3. Penyesuaian `RealMapView` dan `NearbyPage` (toast, filter `!isUnknownHours`, `userAgentPackageName`).
4. Unit testing komprehensif di `test/phase_b5_location_places_route_test.dart`.
5. Verifikasi kualitas: `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.
