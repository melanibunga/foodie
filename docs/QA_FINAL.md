# Laporan QA Akhir & Verifikasi Sistem (Fase B6)

**Tanggal:** 2026-11-20  
**Aplikasi:** Foodie.id (Resep & Belanja Bahan Nusantara)  
**Status Keseluruhan:** **LULUS SEMUA SKENARIO (PASSED)**

---

## 1. Verifikasi Skenario End-to-End (E2E)

Pengujian dilakukan melalui alur pengguna lengkap pada runtime Flutter/Android serta diverifikasi oleh test suite otomatis (`test/phase_b1_auth_hive_test.dart`, `test/phase_b2_api_integration_test.dart`, `test/phase_b3_rating_cooked_isolation_test.dart`, `test/phase_b4_local_notifications_test.dart`, `test/phase_b5_location_places_route_test.dart`).

| Langkah | Aksi Pengguna | Hasil Aktual | Status |
|---|---|---|---|
| 1 | Register User A (`andi@foodie.id`, nama "Andi", sandi "rahasia123") | Akun tersimpan di Hive `users` dengan password salt+SHA-256 (bukan plaintext). Sesi aktif dicatat di `session`. Auto-login ke Home. | **PASS** |
| 2 | Cari resep via API di Search ("Rendang") | API Masakan Nusantara mengembalikan resep nyata (`api:rendang-daging-khas-minang`). Loading skeleton tampil halus, data bahan & langkah terisi lengkap. | **PASS** |
| 3 | Tandai Favorit | Kartu resep menampilkan bookmark aktif. Resep masuk ke box `favorites` dengan key `andi@foodie.id`. | **PASS** |
| 4 | Tambah bahan ke Keranjang Groceries | Bahan-bahan resep masuk ke tab Belanjaan (`cart`), terkelompok per nama resep dengan header terstandarisasi. | **PASS** |
| 5 | Tambah ke Meal Plan | Menu berhasil dijadwalkan pada kalender meal plan (`mealPlan`). Tanggal lampau dinonaktifkan. | **PASS** |
| 6 | Masak (Start Cooking) + Rating Bintang 5 | Alur langkah memasak selesai, rating 5 bintang tersimpan di box `ratings` dan riwayat dimasak tersimpan di `cooked`. | **PASS** |
| 7 | Buat resep sendiri (Create Recipe) | Form resep tersimpan di `myRecipes`. Resep langsung tampil di Profil Saya dan tab pencarian lokal. | **PASS** |
| 8 | Aktifkan toggle "Pengingat makan" | Izin diminta, notifikasi terjadwal pada jam tetap 07:00 (14 hari ke depan) sesuai isi meal plan user aktif. | **PASS** |
| 9 | Buka tab Nearby & pilih rute | Titik tempat makan di sekitar Jl. Kaliurang / lokasi GPS terpetakan. Polyline OSRM jalan raya solid terhubung dari posisi user ke resto dengan estimasi waktu & jarak. | **PASS** |
| 10 | Logout dari Akun A | Sesi di box `session` dihapus. Route diarahkan kembali ke layar Login. | **PASS** |
| 11 | Register User B (`budi@foodie.id`, nama "Budi", sandi "budi456") | Akun baru terdaftar. Masuk ke aplikasi. | **PASS** |
| 12 | **Verifikasi Isolasi Akun B** | **Semua state personal kosong total:** Favorit: 0, Belanjaan: 0, Meal Plan: kosong, Resep Saya: 0, Riwayat Dimasak: 0. Tidak ada data milik Andi yang bocor. | **PASS** |
| 13 | Lakukan aksi berbeda untuk Akun B | Budi memfavoritkan "Soto Ayam", memberi rating 4 bintang, dan memasak menu tersebut. | **PASS** |
| 14 | Logout dari Akun B & Login kembali Akun A | Sesi Andi aktif kembali. **Semua data Andi utuh 100%:** Favorit Rendang ada, Belanjaan Rendang ada, Resep Buatan ada, Riwayat Dimasak ada. Rating rata-rata menggabungkan kontribusi Andi dan Budi secara adil. | **PASS** |

---

## 2. Pengujian Ketahanan Offline & Izin Perangkat

### A. Skenario Internet Mati (Offline Resilience)
1. **Resep yang Pernah Dibuka:**
   - Disimpan secara otomatis ke box Hive `recipeCache` dengan TTL 24 jam.
   - Saat internet dimatikan, halaman detail resep tetap dapat dibuka seketika dari cache lokal dengan indikator halus tanpa crash.
2. **Resep Baru yang Belum Ada di Cache:**
   - Menampilkan status error ramah yang informatif disertai tombol "Coba lagi".
3. **Tempat Makan Sekitar (Nearby):**
   - Menggunakan cache Hive `placesCache` (TTL 1 jam). Bila cache tidak tersedia, secara otomatis fallback ke `LocalPlaceService` disertai toast informatif *"Memakai data contoh"* (hanya muncul sekali).
4. **Rute Jalan Kaki (OSRM):**
   - Bila request rute gagal / offline, langsung fallback ke rute garis lurus perkiraan (*straight line dashed*) dengan toast *"Rute perkiraan"*.

