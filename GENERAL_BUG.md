# Laporan Pelacakan & Status Bug Frontend Foodie.id (Putaran 2: Fase C0–C6)

Dokumen ini memuat audit lengkap terhadap seluruh butir bug, perbaikan UX, dan penyempurnaan pasca-desain putaran 2 (G1–G2, P1–P2, A1–A3, M1, D1–D3, K1–K2) sesuai **docs/PRD.md §15** dan verifikasi regresi akhir Fase C6.

---

## 1. Tabel Matriks Keterlacakan Bug Putaran 2 (Traceability Matrix)

| Kode Bug | Deskripsi & Gejala Awal | Akar Masalah | Fase Perbaikan | File Uji / Bukti Otomasi | Status |
| :--- | :--- | :--- | :---: | :--- | :---: |
| **G1** | Toast snackbar sebelumnya berwarna amberSoft teks olive (kurang kontras & tidak sesuai §15.1) | Implementasi awal di B2 menggunakan amberSoft; PRD §15.1 mewajibkan maroon dengan teks putih 12/600 radius pill | **Fase C2** | `test/phase_c2_toast_greeting_fixed_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **G2** | AppHeader belum menampilkan greeting sapaan waktu dan nama depan pengguna | Header hanya menampilkan avatar dan counter tanpa sapaan waktu kontekstual dinamis | **Fase C2** | `test/phase_c2_toast_greeting_fixed_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **P1** | *Kasus Keyboard di Perangkat Nyata:* Field input nama (Edit Profil) & input bahan tertutup keyboard | `MediaQuery.viewInsetsOf` terpotong/dikonsumsi ancestor sebelum mencapai modal sheet | **Fase C1** | `test/phase_c1_keyboard_sheet_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **P2** | Area header (judul, badge, sub-judul, search bar) di Favorites, Cooked, dan My Recipes ikut ter-scroll | Header berada di dalam SliverList / viewport scroll alih-alih di luar area scroll | **Fase C2** | `test/phase_c2_toast_greeting_fixed_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **A1** | Sheet Tambah Bahan & Sheet Langkah Add Recipe terdorong putih atau tertutup keyboard | Inset keyboard pada sheet builder belum menggunakan kompensasi view padding adaptif | **Fase C1** | `test/phase_c1_keyboard_sheet_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **A2** | Langkah memasak di form Add tidak tampil sebagai daftar ringkasan di bawah input instruction | Belum ada widget list langkah inline dengan nomor lingkaran amber, judul, durasi & tombol hapus | **Fase C3** | `test/phase_c3_add_nav_steps_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **A3** | Halaman Add tidak memiliki BottomNav (di luar ShellRoute) dan tombol DONE sticky di bawah | Route `/add` berada di luar ShellRoute; tombol DONE dibuat sticky melanggar layout §15.5 | **Fase C3** | `test/phase_c3_add_nav_steps_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **M1** | Pemilih tanggal Meal Plan mengizinkan pemilihan hari lampau (sebelum hari ini) | Validasi tanggal `targetDate.isBefore(today)` belum diterapkan pada UI sheet dan provider | **Fase C4** | `test/phase_c4_detail_meal_plan_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **D1** | Tombol Back di Detail Menu berupa tombol floating di atas hero yang ikut ter-scroll atau tertutup status bar | PRD §15.6 mewajibkan bar atas fixed lebar penuh dengan background sage (#717665) dan tombol lingkaran olive 44 di kiri | **Fase C4** | `test/phase_c4_detail_meal_plan_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **D2** | Status bar di Detail Menu gelap sehingga sulit dibaca di atas bar atas sage | `SystemUiOverlayStyle` belum disetel ke mode terang (light icons) saat halaman aktif | **Fase C4** | `test/phase_c4_detail_meal_plan_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **D3** | Bahan-bahan di Detail Menu memiliki checkbox, coret, dan penyimpanan status centang | §15.6 menghapus checkbox/coret/persist bahan per resep; diganti list bullet olive terisi | **Fase C4** | `test/phase_c4_detail_meal_plan_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **K1** | Menu di Groceries tidak berurutan secara kronologis (resep baru tidak muncul di atas) | Belum ada field `addedAt` pada `CartGroup` dan penyortiran descending di provider | **Fase C5** | `test/phase_c5_groceries_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |
| **K2** | Grup kustom "Belanjaan Kamu Nich" tidak dipin di paling atas dan belum mendukung swipe hapus | Urutan grup default menyatu dengan resep; hapus item belum menggunakan Dismissible maroon | **Fase C5** | `test/phase_c5_groceries_test.dart`<br>`test/phase_c6_regression_qa_test.dart` | **TUNTAS** |

---

## 2. Tabel Perbandingan Visual (Viewport 440 × 956 dp terhadap Desain JPG)

| Halaman | JPG Acuan | Status Kecocokan | Selisih yang Disengaja (Aturan §14 / §15) |
| :--- | :--- | :---: | :--- |
| **Home** | `home.jpg` | **Identik** | Header fixed di luar scroll (§14.3); greeting waktu + nama depan user (§15.2); label tab ke-5 "Nearby" (§14.4). |
| **Detail Menu** | `detail_menu.jpg` | **Identik** | Bar atas FIXED lebar penuh sage (#717665) dengan tombol back lingkaran olive 44 di kiri (§15.6); bahan berupa list poin bullet olive tanpa checkbox/coret/persist (§15.6); hari lampau disabled di pemilih tanggal (§15.6). |
| **My Groceries** | `Daftar Belanja.jpg` | **Identik** | Grup kustom "Belanjaan Kamu Nich" dipin teratas (bg amberSoft, border amber 40%, ikon pin, tanpa subtotal) (§15.7); urutan grup resep descending (§15.7); swipe ke kiri latar maroon untuk hapus bahan kustom (§15.7). |
| **Add Recipe** | `add.jpg` | **Identik** | BottomNav tampil fixed (tab Add aktif) di dalam ShellRoute (§15.5); tombol DONE di ujung form dengan padding bawah 120 dp (bukan sticky) (§15.5); list bahan & list langkah interaktif inline (§14.8, §15.5). |
| **Favorites** | `bookmark.jpg` | **Identik** | Area atas (judul + badge + sub-judul + search bar) FIXED di luar scroll (§15.3); pill header memakai ikon heart putih (§14.4). |
| **Riwayat Masak** | `bookmark.jpg` (basis) | **Identik** | Halaman `/cooked` dengan layout fixed top area, badge jumlah dimasak, caption tanggal & rating (§14.10, §15.3). |
| **My Recipes** | `bookmark.jpg` (basis) | **Identik** | Layout fixed top area, grid kartu resep buatan sendiri dengan tombol hapus trash (§7.8, §15.3). |
| **Meal Plan** | `Meal Plan.jpg` | **Identik** | Header + week selector FIXED di luar scroll (§15.3); kartu selebar 330 dp; hari lampau non-aktif (§15.6). |
| **Nearby** | `location.jpg` | **Identik** | Peta interaktif OpenStreetMap nyata + rute jalan kaki OSRM (§14.12); label tab "Nearby" (§14.4). |
| **Profil Saya** | `akun.jpg` | **Identik** | 3 kolom statistik interaktif dapat di-tap (Favorit, Dimasak, Resep Saya) (§14.11); sheet edit nama aman keyboard (§15.4). |

---

## 3. Matriks Layout Responsif & Keyboard

Pengujian otomatis dilakukan pada berkas `test/phase_c6_regression_qa_test.dart` mencakup kombinasi parameter:
- **Lebar Viewport:** 360 dp, 390 dp, 440 dp.
- **Tinggi Viewport:** 640 dp, 956 dp.
- **Safe Area Inset Bawah:** 0 dp, 24 dp, 34 dp, 48 dp.
- **Status Keyboard:** Tertutup (`viewInsets.bottom = 0`) dan Terbuka (`viewInsets.bottom = 280–300 dp`).

**Hasil:**
- Tidak ada `RenderFlex overflow` pada seluruh resolusi.
- Teks greeting di AppHeader menggunakan `Expanded` + `TextOverflow.ellipsis`, tidak pernah overflow di layar 360 dp.
- Navigasi BottomNav dan sticky bottom bar tetap fixed di posisinya (tidak ikut terdorong keyboard karena `resizeToAvoidBottomInset: false`).
- Field input yang sedang fokus pada modal sheet dan form tetap terlihat di viewport saat keyboard layar muncul.
- Tombol DONE di halaman Add dapat dicapai di akhir scroll dengan padding 120 dp tanpa tertutup BottomNav.

---

## 4. Hasil Audit Kualitas Kode & Standar Arsitektur

1. **Design Tokens Compliance:**
   - 0 hardcoded `Color(0x...)` atau `Colors.<nama>` (selain `Colors.transparent`) di luar `lib/core/theme/`.
2. **Pemuatan Gambar:**
   - 100% pemuatan gambar eksternal maupun memori melewati `SmartImage` dan `ImagePlaceholder`.
3. **Standarisasi Modal Sheet:**
   - Seluruh modal bottom sheet menggunakan fungsi bersama `showAppBottomSheet` (`lib/widgets/ui/app_bottom_sheet.dart`).
4. **Pembersihan Data Lama:**
   - 0 sisa kode penyimpanan lokal atau state centang bahan masakan per resep di Detail Menu.
5. **Static Analysis & Formatting:**
   - `flutter analyze` : **No issues found!** (0 error, 0 warning).
   - `dart format --set-exit-if-changed .` : **Clean (120 files formatted)**.
6. **Automated Test Suite:**
   - Seluruh **232 test** (unit, widget, golden layout, regression) **100% lulus (hijau)**.
