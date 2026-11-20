# Foodie.id (Aplikasi Resep & Belanja Bahan Nusantara)

Foodie.id adalah aplikasi mobile berbasis **Flutter (Dart 3)** untuk eksplorasi resep masakan Nusantara, perencanaan menu makan harian (*Meal Plan*), manajemen daftar belanja bahan pangan (*Groceries*), pencarian tempat makan terdekat (*Nearby Places*) berbasis OpenStreetMap, dan rute navigasi jalan kaki nyata via OSRM.

Aplikasi dirancang dengan standar kualitas tinggi: antarmuka presisi mengacu pada berkas desain (`design/*.jpg`), mode gelap menyeluruh (*comprehensive dark mode*), arsitektur state management modern menggunakan **Flutter Riverpod**, penyimpanan lokal berkecepatan tinggi berbasis **Hive**, serta integrasi API backend nyata.

---

## 🚀 Panduan Menjalankan Aplikasi

### 1. Prasyarat Sistem
- **Flutter SDK**: Versi 3.x / Dart 3.x (channel stable).
- **Perangkat Sasaran**: Android Emulator / Real Device (Android 8.0+ / API level 26+), iOS Simulator / Device, atau Google Chrome.

### 2. Mengunduh Dependensi
```bash
flutter pub get
```

### 3. Menjalankan Aplikasi

#### A. Mode Normal (Default: API Resep Nyata)
```bash
flutter run
```

#### B. Menggunakan Opsi `--dart-define`
Foodie.id mendukung flag lingkungan saat menjalankan aplikasi:
```bash
# 1. Reset data & paksa seed akun demo saat aplikasi mulai
flutter run --dart-define=RESET=true

# 2. Menggunakan sumber data lokal/seed (tanpa koneksi internet)
flutter run --dart-define=RECIPE_SOURCE=local

# 3. Menghubungkan ke API backend resep kustom
flutter run --dart-define=RECIPE_API_BASE=https://api-resep-masakan.vercel.app/api/v1
```

#### C. Menjalankan di Browser (Chrome)
```bash
flutter run -d chrome
```

---

## 👤 Akun Demo & Manajemen Data

### 1. Kredensial Akun Demo
Saat aplikasi pertama kali dipasang, akun demo otomatis di-seed:
- **Email**: `najmah@foodie.id`
- **Kata Sandi**: `password123`
- *Catatan:* Anda juga dapat mendaftarkan akun lokal baru tanpa batasan melalui menu **Daftar Akun**. Seluruh data tiap akun terisolasi secara mandiri.

### 2. Cara Mereset Data
- **Melalui Antarmuka Pengguna**: Buka tab **Profil Saya** -> Tekan tombol **Reset Data Akun**. Tindakan ini akan mengembalikan akun demo ke data awal tanpa menghapus akun user lain yang Anda daftarkan.
- **Menu Rahasia Pengembang (Hidden Dev Menu)**: Tekan lama (long press) pada nomor versi aplikasi di bagian bawah halaman Profil Saya untuk membuka dialog pengembang yang menyediakan opsi reset menyeluruh serta tombol uji kirim notifikasi lokal seketika.

---

## 🗄️ Struktur Penyimpanan Lokal (Hive Boxes)

Sesuai spesifikasi arsitektur data Foodie.id, seluruh penyimpanan lokal menggunakan **Hive NoSQL** tanpa `TypeAdapter` / code generator (disimpan sebagai Map JSON serializable). Terdiri dari 13 box:

| Nama Box Hive | Deskripsi & Isi Data |
|---|---|
| `users` | Akun terdaftar (id, nama, email, passwordHash SHA-256 + salt acak, avatar). |
| `session` | Sesi aktif pengguna saat ini (`currentUserId`). |
| `favorites` | Daftar id resep favorit terisolasi per `userId`. |
| `cart` | Bahan belanjaan aktif dan custom items terisolasi per `userId`. |
| `mealPlan` | Jadwal menu makan terencana per tanggal terisolasi per `userId`. |
| `myRecipes` | Resep buatan pengguna terisolasi per `userId`. |
| `cooked` | Riwayat resep yang telah dimasak beserta tanggal dan rating terakhir. |
| `ratings` | Rating bintang (1–5) yang diberikan pengguna per resep. |
| `settings` | Pengaturan lokal per user (tema gelap/terang, toggle pengingat makan). |
| `meta` | Metadata aplikasi (status seed awal, versi skema). |
| `recipes` | Tempat penyimpanan resep statis bawaan aplikasi. |
| `recipeCache` | Cache HTTP respons API resep masakan online (TTL 24 jam) untuk ketahanan offline. |
| `placesCache` | Cache query tempat makan OpenStreetMap Overpass API (TTL 1 jam). |

