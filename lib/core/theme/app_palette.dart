import 'package:flutter/material.dart';

/// Palet Semantik Foodie.id berbasis ThemeExtension (PRD §4, §16, Fase E1).
/// Mendukung Light Mode (identik desain asli) dan Dark Mode (sesuai referensi).
/// Diakses di seluruh UI lewat `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;

  // Latar belakang & permukaan
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color navSurface;
  final Color outerBg;
  final Color splashBg;

  // Teks & tipografi
  final Color textStrong;
  final Color textBody;
  final Color textSecondary;

  // Garis tepi & pemisah
  final Color border;
  final Color divider;

  // Tombol aksi utama (Masuk, Start Cooking, Kosongkan semua, DONE)
  final Color actionBg;
  final Color onAction;

  // Aksen (Amber) & Aksen Lembut (Tag, tombol plus Meal Plan, kartu pin Belanjaan)
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color accentSoftTextAlt;

  // Danger (Merah: Lihat Resep, Hapus menu, Logout, trash, toggle aktif)
  final Color danger;
  final Color onDanger;
  final Color dangerText;
  final Color dangerSoft;
  final Color onDangerSoft;

  // Chip & Filter
  final Color chip;
  final Color chipSelected;
  final Color onChipSelected;

  // Input Field
  final Color field;
  final Color fieldBorder;
  final Color fieldAdd;

  // Toggle switch
  final Color toggleOff;
  final Color toggleKnob;

  // Kartu ringkasan / summary
  final Color summaryBg;

  // Placeholder Foto & Ikon
  final Color photo;
  final Color photoIcon;

  // Peta ilustrasi Explore
  final Color mapBg;
  final Color mapBlock;
  final Color mapRoad;

  // Overlay & Bayangan
  final Color overlayScrim;
  final Color onOverlay;
  final Color heartButtonBg;
  final Color shadowColor;
  final Color dialogBarrier;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.navSurface,
    required this.outerBg,
    required this.splashBg,
    required this.textStrong,
    required this.textBody,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.actionBg,
    required this.onAction,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.accentSoftTextAlt,
    required this.danger,
    required this.onDanger,
    required this.dangerText,
    required this.dangerSoft,
    required this.onDangerSoft,
    required this.chip,
    required this.chipSelected,
    required this.onChipSelected,
    required this.field,
    required this.fieldBorder,
    required this.fieldAdd,
    required this.toggleOff,
    required this.toggleKnob,
    required this.summaryBg,
    required this.photo,
    required this.photoIcon,
    required this.mapBg,
    required this.mapBlock,
    required this.mapRoad,
    required this.overlayScrim,
    required this.onOverlay,
    required this.heartButtonBg,
    required this.shadowColor,
    required this.dialogBarrier,
  });

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8E8E2),
    navSurface: Color(0xFF263C32),
    outerBg: Color(0xFFE9E9E2),
    splashBg: Color(0xFF082B21),
    textStrong: Color(0xFF263C32),
    textBody: Color(0xFF1E1E1E),
    textSecondary: Color(0xFF717665),
    border: Color(0xFFE3E3DC),
    divider: Color(0xFFE3E3DC),
    actionBg: Color(0xFF263C32),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFFF59E0B),
    onAccent: Color(0xFF263C32),
    accentSoft: Color(0xFFF4E9CE),
    onAccentSoft: Color(0xFF263C32),
    accentSoftTextAlt: Color(0xBF263C32),
    danger: Color(0xFF800020),
    onDanger: Color(0xFFFFFFFF),
    dangerText: Color(0xFF800020),
    dangerSoft: Color(0xFFF4E6E9),
    onDangerSoft: Color(0xFF800020),
    chip: Color(0xFFE8E8E2),
    chipSelected: Color(0xFF263C32),
    onChipSelected: Color(0xFFFFFFFF),
    field: Color(0xFFFFFFFF),
    fieldBorder: Color(0xFFE3E3DC),
    fieldAdd: Color(0xFFD6D6D6),
    toggleOff: Color(0xFFE0E0DA),
    toggleKnob: Color(0xFFFFFFFF),
    summaryBg: Color(0xFFF4F1EA),
    photo: Color(0xFFD9D9D4),
    photoIcon: Color(0xFFBDBDB5),
    mapBg: Color(0xFFE7E9DE),
    mapBlock: Color(0xFFDEE3D8),
    mapRoad: Color(0xFFFFFFFF),
    overlayScrim: Color(0x99000000),
    onOverlay: Color(0xFFFFFFFF),
    heartButtonBg: Color(0xCCFFFFFF),
    shadowColor: Color(0x0F263C32),
    dialogBarrier: Color(0x73263C32),
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF101815),
    surface: Color(0xFF1B2822),
    surfaceAlt: Color(0xFF26362F),
    navSurface: Color(0xFF1F2F29),
    outerBg: Color(0xFF0B100D),
    splashBg: Color(0xFF082B21),
    textStrong: Color(0xFFF5F5F0),
    textBody: Color(0xFFF5F5F0),
    textSecondary: Color(0xFF9AA597),
    border: Color(0xFF2F3F37),
    divider: Color(0xFF2F3F37),
    actionBg: Color(0xFFF59E0B),
    onAction: Color(0xFF1A1200),
    accent: Color(0xFFF59E0B),
    onAccent: Color(0xFF1A1200),
    danger: Color(0xFFD6455F),
    onDanger: Color(0xFFFFFFFF),
    dangerText: Color(0xFFE8667C),
    accentSoft: Color(0xFF3E3313),
    onAccentSoft: Color(0xFFF8B84A),
    accentSoftTextAlt: Color(0xFFC8AB4A),
    dangerSoft: Color(0xFF3A1F28),
    onDangerSoft: Color(0xFFE8667C),
    chip: Color(0xFF26362F),
    chipSelected: Color(0xFFF59E0B),
    onChipSelected: Color(0xFF1A1200),
    field: Color(0xFF101815),
    fieldBorder: Color(0x999AA597),
    fieldAdd: Color(0xFF26362F),
    toggleOff: Color(0xFF3A4A42),
    toggleKnob: Color(0xFFFFFFFF),
    summaryBg: Color(0xFF1B2822),
    photo: Color(0xFF26362F),
    photoIcon: Color(0xFF3A4A42),
    mapBg: Color(0xFF101815),
    mapBlock: Color(0xFF1B2822),
    mapRoad: Color(0xFF2F3F37),
    overlayScrim: Color(0x99000000),
    onOverlay: Color(0xFFFFFFFF),
    heartButtonBg: Color(0xFF26362F),
    shadowColor: Color(0x33000000),
    dialogBarrier: Color(0x80000000),
  );

  @override
  ThemeExtension<AppPalette> copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? navSurface,
    Color? outerBg,
    Color? splashBg,
    Color? textStrong,
    Color? textBody,
    Color? textSecondary,
    Color? border,
    Color? divider,
    Color? actionBg,
    Color? onAction,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? accentSoftTextAlt,
    Color? danger,
    Color? onDanger,
    Color? dangerText,
    Color? dangerSoft,
    Color? onDangerSoft,
    Color? chip,
    Color? chipSelected,
    Color? onChipSelected,
    Color? field,
    Color? fieldBorder,
    Color? fieldAdd,
    Color? toggleOff,
    Color? toggleKnob,
    Color? summaryBg,
    Color? photo,
    Color? photoIcon,
    Color? mapBg,
    Color? mapBlock,
    Color? mapRoad,
    Color? overlayScrim,
    Color? onOverlay,
    Color? heartButtonBg,
    Color? shadowColor,
    Color? dialogBarrier,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      navSurface: navSurface ?? this.navSurface,
      outerBg: outerBg ?? this.outerBg,
      splashBg: splashBg ?? this.splashBg,
      textStrong: textStrong ?? this.textStrong,
      textBody: textBody ?? this.textBody,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      actionBg: actionBg ?? this.actionBg,
      onAction: onAction ?? this.onAction,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      accentSoftTextAlt: accentSoftTextAlt ?? this.accentSoftTextAlt,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerText: dangerText ?? this.dangerText,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      onDangerSoft: onDangerSoft ?? this.onDangerSoft,
      chip: chip ?? this.chip,
      chipSelected: chipSelected ?? this.chipSelected,
      onChipSelected: onChipSelected ?? this.onChipSelected,
      field: field ?? this.field,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      fieldAdd: fieldAdd ?? this.fieldAdd,
      toggleOff: toggleOff ?? this.toggleOff,
      toggleKnob: toggleKnob ?? this.toggleKnob,
      summaryBg: summaryBg ?? this.summaryBg,
      photo: photo ?? this.photo,
      photoIcon: photoIcon ?? this.photoIcon,
      mapBg: mapBg ?? this.mapBg,
      mapBlock: mapBlock ?? this.mapBlock,
      mapRoad: mapRoad ?? this.mapRoad,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      onOverlay: onOverlay ?? this.onOverlay,
      heartButtonBg: heartButtonBg ?? this.heartButtonBg,
      shadowColor: shadowColor ?? this.shadowColor,
      dialogBarrier: dialogBarrier ?? this.dialogBarrier,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(
    covariant ThemeExtension<AppPalette>? other,
    double t,
  ) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      navSurface: Color.lerp(navSurface, other.navSurface, t) ?? navSurface,
      outerBg: Color.lerp(outerBg, other.outerBg, t) ?? outerBg,
      splashBg: Color.lerp(splashBg, other.splashBg, t) ?? splashBg,
      textStrong: Color.lerp(textStrong, other.textStrong, t) ?? textStrong,
      textBody: Color.lerp(textBody, other.textBody, t) ?? textBody,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      border: Color.lerp(border, other.border, t) ?? border,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      actionBg: Color.lerp(actionBg, other.actionBg, t) ?? actionBg,
      onAction: Color.lerp(onAction, other.onAction, t) ?? onAction,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      onAccentSoft:
          Color.lerp(onAccentSoft, other.onAccentSoft, t) ?? onAccentSoft,
      accentSoftTextAlt:
          Color.lerp(accentSoftTextAlt, other.accentSoftTextAlt, t) ??
          accentSoftTextAlt,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      onDanger: Color.lerp(onDanger, other.onDanger, t) ?? onDanger,
      dangerText: Color.lerp(dangerText, other.dangerText, t) ?? dangerText,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t) ?? dangerSoft,
      onDangerSoft:
          Color.lerp(onDangerSoft, other.onDangerSoft, t) ?? onDangerSoft,
      chip: Color.lerp(chip, other.chip, t) ?? chip,
      chipSelected:
          Color.lerp(chipSelected, other.chipSelected, t) ?? chipSelected,
      onChipSelected:
          Color.lerp(onChipSelected, other.onChipSelected, t) ?? onChipSelected,
      field: Color.lerp(field, other.field, t) ?? field,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t) ?? fieldBorder,
      fieldAdd: Color.lerp(fieldAdd, other.fieldAdd, t) ?? fieldAdd,
      toggleOff: Color.lerp(toggleOff, other.toggleOff, t) ?? toggleOff,
      toggleKnob: Color.lerp(toggleKnob, other.toggleKnob, t) ?? toggleKnob,
      summaryBg: Color.lerp(summaryBg, other.summaryBg, t) ?? summaryBg,
      photo: Color.lerp(photo, other.photo, t) ?? photo,
      photoIcon: Color.lerp(photoIcon, other.photoIcon, t) ?? photoIcon,
      mapBg: Color.lerp(mapBg, other.mapBg, t) ?? mapBg,
      mapBlock: Color.lerp(mapBlock, other.mapBlock, t) ?? mapBlock,
      mapRoad: Color.lerp(mapRoad, other.mapRoad, t) ?? mapRoad,
      overlayScrim:
          Color.lerp(overlayScrim, other.overlayScrim, t) ?? overlayScrim,
      onOverlay: Color.lerp(onOverlay, other.onOverlay, t) ?? onOverlay,
      heartButtonBg:
          Color.lerp(heartButtonBg, other.heartButtonBg, t) ?? heartButtonBg,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t) ?? shadowColor,
      dialogBarrier:
          Color.lerp(dialogBarrier, other.dialogBarrier, t) ?? dialogBarrier,
    );
  }
}

/// Helper extension untuk mengakses palet semantik langsung dari [BuildContext]:
/// `context.palette.bg`, `context.palette.surface`, dsb.
extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light);
}
