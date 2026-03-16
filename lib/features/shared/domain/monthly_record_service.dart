import 'package:uuid/uuid.dart';

import '../../../core/database/app_repository.dart';
import 'app_models.dart';

/// Auto-generates pending [FeeRecord]s for students and pending
/// [SalaryRecord]s for staff every calendar month.
///
/// Call [generateCurrentMonth] once on app start-up (and optionally after
/// saving a user) to ensure every user with a configured monthly amount has a
/// record for the current month.
class MonthlyRecordService {
  MonthlyRecordService._();

  static const _uuid = Uuid();

  /// Returns the canonical month string for the given [date]: 'YYYY-MM'.
  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// Generates (as *pending*) the current month's fee/salary records for every
  /// user whose [AppUser.monthlyFee] / [AppUser.monthlySalary] is > 0,
  /// provided the record does not already exist.
  static Future<void> generateCurrentMonth() async {
    final repo = AppRepository.instance;
    final data = await repo.loadAll();
    final now = DateTime.now();
    final month = monthKey(now);

    // ----- FEE records for students ----------------------------------------
    final existingFeeKeys = <String>{};
    for (final fee in data.fees) {
      if (fee.month == month) {
        existingFeeKeys.add(fee.studentId);
      }
    }

    for (final user in data.users) {
      if (user.role != AppRole.student) continue;
      if (user.monthlyFee <= 0) continue;
      if (existingFeeKeys.contains(user.id)) continue;

      await repo.insertFee(
        FeeRecord(
          id: _uuid.v4(),
          studentId: user.id,
          amount: user.monthlyFee,
          note: 'Auto-generated monthly fee',
          createdAt: DateTime(now.year, now.month, 1),
          month: month,
          status: FinanceStatus.pending,
        ),
      );
    }

    // ----- SALARY records for staff ----------------------------------------
    final existingSalaryKeys = <String>{};
    for (final salary in data.salaries) {
      if (salary.month == month) {
        existingSalaryKeys.add(salary.teacherId);
      }
    }

    final staffRoles = {
      AppRole.teacher,
      AppRole.accountant,
      AppRole.manager,
      AppRole.admin,
    };

    for (final user in data.users) {
      if (!staffRoles.contains(user.role)) continue;
      if (user.monthlySalary <= 0) continue;
      if (existingSalaryKeys.contains(user.id)) continue;

      await repo.insertSalary(
        SalaryRecord(
          id: _uuid.v4(),
          teacherId: user.id,
          amount: user.monthlySalary,
          month: month,
          createdAt: DateTime(now.year, now.month, 1),
          status: FinanceStatus.pending,
        ),
      );
    }
  }

  /// Generates the current month's record for a *single* user immediately
  /// after they are saved.  Safe to call even if the record already exists.
  static Future<void> generateForUser(String userId) async {
    final repo = AppRepository.instance;
    final data = await repo.loadAll();
    final now = DateTime.now();
    final month = monthKey(now);

    AppUser? user;
    for (final u in data.users) {
      if (u.id == userId) {
        user = u;
        break;
      }
    }
    if (user == null) return;

    if (user.role == AppRole.student && user.monthlyFee > 0) {
      final alreadyExists = data.fees.any(
        (f) => f.studentId == userId && f.month == month,
      );
      if (!alreadyExists) {
        await repo.insertFee(
          FeeRecord(
            id: _uuid.v4(),
            studentId: userId,
            amount: user.monthlyFee,
            note: 'Auto-generated monthly fee',
            createdAt: DateTime(now.year, now.month, 1),
            month: month,
            status: FinanceStatus.pending,
          ),
        );
      }
    }

    final staffRoles = {
      AppRole.teacher,
      AppRole.accountant,
      AppRole.manager,
      AppRole.admin,
    };

    if (staffRoles.contains(user.role) && user.monthlySalary > 0) {
      final alreadyExists = data.salaries.any(
        (s) => s.teacherId == userId && s.month == month,
      );
      if (!alreadyExists) {
        await repo.insertSalary(
          SalaryRecord(
            id: _uuid.v4(),
            teacherId: userId,
            amount: user.monthlySalary,
            month: month,
            createdAt: DateTime(now.year, now.month, 1),
            status: FinanceStatus.pending,
          ),
        );
      }
    }
  }
}