---

## 🏗️ Arsitektur Layanan & Manajemen State

```
[ Antarmuka / Widgets / Pages ]
              │ (ref.watch / ref.read)
              ▼
[ Riverpod Notifiers & Providers ]
              │
    ┌─────────┴─────────┐
    ▼                   ▼
[ Domain Services ]   [ Local Storage (Hive) ]
(Dio HTTP / GPS /     (13 Box terisolasi per user)
 Overpass / OSRM)
```

1. **State Management (`flutter_riverpod`)**:
   - Menggunakan arsitektur deklaratif, compile-safe, dan teruji tanpa singleton global yang rentan mencemari state.
2. **Layanan Jaringan (`Dio`)**:
   - `ApiRecipeService`: Integrasi REST API masakan Nusantara dengan pagination, dynamic search, error handling, dan caching offline berantai.
3. **Layanan Lokasi & Peta (`Geolocator` & `flutter_map`)**:
   - `LocationService`: Penanganan GPS dan izin lokasi dengan graceful fallback ke koordinat default (Jl. Kaliurang, Yogyakarta `-7.7653, 110.3789`).
   - `OverpassPlaceService`: Query Overpass API OpenStreetMap untuk mencari tempat makan nyata dalam radius 500m hingga 5km, dilengkapi parser `opening_hours` pintar.
   - `OsrmRouteService`: Perhitungan rute jalan kaki nyata berbasis GeoJSON OSRM dengan pembatalan request lama via `CancelToken` dan fallback garis lurus putus-putus.
4. **Layanan Notifikasi (`flutter_local_notifications` & `timezone`)**:
   - `LocalNotificationService`: Pengingat makan terjadwal otomatis pada jam 07:00 waktu setempat untuk 14 hari ke depan berdasarkan agenda meal plan user aktif.

---

## ⚠️ Batasan Sistem & Catatan Teknis (Limitations)

1. **Akun Lokal Per Perangkat**: Seluruh autentikasi dan penyimpanan data akun berjalan murni secara lokal di dalam database Hive perangkat (offline-first). Tidak ada sinkronisasi server antar-perangkat.
2. **Data Estimasi (Derived Data)**: Mengingat API resep publik masakan Nusantara berfokus pada nama, bahan, dan langkah masak, field porsi (*servings*), kalori (*kcal*), tingkat kesulitan, dan ulasan dasar diturunkan (*derived*) secara deterministik dari hash id resep agar konsisten di setiap sesi.
3. **Harga Bahan di Groceries**: API resep publik tidak menyediakan estimasi harga bahan baku. Seluruh harga awal bahan berharga Rp0 dan dapat diedit secara inline oleh pengguna di halaman Groceries.
4. **Server Publik Demo**:
   - Peta dan data tempat makan menggunakan server publik OpenStreetMap / Overpass API (`overpass-api.de`).
   - Rute jalan kaki menggunakan server publik OSRM (`router.project-osrm.org`).
   - Server-server ini digunakan murni untuk keperluan demo dan prototipe praktikum. Untuk skala komersial bervolume tinggi, disarankan menggunakan instance server mandiri (*self-hosted*).

---

## 🧪 Pengujian, Analisis Kode & Build APK

Seluruh modul dan kode aplikasi terverifikasi bersih tanpa error analyzer dan lulus seluruh rangkaian unit test:

```bash
# 1. Cek format kode
dart format --set-exit-if-changed .

# 2. Analisis statis linter
flutter analyze

# 3. Menjalankan seluruh pengujian otomatis
flutter test

# 4. Membangun APK Debug Android
flutter build apk --debug
```
