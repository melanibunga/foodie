# Foodie.id Frontend (Flutter)

Aplikasi resep & perencanaan belanja bahan pangan Nusantara berbasis Flutter (Dart 3), dibangun sesuai spesifikasi PRD (`docs/PRD.md`) dan acuan visual (`design/*.jpg`).

Aplikasi memiliki basis desain lebar **440 px**, sepenuhnya responsif fluid turun ke **360 px**, dan pada layar lebar/tablet/desktop kolom 440 px dipusatkan secara elegan (`AppShell`) dengan latar belakang halus `#F3F4F1`.

---

## 🚀 Persyaratan Sistem

- Flutter SDK (stable, 3.x / Dart 3.x)
- Chrome Browser (Web) atau Android Emulator / iOS Simulator / Real Device

---

## 🛠️ Cara Menjalankan & Membangun

### 1. Install Dependensi
```bash
flutter pub get
```

### 2. Menjalankan di Mode Development (Chrome / Web)
```bash
flutter run -d chrome
```

### 3. Menjalankan di Android / iOS Device
```bash
flutter run
```

### 4. Membangun Release Web Bundle
Karena menggunakan paket ikon modern (`lucide_icons`), sertakan flag `--no-tree-shake-icons`:
```bash
flutter build web --no-tree-shake-icons
```

---

## 🧪 Testing, Linting & QA Audit

Seluruh kode terverifikasi bersih tanpa error analyzer, terformat rapi sesuai panduan Dart, dan lulus seluruh 108 test suite otomatis:

```bash
# Verifikasi format kode
dart format --set-exit-if-changed .

# Analisis kode statis
flutter analyze

# Menjalankan seluruh test suite (unit, widget, routing, flow, multi-resolusi QA, dark mode & real map)
flutter test
```

---

## 🌙 Fitur Tema Gelap (Dark Mode) & Peta Nyata (Fase 16)

### 1. Tema Gelap Berbasis Desain Organik (PRD §4):
- **Palet Dark Olive-Charcoal:** Menggunakan warna dasar `appBgDark` (`#121611`), `surfaceDark` (`#1B2218`), dan aksen adaptif `oliveDark` (`#5E7A46`), `amber` (`#F59E0B`), dan `maroonDark` (`#A33B39`).
- **Aktivasi:** Pengguna dapat mengaktifkan toggle **Mode gelap** di halaman **Profil Saya** (`/profile`). State tersimpan persisten di `SharedPreferences` dan diobservasi langsung oleh `FoodieApp` (`ThemeMode.dark`).

### 2. Peta Nyata (OpenStreetMap / CartoDB) + Geolocator & Graceful Fallback:
- **Peta Nyata Interaktif:** Dibangun menggunakan `flutter_map` (OpenStreetMap tiles untuk mode terang dan CartoDB Voyager tiles untuk mode gelap).
- **Penanganan Lokasi Pengguna:** Menggunakan paket `geolocator` untuk memeriksa ketersediaan GPS dan meminta izin runtime (`ACCESS_FINE_LOCATION` di Android dan `NSLocationWhenInUseUsageDescription` di iOS).
- **Graceful Fallback:** Apabila izin lokasi ditolak oleh pengguna, GPS dinonaktifkan, atau berjalan di perangkat tanpa sensor lokasi, sistem secara otomatis beralih ke `IllustratedMap` (CustomPaint) tanpa error/crash serta menampilkan toast informasi ramah pengguna.
- **Peralihan Manual:** Pengguna dapat berpindah kapan saja antara mode **Peta Nyata** dan **Peta Ilustrasi** melalui tombol toggle di sudut kanan atas kartu peta halaman `/nearby`.

---

## 🔄 Mekanisme Reset Data Demo

Aplikasi menyimpan seluruh state (resep, resep favorit, belanjaan, meal plan, profil pengguna, dan preferensi) di local storage (`SharedPreferences`).

Tersedia dua cara untuk mereset seluruh data kembali ke seed awal bawaan:

1. **Hidden Dev Menu di UI:**
   - Masuk ke tab **Profil Saya** (`/profile`).
   - Scroll ke bagian paling bawah dan lakukan **tekan lama (long press)** pada teks **"Versi 1.0.0"**.
   - Dialog konfirmasi *"Reset data demo?"* akan muncul.
   - Ketuk **Reset (Maroon)**: seluruh data lokal dibersihkan dan seed data demo dimuat ulang seketika.

2. **Command Line Flag saat Run:**
   - Jalankan perintah dengan dart-define:
     ```bash
     flutter run --dart-define=RESET=true
     ```
   - Aplikasi otomatis mendeteksi flag ini saat bootstrap di `main.dart` dan mereset storage ke nilai awal sebelum router diinisialisasi.

---

## 🖼️ Registry Foto & Komponen SmartImage

Semua render foto di aplikasi wajib melalui widget `SmartImage` (`lib/widgets/ui/smart_image.dart`) untuk mencegah raw `Image.*` invocation, kebocoran memory, dan kegagalan load gambar:

1. **Format yang Didukung:**
   - **Data URI Base64:** `data:image/jpeg;base64,...` (digunakan saat pengguna mengambil foto via kamera/galeri di Create Recipe & Edit Profile).
   - **Asset Lokal:** path yang diawali dengan `assets/`.
   - **Network URL:** `http://` atau `https://` dengan cache & timeout handling.
   - **Fallback Placeholder:** Apabila URI null, kosong, atau gagal dimuat, `SmartImage` otomatis merender `ImagePlaceholder` dengan inisial atau judul resep, background warna netral `#E2E8F0`, dan icon yang sesuai.

