# PRD — Foodie.id (Frontend, Flutter)

> Dokumen ini adalah sumber kebenaran untuk membangun frontend Foodie.id dengan **Flutter (Dart)**.
> Desain referensi ada di folder `design/` (13 file JPG). **Kalau PRD ini bentrok dengan gambar desain, gambar desain yang menang**, kecuali bagian "Keputusan & Asumsi" (§12).

---

## 1. Ringkasan

**Foodie.id** adalah aplikasi mobile (Flutter, target utama Android & iOS) untuk menemukan resep masakan Nusantara, merencanakan menu mingguan, dan membuat daftar belanja bahan secara otomatis dari resep.

**Tujuan v1 (frontend only):**
1. UI **identik dengan desain** (pixel-faithful) di viewport 440 × 956 dp.
2. Semua alur di workflow berjalan end-to-end memakai **mock data + penyimpanan lokal (`shared_preferences`)** (belum ada backend).
3. Kode rapi, widget reusable, siap disambungkan ke API nanti.

**Bukan tujuan v1:** backend nyata, auth sungguhan, **foto makanan asli / integrasi API resep (sementara semua foto = placeholder abu-abu)**, peta sungguhan, pembayaran, dark mode penuh, notifikasi push, dukungan landscape.

---

## 2. Tech Stack (asumsi, boleh diganti sebelum mulai)

| Hal | Pilihan |
|---|---|
| Framework | Flutter (stable terbaru) + Dart 3, null safety |
| Platform | Android & iOS (utama). Web (Chrome) dipakai untuk QA visual / preview, bukan target rilis |
| UI | Widget Flutter + `ThemeData` kustom. Material 3 boleh jadi basis, tapi **semua** warna/teks/radius di-override lewat token (§4); jangan ada tampilan default Material yang beda dari desain |
| Routing | `go_router` (ShellRoute untuk halaman ber-bottom-nav) |
| State | `flutter_riverpod` (Notifier/AsyncNotifier) |
| Persist | `shared_preferences` (key berprefix `foodie:`) |
| Ikon | `lucide_icons` (cocokkan bentuk dengan desain; kalau ada ikon yang beda, gambar sendiri dengan `CustomPainter`/`Icon` kustom) |
| Font | Poppins (400, 500, 600, 700, 800), **di-bundle** di `assets/fonts/` dan didaftarkan di `pubspec.yaml` |
| Animasi | Implicit animation bawaan (`AnimatedContainer`, `AnimatedOpacity`, dll). Tanpa package animasi |
| Pilih gambar | `image_picker` (cover resep & foto profil) |
| Share | `share_plus` |
| Layar tetap menyala | `wakelock_plus` (Start Cooking) |
| Test | `flutter_test` untuk logika store/service (+ golden test opsional untuk QA visual) |
| Lint | `flutter_lints` (+ `dart format`) |

**Tanpa code generation** (tanpa `freezed`, `json_serializable`, `build_runner`). Model ditulis tangan lengkap dengan `copyWith`, `toJson`, `fromJson`. Jangan menambah package lain tanpa izin.

Struktur folder:

```
foodie/
├─ design/                ← 13 JPG desain + STYLE GUIDE.jpg (read-only referensi)
├─ docs/PRD.md
├─ assets/
│  ├─ fonts/              ← Poppins-Regular/Medium/SemiBold/Bold/ExtraBold.ttf
│  └─ images/             ← kosong dulu (foto makanan = placeholder abu-abu, lihat §10)
├─ test/
├─ pubspec.yaml
└─ lib/
   ├─ main.dart
   ├─ app/                ← app.dart (MaterialApp.router), router.dart, app_shell.dart, bootstrap
   ├─ core/
   │  ├─ theme/           ← app_colors.dart, app_text.dart, app_radius.dart, app_shadows.dart, app_theme.dart
   │  └─ utils/           ← format_rupiah.dart, week_utils.dart, debouncer.dart
   ├─ models/             ← recipe.dart, cart.dart, meal_plan_entry.dart, place.dart, app_user.dart
   ├─ data/               ← mock data (recipes, places, user, seed cart/meal plan)
   ├─ services/           ← recipe_service.dart (interface + LocalRecipeService; v1 = data lokal, nanti diganti API)
   ├─ providers/          ← store Riverpod (auth, favorites, cart, meal_plan, recipes, ui)
   ├─ widgets/
   │  ├─ ui/              ← AppButton, AppChip, AppInput, AppCheckbox, AppToggle, AppBadge, bottom sheet, dialog, toast, EmptyState, Skeleton, ImagePlaceholder, SmartImage
   │  └─ ...              ← AppHeader, AppBottomNav, FeaturedRecipeCard, GridRecipeCard, FavoriteRecipeCard, StatCard, IllustratedMap, dll
   └─ pages/              ← satu file/folder per halaman
```

---

## 3. Referensi Desain

Bagian §14 (Perubahan Pasca-Desain) MENANG atas gambar desain dan bagian PRD lain bila bentrok.

| File | Halaman | Ukuran (px) | Route |
|---|---|---|---|
| `splash.jpg` | Splash / Onboarding | 440×960 | `/` |
| `Login.jpg` | Login | 440×960 | `/login` |
| `Register.jpg` | Register | 440×960 | `/register` |
| `home.jpg` | Home | 440×1280 (scroll) | `/home` |
| `search.jpg` | Search | 440×960 | `/search` |
| `add.jpg` | Create Recipe | 440×960 | `/add` |
| `meal plan.jpg` | Meal Plan | 440×2892 (scroll) | `/meal-plan` |
| `location.jpg` | Nearby (tab "Loc") | 440×960 | `/nearby` |
| `bookmark.jpg` | Menu Favoritmu | 440×1217 (scroll) | `/favorites` |
| `detail_menu.jpg` | Detail Menu | 440×1608 (scroll) | `/recipe/:id` |
| `Daftar Belanja.jpg` | My Groceries (keranjang) | 440×960 | `/groceries` |
| `akun.jpg` | Profil Saya | 440×960 | `/profile` |
| `STYLE GUIDE.jpg` | Font + palet | — | — |

### Aturan kesetiaan desain (WAJIB)

1. **Lebar basis 440.** **1 px desain = 1 logical pixel (dp) Flutter** pada lebar 440. Pada layar lebih lebar dari 440 (web/tablet), tampilkan app di container tengah `maxWidth: 440`, background luar `#E9E9E2`. Pada layar lebih sempit, skala fluid (padding/typography tetap, kartu mengikuti lebar). **Jangan** memakai `MediaQuery.textScaler` untuk mengecilkan teks supaya muat.
2. **Abaikan device chrome pada desain:** status bar "9:41", sinyal/baterai, Dynamic Island, dan strip putih di atas splash **bukan bagian UI**. Jangan dibuat. Pakai `SafeArea`/`MediaQuery.padding` (lihat §12 butir 14 untuk padding atas).
3. **Semua foto di desain (makanan, kolase splash, avatar) diganti placeholder abu-abu** untuk v1 (lihat §10). Jangan memakai foto stok, jangan memotong foto dari JPG desain, dan jangan memakai gambar meme "Jujur / GUE MUAK" yang ada di Home & Bookmark. Ukuran, radius, rasio, dan overlay (hati, chip rating, chip waktu) tetap sama persis dengan desain.
4. Teks UI **salin persis** dari desain (campuran Inggris–Indonesia memang disengaja: "Daily Inspiration", "Popular", "Lihat Resep", dst.). Jangan diterjemahkan atau dikoreksi.
5. Setiap halaman selesai harus lolos **QA visual**: render di 440 × 956 (lihat cara di bawah), bandingkan berdampingan dengan JPG-nya, selisih posisi elemen utama ≤ 2 px, warna sama, teks sama. **Isi foto dikecualikan** dari perbandingan (hanya ukuran, radius, dan rasio area foto yang harus sama).

**Cara render untuk QA visual (pilih yang bisa dijalankan):**
- `flutter run -d chrome` lalu buka di jendela browser setinggi 956 px (app tampil sebagai kolom 440 di tengah) dan screenshot kolomnya; atau
- emulator/simulator dengan layar mendekati 440 × 956 dp; atau
- **golden test** di `test/golden/`: `tester.view.physicalSize = Size(440, 956)`, `devicePixelRatio = 1`, font Poppins dimuat lewat `FontLoader`, lalu `matchesGoldenFile`.

---

## 4. Design Tokens

Semua token didefinisikan **sekali** di `lib/core/theme/` dan dipakai lewat `AppColors.x`, `AppText.x`, `AppRadius.x`, `AppShadows.x`. Tidak boleh ada `Color(0x...)`, `Colors.xxx` (kecuali `Colors.transparent`), atau angka radius/ukuran font liar di dalam widget.

### Warna (dari STYLE GUIDE.jpg)

| Token | Hex | Pemakaian |
|---|---|---|
| `olive` (primary) | `#263C32` | Judul, tombol utama, bottom nav, pill bookmark, checkbox terisi, tombol back |
| `amber` (accent) | `#F59E0B` | CTA splash, tombol "Tambah ke keranjang", pill nav aktif, badge angka, nomor langkah, bintang rating, pin lokasi terpilih |
| `maroon` | `#800020` | Tombol "Lihat Resep", link ("Daftar", "Masuk", "Lupa kata sandi?", "Hapus menu", "Pilihan Chef"), ikon trash, ikon trending, toggle aktif, tombol Logout |
| `sage` | `#717665` | Teks sekunder, ikon placeholder, ikon plus di Add |
| `bg` | `#F5F5F0` | Background semua halaman (`scaffoldBackgroundColor`) |
| `white` | `#FFFFFF` | Kartu, input, search bar |

Warna turunan (ambil dengan color picker dari JPG kalau perlu presisi):

