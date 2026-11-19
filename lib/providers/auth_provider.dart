import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user.dart';
import '../models/models.dart';
import 'storage_provider.dart';

class AuthState {
  final bool isLoggedIn;
  final User? user;

  const AuthState({required this.isLoggedIn, this.user});

  AuthState copyWith({bool? isLoggedIn, User? user}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() {
    return {'isLoggedIn': isLoggedIn, 'user': user?.toJson()};
  }

  factory AuthState.fromJson(Map<String, dynamic> json) {
    return AuthState(
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// State Notifier untuk autentikasi mock & data session pengguna sesuai PRD §8 & §12.
class AuthNotifier extends Notifier<AuthState> {
  static const String prefKey = 'foodie:auth';

  @override
  AuthState build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString(prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return AuthState.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const AuthState(isLoggedIn: false, user: null);
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(prefKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  /// Login mock (password minimal 8 karakter lolos sesuai PRD §12 butir 8).
  /// "Ingat saya" dicentang -> simpan session di shared_preferences.
  /// Tidak dicentang -> session hanya di memori (hilang saat app ditutup).
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (password.length < 8) return false;

    final user = seedUser.email.toLowerCase() == email.trim().toLowerCase()
        ? seedUser
        : seedUser.copyWith(email: email.trim());

    state = AuthState(isLoggedIn: true, user: user);
    if (rememberMe) {
      await _saveToStorage();
    } else {
      // Hapus session tersimpan agar tidak terbaca saat restart
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove(prefKey);
      } catch (_) {}
    }
    return true;
  }

  /// Register mock
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (password.length < 8) return false;

    final newUser = User(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim(),
      cooked: 0,
    );

    state = AuthState(isLoggedIn: true, user: newUser);
    if (rememberMe) {
      await _saveToStorage();
    } else {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove(prefKey);
      } catch (_) {}
    }
    return true;
  }

  /// Logout (menghapus session saja, data resep tetap bertahan sesuai PRD §13)
  Future<void> logout() async {
    state = const AuthState(isLoggedIn: false, user: null);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove(prefKey);
    } catch (_) {}
  }

  /// Update profil (nama, avatar)
  Future<void> updateProfile({String? name, String? avatar}) async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(name: name, avatar: avatar);
    state = state.copyWith(user: updatedUser);
    await _saveToStorage();
  }

  /// Tambah counter "Dimasak" saat menyelesaikan sesi memasak (PRD §7.1)
  Future<void> incrementCooked() async {
    final currentUser = state.user ?? seedUser;
    final updatedUser = currentUser.copyWith(cooked: currentUser.cooked + 1);
    state = state.copyWith(user: updatedUser);
    await _saveToStorage();
  }

  /// Toggle pengingat makan
  Future<void> toggleMealReminder() async {
    if (state.user == null) return;
    final newSettings = state.user!.settings.copyWith(
      mealReminder: !state.user!.settings.mealReminder,
    );
    final updatedUser = state.user!.copyWith(settings: newSettings);
    state = state.copyWith(user: updatedUser);
    await _saveToStorage();
  }

  /// Toggle mode gelap
  Future<void> toggleDarkMode() async {
    if (state.user == null) return;
    final newSettings = state.user!.settings.copyWith(
      darkMode: !state.user!.settings.darkMode,
    );
    final updatedUser = state.user!.copyWith(settings: newSettings);
    state = state.copyWith(user: updatedUser);
    await _saveToStorage();
  }

  /// Reset ke seed demo
  Future<void> resetToSeed() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(prefKey);
    state = const AuthState(isLoggedIn: true, user: seedUser);
    await _saveToStorage();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
