# Laporan Pelacakan & Status Bug Frontend Foodie.id (Fase B0–B8)

Dokumen ini memuat audit lengkap terhadap 22 butir bug dan perbaikan UX (G1–G6, P1–P4, S1, A1–A4, M1–M2, N1–N2, D1–D3) sesuai **docs/PRD.md §14** dan panduan QA akhir Fase B8.

---

## 1. Tabel Matriks Keterlacakan Bug (Traceability Matrix)

| Kode Bug | Deskripsi & Gejala Awal | Akar Masalah | Fase Perbaikan | File Uji / Bukti Otomasi | Status |
| :--- | :--- | :--- | :---: | :--- | :---: |
| **G1** | Pill Favorit di AppHeader memakai ikon bookmark (seharusnya heart terisi putih), Semantics tidak akurat | Pemilihan ikon awal merujuk bookmark alih-alih `LucideIcons.heart` solid putih | **Fase B2** | `test/phase_b2_header_nearby_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **G2** | Tab ke-5 BottomNav berlabel "Loc" dengan pin lama, teks terpotong di bubble aktif 59×57 | Naming tab awal "Loc" dan ukuran padding font belum dioptimalkan untuk "Nearby" | **Fase B2** | `test/phase_b2_header_nearby_test.dart` | **TUNTAS** |
| **G3** | Toast snackbar bawaan menutupi elemen sticky bottom / durasi tidak pas | Menggunakan SnackBar default Scaffold tanpa jarak inset dari sticky bottom bar | **Fase B2** | `test/phase_b2_header_nearby_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **G4** | AppHeader di Home, Search, Add, Meal Plan, Nearby ikut ter-scroll ke atas | Header berada di dalam Sliver / SingleChildScrollView alih-alih di luar scroll viewport | **Fase B2** | `test/phase_b2_header_nearby_test.dart` | **TUNTAS** |
| **G5** | Deskripsi resep hilang di Detail Menu | Widget RecipeDetailPage belum merender `Recipe.description` di bawah baris judul | **Fase B4** | `test/phase_b4_detail_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **G6** | Start Cooking tidak memiliki alur rating setelah memasak selesai | Layar selesai memasak hanya menampilkan tombol kembali tanpa input rating 5 bintang dan persistensi ratings | **Fase B6** | `test/phase_b6_rating_cooked_profile_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **P1** | Tiga kolom statistik Profil (Favorit, Dimasak, Resep Saya) statis dan tidak bisa di-tap | Widget Container tidak dibungkus `InkWell` interaktif dan rute navigasi | **Fase B6** | `test/phase_b6_rating_cooked_profile_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **P2** | *Kasus Keyboard:* Sheet Edit Profil terdorong naik saat keyboard muncul hingga hanya tampak layer putih | `isScrollControlled` tidak dikombinasikan dengan padding `viewInsets.bottom` yang adaptif | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **P3** | *Kasus Button Naik:* Tombol "Kembali Ke Beranda" ikut naik di atas keyboard pada Search / My Recipes / Favorites | `Scaffold.resizeToAvoidBottomInset` aktif secara default pada halaman ber-sticky button | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **P4** | *Kasus No Space:* Tombol "Simpan" di sheet Edit Profil mepet navigasi gesture bar HP | Padding bawah sheet mengabaikan `MediaQuery.viewPadding.bottom` | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **S1** | BottomNav ikut naik saat mengetik di Search bar | `AppShell` memiliki `resizeToAvoidBottomInset: true` sehingga floating BottomNav terangkat | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **A1** | *Kasus Keyboard:* Sheet tambah bahan dan sheet langkah di Add Recipe terdorong putih | `AppBottomSheet` kontennya tidak fleksibel dalam ScrollView saat keyboard muncul | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **A2** | *Kasus Button Naik:* Tombol DONE di Add Recipe terdorong ke tengah layar saat input keyboard | Sticky bottom bar membungkus input di dalam Scaffold tanpa isolasi keyboard insets | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **A3** | Input langkah memasak panjang tertutup keyboard saat mengetik instruksi bawah | Modal sheet instruksi tidak memiliki scroll padding otomatis ke active field | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **A4** | Fokus input loncat kembali ke "Recipe Title" setelah menutup sheet bahan/langkah | State fokus controller lama tidak dilepas (`unfocus()`) saat sheet ditutup | **Fase B1** | `test/phase_b1_insets_keyboard_test.dart` | **TUNTAS** |
| **M1** | Carousel kartu Meal Plan di layar lebar/pendek berubah ukuran tidak menentu | Lebar kartu mengandalkan `MediaQuery.width - offset` alih-alih lebar tetap 330 dp | **Fase B3** | `test/phase_b3_meal_plan_test.dart` | **TUNTAS** |
| **M2** | Pengguna dapat menjadwalkan menu duplikat pada hari yang sama | Tidak ada validasi `has(date, recipeId)` pada `mealPlanProvider` dan tombol di UI | **Fase B3** | `test/phase_b3_meal_plan_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **N1** | Halaman Nearby hanya menampilkan ilustrasi SVG statis, bukan peta interaktif | Belum terintegrasi dengan engine peta `flutter_map` dan service rute pejalan kaki OSRM | **Fase B7** | `test/phase_b7_nearby_map_route_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **N2** | *Kasus No Space:* Tombol "Terapkan" di sheet Filter Nearby mepet gesture bar | Inset bawah modal sheet filter mengabaikan safe area | **Fase B1 & B7** | `test/phase_b1_insets_keyboard_test.dart`<br>`test/phase_b7_nearby_map_route_test.dart` | **TUNTAS** |
| **D1** | Tombol "Tambah ke keranjang" tidak toggle saat bahan sudah ada di belanjaan | State tombol hanya satu arah (tambah saja) tanpa deteksi keberadaan item di keranjang | **Fase B4** | `test/phase_b4_detail_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **D2** | Ikon meal plan di Detail Menu tidak reaktif terhadap status jadwal resep | Provider meal plan tidak di-watch secara real-time pada tombol kalender detail | **Fase B4** | `test/phase_b4_detail_test.dart`<br>`test/phase_b8_regression_qa_test.dart` | **TUNTAS** |
| **D3** | Tombol Back di Detail Menu ikut ter-scroll ke atas hilang dari pandangan | Tombol back berada di dalam scrollable content alih-alih Stack floating top-left | **Fase B4** | `test/phase_b4_detail_test.dart` | **TUNTAS** |

---

## 2. Hasil Audit Kode & Arsitektur
- **Design Tokens Compliance:** 0 hardcoded `Color(0x...)` atau `Colors.<name>` (selain `Colors.transparent`) di luar `lib/core/theme/`.
- **Image Architecture:** 100% pemuatan gambar eksternal/memory melalui `SmartImage` dan `ImagePlaceholder`.
- **Bottom Sheet Architecture:** Seluruh modal sheet (Filter, Edit Profil, Tambah Bahan, Langkah Memasak, Jadwal Meal Plan) menggunakan `showAppBottomSheet` terstandarisasi yang menangani safe area & keyboard insets.
- **Static Analysis:** `flutter analyze` menghasilkan **0 issue** (100% clean).
- **Automated Tests:** Seluruh 150+ unit, widget, dan regression test lulus (100% pass rate).
