import 'package:flutter/material.dart';

/// Design tokens untuk border radius 
abstract final class AppRadius {
  // Nilai numerik
  static const double kCard = 16.0;
  static const double kCardLarge = 20.0;
  static const double kDetailCard = 32.0;
  static const double kInput = 12.0;
  static const double kButton = 14.0;
  static const double kButtonSmall = 10.0;
  static const double kSheet = 24.0;
  static const double kCheckbox = 6.0;
  static const double kPill = 999.0;
  static const double kBottomNav = 999.0;

  // BorderRadius helpers
  static const BorderRadius card = BorderRadius.all(Radius.circular(kCard));
  static const BorderRadius cardLarge = BorderRadius.all(
    Radius.circular(kCardLarge),
  );
  static const BorderRadius detailCard = BorderRadius.all(
    Radius.circular(kDetailCard),
  );
  static const BorderRadius input = BorderRadius.all(Radius.circular(kInput));
  static const BorderRadius button = BorderRadius.all(Radius.circular(kButton));
  static const BorderRadius buttonSmall = BorderRadius.all(
    Radius.circular(kButtonSmall),
  );
  static const BorderRadius checkbox = BorderRadius.all(
    Radius.circular(kCheckbox),
  );
  static const BorderRadius pill = BorderRadius.all(Radius.circular(kPill));
  static const BorderRadius bottomNav = BorderRadius.all(
    Radius.circular(kBottomNav),
  );

  /// Sheet atas (hanya top left & top right)
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(kSheet),
    topRight: Radius.circular(kSheet),
  );

  /// Radius kartu hanya atas (untuk foto hero kartu resep)
  static const BorderRadius cardTop = BorderRadius.only(
    topLeft: Radius.circular(kCard),
    topRight: Radius.circular(kCard),
  );
  static const BorderRadius cardLargeTop = BorderRadius.only(
    topLeft: Radius.circular(kCardLarge),
    topRight: Radius.circular(kCardLarge),
  );
}