| Token | Perkiraan | Pemakaian |
|---|---|---|
| `amberSoft` | ≈ `#F4E9CE` | Tag "MASAK LEBIH MUDAH", tombol plus di Meal Plan |
| `maroonSoft` | ≈ `#F4E6E9` | Chip "Edit profil" |
| `fieldGray` | `#D6D6D6` | Input halaman Add (sesuai desain) |
| `chipGray` | ≈ `#E8E8E2` | Tombol filter bulat, tombol "Rute" non-aktif |
| `mapBg` / `mapBlock` | `#E7E9DE` / `#DEE3D8` | Peta ilustrasi |
| `splashDark` | ≈ `#082B21` | Bagian bawah splash |
| `photoGray` | `#D9D9D4` | Placeholder semua foto (makanan, hero splash, avatar) |
| `photoGrayIcon` | `#BDBDB5` | Ikon garpu-sendok kecil di tengah placeholder (disembunyikan bila area < 64 px) |
| `outerBg` | `#E9E9E2` | Background di luar kolom 440 (web/tablet) |
| `border` | `#E3E3DC` | Border tipis input/chip |
| `text` | `#263C32` untuk judul, `#1E1E1E` untuk teks badan, `#717665` untuk sekunder | — |

### Tipografi — Poppins

`AppText` menyediakan `TextStyle` per peran. Di Flutter, `height` = tinggi baris ÷ ukuran font (mis. 38/32 ≈ 1.19).

| Peran | Weight | Ukuran / tinggi baris (≈) |
|---|---|---|
| H1 auth ("Selamat datang kembali.") | 800 | 32 / 38 |
| Judul halaman (Menu Favoritmu, My Groceries, Profil Saya) | 700 | 26–28 / 34 |
| Judul section (Daily Inspiration, Popular, Pengaturan) | 700 | 20 / 28 |
| Judul kartu hero | 600 | 16 / 22 |
| Judul kartu kecil | 600 | 14 / 20 |
| Body | 400 | 13 / 20 |
| Label form | 600 | 12 / 18 |
| Caption / meta | 400 | 10–11 / 16 |
| Tombol | 600–700 | 12–15 |
| Label bottom nav | 600 | 10–11 |

### Radius, bayangan, jarak (≈, verifikasi ke desain)

- Padding horizontal halaman: **24** (splash: 28; detail menu: 25).
- Radius: kartu 16–20, kartu besar detail 32, input 12–14, tombol besar 12–14, tombol pill 999, bottom nav 999, bottom sheet atas 24.
- Bayangan kartu: `BoxShadow(color: olive @ 6%, offset (0,2), blur 8)`; bayangan bottom nav: `BoxShadow(color: black @ 18%, offset (0,8), blur 24)`.
- Tinggi minimum target sentuh: 40 (set `materialTapTargetSize: shrinkWrap` dan jaga ≥ 40 manual).

---

## 5. Komponen Global

### 5.1 `AppHeader` (Home, Search, Add, Meal Plan, Nearby)
- Kiri: **foto profil bulat ≈ 48** (x=24). Tap → `/profile`.
- Kanan (rata kanan, tepi kanan 24):
  - **Pill Bookmark**: bg olive, ikon bookmark putih + angka putih, **59 × 38** (diukur), radius pill. Angka = jumlah favorit. Tap → `/favorites`.
  - **Keranjang**: ikon cart olive + angka olive (tanpa background), di kanan pill dengan jarak ≈ 12. Angka = jumlah item di keranjang. Tap → `/groceries`.
- Posisi vertikal: baris header berpusat di y ≈ 84–122 (lihat §12 butir 14), jarak ke konten pertama ≈ 28.
- Halaman bersub-judul (Favorites, Groceries, Profile, Detail, Login, Register) **tidak** memakai header ini; masing-masing punya top bar sendiri (lihat §6).

### 5.2 `AppBottomNav` (floating pill)
- Floating (overlay di atas konten lewat `Stack`/`Positioned`), **365 × 75** (diukur) pada lebar 440 → lebar = lebar layar − 75, rata tengah; jarak bawah = `max(21, inset bawah perangkat)`; radius pill, bg olive, bayangan lembut.
- 5 item, jarak rata: **Home · Search · Add · Plan · Loc**. Ikon di atas, label di bawah (putih, 600, ≈ 10–11 px).
- **Item aktif** = lingkaran **amber 59 × 57** berisi ikon + label (warna olive tua), berada di dalam bar (bukan menonjol keluar).
- Ikon (lucide): `home`, `search`, `plus`, `calendarDays`, dan untuk "Loc" ikon bentuk kulkas/pantry (`refrigerator`) — **sesuai gambar desain**.
- Halaman yang **menyembunyikan** nav: Splash, Login, Register, Detail Menu, Start Cooking, Favorites, Groceries, Profile (diubah §15.5: Add tidak lagi masuk daftar, kembali memakai BottomNav). Implementasi: nav hanya ada di `ShellRoute` untuk `/home`, `/search`, `/add` (diubah §15.5), `/meal-plan`, `/nearby`; route lain di luar shell.
- Halaman dengan nav butuh `padding bawah` ≈ 120 agar konten tidak tertutup.

### 5.3 Widget UI dasar
- **AppButton**: varian `primary` (olive), `accent` (amber, teks olive tua), `danger` (maroon), `outlineDanger` (border maroon, teks maroon), `soft` (chipGray), `ghost`. Ukuran: `lg` 52 tinggi (radius 14), `md` 44, `sm` 40 / 32.
- **AppChip kategori**: tinggi ≈ 36, radius pill, aktif = olive + teks putih, non-aktif = putih + border tipis `border` + teks olive. Bisa scroll horizontal.
- **AppInput**: tinggi ≈ 48, radius 12, bg putih, border 1px `border`, ikon kiri sage, placeholder sage. Varian password dengan ikon mata di kanan.
- **Checkbox kotak**: 22 px, radius 6; terisi = olive + centang putih. **Checkbox bulat** (detail menu): 28 px, terisi olive.
- **Toggle**: track 52 × 30; aktif = maroon, non-aktif = `#E0E0DA` (token `toggleOff`); knob putih.
- **Badge angka**: kotak amber 42 × 42 radius 12 (Favorites) / pill olive (header).
- **Bottom Sheet**, **Dialog (alert)**, **Toast** — lihat §7 (tidak ada di desain, ikuti gaya yang sama).
- Aksesibilitas: setiap tombol ikon dibungkus `Semantics(label: ...)` atau `tooltip`.

### 5.4 Kartu resep (3 varian)

**A. `FeaturedRecipeCard`** — dipakai di Home (Daily Inspiration) dan Meal Plan.
- Lebar ≈ 330 (carousel horizontal, snap, **terlihat sebagian kartu tetangga ≈ 12–24 px di sisi**; pakai `PageView` dengan `viewportFraction`/`padEnds: false` atau `ListView` + snap physics), bg putih, radius ≈ 20, bayangan kartu.
- Foto atas tinggi ≈ 175, radius atas ikut kartu. Overlay: tombol hati (lingkaran putih semi-transparan ≈ 32) kanan atas; chip kiri bawah ikon jam maroon + "25 Menit" (teks putih tebal di atas gradien gelap tipis).
- Konten (padding ≈ 14): judul (16/600), deskripsi 1 baris terpotong "…" (11, sage; `maxLines: 1`, `overflow: ellipsis`), baris bawah: bintang amber + "4.9" (600) + "(340 ulasan)" (sage) di kiri; tombol maroon **"Lihat Resep →"** **122 × 40** (radius ≈ 10, teks putih 12/600) di kanan.

**B. `GridRecipeCard`** — Home (Popular) dan Search results.
- 2 kolom, gap ≈ 12, bg putih, radius ≈ 16. Foto kotak (≈ 1:1) dengan hati kanan atas (outline putih; saat difavoritkan terisi maroon) dan chip rating kiri bawah (pill gelap semi-transparan, bintang amber + "4.8" putih).
- Bawah: caption "Chicken · Indonesian" (10, sage), judul "Soto Ayam" (14/600), ikon `circle-plus` maroon (outline) di kanan → quick-add bahan ke keranjang + toast.

**C. `FavoriteRecipeCard`** — Favorites (dan My Recipe).
- Sama dengan B, tetapi ikon kanan bawah = **trash maroon** (hapus dari favorit, dengan dialog konfirmasi).

---

## 6. Spesifikasi Halaman (sesuai desain)

### 6.1 Splash — `splash.jpg` — `/`
- Full-bleed (`Stack`). **Setengah atas**: foto kolase (bumbu melayang: bawang merah, cabai, bawang putih, jeruk nipis, kecap manis, daun ketumbar di atas latar teal/maroon; piring nasi goreng + sate di bagian bawah foto). Untuk v1 diganti **blok `photoGray` polos** (tinggi ≈ 600, tanpa ikon) yang memudar ke splashDark; label melayang tetap ditampilkan di atasnya. Saat foto asli tersedia: 1 gambar utuh (`splash-hero.jpg`).
- **Label melayang** di atas foto (`Positioned`, persentase terhadap lebar):
  - "Bumbu Halus" — pill olive + lingkaran putih ber-border olive berisi ikon keranjang, kiri atas (≈ x 95, y 210).
  - "Kecap Manis" — pill olive + lingkaran putih berisi `+`, tengah kanan (≈ x 205, y 300).
  - "Siap Masak" — pill **amber** + lingkaran ikon keranjang, kiri bawah (≈ x 70, y 435).
