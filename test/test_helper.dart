import 'dart:io';
export 'dart:convert';

import 'package:foodie/data/seed_helper.dart';
import 'package:foodie/providers/storage_provider.dart';
import 'package:hive/hive.dart';

/// Inisialisasi Hive box di direktori temporary untuk keperluan pengujian
Future<FoodieBoxes> initTestBoxes([String prefix = 'foodie_test_']) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  Hive.init(tempDir.path);
  final boxes = await FoodieBoxes.open();
  await seedDemoAccountIfNeeded(boxes);
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
