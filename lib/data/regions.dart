/// Definisi grup dan data daerah untuk "Search by Region" sesuai PRD §6.5, §7.2, §17.
class RegionItem {
  final String id;
  final String name;
  final String group;
  final List<String> aliases;

  const RegionItem({
    required this.id,
    required this.name,
    required this.group,
    this.aliases = const [],
  });

  /// Mengecek apakah cuisine / origin string dari resep cocok dengan daerah ini
  bool matches(String rawOrigin) {
    final lower = rawOrigin.trim().toLowerCase();
    if (lower == name.toLowerCase()) return true;
    for (final alias in aliases) {
      if (lower.contains(alias.toLowerCase())) return true;
    }
    return false;
  }
}

class RegionGroup {
  final String name;
  final List<RegionItem> items;

  const RegionGroup({required this.name, required this.items});
}

/// Normalisasi nama asal daerah (misal "Indonesian" -> "Indonesia")
String normalizeRegionName(String rawOrigin) {
  final trimmed = rawOrigin.trim();
  if (trimmed.isEmpty) return 'Nusantara';
  final lower = trimmed.toLowerCase();
  if (lower == 'indonesian') return 'Indonesia';
  if (lower.contains('jogja') || lower.contains('yogyakarta')) {
    return 'DI Yogyakarta';
  }
  return trimmed;
}

/// Pemetaan setiap asal daerah nyata dari respons API ke tepat 1 grup daerah
String mapOriginToGroup(String rawOrigin) {
  final lower = rawOrigin.trim().toLowerCase();

  // 1. Sumatra
  if (lower.contains('aceh') ||
      lower.contains('sumatera barat') ||
      lower.contains('padang') ||
      lower.contains('minang') ||
      lower.contains('sumatera utara') ||
      lower.contains('medan') ||
      lower.contains('sumatera selatan') ||
      lower.contains('palembang') ||
      lower.contains('riau') ||
      lower.contains('bangka')) {
    return 'Sumatra';
  }

  // 2. Jawa
  if (lower.contains('jakarta') ||
      lower.contains('betawi') ||
      lower.contains('jawa barat') ||
      lower.contains('sunda') ||
      lower.contains('bandung') ||
      lower.contains('cirebon') ||
      lower.contains('purwakarta') ||
      lower.contains('jawa tengah') ||
      lower.contains('semarang') ||
      lower.contains('solo') ||
      lower.contains('banjarnegara') ||
      lower.contains('pati') ||
      lower.contains('magelang') ||
      lower.contains('yogyakarta') ||
      lower.contains('jogja') ||
      lower.contains('jawa timur') ||
      lower.contains('surabaya') ||
      lower.contains('malang') ||
      lower.contains('lamongan') ||
      lower.contains('mojokerto') ||
      lower.contains('madura') ||
      lower == 'jawa' ||
      lower == 'jawa tradisional') {
    return 'Jawa';
  }

  // 3. Bali & Nusa Tenggara
  if (lower.contains('bali') ||
      lower.contains('lombok') ||
      lower.contains('nusa tenggara')) {
    return 'Bali & Nusa Tenggara';
  }

  // 4. Kalimantan
  if (lower.contains('kalimantan') ||
      lower.contains('banjarmasin') ||
      lower.contains('samarinda')) {
    return 'Kalimantan';
  }

  // 5. Sulawesi
  if (lower.contains('sulawesi') ||
      lower.contains('manado') ||
      lower.contains('makassar')) {
    return 'Sulawesi';
  }

  // 6. Maluku & Papua
  if (lower.contains('maluku') ||
      lower.contains('ternate') ||
      lower.contains('papua')) {
    return 'Maluku & Papua';
  }

  // 7. Mancanegara / Internasional
  if (lower.contains('jepang') ||
      lower.contains('korea') ||
      lower.contains('tiongkok') ||
      lower.contains('singapura') ||
      lower.contains('thailand') ||
      lower.contains('timur tengah') ||
      lower.contains('amerika') ||
      lower.contains('belanda') ||
      lower.contains('eropa') ||
      lower.contains('italia') ||
      lower.contains('prancis') ||
      lower.contains('oriental') ||
      lower.contains('chinese')) {
    return 'Mancanegara';
  }

  // 8. Fallback aman ke "Lainnya" (jangan sampai ada yang hilang)
  return 'Lainnya';
}