- Foto memudar (`LinearGradient`) ke **splashDark** mulai ≈ y 560.
- **Blok bawah** (rata tengah): logo = lingkaran putih berisi ikon garpu-sendok + teks **"FOODIE.ID"** (putih, 800, letter-spacing lebar; titik "." amber); judul 2 baris putih "Jelajahi Cita Rasa" / amber "Autentik Nusantara" (700, ≈ 22); paragraf putih 70% "Ribuan resep masakan khas daerah & belanja bahan segar dalam satu genggaman praktis." (12, maks 2 baris); tombol amber **383 × 44** "Mulai Eksplorasi →" (radius ≈ 12, bayangan amber lembut); baris kecil: "✓ 100% Halal • ✓ Bahan Segar Terpilih" (centang amber, teks putih 60%, 11).
- Status bar: ikon terang (`SystemUiOverlayStyle.light`) di halaman ini; halaman lain ikon gelap.
- Aksi: tombol → `/login` (atau `/home` bila sudah login).

### 6.2 Login — `Login.jpg` — `/login`
- Top bar: ikon panah kiri + "Login" (16/500), kembali ke `/`.
- Tag **"MASAK LEBIH MUDAH"** (amberSoft, teks olive 9/700 uppercase, radius ≈ 10, ≈ 173 × 26) di x=24.
- H1 2 baris: **"Selamat / datang kembali."** (32/800 olive). Sub: "Masuk dan lanjutkan cerita dapurmu." (13, sage).
- Kartu putih (x=24, lebar 392, radius 20, padding 20):
  - Label "Email" + input (ikon amplop) placeholder "Masukkan email kamu".
  - Label "Kata sandi" + input (ikon gembok, ikon mata kanan) placeholder "Masukkan kata sandi".
  - Baris: checkbox "Ingat saya" (kiri) · link maroon **"Lupa kata sandi?"** (kanan).
  - Tombol olive **352 × 52** "Masuk".
- Di bawah kartu (tengah): "Belum punya akun? **Daftar**" (Daftar maroon 700) → `/register`.
- Footer tengah dekat dasar: "Ide masak sehari-hari, dalam satu tempat." (11, sage).
- Halaman bisa di-scroll (`SingleChildScrollView`) supaya aman saat keyboard muncul.
- Validasi: email valid, sandi ≥ 8 karakter; error di bawah field (maroon 11). Sukses → set session mock → `/home`.

### 6.3 Register — `Register.jpg` — `/register`
- Struktur sama dengan Login. Top bar "Register". Tag sama. H1 **"Resep baru, / cerita baru."** Sub "Buat akun untuk mulai masak versimu."
- Field berurutan: **Nama lengkap** (ikon user, "Masukkan nama lengkap"), **Email**, **Kata sandi** ("Minimal 8 karakter", ikon mata), **Konfirmasi kata sandi** ("Ulangi kata sandi", ikon mata).
- Checkbox: "Aku menyetujui **Syarat & Ketentuan** dan **Kebijakan Privasi.**" (link maroon 600, teks 11). Wajib dicentang.
- Tombol olive "Daftar". Bawah: "Sudah punya akun? **Masuk**". Footer tagline sama.

### 6.4 Home — `home.jpg` — `/home`
Urutan dari atas:
1. `AppHeader` global (§5.1).
2. Judul **"Daily Inspiration"** (20/700 olive, x=24).
3. Carousel horizontal `FeaturedRecipeCard` (rekomendasi acak; ≥ 5 item; snap; kartu tetangga mengintip di kiri dan kanan).
4. Judul **"Popular"** dengan ikon `trending-up` maroon di kiri judul.
5. Grid 2 kolom `GridRecipeCard` (menu terpopuler, urut rating × ulasan).
6. Bottom nav (aktif: Home).
- Seluruh halaman satu `CustomScrollView`/`ListView` vertikal (grid memakai sliver atau `shrinkWrap` + `NeverScrollableScrollPhysics`).
- Tombol hati = toggle favorit (sinkron dengan pill bookmark). "Lihat Resep" dan tap kartu → `/recipe/:id`.

### 6.5 Search — `search.jpg` — `/search`
1. `AppHeader` global.
2. Baris pencarian: search bar putih pill (tinggi ≈ 40, ikon kaca pembesar sage, placeholder **"Search Recipes..."**) + tombol filter bulat chipGray (ikon `slidersHorizontal`) di kanan.
3. Judul **"Search by Meal"** (20/700 olive).
4. Grid 2 kolom tile foto (radius ≈ 20, tinggi ≈ 90, **tanpa label teks** pada desain) — kategori: Breakfast, Lunch, Dinner, Snack, Dessert, Drinks. Beri `Semantics(label:)`. **Selama foto masih placeholder abu-abu, tampilkan nama kategori (olive 600, 14) di tengah tile supaya tile bisa dibedakan; label ini DIHAPUS otomatis begitu `image` terisi.**
5. Bottom nav (aktif: Search).
- Interaksi: mengetik (debounce 250 ms) atau tap tile → ganti area tile menjadi hasil (`GridRecipeCard`, 2 kolom) dengan judul "Hasil pencarian" + tombol "Bersihkan"; kosong → empty state. Tombol filter → Filter Sheet (§7.2). Tap kartu → `/recipe/:id`. Kalau halaman dibuka dalam **mode pilih resep dari Meal Plan** (`/search?pick=YYYY-MM-DD`), kartu diberi aksi "Tambahkan ke {Hari}" dan setelah memilih kembali ke `/meal-plan`.

### 6.6 Create Recipe — `add.jpg` — `/add` (diubah §15.5)
1. `AppHeader` global.
2. Baris judul: panah kiri `<` + **"Create Recipe"** (20/700 olive). Back → `/home`.
3. **"Recipe Title"** (label 14/700) + input `fieldGray` (radius ≈ 10, bayangan halus) placeholder "Type your recipe name here".
4. Dua kolom:
   - Kiri **"Add Cover Image"** + kotak `fieldGray` ≈ 138 × 100, teks tengah "Add Cover Image"; tap → `image_picker` (galeri); setelah dipilih tampilkan preview gambar (cover).
   - Kanan **"Ingredients"** + kotak `fieldGray` berisi lingkaran sage + `+` dan teks "Add ingredients to recipe"; tap → Sheet bahan (§7.3). Setelah ada bahan tampilkan "N ingredients".
5. **"Serving Size"** + chip dropdown `fieldGray` (ikon `users` + angka "3" + chevron). Tap → popover 1–12.
6. **"Cooking Instructions"** + kotak `fieldGray` placeholder "Add one or multiple steps"; tap → Sheet langkah (§7.4). Setelah ada langkah tampilkan "N steps". (diubah §15.5: langkah yang sudah ditambah tampil sebagai list di bawah kotaknya).
7. Tombol olive pill **"DONE"** (uppercase, 700, lebar penuh ≈ 362 × 55) (diubah §15.5: kembali memakai BottomNav fixed, tombol DONE tidak sticky tetapi di ujung form dengan padding bawah ±120).
- DONE → validasi (judul, ≥ 1 bahan, ≥ 1 langkah) → simpan ke store `myRecipes` → Dialog sukses "Resep berhasil disimpan" (§7.5) → Oke → `/my-recipes`.

### 6.7 Meal Plan — `meal plan.jpg` — `/meal-plan`
1. `AppHeader` global.
2. Pemilih minggu (tengah): tombol bulat olive 35 px dengan chevron putih (kiri/kanan) mengapit judul **"This Week"** (22/700). Minggu lain: "Last Week", "Next Week", atau rentang tanggal ("10–16 Nov").
3. **7 section hari** (Monday–Sunday): judul hari (18/700 olive) kiri; tombol **plus** bulat ≈ 28 (amberSoft, ikon plus olive) kanan, tepi kanan 24.
4. Di bawah tiap hari: carousel horizontal `FeaturedRecipeCard` (kartu pertama lebar penuh, kartu berikutnya mengintip kanan). Hari kosong → kartu putus-putus "Belum ada menu" dengan tombol "+ Tambah menu".
5. Bottom nav (aktif: Plan).
- Plus → `/search?pick=<tanggal>`.
- **Tekan lama (≥ 500 ms)** pada kartu (`GestureDetector.onLongPress`; otomatis batal bila jari bergeser/scroll) → Dialog hapus (§7.6) → hapus dari plan.
- Minggu lalu tetap bisa dilihat (read-only boleh, tapi hapus tetap diizinkan).

### 6.8 Nearby — `location.jpg` — `/nearby`
1. `AppHeader` global.
2. Baris pencarian: search bar putih (placeholder **"Cari resto atau rumah makan"**) + tombol filter bulat chipGray.
3. Chip filter (tunggal-pilih, scroll horizontal): **Terdekat** (default aktif), **Buka sekarang**, **Harga hemat**.
4. **Kartu peta** (lebar 375, tinggi ≈ 210, radius 20): peta **ilustrasi statis** digambar dengan `CustomPaint`/`CustomPainter` (`IllustratedMap`): bg mapBg, jalan putih, blok hijau muda, label jalan "Jl. Kaliurang" & "Pratinjau area" (kecil, sage); pill putih **"Radius 1 km"** kiri atas; **pin bernomor** (aktif = amber, lain = olive, lingkaran 28 putih-border); titik lokasi pengguna (lingkaran olive + halo hijau muda); garis putus-putus olive dari titik pengguna ke pin terpilih; tombol pill putih **"Pusatkan"** kanan bawah.
5. Judul **"Pilihan Di Sekitarmu"** (18/700) + kanan "3 tempat" (sage 11) — jumlah dari data.
6. Daftar kartu putih (radius 12): lingkaran nomor (terpilih = amber, lain = chipGray) · nama (13/700) · "Masakan Jawa · Rp15–30 rb" (11 sage) · "180 m · 3 menit" (11 sage) · kanan: status "Buka"/"Tutup" kecil di atas tombol **Rute** (terpilih = olive teks putih; lain = chipGray teks olive).
7. Bottom nav (aktif: Loc).
- Tap kartu = pilih (pin jadi amber, garis rute berpindah). Tombol Rute → toast "Membuka rute ke {nama}" (v1; nanti bisa deep-link ke Maps). Filter mengurutkan/menyaring daftar dan pin.

