import '../core/utils/week_utils.dart';
import '../models/models.dart';

/// Seed keranjang belanja awal sesuai demo PRD §9, §6.11, §15.7
final List<CartGroup> seedCartGroups = [
  CartGroup(
    id: 'cart-group-custom',
    recipeId: null, // "Belanjaan Kamu Nich"
    name: 'Belanjaan Kamu Nich',
    addedAt: DateTime(2026, 1, 1, 8, 0),
    items: [
      CartItem(
        id: 'ci-custom-1',
        name: 'Tisu',
        qty: '1 bungkus',
        price: 7000,
        checked: false,
        addedAt: DateTime(2026, 1, 1, 8, 0),
      ),
    ],
  ),
  CartGroup(
    id: 'cart-group-ngs',
    recipeId: 'nasi-goreng-spesial',
    name: 'Nasi Goreng Spesial',
    addedAt: DateTime(2026, 1, 1, 10, 0),
    items: [
      CartItem(
        id: 'ci-ngs-1',
        name: 'Telur',
        qty: '2 btr',
        price: 4000,
        checked: true,
        addedAt: DateTime(2026, 1, 1, 10, 0),
      ),
      CartItem(
        id: 'ci-ngs-2',
        name: 'Bawang merah',
        qty: '4 siung',
        price: 2000,
        checked: true,
        addedAt: DateTime(2026, 1, 1, 10, 1),
      ),
      CartItem(
        id: 'ci-ngs-3',
        name: 'Beras',
        qty: '250 g',
        price: 3000,
        checked: false,
        addedAt: DateTime(2026, 1, 1, 10, 2),
      ),
    ],
  ),
  CartGroup(
    id: 'cart-group-sa',
    recipeId: 'soto-ayam',
    name: 'Soto Ayam',
    addedAt: DateTime(2026, 1, 1, 9, 0),
    items: [
      CartItem(
        id: 'ci-sa-1',
        name: 'Ayam',
        qty: '250 g',
        price: 12000,
        checked: true,
        addedAt: DateTime(2026, 1, 1, 9, 0),
      ),
      CartItem(
        id: 'ci-sa-2',
        name: 'Bihun',
        qty: '1 bungkus',
        price: 5000,
        checked: false,
        addedAt: DateTime(2026, 1, 1, 9, 1),
      ),
      CartItem(
        id: 'ci-sa-3',
        name: 'Daun bawang',
        qty: '1 ikat',
        price: 3000,
        checked: false,
        addedAt: DateTime(2026, 1, 1, 9, 2),
      ),
    ],
  ),
];

/// Seed daftar ID menu favorit awal (6 resep) sesuai PRD §9
const List<String> seedFavorites = [
  'ayam-kecap-bawang',
  'nasi-goreng-nusantara',
  'soto-ayam',
  'rendang-sapi-minang',
  'telur-balado',
  'tumis-kangkung',
];

/// Buat seed meal plan awal untuk Senin–Sabtu minggu berjalan sesuai PRD §9.
List<MealPlanEntry> createSeedMealPlan([DateTime? referenceDate]) {
  final monday = WeekUtils.getWeekStart(referenceDate ?? DateTime.now());
  final days = WeekUtils.getWeekDays(monday);

  final recipeAssignments = [
    'ayam-kecap-bawang', // Senin
    'nasi-goreng-nusantara', // Selasa
    'soto-ayam', // Rabu
    'tumis-kangkung', // Kamis
    'telur-balado', // Jumat
    'rendang-sapi-minang', // Sabtu
  ];

  final entries = <MealPlanEntry>[];
  for (int i = 0; i < 6; i++) {
    final dateStr = WeekUtils.formatDateKey(days[i]);
    entries.add(
      MealPlanEntry(
        id: 'mp-seed-$i',
        date: dateStr,
        recipeId: recipeAssignments[i],
      ),
    );
  }

  // Tambahkan resep ke-2 di hari Senin & Rabu (1–2 resep per hari)
  entries.add(
    MealPlanEntry(
      id: 'mp-seed-extra-1',
      date: WeekUtils.formatDateKey(days[0]),
      recipeId: 'bihun-goreng',
    ),
  );
  entries.add(
    MealPlanEntry(
      id: 'mp-seed-extra-2',
      date: WeekUtils.formatDateKey(days[2]),
      recipeId: 'gado-gado-siram',
    ),
  );

  return entries;
}

/// 12 entri seed riwayat masak sesuai PRD §9 & §14.10 ("dimasak 12")
final List<CookedEntry> seedCookedEntries = [
  const CookedEntry(
    id: 'cooked-seed-1',
    recipeId: 'ayam-kecap-bawang',
    date: '2026-11-18',
  ),
  const CookedEntry(
    id: 'cooked-seed-2',
    recipeId: 'soto-ayam',
    date: '2026-11-17',
  ),
  const CookedEntry(
    id: 'cooked-seed-3',
    recipeId: 'nasi-goreng-nusantara',
    date: '2026-11-16',
  ),
  const CookedEntry(
    id: 'cooked-seed-4',
    recipeId: 'rendang-sapi-minang',
    date: '2026-11-14',
  ),
  const CookedEntry(
    id: 'cooked-seed-5',
    recipeId: 'gado-gado-siram',
    date: '2026-11-12',
  ),
  const CookedEntry(
    id: 'cooked-seed-6',
    recipeId: 'salmon-teriyaki',
    date: '2026-11-10',
  ),
  const CookedEntry(
    id: 'cooked-seed-7',
    recipeId: 'sate-ayam',
    date: '2026-11-08',
  ),
  const CookedEntry(
    id: 'cooked-seed-8',
    recipeId: 'telur-balado',
    date: '2026-11-05',
  ),
  const CookedEntry(
    id: 'cooked-seed-9',
    recipeId: 'tumis-kangkung',
    date: '2026-11-02',
  ),
  const CookedEntry(
    id: 'cooked-seed-10',
    recipeId: 'bihun-goreng',
    date: '2026-10-30',
  ),
  const CookedEntry(
    id: 'cooked-seed-11',
    recipeId: 'nasi-goreng-spesial',
    date: '2026-10-26',
  ),
  const CookedEntry(
    id: 'cooked-seed-12',
    recipeId: 'ayam-kecap-bawang',
    date: '2026-10-20',
  ),
];