2. **Audit Aset & Gambar:**
   - 0 kemunculan `Image.network`, `Image.asset`, `Image.memory`, atau `Image.file` di luar `SmartImage`.
   - Rasio gambar dan border radius terjaga konsisten di semua kartu resep (Grid: `childAspectRatio: 0.68`, Featured Carousel: height `330`).

---

## 🔌 Panduan Menghubungkan ke Backend API

Arsitektur aplikasi menerapkan pola *Separation of Concerns* dengan dependency injection melalui **Riverpod**. Seluruh halaman UI dan provider **tidak pernah** mengakses data mentah secara langsung, melainkan melalui abstraksi `RecipeService`.

### Langkah-langkah Integrasi Backend REST / GraphQL:

1. **Buat Implementasi `RecipeService` Baru:**
   Buat file misalnya `lib/services/http_recipe_service.dart`:

   ```dart
   import 'dart:convert';
   import 'package:http/http.dart' as http;
   import '../models/recipe.dart';
   import 'recipe_service.dart';

   class HttpRecipeService implements RecipeService {
     final String baseUrl;
     final http.Client client;

     HttpRecipeService({required this.baseUrl, http.Client? client})
         : client = client ?? http.Client();

     @override
     Future<List<Recipe>> list({
       String? query,
       String? category,
       RecipeDifficulty? difficulty,
       int? maxCookingMinutes,
       String? mainIngredient,
     }) async {
       final uri = Uri.parse('$baseUrl/recipes').replace(queryParameters: {
         if (query != null && query.isNotEmpty) 'q': query,
         if (category != null && category.isNotEmpty) 'category': category,
         if (difficulty != null) 'difficulty': difficulty.name,
         if (maxCookingMinutes != null) 'max_time': maxCookingMinutes.toString(),
         if (mainIngredient != null) 'ingredient': mainIngredient,
       });

       final response = await client.get(uri);
       if (response.statusCode == 200) {
         final List<dynamic> data = jsonDecode(response.body);
         return data.map((json) => Recipe.fromJson(json)).toList();
       } else {
         throw Exception('Gagal memuat resep dari server: ${response.statusCode}');
       }
     }

     @override
     Future<Recipe?> getById(String id) async {
       final response = await client.get(Uri.parse('$baseUrl/recipes/$id'));
       if (response.statusCode == 200) {
         return Recipe.fromJson(jsonDecode(response.body));
       }
       return null;
     }

     @override
     Future<Recipe> create(Recipe recipe) async {
       final response = await client.post(
         Uri.parse('$baseUrl/recipes'),
         headers: {'Content-Type': 'application/json'},
         body: jsonEncode(recipe.toJson()),
       );
       return Recipe.fromJson(jsonDecode(response.body));
     }

     @override
     Future<Recipe> update(Recipe recipe) async {
       final response = await client.put(
         Uri.parse('$baseUrl/recipes/${recipe.id}'),
         headers: {'Content-Type': 'application/json'},
         body: jsonEncode(recipe.toJson()),
       );
       return Recipe.fromJson(jsonDecode(response.body));
     }

     @override
     Future<void> delete(String id) async {
       await client.delete(Uri.parse('$baseUrl/recipes/$id'));
     }
   }
   ```

2. **Inject Provider di Root / App Entry:**
   Ganti instance di `lib/providers/recipes_provider.dart` atau override pada `ProviderScope` di `lib/main.dart`:

   ```dart
   runApp(
     ProviderScope(
       overrides: [
         sharedPreferencesProvider.overrideWithValue(prefs),
         recipeServiceProvider.overrideWithValue(
           HttpRecipeService(baseUrl: 'https://api.foodie.id/v1'),
         ),
       ],
       child: const FoodieApp(),
     ),
   );
   ```

UI akan seketika mengonsumsi backend API tanpa perlu mengubah satupun baris kode di halaman widget!

---

## 📁 Struktur Folder Proyek

```text
foodie/
├── assets/
│   ├── fonts/             # Font Poppins (400, 500, 600, 700, 800)
│   └── images/            # Aset logo dan ikon lokal
├── design/                # 13 Mockup Desain Acuan (JPG)
├── docs/                  # Spesifikasi PRD.md
├── lib/
│   ├── app/               # Root App, Router (GoRouter), AppShell responsif
│   ├── core/
│   │   ├── theme/         # AppColors, AppText, AppRadius, AppShadows, AppTheme
│   │   └── utils/         # Debouncer, WeekUtils, Formatter Rupiah
│   ├── data/              # Seed data demo (recipes, user, places)
│   ├── models/            # Domain models (Recipe, User, Cart, Place, MealPlan)
│   ├── pages/             # 16 Screen views (Splash, Auth, Home, Search, Detail, Cook, 
│   │                      #   Favorites, Groceries, Add, MyRecipes, MealPlan, Nearby, Profile, About)
│   ├── providers/         # Riverpod State Notifiers & Providers
│   ├── services/          # Abstraksi RecipeService & Storage
│   └── widgets/           # Global widgets (AppHeader, AppBottomNav, RecipeCards, IllustratedMap)
│       └── ui/            # Atomic UI components (Button, Input, Checkbox, Toggle, Chip, Badge, Skeleton, SmartImage)
└── test/                  # 108 Unit, Widget, Flow, QA Audit, Dark Mode & Real Map tests
```