### 6.9 Favorites — `bookmark.jpg` — `/favorites`
- Tanpa header global. Judul **"Menu Favoritmu"** (26/700 olive) + badge amber 42×42 berisi jumlah (mis. "6") di kanan. Sub: "Simpan idenya, masak kapan saja." (13 sage).
- Search putih radius ≈ 14, ikon kaca pembesar, placeholder **"Cari nama menu favorit..."**.
- Label **"Filter bahan utama"** (13/700) + chip: **Semua** (aktif), **Ayam**, **Telur**, **Kangkung** (scroll horizontal; dinamis dari bahan utama resep favorit).
- Grid 2 kolom `FavoriteRecipeCard`.
- Tombol olive pill **"Kembali Ke Beranda"** (lebar ≈ 355, tinggi 48, tebal 700) **sticky di bawah** layar (bottom ≈ 24), konten diberi padding bawah agar tidak tertutup. → `/home`.
- Tap kartu → detail. Trash → Dialog konfirmasi → hapus dari favorit.

### 6.10 Detail Menu — `detail_menu.jpg` — `/recipe/:id` (diubah §15.6)
Urutan dari atas (semua padding horizontal 25):
1. **Foto hero** (lebar 390, tinggi ≈ 270, radius ≈ 28). Overlay: tombol back lingkaran **olive 44** (panah putih) kiri atas (diubah §15.6: bar atas FIXED sage dengan tombol back lingkaran olive 44); kanan atas dua lingkaran putih semi-transparan ≈ 40: **share** dan **heart** (toggle favorit).
2. Baris judul: **"Ayam Kecap Bawang"** (22/700 olive) + tombol ikon `calendar-plus` di kanan (**Add to meal plan** → sheet pilih hari/tanggal).
3. Rating: bintang amber + "4.9" (600) + "(184 ulasan)" (sage).
4. Dua tombol sejajar: **"Tambah ke keranjang"** (amber, ≈ 213 × 44, teks olive tua 12/600) dan **"Tambah ke favorit"** (olive, ≈ 163 × 44, teks putih). Tombol favorit berubah jadi "Tersimpan di favorit" saat aktif.
5. **Kartu ringkasan** (bg `#F4F1EA` → token `summaryBg`, bayangan halus, radius ≈ 14) 3 kolom: ikon garpu-sendok maroon **Porsi / 2 Orang**; ikon api maroon **Kalori / 450 kkal**; ikon gauge maroon **Tingkat / Mudah**. Label 10 sage, nilai 12/600.
6. Judul **"Bahan-Bahan"** (18/700 olive) lalu **kartu putih besar** (radius 32, lebar hampir penuh) berisi daftar (diubah §15.6: tanpa checkbox/coret/persist; tiap baris bullet lingkaran olive terisi ±10 + nama 15/400 + takaran rata kanan 13/700).
7. Baris judul **"Langkah Memasak"** (18/700) + kanan "25 menit" (sage 12). Kartu putih (radius 32): daftar langkah — lingkaran amber 28 berisi nomor (olive tua), judul langkah (16/700), deskripsi (12, sage).
8. Tombol olive pill **"Start Cooking >"** (lebar 390, tinggi 52, 700) → `/recipe/:id/cook`.
9. Catatan kecil tengah: "Kalori merupakan estimasi per porsi, tanpa nasi." (11 sage).
- "Tambah ke keranjang" → **semua bahan otomatis masuk** ke keranjang sebagai satu grup bernama resep itu, toast "Bahan ditambahkan ke keranjang". Jika grup sudah ada → toast "Sudah ada di keranjang" (tidak duplikat).

### 6.11 My Groceries (Keranjang) — `Daftar Belanja.jpg` — `/groceries` (diubah §15.7)
- Top bar: panah kiri + **"My Groceries"** (24/700 olive).
- **Add bar** (kartu putih, radius 14, tinggi ≈ 52): lingkaran chipGray berisi ikon cart; teks placeholder **"+ Tambah bahan belanja…"**; pill harga chipGray "Rp" (input angka, `FilteringTextInputFormatter.digitsOnly`); tombol persegi olive 36 × 36 radius 10 berisi `+`. Menambah → masuk ke grup **"Belanjaan Kamu Nich"** (item custom).
- **Urutan grup & item (diubah §15.7):** urutan descending (grup menu dari paling baru ditambahkan; item custom terbaru di atas). "Belanjaan Kamu Nich" selalu dipin di paling atas dengan latar amberSoft, border amber @ 40%, tanpa tombol hapus menu, dan hapus bahan lewat swipe Dismissible latar maroon.
- **Grup per menu** (kartu putih, radius 16, padding ≈ 16): header = nama menu (15/700 olive) kiri + **"Hapus menu"** (maroon 11/600) kanan; baris item: checkbox kotak 22 · nama (14/600) + takaran (11 sage) di bawahnya · harga rata kanan (13/600 "Rp 4.000"). Item tercentang = nama **coret** + sage + checkbox olive. Footer kanan bawah kartu: **"Subtotal Rp 9.000"** (10 sage). Grup custom tidak menampilkan subtotal.
- Catatan kecil: "Harga estimasi, ketuk item untuk mengubah" → tap harga/baris membuka edit harga inline.
- **Panel ringkasan sticky bawah** (putih, radius atas ≈ 24, padding 24): "Total estimasi (belum dibeli)" (11 sage), **"Rp 18.000"** (24/700 olive) kiri; tombol olive **"Kosongkan semua"** (≈ 164 × 44) kanan → Dialog konfirmasi.
- **Aturan hitung (diverifikasi dari desain):** *Subtotal grup* = jumlah **semua** item di grup. *Total estimasi* = jumlah **item yang belum dicentang** di semua grup (contoh desain: 3.000 + 5.000 + 3.000 + 7.000 = 18.000).
- Tanpa bottom nav.

### 6.12 Profil Saya — `akun.jpg` — `/profile`
- Top bar: panah kiri + **"Profil Saya"** (24/700).
- **Kartu profil** (putih, radius 20): foto bulat ≈ 80; nama **"Najmah Cleosaa Tokek"** (18/700); email (12 sage); chip **"✎ Edit profil"** (maroonSoft, teks maroon 12/600, ikon pensil).
- **Kartu statistik** (putih) 3 kolom dengan pemisah vertikal tipis: ikon hati maroon / **6** / "Favorit"; ikon topi koki amber / **12** / "Dimasak"; ikon buku maroon / **4** / "Resep Saya" (→ `/my-recipes`). Angka 24/700, label 12 sage.
- Judul **"Pengaturan"** (20/700).
- **Kartu pengaturan**: "Pengingat makan" + sub "Notifikasi jadwal makan aktif" + toggle (aktif = maroon); garis pemisah; "Mode gelap" + sub "Tampilan terang sedang digunakan" + toggle (non-aktif).
- **Kartu "Tentang aplikasi"** (ikon info bulat, sub "Kenali teman masakmu lebih dekat", chevron kanan) → `/about`.
- Tombol **Logout** (outline maroon 1.5px, radius 12, ikon `log-out`, teks maroon 700, tinggi ≈ 48, lebar penuh) → hapus session → `/login`.
- "Versi 1.0.0" (11 sage, tengah). **Tekan lama** teks versi = menu dev tersembunyi "Reset data demo" (§11). Tanpa bottom nav.
- "Edit profil" → Sheet edit nama + foto (§7.7).

---

## 7. Halaman & Komponen yang BELUM Ada di Desain

Bangun dengan **bahasa visual yang sama** (token §4, radius, bayangan, Poppins). Jangan menambah warna baru.

### 7.1 Start Cooking — `/recipe/:id/cook`
Layar penuh, tanpa nav. Top bar: tombol tutup `x` (kiri, kembali ke detail) + teks "Langkah 2 dari 4" (tengah, sage) + progress bar segmen amber di bawahnya. Konten tengah (`PageView`, mendukung **swipe kiri/kanan** bawaan): lingkaran amber besar (64) berisi nomor langkah (olive tua, 28/700); judul langkah (24/700 olive); deskripsi (16/400, tinggi baris 26); bila ada durasi → chip timer "⏱ 3 menit" dengan tombol Mulai/Jeda (countdown, `Timer.periodic`, dibatalkan di `dispose`). Bawah: tombol **"Sebelumnya"** (outline olive) dan **"Berikutnya"** (olive, lebar sisa); langkah terakhir → **"Selesai"** (amber). Layar menyala selama halaman aktif (`wakelock_plus`, dimatikan saat keluar). Layar selesai: ikon centang amber, "Selamat, masakanmu siap! 🎉", tombol "Kembali ke Beranda", dan menambah counter "Dimasak" +1.

### 7.2 Filter Sheet (Search & Nearby)
Bottom sheet putih radius atas 24, handle abu di atas, judul "Filter" + "Reset" (maroon). Search: Tingkat kesulitan (Mudah/Sedang/Sulit), Waktu masak (< 15 / 15–30 / > 30 menit), Bahan utama (Ayam, Telur, Sapi, Ikan, Sayur, Kangkung) — pakai chip. Nearby: Radius (500 m / 1 km / 2 km / 5 km), Kisaran harga. Tombol olive lebar penuh "Terapkan".

### 7.3 Sheet Tambah Bahan (Add)
Field "Nama bahan", "Jumlah", "Satuan" (dropdown: g, kg, ml, l, sdm, sdt, butir, siung, buah, bungkus, ikat); tombol amber "Tambah"; daftar bahan yang sudah ditambahkan (hapus dengan trash maroon); tombol olive "Simpan". Sheet harus naik mengikuti keyboard (`isScrollControlled: true` + `viewInsets.bottom`).

### 7.4 Sheet Cooking Instructions (Add)
Daftar langkah bernomor (lingkaran amber), tiap langkah: input judul + textarea deskripsi + durasi opsional; tombol "+ Tambah langkah"; hapus langkah; tombol olive "Simpan".

