import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_repository.dart';
import '../../../../core/router/app_router.dart';
import '../domain/usecases/home_data_use_cases.dart';
import '../domain/usecases/home_mutation_use_cases.dart';
import '../../shared/domain/app_models.dart';

part 'sections/attendance_section.dart';
part 'sections/backup_section.dart';
part 'sections/dashboard_section.dart';
part 'sections/finance_section.dart';
part 'sections/reports_section.dart';
part 'sections/results_section.dart';
part 'sections/users_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.section});

  final String section;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _uuid = Uuid();
  final _homeDataUseCases = HomeDataUseCases(
    repository: AppRepository.instance,
  );
  final _homeMutationUseCases = const HomeMutationUseCases();

  final _resultExamController = TextEditingController();
  final _resultMarksController = TextEditingController();
  final _resultTotalController = TextEditingController();

  final _reportMonthController = TextEditingController();

  AppData _data = AppData.empty();
  String? _selectedUserForAttendance;
  bool _attendancePresent = true;
  String? _selectedStudentForResult;
  String? _selectedStudentForReportCard;
  String? _activeUserId;

  String _userSearchQuery = '';
  AppRole? _userRoleFilter;
  String _financeTypeFilter =
      'all'; // 'all' | 'fees' | 'expenses' | 'salaries' | 'funds'
  DateTime? _financeStartDate;
  DateTime? _financeEndDate;
  String _resultSearchQuery = '';
  String _attendanceSearchQuery = '';
  String _attendanceStatusFilter = 'all'; // 'all' | 'present' | 'absent'
  DateTime? _attendanceStartDate;
  DateTime? _attendanceEndDate;

  int _pageIndex = 0;

  bool _isLoading = true;

  void _updateState(VoidCallback updater) {
    setState(updater);
  }

  void _syncSelectionsWithData(AppData data) {
    final students = data.users
        .where((user) => user.role == AppRole.student)
        .toList();
    bool hasUser(String? id) =>
        id != null && data.users.any((user) => user.id == id);
    bool hasStudent(String? id) =>
        id != null && students.any((user) => user.id == id);

    _selectedUserForAttendance = hasUser(_selectedUserForAttendance)
        ? _selectedUserForAttendance
        : null;
    _selectedStudentForResult = hasStudent(_selectedStudentForResult)
        ? _selectedStudentForResult
        : null;
    _selectedStudentForReportCard = hasStudent(_selectedStudentForReportCard)
        ? _selectedStudentForReportCard
        : (students.isEmpty ? null : students.first.id);
  }

  Future<void> _commitMutation(HomeMutationResult result) async {
    _updateState(() {
      _data = result.data;
      _syncSelectionsWithData(_data);
    });
    await _persist();
    if (mounted && result.message.isNotEmpty) {
      _showSnack(result.message);
    }
  }

  void _syncPageWithSection(String section) {
    final normalized = section.toLowerCase();
    final destinations = _destinationsForRole();
    final index = destinations.indexWhere(
      (item) => item.label.toLowerCase() == normalized,
    );
    final desired = index >= 0 ? index : 0;
    if (_pageIndex != desired) {
      _pageIndex = desired;
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _reportMonthController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _syncPageWithSection(widget.section);
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      setState(() => _syncPageWithSection(widget.section));
    }
  }

  @override
  void dispose() {
    _resultExamController.dispose();
    _resultMarksController.dispose();
    _resultTotalController.dispose();
    _reportMonthController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _homeDataUseCases.loadData();
    if (!mounted) {
      return;
    }

    setState(() {
      _data = data;
      _activeUserId = AppAuthNotifier.instance.currentUserId;
      _syncPageWithSection(widget.section);
      _selectedStudentForReportCard = _students.isEmpty
          ? null
          : _students.first.id;
      _isLoading = false;
    });

    if (_activeUserId != null && _activeUser == null) {
      await AppAuthNotifier.instance.logout();
      if (mounted) {
        context.go(AppRoutes.login);
      }
      return;
    }

    await _ensureMonthlyPendingTransactions();
  }

  Future<void> _persist() async {
    await _homeDataUseCases.replaceAll(_data);
  }

  List<AppUser> get _students {
    return _data.users.where((user) => user.role == AppRole.student).toList();
  }

  List<AppUser> get _teachers {
    return _data.users.where((user) => user.role == AppRole.teacher).toList();
  }

  AppUser? get _activeUser {
    if (_activeUserId == null) {
      return null;
    }
    for (final user in _data.users) {
      if (user.id == _activeUserId) {
        return user;
      }
    }
    return null;
  }

  bool _canManageUsers() {
    final role = _activeUser?.role;
    return role == AppRole.admin || role == AppRole.manager;
  }

  bool _canManageFinance() {
    final role = _activeUser?.role;
    return role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.accountant;
  }

  bool _canManageAttendance() {
    final role = _activeUser?.role;
    return role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.teacher;
  }

  bool _canManageResults() {
    final role = _activeUser?.role;
    return role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.teacher;
  }

  bool _canUseBackup() {
    final role = _activeUser?.role;
    return role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.accountant;
  }

  bool _canPrintFinanceReports() {
    final role = _activeUser?.role;
    return role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.accountant;
  }

  bool _canPrintReportCards() {
    return _activeUser != null;
  }

  List<ResultRecord> get _visibleResults {
    final user = _activeUser;
    if (user == null) {
      return [];
    }
    if (user.role == AppRole.student) {
      return _data.results.where((item) => item.studentId == user.id).toList();
    }
    return _data.results;
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _id() => _uuid.v4();

  AppUser? _userById(String id) {
    for (final user in _data.users) {
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  double _toAmount(String raw) {
    return double.tryParse(raw.trim()) ?? 0;
  }

  Future<void> _logout() async {
    final confirmed = await _confirmAction(
      title: 'Sign out?',
      message: 'You will need to sign in again to continue.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) {
      return;
    }

    await AppAuthNotifier.instance.logout();
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.login);
  }

  Future<void> _openCreateUserRoute() async {
    if (!_canManageUsers()) {
      _showSnack('Permission denied for user management.');
      return;
    }

    final changed = await context.push<bool>(AppRoutes.usersNew);
    if (changed == true) {
      await _load();
      if (mounted) {
        _showSnack('User created successfully.');
      }
    }
  }

  Future<void> _openEditUserRoute(String userId) async {
    if (!_canManageUsers()) {
      _showSnack('Permission denied for user management.');
      return;
    }

    final changed = await context.push<bool>(AppRoutes.usersEdit(userId));
    if (changed == true) {
      await _load();
      if (mounted) {
        _showSnack('User updated successfully.');
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    if (!_canManageUsers()) {
      _showSnack('Permission denied for user management.');
      return;
    }
    if (id == _activeUserId) {
      _showSnack('You cannot delete your own logged-in account.');
      return;
    }

    final user = _userById(id);
    final confirmed = await _confirmAction(
      title: 'Delete user?',
      message:
          'This will remove ${user?.name ?? 'this user'} and all linked records.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) {
      return;
    }

    await _commitMutation(
      _homeMutationUseCases.deleteUserCascade(data: _data, userId: id),
    );
  }

  // ─── Finance navigation helpers ───────────────────────────────────────────

  Future<void> _openCreateFeeRoute() async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.feeNew);
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openCreateExpenseRoute() async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.expenseNew);
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openCreateSalaryRoute() async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.salaryNew);
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openCreateFundRoute() async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.fundNew);
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openEditFeeRoute(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.feeEdit(id));
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openEditExpenseRoute(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.expenseEdit(id));
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openEditSalaryRoute(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.salaryEdit(id));
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openEditFundRoute(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final changed = await context.push<bool>(AppRoutes.fundEdit(id));
    if (changed == true) {
      await _load();
    }
  }

  // ─── Finance delete helpers ───────────────────────────────────────────────

  Future<void> _deleteFee(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final confirmed = await _confirmAction(
      title: 'Delete fee record?',
      message: 'This fee entry will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _commitMutation(
      _homeMutationUseCases.deleteFee(data: _data, feeId: id),
    );
  }

  Future<void> _deleteExpense(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final confirmed = await _confirmAction(
      title: 'Delete expense?',
      message: 'This expense entry will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _commitMutation(
      _homeMutationUseCases.deleteExpense(data: _data, expenseId: id),
    );
  }

  Future<void> _deleteSalary(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final confirmed = await _confirmAction(
      title: 'Delete salary record?',
      message: 'This salary payment entry will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _commitMutation(
      _homeMutationUseCases.deleteSalary(data: _data, salaryId: id),
    );
  }

  Future<void> _deleteFund(String id) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final confirmed = await _confirmAction(
      title: 'Delete fund entry?',
      message: 'This fund record will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _commitMutation(
      _homeMutationUseCases.deleteFund(data: _data, fundId: id),
    );
  }

  Future<void> _toggleFeeStatus(FeeRecord fee) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final nextStatus = fee.status.isPaid
        ? FinanceStatus.pending
        : FinanceStatus.paid;
    await _commitMutation(
      _homeMutationUseCases.updateFeeStatus(
        data: _data,
        feeId: fee.id,
        status: nextStatus,
      ),
    );
  }

  Future<void> _toggleSalaryStatus(SalaryRecord salary) async {
    if (!_canManageFinance()) {
      _showSnack('Permission denied for finance module.');
      return;
    }
    final nextStatus = salary.status.isPaid
        ? FinanceStatus.pending
        : FinanceStatus.paid;
    await _commitMutation(
      _homeMutationUseCases.updateSalaryStatus(
        data: _data,
        salaryId: salary.id,
        status: nextStatus,
      ),
    );
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  bool _matchesFinanceDateRange(DateTime date) {
    if (_financeStartDate != null) {
      final start = DateTime(
        _financeStartDate!.year,
        _financeStartDate!.month,
        _financeStartDate!.day,
      );
      if (date.isBefore(start)) {
        return false;
      }
    }
    if (_financeEndDate != null) {
      final end = DateTime(
        _financeEndDate!.year,
        _financeEndDate!.month,
        _financeEndDate!.day,
        23,
        59,
        59,
        999,
      );
      if (date.isAfter(end)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesAttendanceDateRange(DateTime date) {
    if (_attendanceStartDate != null) {
      final start = DateTime(
        _attendanceStartDate!.year,
        _attendanceStartDate!.month,
        _attendanceStartDate!.day,
      );
      if (date.isBefore(start)) {
        return false;
      }
    }
    if (_attendanceEndDate != null) {
      final end = DateTime(
        _attendanceEndDate!.year,
        _attendanceEndDate!.month,
        _attendanceEndDate!.day,
        23,
        59,
        59,
        999,
      );
      if (date.isAfter(end)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _ensureMonthlyPendingTransactions() async {
    final month = _monthKey(DateTime.now());
    final now = DateTime.now();

    final generatedFees = <FeeRecord>[];
    for (final student in _students) {
      // Only generate fees for months strictly after the student's joining month.
      // If the student joined this month, their first fee is due next month.
      final joinMonth = _monthKey(student.createdAt);
      if (joinMonth.compareTo(month) >= 0) continue;

      final exists = _data.fees.any(
        (item) => item.studentId == student.id && item.month == month,
      );
      if (exists) continue;

      double amount = 0;
      for (final item in _data.fees) {
        if (item.studentId == student.id) {
          amount = item.amount;
          break;
        }
      }

      generatedFees.add(
        FeeRecord(
          id: _id(),
          studentId: student.id,
          amount: amount,
          note: 'Auto-generated monthly fee',
          createdAt: now,
          month: month,
          status: FinanceStatus.pending,
        ),
      );
    }

    final generatedSalaries = <SalaryRecord>[];
    for (final teacher in _teachers) {
      // Only generate salaries for months strictly after the teacher's joining month.
      // If the teacher joined this month, their first salary is due next month.
      final joinMonth = _monthKey(teacher.createdAt);
      if (joinMonth.compareTo(month) >= 0) continue;

      final exists = _data.salaries.any(
        (item) => item.teacherId == teacher.id && item.month == month,
      );
      if (exists) continue;

      double amount = 0;
      for (final item in _data.salaries) {
        if (item.teacherId == teacher.id) {
          amount = item.amount;
          break;
        }
      }

      generatedSalaries.add(
        SalaryRecord(
          id: _id(),
          teacherId: teacher.id,
          amount: amount,
          month: month,
          createdAt: now,
          status: FinanceStatus.pending,
        ),
      );
    }

    if (generatedFees.isEmpty && generatedSalaries.isEmpty) {
      return;
    }

    final nextData = _data.copyWith(
      fees: [...generatedFees, ..._data.fees],
      salaries: [...generatedSalaries, ..._data.salaries],
    );

    if (!mounted) return;
    setState(() => _data = nextData);
    await _persist();
  }

  Future<void> _addAttendance() async {
    if (!_canManageAttendance()) {
      _showSnack('Permission denied for attendance module.');
      return;
    }

    if (_selectedUserForAttendance == null) {
      _showSnack('Select a user for attendance.');
      return;
    }

    await _commitMutation(
      _homeMutationUseCases.addAttendance(
        data: _data,
        id: _id(),
        userId: _selectedUserForAttendance!,
        present: _attendancePresent,
        date: DateTime.now(),
      ),
    );
  }

  Future<void> _publishResult() async {
    if (!_canManageResults()) {
      _showSnack('Permission denied for results module.');
      return;
    }

    if (_selectedStudentForResult == null) {
      _showSnack('Select a student first.');
      return;
    }
    final exam = _resultExamController.text.trim();
    final marks = _toAmount(_resultMarksController.text);
    final total = _toAmount(_resultTotalController.text);
    if (exam.isEmpty || marks < 0 || total <= 0 || marks > total) {
      _showSnack('Enter valid exam, marks, and total marks.');
      return;
    }

    final result = _homeMutationUseCases.publishResult(
      data: _data,
      id: _id(),
      studentId: _selectedStudentForResult!,
      exam: exam,
      marks: marks,
      totalMarks: total,
      publishedAt: DateTime.now(),
    );
    _resultExamController.clear();
    _resultMarksController.clear();
    _resultTotalController.clear();
    await _commitMutation(result);
  }

  Future<void> _exportData() async {
    if (!_canUseBackup()) {
      _showSnack('Permission denied for backup.');
      return;
    }

    try {
      final passphrase = await _promptBackupPassphrase(
        title: 'Secure backup export',
        message:
            'Create a passphrase to encrypt this backup. You will need the same passphrase to import it later.',
        requireConfirmation: true,
        confirmLabel: 'Create Secure Backup',
      );
      if (passphrase == null) {
        return;
      }

      final payload = await _homeDataUseCases.exportBackupJson();
      final envelope = await _createEncryptedBackupEnvelope(
        payload: payload,
        passphrase: passphrase,
      );
      final jsonString = const JsonEncoder.withIndent('  ').convert(envelope);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'madrasah_secure_backup_$timestamp.mmbak';
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      String? savedPath;
      try {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save backup file',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['mmbak', 'json'],
          bytes: bytes,
        );
      } catch (_) {
        savedPath = null;
      }

      if (savedPath != null && savedPath.isNotEmpty) {
        _showSnack(
          kIsWeb
              ? 'Backup downloaded successfully.'
              : 'Backup exported to: $savedPath',
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Madrasah Manager secure encrypted backup',
        ),
      );
      _showSnack('Secure backup exported successfully.');
    } catch (error) {
      _showSnack(
        'Backup export failed. ${error is FormatException ? error.message : 'Please try again.'}',
      );
    }
  }

  Future<void> _importData() async {
    if (!_canUseBackup()) {
      _showSnack('Permission denied for backup.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mmbak', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selected = result.files.first;
      String? raw;

      if (selected.bytes != null) {
        raw = utf8.decode(selected.bytes!);
      } else if (selected.path != null) {
        raw = await File(selected.path!).readAsString();
      }

      if (raw == null || raw.trim().isEmpty) {
        _showSnack('Selected file is empty.');
        return;
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = Map<String, dynamic>.from(decoded);
      final isEncrypted = _isEncryptedBackupEnvelope(parsed);

      Map<String, dynamic> importPayload;
      if (isEncrypted) {
        final passphrase = await _promptBackupPassphrase(
          title: 'Secure backup import',
          message:
              'Enter the passphrase used when this backup was created to decrypt it securely.',
          requireConfirmation: false,
          confirmLabel: 'Decrypt Backup',
        );
        if (passphrase == null) {
          return;
        }
        importPayload = await _decryptBackupEnvelope(
          envelope: parsed,
          passphrase: passphrase,
        );
      } else {
        final confirmed = await _confirmAction(
          title: 'Import unencrypted backup?',
          message:
              'This file is not encrypted. You can still import it for compatibility, but it is less secure.',
          confirmLabel: 'Import Anyway',
        );
        if (!confirmed) {
          return;
        }
        importPayload = parsed;
      }

      final preview = AppData.fromBackup(importPayload);
      final confirmed = await _confirmAction(
        title: 'Replace current data?',
        message:
            'This will replace current data with ${preview.users.length} users, ${preview.fees.length} fees, ${preview.attendance.length} attendance, ${preview.expenses.length} expenses, ${preview.salaries.length} salaries, ${preview.funds.length} funds, and ${preview.results.length} results.',
        confirmLabel: 'Import Backup',
        isDestructive: true,
      );
      if (!confirmed) {
        return;
      }

      await _homeDataUseCases.importBackupJson(importPayload);
      await _load();
      _showSnack(
        isEncrypted
            ? 'Encrypted backup imported successfully.'
            : 'Backup imported successfully.',
      );
    } on SecretBoxAuthenticationError {
      _showSnack('Incorrect passphrase or tampered backup file.');
    } on FormatException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Import failed. Please select a valid backup file.');
    }
  }

  bool _isEncryptedBackupEnvelope(Map<String, dynamic> json) {
    return json['type'] == 'madrasah-secure-backup' &&
        json['cipherText'] is String &&
        json['nonce'] is String &&
        json['mac'] is String;
  }

  Future<Map<String, dynamic>> _createEncryptedBackupEnvelope({
    required Map<String, dynamic> payload,
    required String passphrase,
  }) async {
    if (passphrase.trim().length < 8) {
      throw const FormatException(
        'Use a passphrase with at least 8 characters.',
      );
    }

    final salt = _randomBytes(16);
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretKey = await _deriveBackupKey(
      passphrase: passphrase,
      salt: salt,
    );
    final clearText = utf8.encode(jsonEncode(payload));
    final secretBox = await algorithm.encrypt(
      clearText,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'type': 'madrasah-secure-backup',
      'version': 1,
      'algorithm': 'AES-256-GCM',
      'kdf': {
        'name': 'PBKDF2',
        'hash': 'SHA-256',
        'iterations': 120000,
        'salt': base64Encode(salt),
      },
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'metadata': {
        'exportedAt': DateTime.now().toIso8601String(),
        'app': 'Madrasah Manager',
        'users': _data.users.length,
        'fees': _data.fees.length,
        'attendance': _data.attendance.length,
        'expenses': _data.expenses.length,
        'salaries': _data.salaries.length,
        'funds': _data.funds.length,
        'results': _data.results.length,
      },
    };
  }

  Future<Map<String, dynamic>> _decryptBackupEnvelope({
    required Map<String, dynamic> envelope,
    required String passphrase,
  }) async {
    final kdf = envelope['kdf'];
    if (kdf is! Map) {
      throw const FormatException('Invalid backup key metadata.');
    }

    final saltEncoded = kdf['salt'];
    final iterations = kdf['iterations'];
    final nonceEncoded = envelope['nonce'];
    final cipherTextEncoded = envelope['cipherText'];
    final macEncoded = envelope['mac'];

    if (saltEncoded is! String ||
        iterations is! int ||
        nonceEncoded is! String ||
        cipherTextEncoded is! String ||
        macEncoded is! String) {
      throw const FormatException('Backup file is missing encryption fields.');
    }

    final salt = base64Decode(saltEncoded);
    final nonce = base64Decode(nonceEncoded);
    final cipherText = base64Decode(cipherTextEncoded);
    final macBytes = base64Decode(macEncoded);

    final secretKey = await _deriveBackupKey(
      passphrase: passphrase,
      salt: salt,
      iterations: iterations,
    );

    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final clearText = await algorithm.decrypt(secretBox, secretKey: secretKey);
    final decoded = jsonDecode(utf8.decode(clearText));
    if (decoded is! Map) {
      throw const FormatException('Decrypted backup payload is invalid.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<SecretKey> _deriveBackupKey({
    required String passphrase,
    required List<int> salt,
    int iterations = 120000,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Future<String?> _promptBackupPassphrase({
    required String title,
    required String message,
    required bool requireConfirmation,
    required String confirmLabel,
  }) async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    var obscurePass = true;
    var obscureConfirm = true;
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passController,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Passphrase',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setModalState(() => obscurePass = !obscurePass),
                          icon: Icon(
                            obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (requireConfirmation) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm passphrase',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Tip: use a strong passphrase and keep it safe. Without it, encrypted backups cannot be restored.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final pass = passController.text.trim();
                    final confirm = confirmController.text.trim();

                    if (pass.length < 8) {
                      setModalState(() {
                        errorText = 'Passphrase must be at least 8 characters.';
                      });
                      return;
                    }
                    if (requireConfirmation && pass != confirm) {
                      setModalState(() {
                        errorText = 'Passphrases do not match.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(pass);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );

    passController.dispose();
    confirmController.dispose();
    return result;
  }

  bool _isInMonth(DateTime date, String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return false;
    }
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) {
      return false;
    }
    return date.year == y && date.month == m;
  }

  Future<void> _printReportCard({String? studentId}) async {
    if (!_canPrintReportCards()) {
      _showSnack('Permission denied for printing report cards.');
      return;
    }

    final user = _activeUser;
    var targetStudentId = studentId;
    if (user != null && user.role == AppRole.student) {
      targetStudentId = user.id;
    }

    if (targetStudentId == null) {
      _showSnack('Select a student for report card.');
      return;
    }

    final student = _userById(targetStudentId);
    if (student == null) {
      _showSnack('Student not found.');
      return;
    }

    final resultRows = _data.results
        .where((result) => result.studentId == targetStudentId)
        .toList();
    if (resultRows.isEmpty) {
      _showSnack('No published result found for this student.');
      return;
    }

    final totalObtained = resultRows.fold<double>(
      0,
      (sum, item) => sum + item.marks,
    );
    final totalMarks = resultRows.fold<double>(
      0,
      (sum, item) => sum + item.totalMarks,
    );
    final overallPercent = totalMarks == 0
        ? 0
        : (totalObtained / totalMarks) * 100;

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Madrasah Report Card')),
          pw.SizedBox(height: 8),
          pw.Text('Student: ${student.name}'),
          pw.Text('Class/Group: ${student.group}'),
          pw.Text('Printed at: ${_dateText(DateTime.now())}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Exam', 'Obtained', 'Total', 'Percentage'],
            data: resultRows
                .map(
                  (result) => [
                    result.exam,
                    result.marks.toStringAsFixed(2),
                    result.totalMarks.toStringAsFixed(2),
                    '${((result.marks / result.totalMarks) * 100).toStringAsFixed(1)}%',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total Obtained: ${totalObtained.toStringAsFixed(2)}'),
          pw.Text('Total Marks: ${totalMarks.toStringAsFixed(2)}'),
          pw.Text('Overall Percentage: ${overallPercent.toStringAsFixed(1)}%'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => document.save());
  }

  Future<void> _printMonthlyFinancialReport() async {
    if (!_canPrintFinanceReports()) {
      _showSnack('Permission denied for monthly financial report.');
      return;
    }

    final monthKey = _reportMonthController.text.trim();
    final fees = _data.fees
        .where(
          (item) => _isInMonth(item.createdAt, monthKey) && item.status.isPaid,
        )
        .toList();
    final funds = _data.funds
        .where((item) => _isInMonth(item.createdAt, monthKey))
        .toList();
    final expenses = _data.expenses
        .where((item) => _isInMonth(item.createdAt, monthKey))
        .toList();
    final salaries = _data.salaries
        .where(
          (item) => _isInMonth(item.createdAt, monthKey) && item.status.isPaid,
        )
        .toList();

    final totalFees = fees.fold<double>(0, (sum, item) => sum + item.amount);
    final totalFunds = funds.fold<double>(0, (sum, item) => sum + item.amount);
    final totalExpenses = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalSalaries = salaries.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final balance = totalFunds + totalFees - totalExpenses - totalSalaries;

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Monthly Financial Report')),
          pw.Text('Month: $monthKey'),
          pw.Text('Printed at: ${_dateText(DateTime.now())}'),
          pw.SizedBox(height: 8),
          pw.Bullet(text: 'Total Fees: ${_money(totalFees)}'),
          pw.Bullet(text: 'Total Funds: ${_money(totalFunds)}'),
          pw.Bullet(text: 'Total Expenses: ${_money(totalExpenses)}'),
          pw.Bullet(text: 'Total Salaries: ${_money(totalSalaries)}'),
          pw.Bullet(text: 'Net Balance: ${_money(balance)}'),
          pw.SizedBox(height: 12),
          pw.Text('Transaction Counts', style: pw.TextStyle(fontSize: 14)),
          pw.TableHelper.fromTextArray(
            headers: ['Type', 'Count'],
            data: [
              ['Fees', '${fees.length}'],
              ['Funds', '${funds.length}'],
              ['Expenses', '${expenses.length}'],
              ['Salaries', '${salaries.length}'],
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => document.save());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  double get _totalFees {
    return _data.fees
        .where((item) => item.status.isPaid)
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get _totalExpenses {
    return _data.expenses.fold(0, (sum, item) => sum + item.amount);
  }

  double get _totalSalaries {
    return _data.salaries
        .where((item) => item.status.isPaid)
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get _pendingFeesAmount {
    return _data.fees
        .where((item) => item.status.isPending)
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get _pendingSalariesAmount {
    return _data.salaries
        .where((item) => item.status.isPending)
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get _totalFunds {
    return _data.funds.fold(0, (sum, item) => sum + item.amount);
  }

  double get _balance {
    return _totalFunds + _totalFees - _totalExpenses - _totalSalaries;
  }

  bool get _isDarkMode => AppThemeNotifier.instance.themeMode == ThemeMode.dark;

  bool _isTabletWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 700;
  }

  bool _isDesktopWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 1150;
  }

  bool _isMobileWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 700;
  }

  Future<void> _toggleThemeMode() async {
    final nextMode = _isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await AppThemeNotifier.instance.setMode(nextMode);
    if (mounted) {
      setState(() {});
    }
  }

  String _money(double value) => value.toStringAsFixed(2);

  EdgeInsets _pagePadding(BuildContext context) {
    if (_isDesktopWidth(context)) {
      return const EdgeInsets.all(20);
    }
    if (_isTabletWidth(context)) {
      return const EdgeInsets.all(16);
    }
    return const EdgeInsets.all(12);
  }

  double _pageMaxWidth(BuildContext context) {
    if (_isDesktopWidth(context)) {
      return 1320;
    }
    if (_isTabletWidth(context)) {
      return 1080;
    }
    return 820;
  }

  int _columnsForWidth(
    double width, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (width >= 1200) {
      return desktop;
    }
    if (width >= 720) {
      return tablet;
    }
    return mobile;
  }

  Widget _sectionHeader({
    required String title,
    String? subtitle,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          if (icon != null) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets? padding,
    Color? accentColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [scheme.surfaceContainerHigh, scheme.surfaceContainerLow]
              : [scheme.surfaceContainerLowest, scheme.surfaceContainerLow],
        ),
        border: Border.all(
          color: (accentColor ?? scheme.outline).withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (accentColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.5)],
                    ),
                  ),
                ),
              ),
            Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }

  Widget _pageShell(Widget child) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = _pageMaxWidth(context);
          final targetWidth = constraints.maxWidth < maxWidth
              ? constraints.maxWidth
              : maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: targetWidth,
              height: constraints.maxHeight,
              child: Padding(padding: _pagePadding(context), child: child),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _glassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: scheme.outline),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    Color? accentColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? scheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withValues(alpha: 0.22), scheme.surfaceContainerHigh]
              : [color.withValues(alpha: 0.10), color.withValues(alpha: 0.03)],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.30 : 0.18),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.72)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Icon(icon, size: 52, color: color.withValues(alpha: 0.07)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : scheme.onSurface,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color.withValues(alpha: isDark ? 0.85 : 0.75),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? scheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      accent.withValues(alpha: 0.18),
                      scheme.surfaceContainerHigh,
                    ]
                  : [
                      accent.withValues(alpha: 0.09),
                      accent.withValues(alpha: 0.03),
                    ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.15),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.72)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPageByLabel(String label) {
    final destinations = _destinationsForRole();
    final index = destinations.indexWhere((item) => item.label == label);
    if (index >= 0) {
      _goToPageIndex(index, destinations);
    }
  }

  void _goToPageIndex(int index, List<NavigationDestination> destinations) {
    if (index < 0 || index >= destinations.length) {
      return;
    }
    final path = AppRoutes.sectionPath(destinations[index].label);
    context.go(path);
  }

  Widget _activityListCard() {
    final activities = <Map<String, dynamic>>[];

    for (final item in _data.fees.take(6)) {
      final student = _userById(item.studentId);
      activities.add({
        'time': item.createdAt,
        'title': 'Fee collected',
        'subtitle': '${student?.name ?? 'Unknown'} • ${_money(item.amount)}',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF16A34A),
      });
    }
    for (final item in _data.expenses.take(6)) {
      activities.add({
        'time': item.createdAt,
        'title': 'Expense recorded',
        'subtitle': '${item.title} • ${_money(item.amount)}',
        'icon': Icons.shopping_bag_rounded,
        'color': const Color(0xFFDC2626),
      });
    }
    for (final item in _data.attendance.take(6)) {
      final user = _userById(item.userId);
      activities.add({
        'time': item.date,
        'title': 'Attendance recorded',
        'subtitle':
            '${user?.name ?? 'Unknown'} • ${item.present ? 'Present ✓' : 'Absent ✗'}',
        'icon': Icons.fact_check_rounded,
        'color': item.present
            ? const Color(0xFF0D9488)
            : const Color(0xFFD97706),
      });
    }
    for (final item in _data.results.take(6)) {
      final student = _userById(item.studentId);
      activities.add({
        'time': item.publishedAt,
        'title': 'Result published',
        'subtitle': '${student?.name ?? 'Unknown'} • ${item.exam}',
        'icon': Icons.workspace_premium_rounded,
        'color': const Color(0xFF7C3AED),
      });
    }

    activities.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (activities.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${activities.take(8).length} events',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 40, color: scheme.outline),
                    const SizedBox(height: 8),
                    Text(
                      'No recent records yet.',
                      style: TextStyle(color: scheme.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            ...activities.take(8).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final activity = entry.value;
              final color = activity['color'] as Color;
              final isLast = i == (activities.take(8).length - 1);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color, color.withValues(alpha: 0.65)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.30),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            activity['icon'] as IconData,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    color.withValues(alpha: 0.40),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    activity['title'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.9,
                                                )
                                              : scheme.onSurface,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dateText(activity['time'] as DateTime),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activity['subtitle'] as String,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGreetingBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _activeUser;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final greetIcon = hour < 12
        ? Icons.wb_sunny_rounded
        : hour < 17
        ? Icons.wb_cloudy_rounded
        : Icons.nights_stay_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF134E4A), const Color(0xFF1E3A5F)]
              : [const Color(0xFF0D9488), const Color(0xFF0EA5E9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF0D9488,
            ).withValues(alpha: isDark ? 0.22 : 0.35),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(greetIcon, color: Colors.white70, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            greeting,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user?.name ?? 'Welcome',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user?.role.label ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _navAccentColor(String label) {
    switch (label) {
      case 'Dashboard':
        return const Color(0xFF0D9488);
      case 'Users':
        return const Color(0xFF0EA5E9);
      case 'Finance':
        return const Color(0xFF16A34A);
      case 'Attendance':
        return const Color(0xFFD97706);
      case 'Results':
        return const Color(0xFF7C3AED);
      case 'Reports':
        return const Color(0xFF2563EB);
      case 'Backup':
        return const Color(0xFFDC2626);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _navIconData(String label) {
    switch (label) {
      case 'Dashboard':
        return Icons.dashboard_outlined;
      case 'Users':
        return Icons.groups_outlined;
      case 'Finance':
        return Icons.payments_outlined;
      case 'Attendance':
        return Icons.check_circle_outline;
      case 'Results':
        return Icons.assessment_outlined;
      case 'Reports':
        return Icons.print_outlined;
      case 'Backup':
        return Icons.backup_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String _navSubtitle(String label) {
    switch (label) {
      case 'Dashboard':
        return 'Overview & activity';
      case 'Users':
        return 'Accounts & roles';
      case 'Finance':
        return 'Cashflow & records';
      case 'Attendance':
        return 'Daily presence';
      case 'Results':
        return 'Marks & performance';
      case 'Reports':
        return 'Printable documents';
      case 'Backup':
        return 'Import & export';
      default:
        return '';
    }
  }

  NavigationDestination _navDestination(String label) {
    final accent = _navAccentColor(label);
    final icon = _navIconData(label);

    Widget iconBubble({required bool selected}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accent.withValues(alpha: 0.72)],
                )
              : null,
          color: selected ? null : accent.withValues(alpha: 0.08),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 20, color: selected ? Colors.white : accent),
      );
    }

    return NavigationDestination(
      icon: iconBubble(selected: false),
      selectedIcon: iconBubble(selected: true),
      label: label,
    );
  }

  Widget _buildSidebarNavItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _navAccentColor(label);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.20),
                  accent.withValues(alpha: 0.08),
                ],
              )
            : null,
        color: selected ? null : Colors.transparent,
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.28)
              : scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withValues(alpha: 0.72)],
                          )
                        : null,
                    color: selected ? null : accent.withValues(alpha: 0.12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _navIconData(label),
                    color: selected ? Colors.white : accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected ? accent : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _navSubtitle(label),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selected ? 1 : 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<NavigationDestination> _destinationsForRole() {
    final role = _activeUser?.role;
    if (role == null) {
      return const [];
    }

    final destinations = <NavigationDestination>[_navDestination('Dashboard')];

    if (_canManageUsers()) {
      destinations.add(_navDestination('Users'));
    }
    if (_canManageFinance()) {
      destinations.add(_navDestination('Finance'));
    }
    if (_canManageAttendance()) {
      destinations.add(_navDestination('Attendance'));
    }

    destinations.add(_navDestination('Results'));
    destinations.add(_navDestination('Reports'));

    if (_canUseBackup()) {
      destinations.add(_navDestination('Backup'));
    }

    return destinations;
  }

  List<Widget> _pagesForRole() {
    final pages = <Widget>[_buildDashboardPage()];
    if (_canManageUsers()) {
      pages.add(_buildUsersPage());
    }
    if (_canManageFinance()) {
      pages.add(_buildFinancePage());
    }
    if (_canManageAttendance()) {
      pages.add(_buildAttendancePage());
    }
    pages.add(_buildResultsPage());
    pages.add(_buildReportsPage());
    if (_canUseBackup()) {
      pages.add(_buildBackupPage());
    }
    return pages;
  }

  Widget _buildDesktopNavigation({
    required List<NavigationDestination> destinations,
    required Widget child,
    required AppUser current,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SafeArea(
          child: Container(
            width: 292,
            margin: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surfaceContainerLow,
                  scheme.surfaceContainerLowest,
                ],
              ),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D9488), Color(0xFF0EA5E9)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0D9488,
                          ).withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Madrasah Manager',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Creative admin workspace',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.16,
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        current.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${current.role.label} • ${current.username}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Text(
                          'Navigation',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      for (int i = 0; i < destinations.length; i++)
                        _buildSidebarNavItem(
                          label: destinations[i].label,
                          selected: i == _pageIndex,
                          onTap: () => _goToPageIndex(i, destinations),
                        ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _glassCard(
                          accentColor: const Color(0xFF7C3AED),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7C3AED,
                                  ).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smooth workspace',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Modern navigation experience',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pagesForRole();
    final destinations = _destinationsForRole();
    final current = _activeUser;
    final useRailNavigation = _isDesktopWidth(context);

    if (_pageIndex >= pages.length) {
      _pageIndex = 0;
    }

    if (_isLoading || current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final loggedInContent = _pageShell(
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_pageIndex),
          child: IndexedStack(index: _pageIndex, children: pages),
        ),
      ),
    );

    final bodyContent = useRailNavigation
        ? _buildDesktopNavigation(
            destinations: destinations,
            child: loggedInContent,
            current: current,
          )
        : loggedInContent;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D9488), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Madrasah Manager',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _toggleThemeMode,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(_isDarkMode),
              ),
            ),
            tooltip: _isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
          ),
          PopupMenuButton<int>(
            tooltip: 'Jump to page',
            onSelected: (index) => _goToPageIndex(index, destinations),
            itemBuilder: (context) => [
              for (int i = 0; i < destinations.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      destinations[i].icon,
                      const SizedBox(width: 10),
                      Text(destinations[i].label),
                    ],
                  ),
                ),
            ],
            icon: const Icon(Icons.grid_view_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      current.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: bodyContent,
      ),
      bottomNavigationBar: useRailNavigation
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerLow,
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.85),
                      ],
                    ),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.65),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: NavigationBar(
                      selectedIndex: _pageIndex,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      onDestinationSelected: (index) =>
                          _goToPageIndex(index, destinations),
                      labelBehavior: _isMobileWidth(context)
                          ? NavigationDestinationLabelBehavior.alwaysHide
                          : NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: destinations,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
