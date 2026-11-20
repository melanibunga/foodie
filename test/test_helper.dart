export 'dart:convert';

import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:hive/hive.dart';

class _TestFakeBox<T> implements Box<T> {
  final Map<dynamic, T> _storage = {};

  @override
  T? get(dynamic key, {T? defaultValue}) =>
      _storage.containsKey(key) ? _storage[key] : defaultValue;

  @override
  Future<void> put(dynamic key, T value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _storage.remove(key);
  }

  @override
  bool containsKey(dynamic key) => _storage.containsKey(key);

  @override
  Iterable<dynamic> get keys => _storage.keys;

  @override
  Iterable<T> get values => _storage.values;

  @override
  Map<dynamic, T> toMap() => Map.unmodifiable(_storage);

  @override
  int get length => _storage.length;

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  Future<int> clear() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Inisialisasi isolated in-memory Hive boxes untuk keperluan pengujian
Future<FoodieBoxes> initTestBoxes([String prefix = 'foodie_test_']) async {
  final boxes = FoodieBoxes(
    users: _TestFakeBox(),
    session: _TestFakeBox(),
    favorites: _TestFakeBox(),
    cart: _TestFakeBox(),
    mealPlan: _TestFakeBox(),
    myRecipes: _TestFakeBox(),
    cooked: _TestFakeBox(),
    ratings: _TestFakeBox(),
    settings: _TestFakeBox(),
    meta: _TestFakeBox(),
    recipes: _TestFakeBox(),
    recipeCache: _TestFakeBox(),
    placesCache: _TestFakeBox(),
  );
  await seedDemoAccountIfNeeded(boxes);
  await boxes.session.put('currentUserId', kDemoUserId);
  return boxes;
}

/// Mock in-memory SharedPreferences shim untuk menjaga kompatibilitas test lama
class SharedPreferences {
  static final Map<String, dynamic> _mockValues = {};

  static void setMockInitialValues(Map<String, Object> values) {
    _mockValues.clear();
    _mockValues.addAll(values);
  }

  static Future<SharedPreferences> getInstance() async => SharedPreferences();

  Future<bool> setString(String key, String value) async {
    _mockValues[key] = value;
    return true;
  }

  String? getString(String key) => _mockValues[key]?.toString();

  Future<bool> remove(String key) async {
    _mockValues.remove(key);
    return true;
  }

  Future<bool> clear() async {
    _mockValues.clear();
    return true;
  }

  Set<String> getKeys() => _mockValues.keys.toSet();
}
