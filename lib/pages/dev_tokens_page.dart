import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';

/// Halaman inspeksi design tokens untuk verifikasi kesetiaan desain (STYLE GUIDE.jpg).
/// Hanya aktif dalam mode debug (kDebugMode).
class DevTokensPage extends StatelessWidget {
  const DevTokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Design Tokens (STYLE GUIDE)',
          style: AppText.pageTitle.copyWith(color: palette.textStrong),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader(
            context,
            '1. Color Swatches (PRD §4 & AppPalette)',
          ),
          const SizedBox(height: 12),
          _buildColorGrid(context),
          const SizedBox(height: 28),
          _buildSectionHeader(context, '2. Typography (Poppins)'),
          const SizedBox(height: 12),
          _buildTypographySection(context),
          const SizedBox(height: 28),
          _buildSectionHeader(context, '3. Radius & Shadows'),
          const SizedBox(height: 12),
          _buildRadiusAndShadowSection(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: palette.actionBg,
        borderRadius: AppRadius.buttonSmall,
      ),
      child: Text(
        title,
        style: AppText.cardHeroTitle.copyWith(color: palette.onAction),
      ),
    );
  }

  Widget _buildColorGrid(BuildContext context) {
    final palette = context.palette;
    String hex(Color c) =>
        '#${(c.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    final colors = <({String name, String hex, Color color, Color text})>[
      (
        name: 'bg',
        hex: hex(palette.bg),
        color: palette.bg,
        text: palette.textStrong,
      ),
      (
        name: 'surface',
        hex: hex(palette.surface),
        color: palette.surface,
        text: palette.textStrong,
      ),
      (
        name: 'surfaceAlt',
        hex: hex(palette.surfaceAlt),
        color: palette.surfaceAlt,
        text: palette.textStrong,
      ),
      (
        name: 'navSurface',
        hex: hex(palette.navSurface),
        color: palette.navSurface,
        text: palette.textStrong,
      ),
      (
        name: 'actionBg',
        hex: hex(palette.actionBg),
        color: palette.actionBg,
        text: palette.onAction,
      ),
      (
        name: 'accent',
        hex: hex(palette.accent),
        color: palette.accent,
        text: palette.onAccent,
      ),
      (
        name: 'danger',
        hex: hex(palette.danger),
        color: palette.danger,
        text: palette.onDanger,
      ),
      (
        name: 'textStrong',
        hex: hex(palette.textStrong),
        color: palette.textStrong,
        text: palette.bg,
      ),
      (
        name: 'textSecondary',
        hex: hex(palette.textSecondary),
        color: palette.textSecondary,
        text: palette.bg,
      ),
      (
        name: 'border',
        hex: hex(palette.border),
        color: palette.border,
        text: palette.textStrong,
      ),
      (
        name: 'field',
        hex: hex(palette.field),
        color: palette.field,
        text: palette.textStrong,
      ),
      (
        name: 'accentSoft',
        hex: hex(palette.accentSoft),
        color: palette.accentSoft,
        text: palette.onAccentSoft,
      ),
      (
        name: 'dangerSoft',
        hex: hex(palette.dangerSoft),
        color: palette.dangerSoft,
        text: palette.danger,
      ),
      (
        name: 'chip',
        hex: hex(palette.chip),
        color: palette.chip,
        text: palette.textStrong,
      ),
      (
        name: 'photo',
        hex: hex(palette.photo),
        color: palette.photo,
        text: palette.textStrong,
      ),
      (
        name: 'photoIcon',
        hex: hex(palette.photoIcon),
        color: palette.photoIcon,
        text: palette.textStrong,
      ),
      (
        name: 'mapBg',
        hex: hex(palette.mapBg),
        color: palette.mapBg,
        text: palette.textStrong,
      ),
      (
        name: 'mapBlock',
        hex: hex(palette.mapBlock),
        color: palette.mapBlock,
        text: palette.textStrong,
      ),
      (
        name: 'toggleOff',
        hex: hex(palette.toggleOff),
        color: palette.toggleOff,
        text: palette.textStrong,
      ),
      (
        name: 'summaryBg',
        hex: hex(palette.summaryBg),
        color: palette.summaryBg,
        text: palette.textStrong,
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
            border: Border.all(color: palette.border),
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

  Widget _buildTypographySection(BuildContext context) {
    final palette = context.palette;
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
        style: AppText.bottomNav.copyWith(color: palette.textStrong),
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
            color: palette.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                style: AppText.caption.copyWith(
                  color: palette.danger,
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

  Widget _buildRadiusAndShadowSection(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        _buildBoxItem(
          context: context,
          title: 'Card Radius (16) + Card Shadow',
          borderRadius: AppRadius.card,
          shadow: AppShadows.card,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          context: context,
          title: 'Card Large Radius (20)',
          borderRadius: AppRadius.cardLarge,
          shadow: AppShadows.card,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          context: context,
          title: 'Detail Card Radius (32)',
          borderRadius: AppRadius.detailCard,
          shadow: AppShadows.card,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          context: context,
          title: 'Pill Radius (999) + Nav Shadow',
          borderRadius: AppRadius.pill,
          shadow: AppShadows.bottomNav,
          color: palette.actionBg,
          textColor: palette.onAction,
        ),
        const SizedBox(height: 12),
        _buildBoxItem(
          context: context,
          title: 'CTA Button Shadow (Amber)',
          borderRadius: AppRadius.button,
          shadow: AppShadows.cta,
          color: palette.accent,
          textColor: palette.onAccent,
        ),
      ],
    );
  }

  Widget _buildBoxItem({
    required BuildContext context,
    required String title,
    required BorderRadius borderRadius,
    required List<BoxShadow> shadow,
    Color? color,
    Color? textColor,
  }) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: borderRadius,
        boxShadow: shadow,
        border: Border.all(color: palette.border),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppText.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor ?? palette.textBody,
        ),
      ),
    );
  }
}
