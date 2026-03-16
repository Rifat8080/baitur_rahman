import '../../../shared/domain/app_models.dart';

class HomeMutationResult {
  const HomeMutationResult({required this.data, required this.message});

  final AppData data;
  final String message;
}

class HomeMutationUseCases {
  const HomeMutationUseCases();

  HomeMutationResult deleteUserCascade({
    required AppData data,
    required String userId,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        users: data.users.where((user) => user.id != userId).toList(),
        fees: data.fees.where((item) => item.studentId != userId).toList(),
        attendance: data.attendance
            .where((item) => item.userId != userId)
            .toList(),
        salaries: data.salaries
            .where((item) => item.teacherId != userId)
            .toList(),
        results: data.results
            .where((item) => item.studentId != userId)
            .toList(),
      ),
      message: 'User deleted successfully.',
    );
  }

  HomeMutationResult addFee({
    required AppData data,
    required String id,
    required String studentId,
    required double amount,
    required String note,
    required DateTime createdAt,
    String month = '',
    FinanceStatus status = FinanceStatus.paid,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        fees: [
          FeeRecord(
            id: id,
            studentId: studentId,
            amount: amount,
            note: note,
            createdAt: createdAt,
            month: month,
            status: status,
          ),
          ...data.fees,
        ],
      ),
      message: 'Fee saved successfully.',
    );
  }

  HomeMutationResult addExpense({
    required AppData data,
    required String id,
    required String title,
    required double amount,
    required DateTime createdAt,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        expenses: [
          ExpenseRecord(
            id: id,
            title: title,
            amount: amount,
            createdAt: createdAt,
          ),
          ...data.expenses,
        ],
      ),
      message: 'Expense saved successfully.',
    );
  }

  HomeMutationResult addSalary({
    required AppData data,
    required String id,
    required String teacherId,
    required double amount,
    required String month,
    required DateTime createdAt,
    FinanceStatus status = FinanceStatus.paid,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        salaries: [
          SalaryRecord(
            id: id,
            teacherId: teacherId,
            amount: amount,
            month: month,
            createdAt: createdAt,
            status: status,
          ),
          ...data.salaries,
        ],
      ),
      message: 'Salary saved successfully.',
    );
  }

  HomeMutationResult addFund({
    required AppData data,
    required String id,
    required String title,
    required double amount,
    required DateTime createdAt,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        funds: [
          FundRecord(
            id: id,
            title: title,
            amount: amount,
            createdAt: createdAt,
          ),
          ...data.funds,
        ],
      ),
      message: 'Fund saved successfully.',
    );
  }

  HomeMutationResult addAttendance({
    required AppData data,
    required String id,
    required String userId,
    required bool present,
    required DateTime date,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        attendance: [
          AttendanceRecord(
            id: id,
            userId: userId,
            present: present,
            date: date,
          ),
          ...data.attendance,
        ],
      ),
      message: 'Attendance saved successfully.',
    );
  }

  HomeMutationResult publishResult({
    required AppData data,
    required String id,
    required String studentId,
    required String exam,
    required double marks,
    required double totalMarks,
    required DateTime publishedAt,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        results: [
          ResultRecord(
            id: id,
            studentId: studentId,
            exam: exam,
            marks: marks,
            totalMarks: totalMarks,
            publishedAt: publishedAt,
          ),
          ...data.results,
        ],
      ),
      message: 'Result published successfully.',
    );
  }

  HomeMutationResult deleteAttendance({
    required AppData data,
    required String attendanceId,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        attendance: data.attendance
            .where((entry) => entry.id != attendanceId)
            .toList(),
      ),
      message: 'Attendance entry deleted.',
    );
  }

  HomeMutationResult deleteResult({
    required AppData data,
    required String resultId,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        results: data.results.where((item) => item.id != resultId).toList(),
      ),
      message: 'Result deleted.',
    );
  }

  HomeMutationResult deleteFee({required AppData data, required String feeId}) {
    return HomeMutationResult(
      data: data.copyWith(
        fees: data.fees.where((item) => item.id != feeId).toList(),
      ),
      message: 'Fee record deleted.',
    );
  }

  HomeMutationResult deleteExpense({
    required AppData data,
    required String expenseId,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        expenses: data.expenses.where((item) => item.id != expenseId).toList(),
      ),
      message: 'Expense deleted.',
    );
  }

  HomeMutationResult deleteSalary({
    required AppData data,
    required String salaryId,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        salaries: data.salaries.where((item) => item.id != salaryId).toList(),
      ),
      message: 'Salary record deleted.',
    );
  }

  HomeMutationResult deleteFund({
    required AppData data,
    required String fundId,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        funds: data.funds.where((item) => item.id != fundId).toList(),
      ),
      message: 'Fund deleted.',
    );
  }

  // ─── Update records ──────────────────────────────────────────────────────

  HomeMutationResult updateFee({
    required AppData data,
    required FeeRecord fee,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        fees: data.fees.map((f) => f.id == fee.id ? fee : f).toList(),
      ),
      message: 'Fee updated.',
    );
  }

  HomeMutationResult updateExpense({
    required AppData data,
    required ExpenseRecord expense,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        expenses: data.expenses
            .map((e) => e.id == expense.id ? expense : e)
            .toList(),
      ),
      message: 'Expense updated.',
    );
  }

  HomeMutationResult updateSalary({
    required AppData data,
    required SalaryRecord salary,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        salaries: data.salaries
            .map((s) => s.id == salary.id ? salary : s)
            .toList(),
      ),
      message: 'Salary updated.',
    );
  }

  HomeMutationResult updateFund({
    required AppData data,
    required FundRecord fund,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        funds: data.funds.map((f) => f.id == fund.id ? fund : f).toList(),
      ),
      message: 'Fund updated.',
    );
  }

  // ─── Status toggles ──────────────────────────────────────────────────────

  HomeMutationResult updateFeeStatus({
    required AppData data,
    required String feeId,
    required FinanceStatus status,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        fees: data.fees.map((f) {
          if (f.id != feeId) return f;
          return FeeRecord(
            id: f.id,
            studentId: f.studentId,
            amount: f.amount,
            note: f.note,
            createdAt: f.createdAt,
            month: f.month,
            status: status,
          );
        }).toList(),
      ),
      message: status.isPaid ? 'Marked as paid.' : 'Marked as pending.',
    );
  }

  HomeMutationResult updateSalaryStatus({
    required AppData data,
    required String salaryId,
    required FinanceStatus status,
  }) {
    return HomeMutationResult(
      data: data.copyWith(
        salaries: data.salaries.map((s) {
          if (s.id != salaryId) return s;
          return SalaryRecord(
            id: s.id,
            teacherId: s.teacherId,
            amount: s.amount,
            month: s.month,
            createdAt: s.createdAt,
            status: status,
          );
        }).toList(),
      ),
      message: status.isPaid
          ? 'Salary marked as paid.'
          : 'Salary marked as pending.',
    );
  }

  // ─── Bulk generate monthly records ───────────────────────────────────────

  HomeMutationResult bulkAddFees({
    required AppData data,
    required List<FeeRecord> fees,
    required String month,
  }) {
    return HomeMutationResult(
      data: data.copyWith(fees: [...fees, ...data.fees]),
      message: '${fees.length} pending fee record(s) generated for $month.',
    );
  }

  HomeMutationResult bulkAddSalaries({
    required AppData data,
    required List<SalaryRecord> salaries,
    required String month,
  }) {
    return HomeMutationResult(
      data: data.copyWith(salaries: [...salaries, ...data.salaries]),
      message:
          '${salaries.length} pending salary record(s) generated for $month.',
    );
  }
}