### 7.5 Dialog Sukses Simpan Resep
Dialog tengah, overlay `olive @ 45%`, kartu putih radius 24, lebar 320, padding 24: lingkaran amber 56 berisi centang olive, judul **"Resep berhasil disimpan"** (18/700 olive), sub "Resepmu sudah bisa dilihat di Resep Saya." (13 sage), tombol olive **"Oke"** lebar penuh.

### 7.6 Dialog Hapus (alert)
Kartu sama: judul ("Hapus dari meal plan?"), sub, dua tombol: **"Batal"** (outline olive) dan **"Hapus"** (maroon). Dipakai juga untuk hapus favorit, "Hapus menu" di keranjang (opsional), dan "Kosongkan semua".

### 7.7 Sheet Edit Profil
Avatar + "Ganti foto" (`image_picker`), input Nama, input Email (readonly), tombol olive "Simpan".

### 7.8 My Recipe — `/my-recipes`
Meniru Favorites: judul **"Resep Saya"** + badge amber jumlah, search "Cari resep buatanmu...", grid `FavoriteRecipeCard` (ikon kanan bawah = trash). Tombol sticky "Kembali Ke Beranda". Empty state: ilustrasi sederhana + "Belum ada resep. Yuk buat yang pertama!" + tombol amber "Buat Resep" → `/add`.

### 7.9 Lain-lain
- **Toast**: pill olive, teks putih 12/600, radius 999, muncul 24 px di atas bottom nav (atau di atas tombol sticky), hilang 2.2 s. Diimplementasikan dengan `OverlayEntry` (helper `showAppToast(context, msg)`), bukan `SnackBar` default.
- **Empty state** (favorit, keranjang, hasil cari): ikon besar sage 48 + judul 16/700 + sub 12 sage, rata tengah.
- **Lupa kata sandi** `/forgot`: top bar "Lupa kata sandi", 1 input email + tombol olive "Kirim tautan" → toast.
- **Tentang aplikasi** `/about`: logo FOODIE.ID, versi, deskripsi singkat, tagline.
- **Share** (detail): `share_plus` (`Share.share`); bila gagal/tidak didukung, fallback salin tautan ke `Clipboard` + toast.
- **Mode gelap**: toggle di Profil menyimpan preferensi, tetapi tema gelap penuh ditunda ke fase opsional.
- **Loading / error**: loading = `Skeleton` abu-abu berdenyut (dibuat sendiri dengan `AnimationController`, tanpa package shimmer); error = "Gagal memuat. Coba lagi" + tombol.

---

## 8. Navigasi & Alur

```
/ (Splash) → /login ⇄ /register → /home
/home ─┬─ tab: /search · /add · /meal-plan · /nearby
       ├─ avatar → /profile (→ /my-recipes, /about, logout → /login)
       ├─ pill bookmark → /favorites → (Kembali Ke Beranda) /home
       └─ cart → /groceries
/search → kartu → /recipe/:id → Start Cooking → /recipe/:id/cook
/recipe/:id → [Tambah ke keranjang] → /groceries
/recipe/:id → [calendar-plus] → pilih tanggal → /meal-plan
/meal-plan → [+] → /search?pick=YYYY-MM-DD → pilih → /meal-plan
/add → DONE → dialog sukses → /my-recipes
```

- Router: `go_router`. Perpindahan antar tab = `context.go(...)`; halaman turunan (detail, favorites, groceries, profile, cook, dll) = `context.push(...)` supaya tombol back sistem/gesture berperilaku wajar. `ShellRoute` memuat `/home`, `/search`, `/meal-plan`, `/nearby` + `AppBottomNav`.
- Guard (`redirect` + `refreshListenable` dari auth store): tanpa session → redirect ke `/login` (kecuali `/`, `/login`, `/register`, `/forgot`). Sudah login & buka `/` → langsung `/home`.
- Posisi scroll dipulihkan saat kembali (`PageStorageKey` pada list/scroll view).
- Transisi halaman: default platform atau fade 150 ms (opsional).
- Orientasi dikunci portrait (`SystemChrome.setPreferredOrientations`).

---

## 9. Model Data & State

```dart
enum Difficulty { mudah, sedang, sulit }      // label tampil: 'Mudah' | 'Sedang' | 'Sulit'
enum MealType { breakfast, lunch, dinner, snack, dessert, drinks }

class Ingredient {
  final String id;
  final String name;
  final String qty;        // "300"
  final String? unit;      // "g"
  final int price;         // Rupiah
}

class RecipeStep {          // bukan "Step" (bentrok dengan widget Stepper Flutter)
  final String id;
  final String title;
  final String description;
  final int? durationMin;
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final String? image;       // null/kosong = placeholder abu-abu. Boleh URL atau data URI (cover buatan user)
  final String category;     // "Chicken"
  final String cuisine;      // "Indonesian"
  final MealType meal;
  final String mainIngredient;   // untuk filter favorit
  final double rating;
  final int reviews;
  final int timeMin;
  final int servings;
  final int kcal;
  final Difficulty difficulty;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String? authorId;    // terisi untuk resep buatan user
}

class CartItem  { final String id; final String name; final String qty; final int price; final bool checked; }
class CartGroup { final String id; final String? recipeId; final String name; final List<CartItem> items; } // recipeId null = "Belanjaan Kamu Nich"

class MealPlanEntry { final String id; final String date; /* YYYY-MM-DD */ final String recipeId; }

class Place {
  final String id; final String name; final String cuisine;
  final int priceMin; final int priceMax;
  final int distanceM; final int walkMin; final bool open;
  final double x; final double y;   // posisi di peta ilustrasi, 0–100
}

class AppUser {
  final String id; final String name; final String email; final String? avatar;
  final int cooked;
  final bool mealReminder; final bool darkMode;
}
```

Semua model: konstruktor `const`, field `final`, `copyWith`, `toJson()`, `fromJson()` (ditulis tangan).

**Store (Riverpod, semua di-persist lewat `shared_preferences`, key `foodie:<nama>`):**
- `authProvider` (session, user; opsi "Ingat saya")
- `favoritesProvider` (daftar id)
- `cartProvider` (groups) + provider turunan: `cartCountProvider`, `cartTotalUncheckedProvider`, `cartSubtotalProvider(groupId)` (family)
- `mealPlanProvider` (entries) + helper `byWeek(startDate)`
- `recipesProvider` (seed + myRecipes)
- `uiProvider`/helper UI (toast & dialog)
- `sharedPreferencesProvider` di-override di `main()` setelah `SharedPreferences.getInstance()` (supaya store bisa membaca sinkron saat start).

Selector `cartCount` = jumlah semua `CartItem`; `favCount` = `favorites.length`.

### 9.1 Lapisan data (siap diganti API)
Widget dan halaman **tidak boleh** membaca `data/recipes.dart` langsung. Semua lewat `services/recipe_service.dart`:

```dart
abstract class RecipeService {
  Future<List<Recipe>> list({String? q, MealType? meal, String? mainIngredient, Difficulty? difficulty, int? maxTimeMin});
  Future<Recipe?> getById(String id);
  Future<List<Recipe>> popular({int limit = 10});
  Future<List<Recipe>> inspiration(String dateKey, {int limit = 6}); // acak, stabil per hari
}
```
v1 = `LocalRecipeService` (membaca seed + resep buatan user, delay buatan 150 ms agar loading state terbentuk), diekspos lewat `recipeServiceProvider`. Nanti API cukup mengganti implementasi dengan adapter yang memetakan respons API ke tipe `Recipe`. Halaman wajib punya **loading state** (`Skeleton`) dan **error state** ("Gagal memuat. Coba lagi" + tombol) — pakai `AsyncValue.when`.

### Data seed (wajib sesuai desain)
- **User**: Najmah Cleosaa Tokek · benjolmwahh@gmail.com · favorit 6 · dimasak 12 · resep saya 4.
- **Detail "Ayam Kecap Bawang"** (id `ayam-kecap-bawang`, rating 4.9, 184 ulasan, 2 porsi, 450 kkal, Mudah, 25 menit):
  Bahan: Nasi putih dingin 300 g · Telur ayam 2 butir · Bawang merah & putih 4 siung · Kecap manis istimewa 2 sdm · Cabai rawit merah 3 buah · Minyak goreng / margarin 1 sdm.
  Langkah: 1 **Siapkan Bahan** — "Potong ayam seukuran satu suapan. Iris bawang bombai, cincang bawang putih, dan iris daun bawang." · 2 **Tumis Bawang** — "Panaskan minyak. Tumis bawang putih dan bawang bombai selama 2–3 menit hingga harum." · 3 **Masak Ayam** — "Masukkan ayam, aduk 3–4 menit. Tuang kecap, air, garam, dan lada. Masak hingga ayam matang (74°C)." · 4 **Sajikan Selagi Hangat** — "Aduk hingga saus mengental dan meresap. Koreksi rasa, lalu taburi daun bawang bila suka."
