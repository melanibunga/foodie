import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/auth_utils.dart';
import '../data/seed_helper.dart';
import '../models/models.dart';
import 'storage_provider.dart';

/// State autentikasi pengguna
class AuthState {
  final bool isLoggedIn;
  final User? user;
  final String? errorMessage;

  const AuthState({required this.isLoggedIn, this.user, this.errorMessage});

  AuthState copyWith({
    bool? isLoggedIn,
    User? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLoggedIn': isLoggedIn,
      'user': user?.toJson(),
      'errorMessage': errorMessage,
    };
  }

  factory AuthState.fromJson(Map<String, dynamic> json) {
    return AuthState(
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      user: json['user'] != null
          ? User.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// Notifier untuk autentikasi akun lokal dengan Hive dan enkripsi password SHA-256
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    try {
      final sessionBox = ref.watch(sessionBoxProvider);
      final usersBox = ref.watch(usersBoxProvider);
      final settingsBox = ref.watch(settingsBoxProvider);

      final savedUserId = sessionBox.get('currentUserId') as String?;
      if (savedUserId != null && savedUserId.isNotEmpty) {
        final rawUser = usersBox.get(savedUserId);
        if (rawUser is Map) {
          final userMap = Map<String, dynamic>.from(rawUser);
          final rawSettings = settingsBox.get(savedUserId);
          final settings = rawSettings is Map
              ? UserSettings.fromJson(Map<String, dynamic>.from(rawSettings))
              : const UserSettings();

          final user = User(
            id: savedUserId,
            name: userMap['name'] as String? ?? '',
            email: userMap['email'] as String? ?? '',
            avatar: userMap['avatar'] as String?,
            cooked: (userMap['cooked'] as num?)?.toInt() ?? 0,
            settings: settings,
          );
          return AuthState(isLoggedIn: true, user: user);
        }
      }
    } catch (_) {}

    return const AuthState(isLoggedIn: false, user: null);
  }

  /// Login akun lokal
  /// "Ingat saya" dicentang -> session disimpan di box session (permanen).
  /// Tidak dicentang -> session hanya di memori.
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final usersBox = ref.read(usersBoxProvider);
    final sessionBox = ref.read(sessionBoxProvider);
    final settingsBox = ref.read(settingsBoxProvider);

    final cleanEmail = email.trim().toLowerCase();

    Map<String, dynamic>? userMap;
    String? foundUserId;

    for (final key in usersBox.keys) {
      final raw = usersBox.get(key);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final em = (map['email'] as String? ?? '').trim().toLowerCase();
        if (em == cleanEmail) {
          userMap = map;
          foundUserId = key.toString();
          break;
        }
      }
    }

    if (userMap == null || foundUserId == null) {
      state = state.copyWith(errorMessage: 'Email atau kata sandi salah');
      return false;
    }

    final salt = userMap['salt'] as String? ?? '';
    final storedHash = userMap['passwordHash'] as String? ?? '';
    final calculatedHash = AuthUtils.hashPassword(password, salt);

    if (calculatedHash != storedHash) {
      state = state.copyWith(errorMessage: 'Email atau kata sandi salah');
      return false;
    }

    // Ambil preferensi pengaturan user
    final rawSettings = settingsBox.get(foundUserId);
    final settings = rawSettings is Map
        ? UserSettings.fromJson(Map<String, dynamic>.from(rawSettings))
        : const UserSettings();

    final user = User(
      id: foundUserId,
      name: userMap['name'] as String? ?? '',
      email: userMap['email'] as String? ?? '',
      avatar: userMap['avatar'] as String?,
      cooked: (userMap['cooked'] as num?)?.toInt() ?? 0,
      settings: settings,
    );

    if (rememberMe) {
      await sessionBox.put('currentUserId', foundUserId);
    } else {
      await sessionBox.delete('currentUserId');
    }

