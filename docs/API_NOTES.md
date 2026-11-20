# Catatan Teknis & Verifikasi API Backend (Fase B0)

Dokumen ini memuat temuan hasil audit, panggilan API nyata, struktur payload asli, pemetaan field ke model internal Foodie.id (`Recipe`, `Ingredient`, `RecipeStep`), serta batasan layanan publik pihak ketiga (Overpass API dan OSRM).

---

## 1. Status & Hasil Uji API Resep

### 1.1. API #1: Resep Masakan Nusantara (UTAMA / AKTIF)
* **Base URL**: `https://api-resep-masakan.vercel.app`
* **Status**: **LIVE & SANGAT STABIL** (HTTP 200 OK)
* **Backend**: Node.js REST API dengan Supabase/PostgreSQL.
* **Autentikasi**: Publik (tanpa API key).
* **Format Envelope**:
  ```json
  {
    "statusCode": 200,
    "success": true,
    "message": "...",
    "data": [ ... ] / { ... },
    "meta": {
      "page": 1,
      "limit": 10,
      "totalItems": 210,
      "totalPages": 21,
      "hasNextPage": true,
      "hasPrevPage": false
    }
  }
  ```

#### Endpoint & Parameter
1. **List Resep**: `GET /api/v1/recipes`
   * Query params:
     * `limit`: integer (min 1, max 100). Default: 10. **Penting:** Nilai > 100 menghasilkan `HTTP 400 Bad Request` (`["limit must not be greater than 100"]`).
     * `page`: integer (min 1). Default: 1.
     * `scope`: filter wilayah/negara, contoh `INDONESIA` (menghasilkan 190 resep autentik).
     * `category`: filter slug kategori (contoh: `daging-sapi-kambing`, `ayam-bebek`, `seafood`).
     * `origin`: filter nama daerah/provinsi (contoh: `Sumatera Barat`, `Jawa Tengah`, `Bali`).
     * `search` atau `q`: pencarian teks bebas judul/nama masakan (contoh: `?search=soto` atau `?q=rendang`).
2. **Detail Resep**:
   * `GET /api/v1/recipes/{slug}` (contoh: `/api/v1/recipes/rendang-daging-khas-minang`)
   * `GET /api/v1/recipes/{id}` (contoh: `/api/v1/recipes/927ea8d8-cfa2-4fc0-a91a-adc0ff8a32d1`)
   * **Keduanya didukung secara penuh**. Endpoint detail mengembalikan struktur lengkap: `ingredientGroups`, `steps`, dan `nutrition`.
3. **Kategori Resep**: `GET /api/v1/categories`
   * Mengembalikan 11 kategori masakan:
     * `ayam-bebek` (Ayam & Bebek)
     * `daging-sapi-kambing` (Daging Sapi & Kambing)
     * `seafood` (Ikan & Seafood)
     * `tahu-tempe-telur` (Tahu, Tempe & Telur)
     * `sayuran-tumisan` (Sayur & Tumisan)
     * `nasi-mie-pasta` (Nasi, Mie & Pasta)
     * `sup-soto` (Sup & Soto)
     * `kue-dessert` (Kue & Dessert)
     * `minuman-es` (Minuman & Minuman Dingin)
     * `sambal-saus` (Sambal & Saus)
     * `camilan-gorengan` (Camilan & Gorengan)

#### Struktur Bahan & Langkah di API #1
* **Bahan (`ingredientGroups`)**: Sangat terstruktur dan dikelompokkan secara semantik (`name`: "Bahan Utama", "Bumbu Halus", "Bumbu Rempah Cemplung"). Tiap item memiliki:
  * `id`: UUID
  * `name`: Nama bahan (contoh: "Daging Sapi")
  * `amount`: Nilai kuantitas dalam string (contoh: "1", "150", "2")
  * `unit`: Satuan (contoh: "kg", "g", "liter", "siung", "sdm", "lembar", "batang")
  * `notes`: Catatan teknis (contoh: "potongan Gandik, potong dadu 5x5 cm")
  * `rawText`: String teks asli utuh.