- **Kartu**: Nasi Goreng Nusantara (4.9, 340 ulasan, 25 Menit, desk. "Paduan bumbu terasi, kecap manis legit, serta taburan bawang goreng."), Soto Ayam (Chicken · Indonesian, 4.8), + minimal 8 resep lain (Rendang, Gado-Gado, Salmon Teriyaki, Sate Ayam, Telur Balado, Tumis Kangkung, Bihun Goreng, Nasi Goreng Spesial) dengan bahan & langkah lengkap. Pastikan ada resep dengan bahan utama Ayam, Telur, Kangkung.
- **Keranjang awal (demo)**: "Nasi Goreng Spesial" — Telur 2 btr Rp 4.000 ✓, Bawang merah 4 siung Rp 2.000 ✓, Beras 250 g Rp 3.000; "Soto Ayam" — Ayam 250 g Rp 12.000 ✓, Bihun 1 bungkus Rp 5.000, Daun bawang 1 ikat Rp 3.000; "Belanjaan Kamu Nich" — Tisu 1 bungkus Rp 7.000.
- **Places**: Warung Bu Sari (Masakan Jawa · Rp15–30 rb · 180 m · 3 menit · Buka), Ayam Bakar Pak Hadi (Ayam bakar · Rp20–35 rb · 450 m · 6 menit · Buka), + tempat ke-3 (tutup/buka bebas).
- **Meal plan awal**: Senin–Sabtu masing-masing 1–2 resep di minggu berjalan (tanggal dihitung relatif terhadap minggu berjalan saat pertama kali app dibuka, lalu di-persist).
- Format Rupiah: `Rp 12.000` (titik pemisah ribuan, spasi setelah "Rp") lewat `formatRupiah(int)` di `core/utils`.
- Minggu dimulai **Senin**; kunci tanggal `YYYY-MM-DD`.

---

## 10. Foto & Aset Gambar (v1: placeholder abu-abu)

Semua foto sementara **abu-abu**. Sumber foto asli (API resep) menyusul di luar v1.

- Widget `ImagePlaceholder`: blok `photoGray` (`#D9D9D4`) dengan radius, ukuran, dan rasio yang diwariskan dari wadahnya (`AspectRatio`/`SizedBox` di pemanggil, supaya identik dengan desain). Ikon garpu-sendok `photoGrayIcon` di tengah **hanya jika area ≥ 64 px** (cek lewat `LayoutBuilder`); avatar bulat menampilkan **inisial nama** (olive, 600) di atas `photoGray`.
- Widget `SmartImage` (`src`, `semanticLabel`, `fit`): bila `src` kosong/`null` atau gagal dimuat → render `ImagePlaceholder`. Bila `src` diawali `data:` → `Image.memory(base64Decode(...))`; bila URL → `Image.network` (dengan `errorBuilder` → placeholder, `fit: BoxFit.cover`, `gaplessPlayback: true`). Hero detail dimuat langsung; sisanya lazy secara alami lewat `ListView/Sliver` builder. **Semua** gambar di app wajib lewat `SmartImage`, sehingga nanti cukup mengisi `recipe.image` dari API tanpa mengubah UI.
- Overlay di atas foto (tombol hati, chip rating, chip waktu, gradien gelap tipis di bawah) **tetap dirender** seperti desain; pastikan teks putih tetap terbaca di atas abu-abu terang dengan gradien `black @ 35%` → transparan.
- Seed `recipes.dart`: `image: null` untuk semua resep. Foto upload user di halaman Add (cover) **tetap ditampilkan** (itu foto dari user, bukan aset). Cover disimpan sebagai **data URI JPEG** (`image_picker` dengan `maxWidth: 1080`, `imageQuality: 80`; tolak jika hasil > 1 MB).
- Aset lokal yang tetap boleh ada: logo/ikon vektor yang digambar lewat kode. Tidak ada file di `assets/images/` untuk v1.
- **Nanti (saat API dipilih):** isi `recipe.image` lewat adapter; foto splash dan avatar tetap placeholder sampai ada aset resmi dari Figma (`splash-hero.jpg`, `avatar-*.jpg`).

---

## 11. Non-Fungsional

- **Aksesibilitas**: semua tombol ikon punya `Semantics`/`tooltip`; kontras teks ≥ 4.5:1 untuk teks badan (khususnya sage `#717665` di atas putih: pakai hanya untuk teks ≥ 11 px non-kritis); fokus terlihat (ring amber 2px untuk navigasi keyboard di web/desktop); target sentuh ≥ 40; teks mengikuti pengaturan ukuran font sistem tanpa membuat layout pecah (uji di 1.0× dan 1.3×).
- **Performa**: gunakan `const` widget, `ListView.builder`/sliver untuk daftar, rasio gambar ditetapkan lewat `AspectRatio` agar tidak layout shift, tidak ada rebuild berlebihan (pakai `select` pada provider), `flutter analyze` bersih.
- **Responsif**: lihat §3 aturan 1; uji di lebar 360, 390, 412, 440 dp, dan tablet/web (kolom 440 di tengah). Tidak ada `RenderFlex overflow` di semua ukuran tersebut.
- **Persist**: data di `shared_preferences` dengan prefix `foodie:`; menu dev tersembunyi **"Reset data demo"** (tekan lama teks "Versi 1.0.0" di Profil), serta flag `--dart-define=RESET=true` untuk reset saat start.
- **Platform**: Android (API 24+) dan iOS 13+; portrait saja; Chrome (web) hanya untuk preview/QA.

---

## 12. Keputusan & Asumsi (ubah di sini kalau tidak setuju)

1. **Label tab ke-5** *(digantikan oleh §14.4 dan §14.12)*: workflow menyebut "Nearby", style guide menyebut "My Pantry", layar menyebut "Loc". **Keputusan: ikuti layar → label "Loc", ikon kulkas seperti gambar, route `/nearby`.**
2. **Ikon `+` di kartu Popular**: tidak dijelaskan di workflow. Asumsi: *quick-add* semua bahan ke keranjang.
3. **Bookmark = Favorit**: tombol hati/"Tambah ke favorit" dan pill bookmark memakai daftar yang sama.
4. **Halaman Add memakai field abu `#D6D6D6`** (berbeda dari field putih di Login). Diikuti persis sesuai desain; bisa dirapikan nanti.
5. **Search by Meal tanpa label** diikuti persis; tile tetap fungsional via `Semantics`.
6. **Peta Nearby = ilustrasi statis (`CustomPaint`)** *(digantikan oleh §14.4 dan §14.12)* sesuai desain. Peta sungguhan (`flutter_map`/Google Maps) ditunda.
7. **Meal Plan di desain hanya memperlihatkan Senin–Sabtu** karena gambar terpotong; implementasi tetap 7 hari.
8. **Auth mock**: sandi apa pun ≥ 8 karakter lolos; user demo di §9. "Ingat saya" dicentang → session disimpan permanen; tidak dicentang → session hanya di memori (hilang saat app ditutup).
9. **Pill bookmark/keranjang**: angka tampil walau 0 (sesuai desain).
10. Halaman Start Cooking, My Recipe, sheet/dialog, toast, empty state, lupa sandi, tentang aplikasi **tidak ada di desain** → ikuti §7.
11. **Foto = placeholder abu-abu** di v1 (termasuk hero splash dan avatar). Tile Search by Meal menampilkan label kategori sementara (§6.5).
12. **Sumber resep & foto nanti dari API** (belum dipilih). Karena itu semua akses data lewat `RecipeService` (§9.1); field yang tidak disediakan API (rating, ulasan, kalori, tingkat kesulitan, harga bahan) akan diisi adapter/lokal.
13. Data demo memakai **nama masakan Indonesia** sesuai desain; bila API tidak punya, adapter boleh jatuh ke data lokal.
14. **Padding atas (pengganti status bar desain)**: desain punya status bar ≈ 60 px lalu baris header mulai y ≈ 84. Implementasi: `topChrome = max(MediaQuery.padding.top, 60)`, konten halaman dimulai di `topChrome + 24`. Di perangkat berinset besar (notch) hasilnya tetap wajar; di QA web (inset 0) posisi identik dengan desain.
15. **`?reset=1` (versi web lama) diganti** menu dev "Reset data demo" + `--dart-define=RESET=true`, karena app mobile tidak punya query string.
16. **Package tambahan yang diizinkan** (di luar yang jelas di §2): tidak ada. Perubahan stack perlu izin.
17. **Portrait only**; landscape tidak didukung di v1.

---

## 13. Kriteria Penerimaan

**Fungsional**
- [ ] Semua alur di §8 berjalan tanpa exception/error di console.
- [ ] Menambah/menghapus favorit mengubah angka pill di semua halaman secara real-time.
- [ ] "Tambah ke keranjang" di detail memasukkan semua bahan sebagai satu grup; angka keranjang naik; tidak duplikat.
- [ ] Total keranjang = jumlah item belum dicentang; subtotal grup = jumlah semua item grup (seed: Rp 18.000 / Rp 9.000 / Rp 20.000).
- [ ] Meal Plan: tambah via `+`→Search→pilih, hapus via tekan lama + alert, navigasi minggu lalu/depan.
- [ ] Form Add tervalidasi; setelah DONE resep muncul di `/my-recipes` dan bisa dibuka di detail.
- [ ] Data bertahan setelah app ditutup & dibuka lagi; Logout menghapus session saja (bukan data resep).
- [ ] Tombol back sistem (Android) dan gesture back (iOS) berperilaku wajar di semua halaman.

**Visual** (per halaman, di viewport 440 × 956)
- [ ] Posisi elemen utama selisih ≤ 2 px dari JPG; warna sama persis; font Poppins dengan weight benar; teks identik. (Isi foto dikecualikan; area foto = placeholder abu-abu dengan ukuran/radius/rasio sama.)
- [ ] Tidak ada `Image.network/asset/memory/file` langsung di luar `SmartImage`. Tidak ada akses langsung ke `data/recipes.dart` dari widget/halaman (hanya lewat `RecipeService`).
- [ ] Tidak ada `RenderFlex overflow` maupun scroll horizontal pada halaman; scroll horizontal hanya di carousel Home & Meal Plan serta chip filter.
- [ ] Bottom nav hanya muncul di Home, Search, Meal Plan, Nearby (dan tidak menutupi konten).

**Teknis**
- [ ] `flutter analyze` tanpa error/warning; `dart format --set-exit-if-changed .` bersih.
- [ ] `flutter test` hijau.
- [ ] `flutter build apk --debug` (atau `flutter build web` bila Android SDK tidak tersedia) sukses.
- [ ] Tidak ada `Color(0x…)` / `Colors.xxx` (selain `Colors.transparent`) di luar `core/theme/` (semua lewat token).

