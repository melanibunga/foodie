import 'package:flutter/material.dart';

abstract final class AppText {
  static const String fontFamily = 'Poppins';

  /// H1 auth: 32 / 38 (Weight 800)
  static const TextStyle h1Auth = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32.0,
    height: 38.0 / 32.0,
    fontWeight: FontWeight.w800,
  );

  /// Judul halaman (Menu Favoritmu, My Groceries, Profil Saya): 26 / 34 (Weight 700)
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26.0,
    height: 34.0 / 26.0,
    fontWeight: FontWeight.w700,
  );

  /// Judul halaman besar (opsional 28/34)
  static const TextStyle pageTitleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28.0,
    height: 34.0 / 28.0,
    fontWeight: FontWeight.w700,
  );

  /// Judul section (Daily Inspiration, Popular, Pengaturan): 20 / 28 (Weight 700)
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20.0,
    height: 28.0 / 20.0,
    fontWeight: FontWeight.w700,
  );

  /// Judul sub-section / recipe detail title: 18 / 24 (Weight 700)
  static const TextStyle subSectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18.0,
    height: 24.0 / 18.0,
    fontWeight: FontWeight.w700,
  );

  /// Judul kartu hero: 16 / 22 (Weight 600)
  static const TextStyle cardHeroTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 22.0 / 16.0,
    fontWeight: FontWeight.w600,
  );

  /// Judul kartu kecil (Popular, Grid, Search): 14 / 20 (Weight 600)
  static const TextStyle cardSmallTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    fontWeight: FontWeight.w600,
  );

  /// Body teks reguler: 13 / 20 (Weight 400)
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    height: 20.0 / 13.0,
    fontWeight: FontWeight.w400,
  );

  /// Body medium: 13 / 20 (Weight 500)
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    height: 20.0 / 13.0,
    fontWeight: FontWeight.w500,
  );

  /// Label form: 12 / 18 (Weight 600)
  static const TextStyle formLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 18.0 / 12.0,
    fontWeight: FontWeight.w600,
  );

  /// Caption / meta: 11 / 16 (Weight 400)
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.0,
    height: 16.0 / 11.0,
    fontWeight: FontWeight.w400,
  );

  /// Caption kecil: 10 / 14 (Weight 400)
  static const TextStyle captionSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.0,
    height: 14.0 / 10.0,
    fontWeight: FontWeight.w400,
  );

  /// Tombol besar (lg): 14–15 (Weight 700)
  static const TextStyle buttonLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Tombol sedang (md): 12–13 (Weight 600)
  static const TextStyle buttonMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// Label bottom nav: 10–11 (Weight 600)
  static const TextStyle bottomNav = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.0,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// Tagline / Mini badge: 9–10 (Weight 700 uppercase)
  static const TextStyle tag = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9.0,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}
