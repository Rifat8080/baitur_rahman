import 'package:flutter/foundation.dart';

import '../../features/shared/domain/app_models.dart';
import '../../features/shared/domain/repositories/madrasah_repository.dart';
import 'json_repository.dart';
import 'sqlite_repository.dart';

/// Abstract repository interface for all data persistence.
/// Implemented by [SqliteRepository] on native and [JsonRepository] on web.
abstract class AppRepository implements MadrasahRepository {
  // ─── Singleton ────────────────────────────────────────────────────────────

  static AppRepository? _instance;

  /// The globally available repository instance.
  /// Must be initialised via [AppRepository.initialize()] before use.
  static AppRepository get instance {
    assert(_instance != null, 'Call AppRepository.initialize() first.');
    return _instance!;
  }

  /// Initialises the appropriate repository implementation for the current
  /// platform and opens/migrates the underlying store.
  static Future<void> initialize() async {
    if (kIsWeb) {
      _instance = JsonRepository();
    } else {
      _instance = await SqliteRepository.open();
    }
  }

  // ─── Bulk operations (used for initial load + full import) ────────────────

  Future<AppData> loadAll();

  /// Replaces **all** data in the store with [data].
  /// Used only for import / restore operations.
  Future<void> replaceAll(AppData data);

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<void> upsertUser(AppUser user);
  Future<void> deleteUser(String id);

  // ─── Fees ─────────────────────────────────────────────────────────────────

  Future<void> insertFee(FeeRecord fee);
  Future<void> deleteFee(String id);

  // ─── Attendance ───────────────────────────────────────────────────────────

  Future<void> insertAttendance(AttendanceRecord record);
  Future<void> deleteAttendance(String id);

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<void> insertExpense(ExpenseRecord expense);
  Future<void> deleteExpense(String id);

  // ─── Salaries ─────────────────────────────────────────────────────────────

  Future<void> insertSalary(SalaryRecord salary);
  Future<void> deleteSalary(String id);

  // ─── Funds ────────────────────────────────────────────────────────────────

  Future<void> insertFund(FundRecord fund);
  Future<void> deleteFund(String id);

  // ─── Results ──────────────────────────────────────────────────────────────

  Future<void> insertResult(ResultRecord result);
  Future<void> deleteResult(String id);

  // ─── Cascade helpers ──────────────────────────────────────────────────────

  /// Deletes a user and every record that references the user id.
  Future<void> deleteUserCascade(String userId);

  // ─── Import / Export ──────────────────────────────────────────────────────

  /// Returns the full data set serialised as a JSON-compatible map ready to be
  /// encoded and written to a file.
  Future<Map<String, dynamic>> exportJson();

  /// Parses [json] (from an imported backup file) and replaces all stored data.
  Future<void> importJson(Map<String, dynamic> json);
}
