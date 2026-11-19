import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';

/// Halaman inspeksi design tokens untuk verifikasi kesetiaan desain (STYLE GUIDE.jpg).
/// Hanya aktif dalam mode debug (kDebugMode).
class DevTokensPage extends StatelessWidget {
  const DevTokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Design Tokens (STYLE GUIDE)',
          style: AppText.pageTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader('1. Color Swatches (PRD §4)'),
          const SizedBox(height: 12),
          _buildColorGrid(),
          const SizedBox(height: 28),
          _buildSectionHeader('2. Typography (Poppins)'),
          const SizedBox(height: 12),
          _buildTypographySection(),
          const SizedBox(height: 28),
          _buildSectionHeader('3. Radius & Shadows'),
          const SizedBox(height: 12),
          _buildRadiusAndShadowSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.olive,
        borderRadius: AppRadius.buttonSmall,
      ),
      child: Text(
        title,
        style: AppText.cardHeroTitle.copyWith(color: AppColors.white),
      ),
    );
  }

  Widget _buildColorGrid() {
    final colors = <({String name, String hex, Color color, Color text})>[
      (
        name: 'olive (primary)',
        hex: '#263C32',
        color: AppColors.olive,
        text: AppColors.white,
      ),
      (
        name: 'amber (accent)',
        hex: '#F59E0B',
        color: AppColors.amber,
        text: AppColors.olive,
      ),
      (
        name: 'maroon',
        hex: '#800020',
        color: AppColors.maroon,
        text: AppColors.white,
      ),
      (
        name: 'sage',
        hex: '#717665',
        color: AppColors.sage,
        text: AppColors.white,
      ),
      (name: 'bg', hex: '#F5F5F0', color: AppColors.bg, text: AppColors.olive),
      (
        name: 'white',
        hex: '#FFFFFF',
        color: AppColors.white,
        text: AppColors.olive,
      ),
      (
        name: 'amberSoft',
        hex: '#F4E9CE',
        color: AppColors.amberSoft,
        text: AppColors.olive,
      ),
      (
        name: 'maroonSoft',
        hex: '#F4E6E9',
        color: AppColors.maroonSoft,
        text: AppColors.maroon,
      ),
      (
        name: 'fieldGray',
        hex: '#D6D6D6',
        color: AppColors.fieldGray,
        text: AppColors.textBody,
      ),
      (
        name: 'chipGray',
        hex: '#E8E8E2',
        color: AppColors.chipGray,
        text: AppColors.textBody,
      ),
      (
        name: 'mapBg',
        hex: '#E7E9DE',
        color: AppColors.mapBg,
        text: AppColors.olive,
      ),
      (
        name: 'mapBlock',
        hex: '#DEE3D8',
        color: AppColors.mapBlock,
        text: AppColors.olive,
      ),
      (
        name: 'splashDark',
        hex: '#082B21',
        color: AppColors.splashDark,
        text: AppColors.white,
      ),
      (
        name: 'photoGray',
        hex: '#D9D9D4',
        color: AppColors.photoGray,
        text: AppColors.olive,
      ),
      (
        name: 'photoGrayIcon',
        hex: '#BDBDB5',
        color: AppColors.photoGrayIcon,
        text: AppColors.olive,
      ),
      (
        name: 'outerBg',
        hex: '#E9E9E2',
        color: AppColors.outerBg,
        text: AppColors.olive,
      ),
      (
        name: 'border',
        hex: '#E3E3DC',
        color: AppColors.border,
        text: AppColors.olive,
      ),
      (
        name: 'toggleOff',
        hex: '#E0E0DA',
        color: AppColors.toggleOff,
        text: AppColors.textBody,
      ),
      (
        name: 'summaryBg',
        hex: '#F4F1EA',
        color: AppColors.summaryBg,
        text: AppColors.olive,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((c) {
        return Container(
          width: 124,
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.color,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.name,
                style: TextStyle(
                  fontFamily: AppText.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                c.hex,
                style: TextStyle(
                  fontFamily: AppText.fontFamily,
                  fontSize: 10,
                  color: c.text,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypographySection() {
    final samples = <({String label, TextStyle style, String sample})>[
      (
        label: 'H1 auth (32/38 w800)',
        style: AppText.h1Auth,
        sample: 'Selamat datang kembali.',
      ),
      (
        label: 'Judul halaman (26/34 w700)',
        style: AppText.pageTitle,
        sample: 'Menu Favoritmu',
      ),
      (
        label: 'Judul section (20/28 w700)',
        style: AppText.sectionTitle,
        sample: 'Daily Inspiration',
      ),
      (
        label: 'Judul sub-section (18/24 w700)',
        style: AppText.subSectionTitle,
        sample: 'Ayam Kecap Bawang',
      ),
      (
        label: 'Judul kartu hero (16/22 w600)',
        style: AppText.cardHeroTitle,
        sample: 'Nasi Goreng Nusantara',
      ),
      (
        label: 'Judul kartu kecil (14/20 w600)',
        style: AppText.cardSmallTitle,
        sample: 'Soto Ayam Lamongan',
      ),
      (
        label: 'Body (13/20 w400)',
        style: AppText.body,
        sample: 'Paduan bumbu terasi, kecap manis legit, serta taburan bawang goreng.',
      ),
      (
        label: 'Label form (12/18 w600)',
        style: AppText.formLabel,
        sample: 'Email Pengguna',
      ),
      (
        label: 'Caption / meta (11/16 w400)',
        style: AppText.caption,
        sample: '25 Menit • 2 Porsi • 450 kkal',
      ),
      (
        label: 'Tag / uppercase badge (9/12 w700)',
        style: AppText.tag,
        sample: 'MASAK LEBIH MUDAH',
      ),
      (
        label: 'Bottom nav (11/13 w600)',
        style: AppText.bottomNav.copyWith(color: AppColors.olive),
        sample: 'Home • Search • Add • Plan • Loc',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: samples.map((s) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                style: AppText.caption.copyWith(
                  color: AppColors.maroon,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(s.sample, style: s.style),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRadiusAndShadowSection() {
    return Column(
      children: [
        _buildBoxItem(
          title: 'Card Radius (16) + Card Shadow',
          borderRadius: AppRadius.card,
          shadow: AppShadows.card,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          title: 'Card Large Radius (20)',
          borderRadius: AppRadius.cardLarge,
          shadow: AppShadows.card,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          title: 'Detail Card Radius (32)',
          borderRadius: AppRadius.detailCard,
          shadow: AppShadows.card,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          title: 'Pill Radius (999) + Nav Shadow',
          borderRadius: AppRadius.pill,
          shadow: AppShadows.bottomNav,
          color: AppColors.olive,
          textColor: AppColors.white,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          title: 'CTA Button Shadow (Amber)',
          borderRadius: AppRadius.button,
          shadow: AppShadows.cta,
          color: AppColors.amber,
          textColor: AppColors.olive,
        ),
      ],
    );
  }

  Widget _buildBoxItem({
    required String title,
    required BorderRadius borderRadius,
    required List<BoxShadow> shadow,
    Color color = AppColors.white,
    Color textColor = AppColors.textBody,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: shadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppText.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