/// Daftar grup daerah resmi untuk grid "Search by Region" di halaman Search
const List<RegionGroup> kRegionGroups = [
  RegionGroup(
    name: 'Sumatra',
    items: [
      RegionItem(
        id: 'sumatera-barat',
        name: 'Sumatera Barat',
        group: 'Sumatra',
        aliases: ['sumatera barat', 'padang', 'minang'],
      ),
      RegionItem(id: 'aceh', name: 'Aceh', group: 'Sumatra', aliases: ['aceh']),
      RegionItem(
        id: 'sumatera-utara',
        name: 'Sumatera Utara',
        group: 'Sumatra',
        aliases: ['sumatera utara', 'medan'],
      ),
      RegionItem(
        id: 'sumatera-selatan',
        name: 'Sumatera Selatan',
        group: 'Sumatra',
        aliases: ['sumatera selatan', 'palembang'],
      ),
      RegionItem(id: 'riau', name: 'Riau', group: 'Sumatra', aliases: ['riau']),
      RegionItem(
        id: 'bangka',
        name: 'Bangka Belitung',
        group: 'Sumatra',
        aliases: ['bangka'],
      ),
    ],
  ),
  RegionGroup(
    name: 'Jawa',
    items: [
      RegionItem(
        id: 'dki-jakarta',
        name: 'DKI Jakarta',
        group: 'Jawa',
        aliases: ['dki jakarta', 'jakarta', 'betawi'],
      ),
      RegionItem(
        id: 'jawa-barat',
        name: 'Jawa Barat',
        group: 'Jawa',
        aliases: ['jawa barat', 'sunda', 'bandung', 'cirebon', 'purwakarta'],
      ),
      RegionItem(
        id: 'jawa-tengah',
        name: 'Jawa Tengah',
        group: 'Jawa',
        aliases: [
          'jawa tengah',
          'semarang',
          'solo',
          'banjarnegara',
          'pati',
          'magelang',
        ],
      ),
      RegionItem(
        id: 'di-yogyakarta',
        name: 'DI Yogyakarta',
        group: 'Jawa',
        aliases: ['di yogyakarta', 'yogyakarta', 'jogja'],
      ),
      RegionItem(
        id: 'jawa-timur',
        name: 'Jawa Timur',
        group: 'Jawa',
        aliases: ['jawa timur', 'surabaya', 'malang', 'lamongan', 'mojokerto'],
      ),
      RegionItem(
        id: 'madura',
        name: 'Madura',
        group: 'Jawa',
        aliases: ['madura'],
      ),
    ],
  ),
  RegionGroup(
    name: 'Bali & Nusa Tenggara',
    items: [
      RegionItem(
        id: 'bali',
        name: 'Bali',
        group: 'Bali & Nusa Tenggara',
        aliases: ['bali'],
      ),
      RegionItem(
        id: 'lombok',
        name: 'Lombok & NTB',
        group: 'Bali & Nusa Tenggara',
        aliases: ['lombok', 'nusa tenggara barat', 'ntb'],
      ),
    ],
  ),
  RegionGroup(
    name: 'Kalimantan',
    items: [
      RegionItem(
        id: 'kalimantan-selatan',
        name: 'Kalimantan Selatan',
        group: 'Kalimantan',
        aliases: ['kalimantan selatan', 'banjarmasin'],
      ),
      RegionItem(
        id: 'kalimantan-timur',
        name: 'Kalimantan Timur',
        group: 'Kalimantan',
        aliases: ['kalimantan timur', 'samarinda'],
      ),
    ],
  ),
  RegionGroup(
    name: 'Sulawesi',
    items: [
      RegionItem(
        id: 'sulawesi-utara',
        name: 'Sulawesi Utara',
        group: 'Sulawesi',
        aliases: ['sulawesi utara', 'manado'],
      ),
      RegionItem(
        id: 'sulawesi-selatan',
        name: 'Sulawesi Selatan',
        group: 'Sulawesi',
        aliases: ['sulawesi selatan', 'makassar'],
      ),
    ],
  ),
  RegionGroup(
    name: 'Maluku & Papua',
    items: [
      RegionItem(
        id: 'maluku',
        name: 'Maluku',
        group: 'Maluku & Papua',
        aliases: ['maluku', 'ternate', 'maluku utara'],
      ),
      RegionItem(
        id: 'papua',
        name: 'Papua',
        group: 'Maluku & Papua',
        aliases: ['papua'],
      ),
    ],
  ),
  RegionGroup(
    name: 'Mancanegara',
    items: [
      RegionItem(
        id: 'asia-timur',
        name: 'Asia Timur & Tenggara',
        group: 'Mancanegara',
        aliases: [
          'jepang',
          'korea',
          'tiongkok',
          'singapura',
          'thailand',
          'oriental',
          'chinese',
        ],
      ),
      RegionItem(
        id: 'timur-tengah',
        name: 'Timur Tengah',
        group: 'Mancanegara',
        aliases: ['timur tengah', 'arab'],
      ),
      RegionItem(
        id: 'barat-eropa',
        name: 'Barat & Eropa',
        group: 'Mancanegara',
        aliases: [
          'amerika serikat',
          'belanda',
          'eropa',
          'italia',
          'prancis',
          'burger',
        ],
      ),
    ],
  ),
  RegionGroup(
    name: 'Lainnya',
    items: [
      RegionItem(
        id: 'masakan-rumahan',
        name: 'Masakan Rumahan',
        group: 'Lainnya',
        aliases: [
          'masakan rumahan',
          'sajian kaki lima',
          'sajian restoran',
          'sajian takjil',
        ],
      ),
      RegionItem(
        id: 'nusantara',
        name: 'Nusantara',
        group: 'Lainnya',
        aliases: ['nusantara', 'indonesia'],
      ),
    ],
  ),
];

/// Daftar kategori nyata dari API
const List<String> kApiRecipeCategories = [
  'Ayam & Unggas',
  'Daging Sapi & Kambing',
  'Ikan & Seafood',
  'Kudapan & Jajanan Pasar',
  'Lauk Utama Nusantara',
  'Mi & Pasta',
  'Minuman Segar',
  'Nasi & Olahan Beras',
  'Sate & Bakaran',
  'Sayuran & Tumisan',
  'Sup & Soto',
];

/// Daftar opsi bahan utama nyata dari API
const List<String> kApiMainIngredients = [
  'Ayam',
  'Sapi',
  'Ikan',
  'Telur',
  'Tahu & Tempe',
  'Sayur',
  'Udang',
];
