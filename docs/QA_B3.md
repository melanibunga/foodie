# QA Report — Fase B3: Sinkronisasi Rating, Riwayat Dimasak, dan Audit Isolasi

**Tanggal Pengujian:** 2026-11-20  
**Target:** Foodie.id (Flutter / Riverpod / Hive)  
**Status:** LULUS (Semua kriteria terpenuhi, analisis bersih, 18/18 tes unit & integrasi hijau)

---

## 1. Lingkup Pekerjaan & Spesifikasi Fase B3

1. **Sinkronisasi Rating Tampil (`ratingSummaryProvider`)**:
   - Formula:
     $$\text{avg} = \frac{\text{baseRating} \times \text{dummyCount} + \text{sum}}{\text{dummyCount} + n}$$
     $$\text{reviews} = \text{dummyCount} + n$$
   - Menggabungkan rating dasar dummy (berbasis hash deterministik ID resep) dengan seluruh rating yang diberikan oleh pengguna aktif maupun pengguna lokal lainnya di Hive box `ratings`.
   - Mengembalikan `RatingSummary` yang berisi `rating` (rata-rata terhitung dibulatkan 1 desimal), `reviews` (total ulasan), `hasUserRating`, dan `userRating` (rating bintang khusus milik akun aktif).
   - Seluruh kartu menu (Home `FeaturedRecipeCard`, `GridRecipeCard`, `Popular`, `FavoriteRecipeCard`) dan halaman `RecipeDetailPage` menggunakan `ratingSummaryProvider` sehingga langsung ter-update secara reaktif saat rating diberikan.

2. **Layar Selesai Start Cooking & Riwayat Memasak (`CookedEntry`)**:
   - Menambahkan field `rating` pada model `CookedEntry` yang tersimpan di box `cooked` per akun aktif.
   - Pada layar selesai memasak di `CookPage`, pengguna dapat memberikan rating bintang (1–5) yang secara simultan disimpan ke:
     - Hive box `ratings` untuk `userId` aktif pada `recipeId` tersebut.
     - Hive box `cooked` untuk entri memasak terakhir akun aktif.
   - Pengguna dapat mengubah rating yang sudah dipilih sebelum meninggalkan layar.
   - Jika resep yang sama dimasak berulang kali:
     - Seluruh riwayat tetap tercatat (counter statistik bertambah, misalnya dimasak 3 kali = 3 entri).
     - Di antarmuka Riwayat Masak (`/cooked` via `byRecipe()`), resep tersebut tidak terduplikasi menjadi banyak baris (hanya 1 baris/kartu unik), menampilkan `Dimasak 3× · {tanggal terakhir}` dan badge `Rating kamu ★N` jika pernah diberi rating.

3. **Isolasi Data Profil & Halaman `/cooked`**:
   - Statistik profil (Favorit, Dimasak, Resep Saya) hanya menghitung data milik akun yang sedang login.
   - Halaman `/cooked` hanya menampilkan riwayat masakan akun yang sedang login.

4. **Audit Isolasi E2E Dua Akun**:
   - Akun User A memasak resep `ayam-kecap-bawang` dan memberi rating 5 bintang.
   - Akun User B mendaftar dan login:
     - Riwayat dimasak User B kosong (`cookedCount = 0`).
     - User B memasak resep yang sama dan memberi rating 3 bintang.
     - `ratingSummary` secara tepat menggabungkan rating A (5) dan B (3) dengan bobot ulasan dasar:
       $$\text{avg} = \frac{4.9 \times 184 + (5 + 3)}{184 + 2} \approx 4.9$$
       $$\text{reviews} = 186$$
     - User A melihat `userRating = 5`, sedangkan User B melihat `userRating = 3`.
   - User A menghapus favorit, jadwal meal plan, dan resep buatannya -> Data User B tetap utuh 100%.

5. **Pencegahan Kebocoran State Global**:
   - Seluruh personal provider (`favoritesProvider`, `cartProvider`, `mealPlanProvider`, `myRecipesProvider`, `cookedProvider`, `ratingsProvider`, `themeModeProvider`) mengamati `currentUserIdProvider`.
   - Tidak ada in-memory cache atau static list yang menyimpan data personal lintas sesi pengguna.

---

## 2. Hasil Eksekusi Pengujian Otomatis

### A. Pengujian Unit & Integrasi (`flutter test`)
- `test/phase_b1_hive_user_isolation_test.dart` (9 test) -> **Passed**
- `test/phase_b2_api_integration_test.dart` (6 test) -> **Passed**
- `test/phase_b3_sync_rating_cooked_isolation_test.dart` (3 test) -> **Passed**

**Total: 18 / 18 tests PASSED (0 failures)**

### B. Analisis Statis Kode (`flutter analyze`)
```text
Analyzing foodie_recipe...
No issues found! (ran in 7.0s)
```

---

## 3. Checklist Kepatuhan UI Freeze

- [x] Tidak ada perubahan layout, ukuran padding, margin, warna, atau font pada antarmuka.
- [x] Input rating 5 bintang di `CookPage` mempertahankan desain asli.
- [x] Grid 2 kolom kartu pada `/cooked` tetap mempertahankan layout dan token warna tema.
- [x] Tampilan kartu resep pada Home, Search, Favorites, dan Meal Plan tetap identik dengan desain referensi.
- [x] Tidak ada penambahan package liar (hanya menggunakan stack yang disetujui).