### B. Skenario Izin Lokasi & GPS Ditolak
1. **GPS Dimatikan / Izin Ditolak:**
   - Tidak terjadi exception atau crash.
   - Aplikasi menggunakan koordinat fallback default Yogyakarta (Jl. Kaliurang KM 5: `-7.7653, 110.3789`).
   - Ditampilkan toast informatif: *"Lokasi tidak tersedia, memakai lokasi contoh"*.
   - Tombol "Pusatkan" memusatkan kamera ke posisi koordinat fallback.

### C. Skenario Izin Notifikasi Ditolak
1. **Izin POST_NOTIFICATIONS Ditolak Pengguna:**
   - Toggle "Pengingat makan" otomatis kembali ke posisi nonaktif.
   - Menampilkan toast: *"Izin notifikasi ditolak"*.
   - Pengaturan tersimpan aman di box `settings` tanpa error unhandled exception.

---

## 3. Pengujian Mode Gelap (Dark Mode) Menyeluruh

- **Cakupan Pengujian:** Diuji pada seluruh halaman utama: Login, Register, Home, Search, Detail Resep, Groceries, Meal Plan, Profil Saya, Nearby, Cook Mode, Cooked History, dan Create Recipe.
- **Konsistensi Warna Semantik:**
  - Latar belakang (`bg: #101815`, `surface: #1B2822`, `surfaceAlt: #26362F`).
  - Teks (`textStrong` & `textBody: #F5F5F0`, `textSecondary: #9AA597`).
  - Seluruh teks terbaca jelas dan memenuhi standar rasio kontras WCAG AA (>= 4.5:1).
  - Peta OpenStreetMap otomatis menggunakan matrix filter invert warna lembut sehingga menyatu dengan tema gelap.
- **Persistensi Tema:**
  - Pengaturan tema disimpan per user aktif di Hive `settings`.
  - Berpindah akun tetap mengingat preferensi tema masing-masing pengguna.

---

## 4. Audit Kebocoran Kode & Kepatuhan Arsitektur

Audit dilakukan menggunakan scanning `git grep` pada seluruh direktori `lib/`:

| Kriteria Audit | Hasil Scan | Keterangan | Status |
|---|---|---|---|
| **Tidak ada state personal global** | Bersih (0 temuan) | Semua data tersimpan per user di Hive boxes dengan prefix `userId`. | **PASS** |
| **Tidak ada `shared_preferences` tersisa** | Bersih (0 temuan) | Seluruh penyimpanan telah dimigrasi ke Hive (tanpa TypeAdapter). | **PASS** |
| **Tidak ada `Image.network` / `Image.asset` mentah** | Bersih (1 file saja) | Hanya ada di `lib/widgets/ui/smart_image.dart` sebagai wrapper sentral. | **PASS** |
| **Tidak ada akses langsung ke `data/recipes.dart` dari widget/halaman** | Bersih (0 temuan) | Seluruh widget mengakses data melalui `recipeServiceProvider` / Riverpod. | **PASS** |
| **Tidak ada `Color(0x...)` / `Colors.xxx` di luar `core/theme`** | Bersih | Hanya `Colors.transparent` untuk status bar / container dan scrim hitam visual foto. | **PASS** |
| **Tidak ada sisa referensi "Lupa kata sandi" / "forgot"** | Bersih (0 temuan) | Link telah dihapus total dari Login sesuai instruksi B1. | **PASS** |

---

## 5. Audit Performa & Stabilitas

1. **Konsol & Error Log:** Bersih dari unhandled exception, assertion error, maupun memory leak.
2. **Pengujian Responsivitas Multi-Resolusi:**
   - Diuji pada viewport lebar: **360 dp**, **390 dp**, **412 dp**, dan **440 dp**.
   - Hasil: **0 RenderFlex overflow**. Seluruh teks, kartu resep, dialog, dan form beradaptasi secara fluid.
3. **Pembatalan Request Jaringan (`CancelToken`):**
   - Saat pengguna berpindah halaman atau memilih resto lain di tab Nearby, request rute OSRM lama yang sedang berjalan langsung dibatalkan (`cancelToken.cancel('Place changed')`).
4. **Pembersihan Sumber Daya (Resource Disposal):**
   - Seluruh `TextEditingController`, `ScrollController`, `MapController`, dan `FocusNode` di-dispose dengan disiplin di method `dispose()`.

---

## 6. Usulan Penyempurnaan Visual Masa Depan (Non-Blocking)

Sesuai aturan UI Freeze, perubahan tampilan berikut tidak dieksekusi pada rilis ini dan dicatat sebagai usulan untuk iterasi selanjutnya:
1. *Skeleton Loading Shimmer:* Menambahkan efek shimmer gradasi bergerak pada placeholder loading pencarian dan Nearby untuk meningkatkan kehalusan visual.
2. *Pilihan Satuan Kustom:* Pada pembuatan resep baru, menambahkan dropdown autocomplete satuan bahan yang umum dipakai di Indonesia (misal: "sdm", "sdt", "siung", "ruas", "lembar").
3. *Animasi Pin Peta:* Menambahkan efek pantulan halus (*spring bounce*) saat pin tempat makan dipilih pada peta interaktif.
