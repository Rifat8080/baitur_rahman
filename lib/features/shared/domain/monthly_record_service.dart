import 'package:uuid/uuid.dart';

import '../../../core/database/app_repository.dart';
import 'app_models.dart';

/// Auto-generates pending [FeeRecord]s for students and pending
/// [SalaryRecord]s for staff after each completed month from the user's
/// joining date.
///
/// Example: if a user joins on 2026-03-16, the first auto-generated record is
/// due on 2026-04-16, then 2026-05-16, 2026-06-16, and so on.
class MonthlyRecordService {
  MonthlyRecordService._();

  static const _uuid = Uuid();

  /// Returns the canonical month string for the given [date]: 'YYYY-MM'.
  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _daysInMonth(int year, int month) {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  static DateTime _addMonths(DateTime value, int months) {
    final totalMonths = value.month - 1 + months;
    final year = value.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12) + 1;
    final day = value.day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static List<DateTime> _dueDatesUntil(DateTime joiningDate, DateTime now) {
    final dueDates = <DateTime>[];
    final start = _dateOnly(joiningDate);
    final end = _dateOnly(now);

    var index = 1;
    while (true) {
      final due = _addMonths(start, index);
      if (due.isAfter(end)) {
        break;
      }
      dueDates.add(due);
      index++;
    }

    return dueDates;
  }

  static bool _isStaff(AppRole role) {
    return role == AppRole.teacher ||
        role == AppRole.accountant ||
        role == AppRole.manager ||
        role == AppRole.admin;
  }

  static Future<void> _generateFeesForUser({
    required AppRepository repo,
    required AppUser user,
    required List<FeeRecord> existingFees,
    required DateTime now,
  }) async {
    if (user.role != AppRole.student || user.monthlyFee <= 0) {
      return;
    }

    final existingMonths = <String>{};
    for (final fee in existingFees) {
      if (fee.studentId == user.id) {
        existingMonths.add(fee.month);
      }
    }

    for (final dueDate in _dueDatesUntil(user.createdAt, now)) {
      final month = monthKey(dueDate);
      if (existingMonths.contains(month)) {
        continue;
      }
      await repo.insertFee(
        FeeRecord(
          id: _uuid.v4(),
          studentId: user.id,
          amount: user.monthlyFee,
          note: 'Auto-generated monthly fee',
          createdAt: dueDate,
          month: month,
          status: FinanceStatus.pending,
        ),
      );
      existingMonths.add(month);
    }
  }

  static Future<void> _generateSalariesForUser({
    required AppRepository repo,
    required AppUser user,
    required List<SalaryRecord> existingSalaries,
    required DateTime now,
  }) async {
    if (!_isStaff(user.role) || user.monthlySalary <= 0) {
      return;
    }

    final existingMonths = <String>{};
    for (final salary in existingSalaries) {
      if (salary.teacherId == user.id) {
        existingMonths.add(salary.month);
      }
    }

    for (final dueDate in _dueDatesUntil(user.createdAt, now)) {
      final month = monthKey(dueDate);
      if (existingMonths.contains(month)) {
        continue;
      }
      await repo.insertSalary(
        SalaryRecord(
          id: _uuid.v4(),
          teacherId: user.id,
          amount: user.monthlySalary,
          month: month,
          createdAt: dueDate,
          status: FinanceStatus.pending,
        ),
      );
      existingMonths.add(month);
    }
  }

  /// Generates all due fee/salary records that should exist after completed
  /// monthly intervals from the joining date.
  static Future<void> generateCurrentMonth() async {
    final repo = AppRepository.instance;
    final data = await repo.loadAll();
    final now = DateTime.now();

    for (final user in data.users) {
      await _generateFeesForUser(
        repo: repo,
        user: user,
        existingFees: data.fees,
        now: now,
      );
      await _generateSalariesForUser(
        repo: repo,
        user: user,
        existingSalaries: data.salaries,
        now: now,
      );
    }
  }

  /// Generates all due records for a single user. Safe to call after save.
  static Future<void> generateForUser(String userId) async {
    final repo = AppRepository.instance;
    final data = await repo.loadAll();
    final now = DateTime.now();

    AppUser? user;
    for (final u in data.users) {
      if (u.id == userId) {
        user = u;
        break;
      }
    }
    if (user == null) return;

    await _generateFeesForUser(
      repo: repo,
      user: user,
      existingFees: data.fees,
      now: now,
    );
    await _generateSalariesForUser(
      repo: repo,
      user: user,
      existingSalaries: data.salaries,
      now: now,
    );
  }
}