* **Langkah (`steps`)**:
  * `id`: UUID
  * `stepNumber`: 1, 2, 3...
  * `title`: Judul langkah ringkas (contoh: "Menyangrai Bumbu", "Memasukkan Daging", "Proses Slow Cooking")
  * `instruction`: Kalimat instruksi mendalam
  * `rawText`: Judul + instruksi gabungan.
* **Nutrisi (`nutrition`)**:
  * `calories`: integer kkal (contoh: 320)
  * `protein`: string gram (contoh: "22")
  * `fat`: string gram (contoh: "24")
  * `carbohydrates`: string gram (contoh: "5")
  * `serving`: string (contoh: "Per 100g")
  * `notes`: catatan kandungan gizi.

---

### 1.2. API #2: Masak Apa Hari Ini (tomorisakura) (TIDAK AKTIF / RUSAK)
* **Base URL**: `https://masak-apa.tomorisakura.vercel.app`
* **Status**: **HTTP 404 NOT FOUND** pada seluruh endpoint (`/api/recipes`, `/api/recipe/:key`, `/api/search/?q=coto`).
* **Penyebab**: API ini merupakan unofficial web scraper terhadap portal `masakapahariini.com`. Portal sumber telah merombak arsitektur rute web dan menambahkan proteksi CDN/Cloudflare sehingga parser cheerio/scraper upstream gagal (menghasilkan status `Error: Request failed with status code 404`).
* **Rekomendasi**: Jangan dijadikan sumber utama maupun cadangan aktif karena dependensi parsing HTML pihak ketiga yang rapuh.

---

### 1.3. API #3: Masak Apa Hari Ini v1 (Cadangan Alternatif) (TIDAK AKTIF)
* **Base URL**: `https://masakapahariini-api.vercel.app`
* **Status**: **HTTP 404 NOT FOUND** pada `/api/v1/recipes`. Layanan upstream mati.

---

## 2. Pemetaan Lapisan Data (API #1 -> Model Foodie.id)

Berikut adalah aturan pemetaan dari payload API #1 (`api-resep-masakan`) ke model domain Foodie.id (`Recipe`, `Ingredient`, `RecipeStep`):

### 2.1. Model `Recipe` (`lib/models/recipe.dart`)

