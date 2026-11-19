import '../core/utils/week_utils.dart';
import '../models/models.dart';

/// Seed keranjang belanja awal sesuai demo PRD §9 & §6.11
final List<CartGroup> seedCartGroups = [
  const CartGroup(
    id: 'cart-group-ngs',
    recipeId: 'nasi-goreng-spesial',
    name: 'Nasi Goreng Spesial',
    items: [
      CartItem(
        id: 'ci-ngs-1',
        name: 'Telur',
        qty: '2 btr',
        price: 4000,
        checked: true,
      ),
      CartItem(
        id: 'ci-ngs-2',
        name: 'Bawang merah',
        qty: '4 siung',
        price: 2000,
        checked: true,
      ),
      CartItem(
        id: 'ci-ngs-3',
        name: 'Beras',
        qty: '250 g',
        price: 3000,
        checked: false,
      ),
    ],
  ),
  const CartGroup(
    id: 'cart-group-sa',
    recipeId: 'soto-ayam',
    name: 'Soto Ayam',
    items: [
      CartItem(
        id: 'ci-sa-1',
        name: 'Ayam',
        qty: '250 g',
        price: 12000,
        checked: true,
      ),
      CartItem(
        id: 'ci-sa-2',
        name: 'Bihun',
        qty: '1 bungkus',
        price: 5000,
        checked: false,
      ),
      CartItem(
        id: 'ci-sa-3',
        name: 'Daun bawang',
        qty: '1 ikat',
        price: 3000,
        checked: false,
      ),
    ],
  ),
  const CartGroup(
    id: 'cart-group-custom',
    recipeId: null, // "Belanjaan Kamu Nich"
    name: 'Belanjaan Kamu Nich',
    items: [
      CartItem(
        id: 'ci-custom-1',
        name: 'Tisu',
        qty: '1 bungkus',
        price: 7000,
        checked: false,
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