---

## 14. Perubahan Pasca-Desain (Bug Fix Round 1)

§15 (Putaran 2) MENANG atas §14 bila bentrok.

14.0 Prioritas: §14 menang atas desain JPG dan bagian lain PRD.

14.1 Istilah: "kasus keyboard" (sheet/form ikut terdorong naik sampai hanya layer putih), "kasus button naik" (tombol/nav fixed ikut naik di atas keyboard), "kasus no space" (tombol/alert/sheet mepet atau tertutup navigasi HP).

14.2 Aturan layout global (insets & keyboard):
- Semua elemen sticky di bawah (tombol "Kembali Ke Beranda", DONE, panel ringkasan Groceries, tombol aksi di sheet): jarak bawah = max(24, MediaQuery.viewPadding.bottom + 16). Tidak boleh tertutup gesture bar / 3 tombol navigasi.
- Halaman yang punya elemen sticky bawah (termasuk BottomNav di ShellRoute) memakai Scaffold(resizeToAvoidBottomInset: false). Elemen sticky TIDAK bergerak saat keyboard muncul. Area scroll diberi padding bawah = viewInsets.bottom supaya field yang fokus tetap terlihat (ensureVisible).
- Bottom sheet (isScrollControlled: true): tinggi maksimum = tinggi layar − topChrome; isi di dalam scroll view; padding bawah = viewInsets.bottom saat keyboard terbuka, dan = viewPadding.bottom + 16 saat tidak; tombol aksi sheet tidak boleh tertutup navigasi sistem. Tidak boleh tampil area putih kosong.
- Fokus: membuka sheet/dialog atau menutupnya TIDAK boleh membuat field lain otomatis fokus; keyboard tidak boleh muncul sendiri. Sebelum membuka sheet: unfocus. Setelah sheet ditutup: unfocus. Tap area kosong = tutup keyboard.
- Android: mode edge-to-edge dengan system bar transparan; selalu pakai viewPadding/viewInsets dari MediaQuery.

14.3 AppHeader (avatar + pill favorit + keranjang) di Home, Search, Add, Meal Plan, Nearby bersifat FIXED: berada di luar area scroll, tidak ikut ter-scroll, background bg.

14.4 Tab ke-5 berlabel "Nearby" (bukan "Loc") dengan ikon map-pin; route tetap /nearby. Pill di header memakai ikon heart (terisi putih) menggantikan bookmark, label semantik "Favorit", agar konsisten dengan hati di kartu dan judul "Menu Favoritmu".

14.5 Toast (diubah §15.1 untuk warna): muncul 16 px DI ATAS elemen fixed paling bawah pada halaman itu (BottomNav = tinggi 75 + jaraknya; atau tombol sticky). Warna: background amberSoft, teks olive 12/600, radius pill, bayangan kartu; TIDAK sama dengan warna bottom nav. Hilang 2.2 s. (Catatan: digantikan oleh §15.1 untuk warna maroon).

14.6 Detail Menu:
- Deskripsi singkat resep tampil tepat di bawah judul (13/400 sage, tinggi baris 20), maksimal 3 baris; bila lebih panjang tampil tautan "Lihat semua" (maroon 12/600) yang membuka teks penuh, lalu menjadi "Tutup". Bila deskripsi kosong (resep buatan user), bagian disembunyikan.
- Tombol back FIXED di kiri atas (tidak ikut scroll), lingkaran 44, background sage, panah putih (diubah §15.6: bar atas FIXED lebar penuh background sage dengan tombol back lingkaran olive 44 di kiri). Share & heart tetap di hero.
- "Tambah ke keranjang": bila resep sudah ada di keranjang, tombol tampil gaya non-aktif (bg amberSoft, teks olive, ikon centang, label "Sudah di keranjang") TAPI tetap bisa di-tap: tap = keluarkan grup resep dari keranjang + toast "Dikeluarkan dari keranjang" dan tombol kembali ke gaya semula.
- Ikon calendar-plus: bila resep sudah terjadwal (ada entri meal plan dengan tanggal >= hari ini), ikon berubah menjadi calendar-check dengan latar amberSoft.

14.7 Meal Plan:
- Lebar kartu di carousel selalu ≈ 330 (sama untuk 1 atau lebih menu), rata kiri; kartu berikutnya mengintip bila ada.
- Tidak boleh ada resep yang sama pada tanggal yang sama. mealPlanProvider.add mengembalikan status added/exists; bila exists: tidak menambah, toast "Menu sudah ada di meal plan". Berlaku dari jalur plus (/search?pick=) maupun dari ikon di detail. Resep yang sama pada tanggal berbeda diperbolehkan.
- Sheet pilih tanggal di detail: tanggal yang sudah berisi resep ini tampil dengan centang dan non-aktif (tap = toast "Menu sudah ada di meal plan"). Di mode /search?pick=, kartu resep yang sudah ada di tanggal itu menampilkan tombol non-aktif "Sudah ada".

14.8 Add Recipe: daftar bahan yang sudah ditambahkan tampil sebagai list langsung di bawah baris dua kolom (nama + takaran, tombol hapus), menampilkan 3 item pertama dan tautan "Lihat semua (N)" bila lebih dari 3 (expand inline, lalu "Sembunyikan"). Kotak "Ingredients" tetap sebagai pemicu sheet.

14.9 Rating:
- Di layar selesai Start Cooking ("Selamat, masakanmu siap!") tampil pemilih 5 bintang amber ("Beri rating untuk {judul}"), tombol olive "Kirim rating" (non-aktif sampai memilih) dan "Lewati". Setelah kirim: toast "Terima kasih atas ratingmu".
- Disimpan di ratingsProvider (resepId → 1..5, persist). Rating yang ditampilkan di kartu & detail = (ratingDasar × ulasanDasar + ratingUser) / (ulasanDasar + 1), 1 desimal, ulasan +1; bila user memberi rating lagi untuk resep yang sama, nilainya MENGGANTI (tidak dihitung dobel).
- v1: rating dasar = data dummy/seed + rating user lokal. API resep tidak wajib menyediakan rating; rating asli multi-user menunggu backend.

14.10 Riwayat Dimasak: route /cooked (tanpa AppHeader & bottom nav), meniru Favorites: judul "Riwayat Masak" + badge amber jumlah resep unik, sub "Resep yang sudah kamu masak.", search "Cari riwayat masak...", grid kartu (FavoriteRecipeCard tanpa trash; caption "Dimasak N× · {tanggal terakhir}" dan "Rating kamu ★N" bila ada), tombol sticky "Kembali Ke Beranda", EmptyState "Belum ada yang dimasak. Yuk mulai masak!". Model CookedEntry {id, recipeId, date}; cookedProvider (persist); selesai Start Cooking menambah entri. Statistik "Dimasak" di Profil = jumlah entri; seed 12 entri (dari resep seed, tanggal mundur).

14.11 Profil: ketiga kolom statistik interaktif: tap = Favorit → /favorites, Dimasak → /cooked, Resep Saya → /my-recipes. Feedback: efek tekan (ripple/highlight maroonSoft) dan hover + kursor pointer di web/desktop.

14.12 Nearby peta nyata: peta OpenStreetMap (flutter_map + latlong2), lokasi pengguna (geolocator; izin lokasi; bila ditolak → pusat default area desain + toast), rute jalan kaki ke tempat terpilih digambar mengikuti jalan sungguhan (OSRM, profil foot, geometri geojson), bukan garis lurus. Tampilan overlay (pill "Radius 1 km", pin bernomor amber/olive, titik pengguna berhalo, tombol "Pusatkan") dipertahankan seperti desain. Atribusi "© OpenStreetMap contributors" wajib tampil. Bila tile/rute gagal: fallback ke IllustratedMap / garis putus-putus lurus + toast. Model Place ditambah lat & lng; data tempat v1 masih mock (diletakkan relatif terhadap lokasi pengguna) di balik interface PlaceService supaya nanti diganti sumber nyata. Menggantikan §12 butir 6.

14.13 Rating & data dari API: lihat 14.9 (v1 dummy + lokal).

14.14 Status Penyelesaian Bug Fix Round 1 (Fase B0–B8):
- Seluruh 22 butir bug (G1–G6, P1–P4, S1, A1–A4, M1–M2, N1–N2, D1–D3) telah diperbaiki dan diverifikasi melalui unit test, widget test, matriks layout lintas resolusi (360x640 hingga 440x956 dp, inset 0-48 dp, keyboard terbuka/tertutup), dan tes ujung-ke-ujung (E2E flow) di `test/phase_b8_regression_qa_test.dart`.
- Daftar pelacakan lengkap dicatat pada `BUG_FRONTEND.md`.

---

## 15. Perubahan Pasca-Desain (Putaran 2)

15.0 Prioritas: §15 menang atas §14, bagian lain PRD, dan desain JPG.

