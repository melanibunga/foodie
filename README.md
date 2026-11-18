# Foodie.id Frontend (Flutter)

Aplikasi resep & belanja bahan Nusantara berbasis Flutter.

## Persyaratan
- Flutter SDK (stable, Dart 3)
- Chrome / Android Emulator / iOS Simulator

## Cara Menjalankan

1. **Install dependensi:**
   ```bash
   flutter pub get
   ```

2. **Jalankan di Chrome (Web):**
   ```bash
   flutter run -d chrome
   ```

3. **Jalankan di Emulator / Device:**
   ```bash
   flutter run
   ```

4. **Testing & Analisis:**
   ```bash
   flutter analyze
   flutter test
   ```

## Struktur Folder

```text
foodie/
├── assets/
│   ├── fonts/         # Font Poppins (400, 500, 600, 700, 800)
│   └── images/        # Aset gambar lokal
├── design/            # Referensi desain (13 file JPG)
├── docs/              # Dokumentasi & PRD.md
├── lib/
│   ├── app/           # Konfigurasi router, wrapper app, provider utama
│   ├── core/
│   │   ├── theme/     # Definisi tema, palet warna, tipografi
│   │   └── utils/     # Format rupiah, konstanta, helper
│   ├── data/          # Mock seed data (recipes, places, users)
│   ├── models/        # Model data (Recipe, CartItem, User, MealPlan, dll.)
│   ├── pages/         # Halaman / screen aplikasi
│   ├── providers/     # State management (Riverpod providers)
│   ├── services/      # Abstraksi data (RecipeService, StorageService)
│   └── widgets/       # Reusable components
│       └── ui/        # Atomic UI widgets (Button, Input, Chip, Badge, dll.)
└── test/              # Unit & widget tests
```