    state = AuthState(isLoggedIn: true, user: user, errorMessage: null);
    return true;
  }

  /// Register akun lokal baru
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final usersBox = ref.read(usersBoxProvider);
    final sessionBox = ref.read(sessionBoxProvider);
    final settingsBox = ref.read(settingsBoxProvider);
    final favoritesBox = ref.read(favoritesBoxProvider);
    final cartBox = ref.read(cartBoxProvider);
    final mealPlanBox = ref.read(mealPlanBoxProvider);
    final myRecipesBox = ref.read(myRecipesBoxProvider);
    final cookedBox = ref.read(cookedBoxProvider);

    final cleanEmail = email.trim().toLowerCase();

    // Cek apakah email sudah terdaftar
    for (final key in usersBox.keys) {
      final raw = usersBox.get(key);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final em = (map['email'] as String? ?? '').trim().toLowerCase();
        if (em == cleanEmail) {
          state = state.copyWith(errorMessage: 'Email sudah terdaftar');
          return false;
        }
      }
    }

    final salt = AuthUtils.generateSalt();
    final passwordHash = AuthUtils.hashPassword(password, salt);
    final newId = 'user-${DateTime.now().millisecondsSinceEpoch}';

    final newUser = User(
      id: newId,
      name: name.trim(),
      email: email.trim(),
      avatar: null,
      cooked: 0,
      settings: const UserSettings(mealReminder: true, darkMode: false),
    );

    final userMap = {
      ...newUser.toJson(),
      'salt': salt,
      'passwordHash': passwordHash,
    };

    await usersBox.put(newId, userMap);
    await settingsBox.put(newId, {'mealReminder': true, 'darkMode': false});

    // Inisialisasi storage personal kosong untuk user baru
    await favoritesBox.put(newId, <String>[]);
    await cartBox.put(newId, <dynamic>[]);
    await mealPlanBox.put(newId, <dynamic>[]);
    await myRecipesBox.put(newId, <dynamic>[]);
    await cookedBox.put(newId, <dynamic>[]);

    if (rememberMe) {
      await sessionBox.put('currentUserId', newId);
    } else {
      await sessionBox.delete('currentUserId');
    }

    state = AuthState(isLoggedIn: true, user: newUser, errorMessage: null);
    return true;
  }

  /// Logout (menghapus session saja, data user tetap utuh)
  Future<void> logout() async {
    final sessionBox = ref.read(sessionBoxProvider);
    await sessionBox.delete('currentUserId');
    state = const AuthState(isLoggedIn: false, user: null);
  }

  /// Update profil (nama, avatar)
  Future<void> updateProfile({String? name, String? avatar}) async {
    if (state.user == null) return;
    final uid = state.user!.id;
    final usersBox = ref.read(usersBoxProvider);

    final raw = usersBox.get(uid);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (name != null) map['name'] = name.trim();
      if (avatar != null) map['avatar'] = avatar;
      await usersBox.put(uid, map);
    }

    final updatedUser = state.user!.copyWith(
      name: name?.trim(),
      avatar: avatar,
    );
    state = state.copyWith(user: updatedUser);
  }

  /// Tambah counter "Dimasak" pengguna aktif
  Future<void> incrementCooked() async {
    if (state.user == null) return;
    final uid = state.user!.id;
    final usersBox = ref.read(usersBoxProvider);

    final raw = usersBox.get(uid);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final currentCooked = (map['cooked'] as num?)?.toInt() ?? 0;
      map['cooked'] = currentCooked + 1;
      await usersBox.put(uid, map);
    }

    final updatedUser = state.user!.copyWith(cooked: state.user!.cooked + 1);
    state = state.copyWith(user: updatedUser);
  }

  /// Toggle pengingat makan
  Future<void> toggleMealReminder() async {
    if (state.user == null) return;
    final uid = state.user!.id;
    final settingsBox = ref.read(settingsBoxProvider);

    final raw = settingsBox.get(uid);
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final current = map['mealReminder'] as bool? ?? true;
    map['mealReminder'] = !current;
    await settingsBox.put(uid, map);

    final newSettings = state.user!.settings.copyWith(mealReminder: !current);
    state = state.copyWith(user: state.user!.copyWith(settings: newSettings));
  }

  /// Toggle mode gelap
  Future<void> toggleDarkMode() async {
    if (state.user == null) return;
    final uid = state.user!.id;
    final settingsBox = ref.read(settingsBoxProvider);

    final raw = settingsBox.get(uid);
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final current = map['darkMode'] as bool? ?? false;
    map['darkMode'] = !current;
    await settingsBox.put(uid, map);

    final newSettings = state.user!.settings.copyWith(darkMode: !current);
    state = state.copyWith(user: state.user!.copyWith(settings: newSettings));
  }

  /// Sinkronisasi settings dari box settings
  Future<void> syncSettingsFromBox() async {
    if (state.user == null) return;
    final uid = state.user!.id;
    final settingsBox = ref.read(settingsBoxProvider);
    final raw = settingsBox.get(uid);
    if (raw is Map) {
      final settings = UserSettings.fromJson(Map<String, dynamic>.from(raw));
      state = state.copyWith(user: state.user!.copyWith(settings: settings));
    }
  }

  /// Reset session ke demo user
  Future<void> resetToSeed() async {
    final boxes = ref.read(foodieBoxesProvider);
    await seedDemoAccountIfNeeded(boxes);

    await boxes.session.put('currentUserId', kDemoUserId);
    final demoRaw = boxes.users.get(kDemoUserId);
    final demoMap = Map<String, dynamic>.from(demoRaw as Map);
    final demoSettingsRaw = boxes.settings.get(kDemoUserId);
    final demoSettings = demoSettingsRaw is Map
        ? UserSettings.fromJson(Map<String, dynamic>.from(demoSettingsRaw))
        : const UserSettings();

    final demoUser = User(
      id: kDemoUserId,
      name: demoMap['name'] as String,
      email: demoMap['email'] as String,
      avatar: demoMap['avatar'] as String?,
      cooked: (demoMap['cooked'] as num?)?.toInt() ?? 12,
      settings: demoSettings,
    );

    state = AuthState(isLoggedIn: true, user: demoUser, errorMessage: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Provider ID user yang sedang aktif (null jika belum login)
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.id;
});

/// Provider User yang sedang aktif (null jika belum login)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