15.1 Toast: background maroon (#800020), teks putih 12/600, radius pill, bayangan kartu. Posisi tidak berubah (16 px di atas elemen fixed paling bawah). Menggantikan §14.5 untuk warna.

15.2 AppHeader greeting: di kanan avatar (kiri pill favorit) tampil greeting dua baris: baris 1 sapaan menurut jam ("Selamat pagi" 04.00–10.59, "Selamat siang" 11.00–14.59, "Selamat sore" 15.00–17.59, "Selamat malam" 18.00–03.59) gaya 11/400 sage; baris 2 nama depan user gaya 15/700 olive ("Najmah"). Jarak 12 dari avatar, memakai Expanded + ellipsis sehingga tidak pernah overflow di lebar 360 dp; tidak mengubah ukuran/posisi avatar, pill, dan keranjang. Nama depan = kata pertama user.name.

15.3 Header fixed per halaman (area fixed = di luar scroll, background bg):
- Home, Search, Add, Nearby: AppHeader.
- Meal Plan: AppHeader + pemilih minggu "< This Week >".
- Favorites, Cooked (Riwayat Masak), My Recipes: judul + badge + sub-judul + search bar (sampai search bar). Chip filter dan seterusnya ikut scroll.

15.4 Editor input (Edit Profil, Tambah Bahan, Langkah Memasak) harus aman dari keyboard di perangkat nyata: field yang fokus selalu terlihat penuh, tidak ada layer putih, tidak tertutup navigasi sistem. Inset keyboard dibaca dari View (bukan dari MediaQuery yang bisa sudah dikonsumsi ancestor). Bila sheet tidak bisa dibuat andal, editor boleh diubah menjadi halaman layar penuh (Scaffold dengan resizeToAvoidBottomInset: true).

15.5 Add: kembali memakai BottomNav (fixed, tab "Add" aktif), route /add berada di dalam ShellRoute; aturan nav sama dengan halaman lain (tidak bergerak karena keyboard). Tombol DONE tidak sticky: berada di ujung form (lebar penuh ±362x55) dengan padding bawah ±120 agar tidak tertutup nav. "Cooking Instructions": setelah ditambah, langkah tampil sebagai list di bawah kotaknya (nomor lingkaran amber 28 + judul 14/600 + deskripsi 1 baris sage 11 dengan ellipsis + tombol hapus trash maroon), tampil 3 langkah pertama + "Lihat semua (N)" / "Sembunyikan", sama pola dengan daftar Ingredients (§14.8).

15.6 Detail Menu:
- Bar atas FIXED seperti header halaman dashboard: lebar penuh, background sage (#717665), tinggi = inset atas perangkat + 60, berisi tombol back lingkaran OLIVE 44 dengan panah putih di kiri (x=25). Konten dan hero ter-scroll di bawah bar (tidak tembus). Ikon status bar terang di halaman ini. Share & heart tetap di hero (ikut scroll). Menggantikan gaya back di §14.6.
- Bahan-bahan: tanpa checkbox/coret/persist. Tiap baris: bullet lingkaran olive terisi (±10) + nama (15/400) + takaran rata kanan (13/700). Hapus penyimpanan "centang bahan per resep".
- Pemilih tanggal meal plan: tanggal sebelum hari ini (hari aktual = hari ini masih boleh) tampil non-aktif (redup, tidak bisa di-tap). Aturan sama berlaku untuk tombol plus per hari di halaman Meal Plan (hari lampau & minggu-minggu lalu: plus non-aktif). mealPlanProvider.add menolak tanggal < hari ini (status pastDate); sediakan injeksi "sekarang" (clock) agar bisa diuji.

15.7 Groceries:
- Urutan DESCENDING: grup menu diurutkan dari yang paling baru ditambahkan ke yang lama (CartGroup.addedAt). Item di grup "Belanjaan Kamu Nich" juga terbaru di atas (CartItem.addedAt). Item dalam grup resep tetap urutan resep.
- "Belanjaan Kamu Nich" selalu dipin di paling atas (di atas semua grup menu), selalu tampil walau kosong (hint "Belum ada bahan. Tambahkan lewat kolom di atas."). Warna kartu beda: background amberSoft, border 1px amber @ 40%, ikon pin kecil di judul; teks wajib terbaca (nama & harga olive, takaran olive @ 75%, kontras >= 4.5:1), checkbox olive.
- Tidak ada "Hapus menu" untuk kartu ini. Hapus per bahan dengan swipe ke kiri (Dismissible endToStart: latar maroon + ikon trash putih, radius mengikuti kartu), toast "Bahan dihapus", plus aksi semantik "Hapus" untuk aksesibilitas. Kartu grup menu tetap memakai "Hapus menu".
- Perhitungan total/subtotal tidak berubah.

15.8 Data: CartGroup.addedAt, CartItem.addedAt (migrasi data lama: isi dari urutan yang ada); MealPlan add status: added / exists / pastDate.

15.9 Status Penyelesaian Bug Fix Round 2 (Fase C0–C6):
- Seluruh 13 butir perbaikan dan penyempurnaan (G1–G2, P1–P2, A1–A3, M1, D1–D3, K1–K2) telah selesai diimplementasikan dan diverifikasi secara menyeluruh.
- Telah teruji melalui pengujian unit, widget, regresi visual, matriks layout responsif (360x640 hingga 440x956 dp, inset 0–48 dp, keyboard terbuka/tertutup), serta alur ujung-ke-ujung (E2E) pada `test/phase_c6_regression_qa_test.dart`.
- Daftar pelacakan terperinci dicatat pada `GENERAL_BUG.md`.

---

## 16. Sistem Tema & Dark Mode Menyeluruh (Fase E1)

16.0 Prioritas: §16 menang atas §15, §14, dan spesifikasi sebelumnya terkait warna, perataan kartu belanjaan, dan sistem tema.

16.1 Keselarasan Header Grup Groceries (Bug A):
- Menggunakan widget bersama `GroceryGroupHeader` (`lib/widgets/grocery_group_header.dart`).
- Struktur: `Row(crossAxisAlignment: CrossAxisAlignment.start)` berisi `Expanded` (judul, maks 2 baris, ellipsis) + `SizedBox(width: 12)` + tombol "Hapus menu".
- Tombol "Hapus menu" dibuat tanpa padding horizontal liar (`padding: EdgeInsets.zero`, tap target dijaga dengan padding vertikal).
- Tepi kanan tombol `GroceryGroupHeader` sejajar presisi dengan tepi kanan teks harga pada baris item belanjaan di bawahnya (`Rect.right` identik, toleransi < 0.5 dp).
- Pusat vertikal tombol sejajar dengan baris pertama judul baik untuk judul 1 baris maupun judul panjang 2 baris (toleransi <= 2 dp).
- Kartu pin "Belanjaan Kamu Nich" tetap tanpa tombol hapus grup (dihapus via swipe ke kiri per item, §15.7).

16.2 Arsitektur Palet Semantik `AppPalette`:
- Token warna tidak lagi bersifat statis monolitik, melainkan berbentuk `ThemeExtension<AppPalette>` yang terdaftar di `ThemeData.light` dan `ThemeData.dark`.
- Seluruh widget dan halaman mengakses warna secara semantik melalui ekstensi `context.palette`.
- Zero raw color policy: Seluruh pemakaian `AppColors.*` dan `Colors.*` (kecuali `Colors.transparent`) di luar `lib/core/theme/` telah dibersihkan secara total (0 occurrences).
- Token semantik memisahkan peran warna berdasarkan konteks fungsional:
  - `bg`: Latar belakang kanvas aplikasi (#F5F5F0 light / #101815 dark).
  - `surface`: Latar kartu, dialog, sheet, input standard (#FFFFFF light / #1B2822 dark).
  - `surfaceAlt`: Latar alternatif / tombol sekunder / avatar (#E8E8E2 light / #26362F dark).
  - `navSurface`: Latar AppBottomNav dan bar atas fixed Detail Menu (#263C32 light / #1F2F29 dark).
  - `outerBg`: Latar pilar samping web/tablet lebar > 440 dp (#E9E9E2 light / #0B100D dark).
  - `textStrong`: Judul dan penekanan kuat (#263C32 light / #F5F5F0 dark).
  - `textBody`: Teks badan konten (#1E1E1E light / #F5F5F0 dark).
  - `textSecondary`: Label pembantu, placeholder, teks tersier (#717665 light / #9AA597 dark).
  - `border` & `divider`: Garis batas (#E3E3DC light / #2F3F37 dark).
  - `actionBg` & `onAction`: Tombol utama (#263C32 / on: #FFFFFF light; #F59E0B / on: #1A1200 dark).
  - `accent` & `onAccent`: Aksen amber (#F59E0B / on: #263C32 light; #F59E0B / on: #1A1200 dark).
  - `accentSoft`, `onAccentSoft`, `accentSoftTextAlt`: Tag dan kartu belanjaan tersemat (#F4E9CE / #3E3313 dark).
  - `danger` (#800020 light / #D6455F dark), `dangerText` (#800020 light / #E8667C dark untuk memenuhi kontras WCAG >= 4.5:1), `dangerSoft` (#F4E6E9 light / #3A1F28 dark).
  - `field`, `fieldBorder`, `fieldAdd`: Bidang input & form (#D6D6D6 light / #26362F dark pada form Add).
  - `toggleOff` (#E0E0DA light / #3A4A42 dark), `photo` (#D9D9D4 light / #26362F dark), `photoIcon` (#BDBDB5 light / #3A4A42 dark).

16.3 State & Persistensi Tema:
- Dikelola oleh `themeModeProvider` (`lib/providers/theme_provider.dart`) yang mandiri dan terpisah dari siklus otentikasi user.
- Preferensi disimpan secara persisten di `SharedPreferences` dengan key `"foodie:themeMode"` (default: `ThemeMode.light`).
- Toggle "Mode gelap" di Halaman Profil (§6.12) tersambung langsung ke `themeModeProvider` dengan indikator status dinamis: "Tampilan gelap sedang digunakan" / "Tampilan terang sedang digunakan".

16.4 Kontras Aksesibilitas WCAG 2.1:
- Seluruh kombinasi warna lulus uji rasio kontras WCAG: teks normal >= 4.5:1, teks besar/komponen >= 3.0:1.
- Teks bahaya/danger kecil pada mode gelap menggunakan `dangerText` (#E8667C) yang menghasilkan rasio kontras 5.3:1 terhadap `surface`, menggantikan `#D6455F` (3.9:1) khusus pada teks kecil demi memenuhi standar keterbacaan.
- Kartu pin "Belanjaan Kamu Nich" pada dark mode menggunakan `accentSoftTextAlt` (#C8AB4A) yang memberikan rasio kontras 5.1:1 terhadap latar `accentSoft` (#3E3313).



