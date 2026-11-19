import '../models/models.dart';

/// Data seed awal tempat makan sekitar (Nearby) sesuai PRD §9 & §12.
const List<Place> seedPlaces = [
  Place(
    id: 'warung-bu-sari',
    name: 'Warung Bu Sari',
    cuisine: 'Masakan Jawa',
    priceMin: 15000,
    priceMax: 30000,
    distanceM: 180,
    walkMin: 3,
    open: true,
    x: 47.0,
    y: 35.0,
  ),
  Place(
    id: 'ayam-bakar-pak-hadi',
    name: 'Ayam Bakar Pak Hadi',
    cuisine: 'Ayam bakar',
    priceMin: 20000,
    priceMax: 35000,
    distanceM: 450,
    walkMin: 6,
    open: true,
    x: 76.0,
    y: 44.0,
  ),
  Place(
    id: 'warung-padang-salero',
    name: 'Warung Padang Salero',
    cuisine: 'Masakan Padang',
    priceMin: 18000,
    priceMax: 35000,
    distanceM: 700,
    walkMin: 10,
    open: false,
    x: 21.0,
    y: 46.0,
  ),
];
