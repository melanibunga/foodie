import 'package:flutter/services.dart';

/// Formatter angka dengan pemisah ribuan otomatis (titik) saat mengetik.
/// Hanya menerima digit angka, maksimal 9 digit (hingga 999.999.999).
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const int maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Ambil semua digit
    var digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Hitung berapa banyak digit sebelum kursor pada newValue
    final textBeforeCursor =
        newValue.selection.baseOffset >= 0 &&
            newValue.selection.baseOffset <= newValue.text.length
        ? newValue.text.substring(0, newValue.selection.baseOffset)
        : newValue.text;
    var digitsBeforeCursor = textBeforeCursor
        .replaceAll(RegExp(r'\D'), '')
        .length;

    // Jika karakter yang baru saja dihapus adalah titik pemisah ribuan
    if (oldValue.text.length == newValue.text.length + 1 &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.selection.baseOffset <= oldValue.text.length &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '.') {
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      if (oldDigits == digitsOnly && digitsBeforeCursor > 0) {
        final removeIndex = digitsBeforeCursor - 1;
        digitsOnly =
            digitsOnly.substring(0, removeIndex) +
            digitsOnly.substring(removeIndex + 1);
        digitsBeforeCursor--;
      }
    }

    // Batasi maks 9 digit
    if (digitsOnly.length > maxDigits) {
      digitsOnly = digitsOnly.substring(0, maxDigits);
    }

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Format dengan pemisah ribuan '.'
    final formatted = formatDigits(digitsOnly);

    // Hitung posisi kursor baru yang tepat berdasarkan jumlah digit sebelum kursor
    final targetDigitCount = digitsBeforeCursor.clamp(0, digitsOnly.length);
    int newCursorOffset = 0;
    int countedDigits = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (countedDigits >= targetDigitCount) {
        break;
      }
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        countedDigits++;
      }
      newCursorOffset = i + 1;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }

  /// Format deretan digit string ke format ribuan bertitik, e.g. "1234567" -> "1.234.567"
  static String formatDigits(String digitsOnly) {
    final buffer = StringBuffer();
    final len = digitsOnly.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digitsOnly[i]);
    }
    return buffer.toString();
  }
}