| Field `Recipe` | Tipe Data | Sumber dari API #1 | Aturan / Fallback jika Kosong / Beda Format |
|---|---|---|---|
| `id` | `String` | `data.id` (UUID) | Gunakan `data.id` langsung. |
| `title` | `String` | `data.name` | **PENTING**: Gunakan `data.name` (mis. "Rendang Daging Khas Minang"), **BUKAN** `data.title` karena `data.title` mengandung prefix angka dan asal daerah (mis. `"1. Rendang Daging Khas Minang (Sumatera Barat)"`). |
| `description` | `String` | `data.category.description` atau `data.rawContent` | Bila deskripsi naratif tidak ada, gunakan kalimat ringkasan: `"${data.name} khas ${data.origin}, disajikan untuk ${data.servings} porsi."` |
| `image` | `String?` | `data.imageUrl` | URL Supabase Storage publik. Jika null/gagal dimuat, ditangani otomatis oleh widget `SmartImage`. |
| `category` | `String` | `data.category.name` | Contoh: "Daging Sapi & Kambing", "Sup & Soto". |
| `cuisine` | `String` | `data.origin` | Contoh: "Sumatera Barat", "Jawa Tengah". |
| `meal` | `MealType` | *Tidak ada langsung di API* | Mapping heuristik berdasarkan kategori API: <br>• `minuman-es` -> `MealType.drinks`<br>• `kue-dessert` -> `MealType.dessert`<br>• `camilan-gorengan` -> `MealType.snack`<br>• default -> `MealType.lunch` atau `MealType.dinner`. |
| `mainIngredient` | `String` | Dari `ingredientGroups` | Ambil nama bahan pertama pada kelompok utama: `data.ingredientGroups[0].ingredients[0].name`. Fallback: `data.category.name`. |
| `rating` | `double` | *Tidak ada di API* | Default `4.8` (atau dihitung dinamis dari rating pengguna lokal di storage Hive). |
| `reviews` | `int` | *Tidak ada di API* | Default `12` (atau dihitung dinamis dari riwayat rating pengguna lokal). |
| `timeMin` | `int` | `prepTimeMinutes + cookTimeMinutes` | Total waktu memasak. Jika nol, fallback 30 menit. |
| `servings` | `int` | `data.servings` | Default 2 jika null/0. |
| `kcal` | `int` | `data.nutrition.calories` | Nilai kalori kkal. Default 250 jika null/0. |
| `difficulty` | `Difficulty` | `data.difficulty` | Mapping string: <br>• `"EASY"` -> `Difficulty.mudah`<br>• `"MEDIUM"` -> `Difficulty.sedang`<br>• `"HARD"` -> `Difficulty.sulit`<br>• Lainnya -> `Difficulty.mudah`. |
| `ingredients` | `List<Ingredient>` | `data.ingredientGroups` | Flatten seluruh `ingredients` dari setiap `ingredientGroups` (lihat tabel Ingredient). |
| `steps` | `List<RecipeStep>` | `data.steps` | Mapping dari daftar langkah API (lihat tabel RecipeStep). |
| `authorId` | `String?` | *null* | Tetap `null` untuk resep bawaan API/sistem. Hanya terisi jika resep dibuat oleh user lokal di HP. |

---

### 2.2. Model `Ingredient` (`lib/models/ingredient.dart`)

| Field `Ingredient` | Tipe Data | Sumber dari API #1 | Penjelasan & Fallback |
|---|---|---|---|
| `id` | `String` | `ingredient.id` | Gunakan UUID dari API. |
| `name` | `String` | `ingredient.name` | Nama bahan bersih (mis. "Daging Sapi", "Cabai merah keriting"). |
| `qty` | `String` | `ingredient.amount` | Kuantitas (mis. "1", "150", "2"). Jika null/kosong, fallback `"1"`. |
| `unit` | `String?` | `ingredient.unit` | Satuan (mis. "kg", "g", "liter", "siung", "sdm"). |
| `price` | `int` | *Tidak ada di API* | API resep tidak menyediakan estimasi harga bahan. Untuk mendukung fitur keranjang belanja (*Groceries*) dan total estimasi belanja, gunakan generator harga deterministik berbasis hash nama bahan (mis. range Rp 3.000 – Rp 25.000) atau tabel harga bahan pokok Nusantara default. |

---

### 2.3. Model `RecipeStep` (`lib/models/recipe_step.dart`)

| Field `RecipeStep` | Tipe Data | Sumber dari API #1 | Penjelasan & Fallback |
|---|---|---|---|
| `id` | `String` | `step.id` | Gunakan UUID dari API. |
| `title` | `String` | `step.title` | Judul langkah API (mis. "Menyangrai Bumbu"). Jika kosong, fallback `"Langkah ${step.stepNumber}"`. |
| `description` | `String` | `step.instruction` | Uraian detail cara pengolahan/memasak. |
| `durationMin` | `int?` | *Tidak ada di API per langkah* | Biarkan `null` atau diestimasi rata: `(timeMin / steps.length).round()`. |

---

## 3. Verifikasi Layanan Peta & Rute Publik

