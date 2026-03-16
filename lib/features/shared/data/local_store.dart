import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_models.dart';

class LocalStore {
  static const _storageKey = 'madrasah_data_v2';
  static const _legacyStorageKey = 'madrasah_students_v1';

  Future<AppData> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppData.fromJson(decoded);
    }

    final legacyRaw = prefs.getString(_legacyStorageKey);
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      final decoded = jsonDecode(legacyRaw) as List<dynamic>;
      return AppData.fromLegacyStudents(decoded);
    }

    return AppData.empty();
  }

  Future<void> saveData(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data.toJson()));
  }
}
