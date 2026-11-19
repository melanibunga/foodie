/// Model pengaturan pengguna sesuai PRD §9
class UserSettings {
  final bool mealReminder;
  final bool darkMode;

  const UserSettings({this.mealReminder = true, this.darkMode = false});

  UserSettings copyWith({bool? mealReminder, bool? darkMode}) {
    return UserSettings(
      mealReminder: mealReminder ?? this.mealReminder,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {'mealReminder': mealReminder, 'darkMode': darkMode};
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      mealReminder: json['mealReminder'] as bool? ?? true,
      darkMode: json['darkMode'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          mealReminder == other.mealReminder &&
          darkMode == other.darkMode;

  @override
  int get hashCode => Object.hash(mealReminder, darkMode);
}

/// Model pengguna (User) sesuai PRD §9
class User {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final int cooked;
  final UserSettings settings;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.cooked = 0,
    this.settings = const UserSettings(),
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    int? cooked,
    UserSettings? settings,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      cooked: cooked ?? this.cooked,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'cooked': cooked,
      'settings': settings.toJson(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      cooked: (json['cooked'] as num?)?.toInt() ?? 0,
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const UserSettings(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          avatar == other.avatar &&
          cooked == other.cooked &&
          settings == other.settings;

  @override
  int get hashCode => Object.hash(id, name, email, avatar, cooked, settings);
}
