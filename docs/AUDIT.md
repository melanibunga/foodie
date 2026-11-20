# Audit Kode & Penyimpanan State Foodie.id (Fase B0)

> Dokumen audit teknis menyeluruh terhadap penggunaan penyimpanan lokal (`shared_preferences`), state personal pengguna, penyimpanan resep kustom / rating / riwayat masak, serta arsitektur modul lokasi & peta.
> Tanggal audit: 20 November 2026.

---

## 1. Daftar File yang Menggunakan `shared_preferences` & Key-nya

Saat ini seluruh persistensi lokal aplikasi menggunakan package `shared_preferences` (diakses via `sharedPreferencesProvider` di `lib/providers/storage_provider.dart`).

| File | Provider / Fungsi | Key Prefs | Tipe Data Disimpan | Deskripsi |
|---|---|---|---|---|
| `lib/providers/auth_provider.dart` | `AuthNotifier` | `foodie:auth` | String (JSON Map) | Menyimpan data sesi login & profil pengguna aktif (`isLoggedIn`, `user`: id, name, email, avatar, cooked, settings). |
| `lib/providers/recipes_provider.dart` | `RecipesNotifier` | `foodie:my_recipes` | String (JSON List) | Menyimpan daftar resep kustom/kreasi yang dibuat pengguna melalui halaman Create Recipe (`/add`). |
| `lib/providers/favorites_provider.dart` | `FavoritesNotifier` | `foodie:favorites` | String (JSON List) | Menyimpan daftar ID resep (`List<String>`) yang ditandai sebagai favorit. |
| `lib/providers/cart_provider.dart` | `CartNotifier` | `foodie:cart` | String (JSON List) | Menyimpan daftar grup belanjaan (`List<CartGroup>`) beserta item belanjaan (`CartItem`). |
| `lib/providers/meal_plan_provider.dart` | `MealPlanNotifier` | `foodie:meal_plan` | String (JSON List) | Menyimpan entri rencana makan mingguan (`List<MealPlanEntry>`). |
| `lib/providers/ratings_provider.dart` | `RatingsNotifier` | `foodie:ratings` | String (JSON Map) | Menyimpan rating bintang lokal (`Map<String, int>`, recipeId → 1..5). |
| `lib/providers/cooked_provider.dart` | `CookedNotifier` | `foodie:cooked` | String (JSON List) | Menyimpan riwayat entri masakan yang telah diselesaikan (`List<CookedEntry>`). |
| `lib/providers/theme_provider.dart` | `ThemeModeNotifier` | `foodie:themeMode` | String ("light" \| "dark" \| "system") | Menyimpan preferensi tema tampilan (terpisah mandiri dari sesi user). |
| `lib/providers/reset_data.dart` | `clearAllFoodiePrefs()` | Semua key berawalan `foodie:` | - | Utilitas untuk menghapus seluruh key berprefix `foodie:` saat aksi reset data demo. |
| `lib/providers/storage_provider.dart` | `sharedPreferencesProvider` | - | - | Registrasi dependency injection provider `SharedPreferences` yang di-override pada bootstrap `main()`. |

---

## 2. Daftar Semua State Personal Pengguna & Lokasi Penyimpanan Saat Ini

Sesuai aturan arsitektur data personal Foodie.id, data berikut merupakan **state personal** yang idealnya terisolasi per akun pengguna:

1. **Sesi & Profil Pengguna:**
   - Disimpan di: `authProvider` (`lib/providers/auth_provider.dart`).
   - Key: `foodie:auth`.
   - Isi: ID pengguna (`id`), nama lengkap (`name`), email (`email`), URI foto avatar (`avatar`), jumlah riwayat masak (`cooked`), dan pengaturan (`settings`: pengingat makan, mode gelap).
2. **Resep Favorit (Favorites):**
   - Disimpan di: `favoritesProvider` (`lib/providers/favorites_provider.dart`).
   - Key: `foodie:favorites`.
   - Isi: Kumpulan ID resep (`List<String>`).
3. **Daftar Belanjaan (Groceries / Cart):**
   - Disimpan di: `cartProvider` (`lib/providers/cart_provider.dart`).
   - Key: `foodie:cart`.
   - Isi: Daftar `CartGroup` yang mencakup grup resep dan grup khusus "Belanjaan Kamu Nich" beserta status centang & harga.
