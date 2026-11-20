import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Helper utilitas untuk pembuatan salt dan hashing kata sandi dengan SHA-256
class AuthUtils {
  /// Menghasilkan string acak hexadecimal untuk salt per user
  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Menghitung SHA-256 dari salt + password
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(salt + password);
    return sha256.convert(bytes).toString();
  }
}
