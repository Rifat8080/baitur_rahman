import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/shared/domain/app_models.dart';
import 'app_repository.dart';

/// SharedPreferences-backed JSON repository.
/// Used on **web** where SQLite is not available.
/// Maintains full backwards-compatibility with the v2 JSON schema so that
/// existing browser data is preserved transparently.
class JsonRepository implements AppRepository {
  static const _storageKey = 'madrasah_data_v2';
  static const _legacyKey = 'madrasah_students_v1';

  // ─── In-memory cache ──────────────────────────────────────────────────────

  AppData? _cache;

  Future<AppData> _load() async {
    if (_cache != null) return _cache!;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _cache = AppData.fromJson(decoded);
      return _cache!;
    }

    // Legacy v1 migration (first run after old installation).
    final legacyRaw = prefs.getString(_legacyKey);
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      final decoded = jsonDecode(legacyRaw) as List<dynamic>;
      _cache = AppData.fromLegacyStudents(decoded);
      await _persist(_cache!);
      return _cache!;
    }

    _cache = AppData.empty();
    return _cache!;
  }

  Future<void> _persist(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data.toJson()));
    _cache = data;
  }

  static Object? _canonicalizeJson(Object? value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(
        value.map((key, v) => MapEntry(key.toString(), v)),
      );
      final sortedKeys = map.keys.toList()..sort();
      return {for (final key in sortedKeys) key: _canonicalizeJson(map[key])};
    }
    if (value is List) {
      return value.map(_canonicalizeJson).toList(growable: false);
    }
    return value;
  }

  static String _hex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<String> _checksumSha256(Map<String, dynamic> data) async {
    final canonical = _canonicalizeJson(data);
    final encoded = utf8.encode(jsonEncode(canonical));
    final hash = await Sha256().hash(encoded);
    return _hex(hash.bytes);
  }

  Future<void> _validateIntegrityIfPresent(
    Map<String, dynamic> backup,
    AppData data,
  ) async {
    final rawIntegrity = backup['integrity'];
    if (rawIntegrity is! Map) {
      return;
    }

    final integrity = Map<String, dynamic>.from(rawIntegrity);

    final expectedTotal = integrity['totalRecords'];
    if (expectedTotal is int && expectedTotal != data.totalRecords) {
      throw const FormatException(
        'Backup integrity check failed: total record count mismatch.',
      );
    }

    final expectedCountsRaw = integrity['counts'];
    if (expectedCountsRaw is Map) {
      final expectedCounts = Map<String, dynamic>.from(expectedCountsRaw);
      for (final entry in data.recordCounts.entries) {
        final expectedCount = expectedCounts[entry.key];
        if (expectedCount is int && expectedCount != entry.value) {
          throw FormatException(
            'Backup integrity check failed: ${entry.key} count mismatch.',
          );
        }
      }
    }

    final expectedChecksum =
        (integrity['checksumSha256'] ?? integrity['checksum'])?.toString();
    if (expectedChecksum != null && expectedChecksum.trim().isNotEmpty) {
      final actualChecksum = await _checksumSha256(data.toJson());
      if (actualChecksum != expectedChecksum.toLowerCase()) {
        throw const FormatException(
          'Backup integrity check failed: checksum mismatch.',
        );
      }
    }
  }

  // ─── Bulk ─────────────────────────────────────────────────────────────────

  @override
  Future<AppData> loadAll() => _load();

  @override
  Future<void> replaceAll(AppData data) => _persist(data);

  // ─── Users ────────────────────────────────────────────────────────────────

  @override
  Future<void> upsertUser(AppUser user) async {
    final data = await _load();
    final idx = data.users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      data.users[idx] = user;
    } else {
      data.users.insert(0, user);
    }
    await _persist(data);
  }

  @override
  Future<void> deleteUser(String id) async {
    final data = await _load();
    data.users.removeWhere((u) => u.id == id);
    await _persist(data);
  }

  @override
  Future<void> deleteUserCascade(String userId) async {
    final data = await _load();
    data.users.removeWhere((u) => u.id == userId);
    data.fees.removeWhere((f) => f.studentId == userId);
    data.attendance.removeWhere((a) => a.userId == userId);
    data.salaries.removeWhere((s) => s.teacherId == userId);
    data.results.removeWhere((r) => r.studentId == userId);
    await _persist(data);
  }

  // ─── Fees ─────────────────────────────────────────────────────────────────

  @override
  Future<void> insertFee(FeeRecord fee) async {
    final data = await _load();
    data.fees.insert(0, fee);
    await _persist(data);
  }

  @override
  Future<void> deleteFee(String id) async {
    final data = await _load();
    data.fees.removeWhere((f) => f.id == id);
    await _persist(data);
  }

  // ─── Attendance ───────────────────────────────────────────────────────────

  @override
  Future<void> insertAttendance(AttendanceRecord record) async {
    final data = await _load();
    data.attendance.insert(0, record);
    await _persist(data);
  }

  @override
  Future<void> deleteAttendance(String id) async {
    final data = await _load();
    data.attendance.removeWhere((a) => a.id == id);
    await _persist(data);
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  @override
  Future<void> insertExpense(ExpenseRecord expense) async {
    final data = await _load();
    data.expenses.insert(0, expense);
    await _persist(data);
  }

  @override
  Future<void> deleteExpense(String id) async {
    final data = await _load();
    data.expenses.removeWhere((e) => e.id == id);
    await _persist(data);
  }

  // ─── Salaries ─────────────────────────────────────────────────────────────

  @override
  Future<void> insertSalary(SalaryRecord salary) async {
    final data = await _load();
    data.salaries.insert(0, salary);
    await _persist(data);
  }

  @override
  Future<void> deleteSalary(String id) async {
    final data = await _load();
    data.salaries.removeWhere((s) => s.id == id);
    await _persist(data);
  }

  // ─── Funds ────────────────────────────────────────────────────────────────

  @override
  Future<void> insertFund(FundRecord fund) async {
    final data = await _load();
    data.funds.insert(0, fund);
    await _persist(data);
  }

  @override
  Future<void> deleteFund(String id) async {
    final data = await _load();
    data.funds.removeWhere((f) => f.id == id);
    await _persist(data);
  }

  // ─── Results ──────────────────────────────────────────────────────────────

  @override
  Future<void> insertResult(ResultRecord result) async {
    final data = await _load();
    data.results.insert(0, result);
    await _persist(data);
  }

  @override
  Future<void> deleteResult(String id) async {
    final data = await _load();
    data.results.removeWhere((r) => r.id == id);
    await _persist(data);
  }

  // ─── Import / Export ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> exportJson() async {
    final data = (await _load()).normalizedForImport();
    final dataJson = data.toJson();
    final checksum = await _checksumSha256(dataJson);
    return {
      'app': 'madrasah_manager',
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': dataJson,
      'integrity': {
        'algorithm': 'SHA-256',
        'checksumSha256': checksum,
        'totalRecords': data.totalRecords,
        'counts': data.recordCounts,
      },
    };
  }

  @override
  Future<void> importJson(Map<String, dynamic> json) async {
    final data = AppData.fromBackup(json).normalizedForImport();
    data.validateRelationalIntegrity();
    await _validateIntegrityIfPresent(json, data);
    await _persist(data);
  }
}