### 3.1. Overpass API (OpenStreetMap)
* **URL Interpreter**: `https://overpass-api.de/api/interpreter`
* **Status**: **LIVE & TERVERIFIKASI** (HTTP 200 OK).
* **Fungsi pada Foodie.id**: Mencari toko bahan makanan, pasar tradisional, supermarket, dan restoran/warung terdekat di halaman Nearby / Groceries.
* **Format Query**: Overpass QL via `POST` atau `GET ?data=...`
  ```overpass
  [out:json][timeout:15];
  (
    node["shop"~"supermarket|convenience|greengrocer"](around:2000, -6.2000, 106.8166);
    node["amenity"~"marketplace|restaurant"](around:2000, -6.2000, 106.8166);
  );
  out body;
  ```
* **Batasan & Aturan Pemakaian Publik**:
  1. **Concurrency Limit**: Maksimal **2 koneksi simultan** per alamat IP. Melebihi ini akan menerima respon `HTTP 429 Too Many Requests` atau `HTTP 504 Gateway Timeout`.
  2. **Quota / Rate Limit**: Kuota publik sekitar 10.000 request/hari atau 1 GB bandwidth. Tidak diperuntukkan bagi continuous polling.
  3. **Timeout Default**: Wajib menyertakan `[timeout:15]` agar server tidak hang.
  4. **User-Agent Requirement**: Wajib menyertakan Header `User-Agent` yang jelas (misal: `FoodieApp/1.0 (contact: foodie.id)`).
  5. **Strategi di Aplikasi**: Wajib mengimplementasikan in-memory caching (berdasarkan radius geohash/koordinat) dan debounce saat menggeser peta agar tidak membanjiri server publik OSM.

---

### 3.2. OSRM (Open Source Routing Machine)
* **URL Demo**: `https://router.project-osrm.org`
* **Status**: **LIVE & TERVERIFIKASI** (HTTP 200 OK).
* **Fungsi pada Foodie.id**: Menghitung rute perjalanan pejalan kaki/kendaraan, jarak tempuh (meter), dan estimasi waktu perjalanan (detik) ke toko/pasar terdekat.
* **Format Request**:
  `GET /route/v1/foot/{start_lng},{start_lat};{end_lng},{end_lat}?overview=full&geometries=geojson`
  * Contoh respons terverifikasi:
    ```json
    {
      "code": "Ok",
      "routes": [{
        "geometry": { "coordinates": [ ... ], "type": "LineString" },
        "distance": 847.2,
        "duration": 609.9
      }],
      "waypoints": [ ... ]
    }
    ```
* **Batasan & Aturan Pemakaian Publik**:
  1. **Demo Server Policy**: Server `router.project-osrm.org` disediakan bebas tanpa jaminan SLA untuk keperluan testing & prototyping saja.
  2. **Rate Limit**: Batasi request hanya saat pengguna memilih destinasi spesifik (on-demand), jangan melakukan recalculation setiap perubahan mikro GPS.
  3. **No Heavy Batch**: Dilarang melakukan bulk matrix routing.
  4. **Fallback**: Jika OSRM down/timeout, aplikasi harus memiliki fallback perhitungan jarak Haversine (garis lurus) sederhana yang sudah ada di helper lokal.

---

## 4. Lokasi File Fixture Pengujian

Untuk keperluan unit test dan widget test offline di fase B1 dan seterusnya, sample respons mentah telah disimpan di:
* `test/fixtures/api1_recipes_list.json` — Respons list resep (`/api/v1/recipes?scope=INDONESIA&limit=10`).
* `test/fixtures/api1_recipe_detail_by_slug.json` — Respons detail resep via slug (`rendang-daging-khas-minang`).
* `test/fixtures/api1_recipe_detail_by_id.json` — Respons detail resep via UUID.
* `test/fixtures/api1_search_soto.json` — Respons query pencarian `?search=soto`.
* `test/fixtures/osrm_route_sample.json` — Respons rute routing OSRM (koordinat geojson, jarak, durasi).
* `test/fixtures/overpass_sample.json` — Respons POI Overpass OSM (node toko/restoran terdekat).
