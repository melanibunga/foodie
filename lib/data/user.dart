import '../models/models.dart';

/// Data seed awal pengguna default sesuai PRD §9
const User seedUser = User(
  id: 'user-default-1',
  name: 'Najmah Cleosaa Tokek',
  email: 'benjolmwahh@gmail.com',
  avatar: null,
  cooked: 12,
  settings: UserSettings(mealReminder: true, darkMode: false),
);