4. **Rencana Makan Mingguan (Meal Plan):**
   - Disimpan di: `mealPlanProvider` (`lib/providers/meal_plan_provider.dart`).
   - Key: `foodie:meal_plan`.
   - Isi: Daftar `MealPlanEntry` (hari, tanggal, tipe makan pagi/siang/malam, recipeId).
5. **Resep Kreasi Pengguna (My Recipes / Custom Recipes):**
   - Disimpan di: `recipesProvider` (`lib/providers/recipes_provider.dart`).
   - Key: `foodie:my_recipes`.
   - Isi: Daftar objek `Recipe` lengkap yang ditambahkan melalui form Create Recipe (`/add`).
6. **Ulasan & Rating Bintang Pengguna:**
   - Disimpan di: `ratingsProvider` (`lib/providers/ratings_provider.dart`).
   - Key: `foodie:ratings`.
   - Isi: Map pasangan `recipeId` -> nilai rating pengguna (1..5).
7. **Riwayat Dimasak (Cooked History):**
   - Disimpan di: `cookedProvider` (`lib/providers/cooked_provider.dart`).
   - Key: `foodie:cooked`.
   - Isi: Daftar `CookedEntry` (id, recipeId, tanggal masak `dateKey`).

> [!WARNING]
> **Temuan Kritis Isolasi Data Personal:**
> Saat ini seluruh key di atas bersifat **GLOBAL** (satu key untuk seluruh aplikasi tanpa namespace ID pengguna). Jika Akun A logout dan Akun B login, Akun B akan melihat favorit, belanjaan, meal plan, resep kreasi, dan rating milik Akun A.
> Di tahap migrasi database lokal (Hive / Multi-user), seluruh penyimpanan personal ini wajib diisolasi berbasis `currentUserId` (misalnya: `foodie:{userId}:favorites` atau box Hive per user).

---

## 3. Analisis Mekanisme Penyimpanan Saat Ini

### (a) Resep Buatan User (`recipesProvider`)
- **Alur Penyimpanan:**
  Saat pengguna menyelesaikan form di `/add`, `_handleSubmit()` membuat objek `Recipe` dengan ID unik `custom-${timestamp}`, lalu memanggil `ref.read(recipesProvider.notifier).addCustomRecipe(newRecipe)`.
- **Mekanisme Persistence:**
  `addCustomRecipe` memfilter resep yang bukan berasal dari `seedRecipes`, menambahkan resep baru, lalu men-serialize seluruh resep non-seed ke format JSON string dan menyimpannya di SharedPreferences dengan key `foodie:my_recipes`.
- **Pemuatan Awal (`build`):**
  Saat aplikasi start, `RecipesNotifier.build()` membaca key `foodie:my_recipes`, men-decode JSON, dan menggabungkannya di belakang seed: `[...seedRecipes, ...userRecipes]`.
- **Kelemahan Saat Ini:**
  Tidak ada penanda `authorId` yang membatasi kepemilikan resep per user (default diisi hardcoded `'user-default-1'`), dan tidak terisolasi antar sesi login.

### (b) Rating Pengguna (`ratingsProvider`)
- **Alur Penyimpanan:**
  Di layar selesai memasak (`CookPage` langkah terakhir), dialog rating memanggil `ref.read(ratingsProvider.notifier).rate(recipeId, rating)`.
- **Mekanisme Persistence:**
  State berupa `Map<String, int>` di-encode menjadi JSON string dan disimpan di SharedPreferences dengan key `foodie:ratings`.
- **Kalkulasi Nilai:**
  Fungsi pembantu `calculateRecipeRating(recipe, userRating)` menghitung rata-rata baru:
  $$\text{Rating Baru} = \frac{\text{ratingDasar} \times \text{ulasanDasar} + \text{userRating}}{\text{ulasanDasar} + 1}$$
- **Kelemahan Saat Ini:**
  Rating bersifat perangkat tunggal (global). Tidak ada pemisahan ulasan antar akun berbeda pada perangkat yang sama.

### (c) Riwayat Dimasak (`cookedProvider`)
- **Alur Penyimpanan:**
  Ketika pengguna menekan tombol "Selesai Memasak" pada `CookPage`, dipanggil `ref.read(cookedProvider.notifier).add(recipeId)`.
- **Mekanisme Persistence:**
  Objek `CookedEntry` (`id`, `recipeId`, `date`) ditambahkan ke state list, di-serialize ke JSON string, dan disimpan pada key `foodie:cooked`.
- **Pemuatan Awal:**
  Jika data pada key `foodie:cooked` belum pernah diisi atau kosong, provider mengembalikan `seedCookedEntries` (12 riwayat masak bawaan).
