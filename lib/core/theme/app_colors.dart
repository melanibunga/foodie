import 'package:flutter/material.dart';

/// Design tokens warna untuk Foodie.id sesuai PRD §4.
/// Tidak boleh ada Color(0x...) atau Colors.xxx di luar file ini,
/// kecuali Colors.transparent di widget.
abstract final class AppColors {
  // Brand / Utama (dari STYLE GUIDE.jpg)
  static const Color olive = Color(0xFF263C32); // primary
  static const Color amber = Color(0xFFF59E0B); // accent
  static const Color maroon = Color(0xFF800020);
  static const Color sage = Color(0xFF717665);
  static const Color bg = Color(0xFFF5F5F0);
  static const Color white = Color(0xFFFFFFFF);

  // Warna Turunan & Spesifik
  static const Color amberSoft = Color(
    0xFFF4E9CE,
  ); // Tag "MASAK LEBIH MUDAH", tombol plus Meal Plan
  static const Color maroonSoft = Color(0xFFF4E6E9); // Chip "Edit profil"
  static const Color fieldGray = Color(0xFFD6D6D6); // Input halaman Add
  static const Color chipGray = Color(
    0xFFE8E8E2,
  ); // Tombol filter bulat, rute non-aktif
  static const Color mapBg = Color(0xFFE7E9DE); // Peta ilustrasi background
  static const Color mapBlock = Color(
    0xFFDEE3D8,
  ); // Blok bangunan peta ilustrasi
  static const Color splashDark = Color(0xFF082B21); // Bagian bawah splash
  static const Color photoGray = Color(0xFFD9D9D4); // Placeholder semua foto
  static const Color photoGrayIcon = Color(
    0xFFBDBDB5,
  ); // Ikon garpu-sendok di tengah placeholder
  static const Color outerBg = Color(
    0xFFE9E9E2,
  ); // Background luar kolom 440 (web/tablet)
  static const Color border = Color(0xFFE3E3DC); // Border tipis input/chip
  static const Color toggleOff = Color(0xFFE0E0DA); // Track toggle non-aktif
  static const Color summaryBg = Color(
    0xFFF4F1EA,
  ); // Kartu ringkasan detail menu

  // Teks
  static const Color textTitle = Color(0xFF263C32); // Judul (olive)
  static const Color textBody = Color(0xFF1E1E1E); // Teks badan
  static const Color textSecondary = Color(0xFF717665); // Sekunder (sage)

  // Overlay / Bayangan transparan
  static const Color shadowOlive = Color(0x0F263C32); // olive @ 6%
  static const Color shadowNav = Color(0x2E000000); // black @ 18%
  static const Color shadowShell = Color(0x14000000); // black @ 8%
  static const Color shadowAmber = Color(0x40F59E0B); // amber @ 25%
  static const Color dialogBarrier = Color(0x73263C32); // olive @ 45%
  static const Color photoGradient = Color(0x59000000); // black @ 35%
  static const Color overlayWhite80 = Color(
    0xCCFFFFFF,
  ); // Tombol bulat hero foto (80%)
  static const Color overlayDark60 = Color(
    0x99000000,
  ); // Chip rating & waktu di atas foto (60%)
  static const Color shadowThumb = Color(0x26000000); // Bayangan thumb toggle
  static const Color shadowSubtle = Color(
    0x1A000000,
  ); // Bayangan tombol overlay

  // Dark Mode Tokens (Fase 16)
  static const Color bgDark = Color(0xFF121611); // Latar utama dark
  static const Color outerBgDark = Color(
    0xFF0A0D09,
  ); // Latar outer column 440 dark
  static const Color surfaceDark = Color(0xFF1B2218); // Kartu & surface dark
  static const Color surfaceDarkElevated = Color(
    0xFF242D20,
  ); // Input & dropdown dark
  static const Color borderDark = Color(0xFF2C3626); // Border tipis dark
  static const Color chipGrayDark = Color(
    0xFF242D20,
  ); // Chip & tombol filter dark
  static const Color summaryBgDark = Color(0xFF1F281B); // Summary card dark
  static const Color textTitleDark = Color(0xFFF3F4F1); // Judul di dark mode
  static const Color textBodyDark = Color(0xFFE2E8F0); // Teks body dark mode
  static const Color textSecondaryDark = Color(
    0xFF94A3B8,
  ); // Teks secondary dark mode
  static const Color oliveDark = Color(
    0xFF5E7A46,
  ); // Olive terangkat di dark mode
  static const Color oliveSoftDark = Color(0xFF1F2B17); // Olive soft dark
  static const Color amberSoftDark = Color(0xFF382B12); // Amber soft dark
  static const Color maroonDark = Color(
    0xFFA33B39,
  ); // Maroon terangkat di dark mode
  static const Color maroonSoftDark = Color(0xFF331818); // Maroon soft dark
}
