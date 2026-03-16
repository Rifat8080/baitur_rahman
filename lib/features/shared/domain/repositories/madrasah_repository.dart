import '../app_models.dart';

abstract class MadrasahRepository {
  Future<AppData> loadAll();
  Future<void> replaceAll(AppData data);

  Future<void> upsertUser(AppUser user);
  Future<void> deleteUser(String id);

  Future<void> insertFee(FeeRecord fee);
  Future<void> deleteFee(String id);

  Future<void> insertAttendance(AttendanceRecord record);
  Future<void> deleteAttendance(String id);

  Future<void> insertExpense(ExpenseRecord expense);
  Future<void> deleteExpense(String id);

  Future<void> insertSalary(SalaryRecord salary);
  Future<void> deleteSalary(String id);

  Future<void> insertFund(FundRecord fund);
  Future<void> deleteFund(String id);

  Future<void> insertResult(ResultRecord result);
  Future<void> deleteResult(String id);

  Future<void> deleteUserCascade(String userId);

  Future<Map<String, dynamic>> exportJson();
  Future<void> importJson(Map<String, dynamic> json);
}