- **Kelemahan Saat Ini:**
  Riwayat memasak bercampur antar pengguna dan seed bawaan diterapkan secara global.

---

## 4. Ringkasan Modul Lokasi & Peta Nyata

Modul ini diimplementasikan pada Fase 16 & Fase B2 untuk mendukung fitur **Nearby (/nearby)**:

### 1. `LocationService` (`lib/services/location_service.dart`)
- **Tanggung Jawab:** Wrapper aman di atas package `geolocator`.
- **Metode:**
  - `isServiceEnabled()`: Memeriksa apakah layanan GPS perangkat aktif.
  - `checkPermission()` & `requestPermission()`: Menangani alur izin lokasi Android/iOS.
  - `getCurrentPosition()`: Mengambil koordinat perangkat dengan batas waktu (`timeLimit: Duration(seconds: 5)`) dan akurasi sedang (`LocationAccuracy.medium`).
- **Resilience:** Fallback anggun ke koordinat default Yogyakarta (Jl. Kaliurang KM 5: `-7.7653, 110.3789`) bila GPS mati, izin ditolak, atau emulator tidak memiliki lokasi.

### 2. `PlaceService` & `LocalPlaceService` (`lib/services/place_service.dart`)
- **Tanggung Jawab:** Abstraksi sumber data tempat makan di sekitar pengguna.
- **Implementasi Saat Ini (`LocalPlaceService`):**
  Menggunakan template tempat makan (5 resto khas Nusantara: Warung Bu Sari, Ayam Bakar Pak Hadi, Warung Padang Salero, Sate Madura Cak Sholeh, Gudeg Yu Djum).
- **Relatif Terhadap Pengguna:** Tempat makan digeser secara matematis (menggunakan trigonometri `distanceM` dan `bearingDegrees`) relatif terhadap posisi nyata pengguna saat ini. Hal ini memastikan rute jalan kaki selalu valid dan dapat dihitung di belahan bumi mana pun aplikasi dijalankan.
- **Kesiapan Backend:** Kontrak `PlaceService.nearby({latitude, longitude, radiusMeters})` sudah siap disambungkan ke backend API / Overpass API.

### 3. `RouteService` & `OsrmRouteService` (`lib/services/route_service.dart`)
- **Tanggung Jawab:** Menghitung rute jalan kaki nyata mengikuti jalur pedestrian/jalan raya.
- **Implementasi:** Menggunakan HTTP client `dio` yang menembak server publik **OSRM (Open Source Routing Machine)**:
  `https://router.project-osrm.org/route/v1/foot/{startLng},{startLat};{endLng},{endLat}?overview=full&geometries=geojson`
- **Output:** Objek `RouteResult` berisi `List<LatLng> points`, `distanceMeters`, `durationSeconds`, format teks (mis. `"180 m · 3 menit"`).
- **Resilience / Fallback:**
  - Bila request dibatalkan (`CancelToken` saat user berpindah target cepat), tidak terjadi error.
  - Bila server OSRM timeout / error (mis. status 400/500/offline), secara otomatis membuat fallback rute garis lurus (Haversine distance) dengan flag `isStraightLineFallback = true`.

### 4. `RealMapView` (`lib/widgets/real_map_view.dart`)
- **Tanggung Jawab:** Widget tampilan peta interaktif berbasis OpenStreetMap (`flutter_map` + `latlong2`).
- **Fitur:**
  - Layer tile OSM: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` dengan User-Agent identitas aplikasi.
  - Polyline rute jalan kaki (warna aksen amber atau garis putus-putus fallback).
  - Titik posisi pengguna dengan halo pulsasi.
  - Marker resto bernomor pin interaktif (dapat diketuk).
  - Kontrol kamera (tombol "Pusatkan", auto-fit rute camera).
  - Atribusi wajib OpenStreetMap di pojok kanan bawah.

### 5. `NearbyPage` (`lib/pages/nearby_page.dart`)
- **Tanggung Jawab:** Halaman utama fitur Jelajah Kuliner Sekitar (`/nearby`).
- **Integrasi:**
  - Switch antara peta ilustrasi (`IllustratedMap`) dan peta nyata (`RealMapView`).
  - Integrasi pencarian teks resto & filter cepat (Terdekat, Buka Sekarang, Harga Hemat).
  - Sheet filter kustom (Radius 1–5 km, rentang harga, status).
  - Sinkronisasi pemilihan resto pada kartu bawah dengan kamera dan rute di peta.
