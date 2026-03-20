import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../features/shared/domain/app_models.dart';
import 'app_repository.dart';

/// Full SQLite-backed repository.  Used on all native platforms
/// (iOS, Android, macOS, Windows, Linux).
class SqliteRepository implements AppRepository {
  SqliteRepository._(this._db);

  final Database _db;

  static const _uuid = Uuid();
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[1-5][0-9a-fA-F]{3}\-[89abAB][0-9a-fA-F]{3}\-[0-9a-fA-F]{12}$',
  );

  // ─── Factory / open ───────────────────────────────────────────────────────

  static Future<SqliteRepository> open() async {
    // Desktop platforms need the FFI factory initialised before use.
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getDatabasesPath();
    final path = p.join(dir, 'madrasah_v1.db');

    final db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, _) => _createSchema(db),
      onUpgrade: _migrate,
    );

    final repo = SqliteRepository._(db);

    // One-time migration from the old SharedPreferences JSON store.
    await repo._migrateFromSharedPrefs();
    await repo._ensureUuidPrimaryKeys();

    return repo;
  }

  // ─── Schema ───────────────────────────────────────────────────────────────

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id                 TEXT PRIMARY KEY,
        name               TEXT NOT NULL,
        username           TEXT NOT NULL UNIQUE,
        password           TEXT NOT NULL,
        role               TEXT NOT NULL,
        phone              TEXT NOT NULL DEFAULT '',
        grp                TEXT NOT NULL DEFAULT '',
        created_at         TEXT NOT NULL,
        father_name        TEXT NOT NULL DEFAULT '',
        father_phone       TEXT NOT NULL DEFAULT '',
        mother_name        TEXT NOT NULL DEFAULT '',
        mother_phone       TEXT NOT NULL DEFAULT '',
        guardian_name      TEXT NOT NULL DEFAULT '',
        guardian_phone     TEXT NOT NULL DEFAULT '',
        guardian_relation  TEXT NOT NULL DEFAULT '',
        present_address    TEXT NOT NULL DEFAULT '',
        permanent_address  TEXT NOT NULL DEFAULT '',
        nid_number         TEXT NOT NULL DEFAULT '',
        monthly_fee        REAL NOT NULL DEFAULT 0,
        monthly_salary     REAL NOT NULL DEFAULT 0,
        attachments        TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    batch.execute('''
      CREATE TABLE fees (
        id         TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        amount     REAL NOT NULL,
        note       TEXT NOT NULL DEFAULT '',
         created_at TEXT NOT NULL,
         month      TEXT NOT NULL DEFAULT '',
         status     TEXT NOT NULL DEFAULT 'paid'
      )
    ''');

    batch.execute('''
      CREATE TABLE attendance (
        id         TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL,
        present    INTEGER NOT NULL,
        date       TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE expenses (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        amount     REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE salaries (
        id         TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL,
        amount     REAL NOT NULL,
        month      TEXT NOT NULL,
         created_at TEXT NOT NULL,
         status     TEXT NOT NULL DEFAULT 'paid'
      )
    ''');

    batch.execute('''
      CREATE TABLE funds (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        amount     REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE results (
        id           TEXT PRIMARY KEY,
        student_id   TEXT NOT NULL,
        exam         TEXT NOT NULL,
        marks        REAL NOT NULL,
        total_marks  REAL NOT NULL,
        published_at TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  // ─── Migration from SharedPreferences ─────────────────────────────────────

  static const _legacyKey = 'madrasah_data_v2';
  static const _legacyV1Key = 'madrasah_students_v1';
  static const _migratedFlag = 'madrasah_sqlite_migrated';

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE fees ADD COLUMN month TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE fees ADD COLUMN status TEXT NOT NULL DEFAULT 'paid'",
      );
      await db.execute(
        "ALTER TABLE salaries ADD COLUMN status TEXT NOT NULL DEFAULT 'paid'",
      );
    }
    if (oldVersion < 3) {
      for (final col in [
        "ALTER TABLE users ADD COLUMN father_name TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN father_phone TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN mother_name TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN mother_phone TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN guardian_name TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN guardian_phone TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN guardian_relation TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN present_address TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN permanent_address TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE users ADD COLUMN nid_number TEXT NOT NULL DEFAULT ''",
        'ALTER TABLE users ADD COLUMN monthly_fee REAL NOT NULL DEFAULT 0',
        'ALTER TABLE users ADD COLUMN monthly_salary REAL NOT NULL DEFAULT 0',
        "ALTER TABLE users ADD COLUMN attachments TEXT NOT NULL DEFAULT '[]'",
      ]) {
        await db.execute(col);
      }
    }
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

  Future<void> _migrateFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Already migrated or no old data.
    if (prefs.getBool(_migratedFlag) == true) return;

    // Check if there is anything to migrate.
    final raw = prefs.getString(_legacyKey) ?? prefs.getString(_legacyV1Key);
    if (raw == null || raw.trim().isEmpty) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }

    // Check if the SQLite DB is already populated (avoid double migration).
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    if ((count ?? 0) > 0) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final AppData data;

      if (prefs.getString(_legacyKey) != null) {
        data = AppData.fromJson(decoded);
      } else {
        final students = decoded['students'];
        data = AppData.fromLegacyStudents(
          students is List ? students : <dynamic>[],
        );
      }

      await replaceAll(data);
    } catch (_) {
      // Migration failed – start with empty DB; do not block startup.
    }

    await prefs.setBool(_migratedFlag, true);
  }

  // ─── Bulk ─────────────────────────────────────────────────────────────────

  @override
  Future<AppData> loadAll() async {
    final users = await _db.query('users', orderBy: 'created_at ASC');
    final fees = await _db.query('fees', orderBy: 'created_at DESC');
    final attendance = await _db.query('attendance', orderBy: 'date DESC');
    final expenses = await _db.query('expenses', orderBy: 'created_at DESC');
    final salaries = await _db.query('salaries', orderBy: 'created_at DESC');
    final funds = await _db.query('funds', orderBy: 'created_at DESC');
    final results = await _db.query('results', orderBy: 'published_at DESC');

    return AppData(
      users: users.map(_userFromRow).toList(),
      fees: fees.map(_feeFromRow).toList(),
      attendance: attendance.map(_attendanceFromRow).toList(),
      expenses: expenses.map(_expenseFromRow).toList(),
      salaries: salaries.map(_salaryFromRow).toList(),
      funds: funds.map(_fundFromRow).toList(),
      results: results.map(_resultFromRow).toList(),
    );
  }

  @override
  Future<void> replaceAll(AppData data) async {
    final normalized = _normalizeDataForUuid(data);
    final safeData = normalized.data;

    await _db.transaction((txn) async {
      for (final table in [
        'users',
        'fees',
        'attendance',
        'expenses',
        'salaries',
        'funds',
        'results',
      ]) {
        await txn.delete(table);
      }

      for (final u in safeData.users) {
        await txn.insert('users', _userToRow(u));
      }
      for (final f in safeData.fees) {
        await txn.insert('fees', _feeToRow(f));
      }
      for (final a in safeData.attendance) {
        await txn.insert('attendance', _attendanceToRow(a));
      }
      for (final e in safeData.expenses) {
        await txn.insert('expenses', _expenseToRow(e));
      }
      for (final s in safeData.salaries) {
        await txn.insert('salaries', _salaryToRow(s));
      }
      for (final f in safeData.funds) {
        await txn.insert('funds', _fundToRow(f));
      }
      for (final r in safeData.results) {
        await txn.insert('results', _resultToRow(r));
      }
    });
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  @override
  Future<void> upsertUser(AppUser user) async {
    await _db.insert(
      'users',
      _userToRow(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteUser(String id) async {
    await _db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteUserCascade(String userId) async {
    await _db.transaction((txn) async {
      await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
      await txn.delete('fees', where: 'student_id = ?', whereArgs: [userId]);
      await txn.delete('attendance', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(
        'salaries',
        where: 'teacher_id = ?',
        whereArgs: [userId],
      );
      await txn.delete('results', where: 'student_id = ?', whereArgs: [userId]);
    });
  }

  // ─── Fees ─────────────────────────────────────────────────────────────────

  @override
  Future<void> insertFee(FeeRecord fee) async {
    await _db.insert('fees', _feeToRow(fee));
  }

  @override
  Future<void> deleteFee(String id) async {
    await _db.delete('fees', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Attendance ───────────────────────────────────────────────────────────

  @override
  Future<void> insertAttendance(AttendanceRecord record) async {
    await _db.insert('attendance', _attendanceToRow(record));
  }

  @override
  Future<void> deleteAttendance(String id) async {
    await _db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  @override
  Future<void> insertExpense(ExpenseRecord expense) async {
    await _db.insert('expenses', _expenseToRow(expense));
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Salaries ─────────────────────────────────────────────────────────────

  @override
  Future<void> insertSalary(SalaryRecord salary) async {
    await _db.insert('salaries', _salaryToRow(salary));
  }

  @override
  Future<void> deleteSalary(String id) async {
    await _db.delete('salaries', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Funds ────────────────────────────────────────────────────────────────

  @override
  Future<void> insertFund(FundRecord fund) async {
    await _db.insert('funds', _fundToRow(fund));
  }

  @override
  Future<void> deleteFund(String id) async {
    await _db.delete('funds', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Results ──────────────────────────────────────────────────────────────

  @override
  Future<void> insertResult(ResultRecord result) async {
    await _db.insert('results', _resultToRow(result));
  }

  @override
  Future<void> deleteResult(String id) async {
    await _db.delete('results', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Import / Export ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> exportJson() async {
    final data = (await loadAll()).normalizedForImport();
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
    await replaceAll(data);
  }

  // ─── Row mappers ──────────────────────────────────────────────────────────

  static List<String> _parseAttachmentsList(String? raw) {
    try {
      if (raw == null || raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> _userToRow(AppUser u) => {
    'id': u.id,
    'name': u.name,
    'username': u.username,
    'password': u.password,
    'role': u.role.name,
    'phone': u.phone,
    'grp': u.group,
    'created_at': u.createdAt.toIso8601String(),
    'father_name': u.fatherName,
    'father_phone': u.fatherPhone,
    'mother_name': u.motherName,
    'mother_phone': u.motherPhone,
    'guardian_name': u.guardianName,
    'guardian_phone': u.guardianPhone,
    'guardian_relation': u.guardianRelation,
    'present_address': u.presentAddress,
    'permanent_address': u.permanentAddress,
    'nid_number': u.nidNumber,
    'monthly_fee': u.monthlyFee,
    'monthly_salary': u.monthlySalary,
    'attachments': jsonEncode(u.attachments),
  };

  static AppUser _userFromRow(Map<String, dynamic> r) => AppUser(
    id: r['id'] as String,
    name: r['name'] as String,
    username: r['username'] as String,
    password: r['password'] as String,
    role: parseRole(r['role'] as String),
    phone: (r['phone'] as String?) ?? '',
    group: (r['grp'] as String?) ?? '',
    createdAt: DateTime.parse(r['created_at'] as String),
    fatherName: (r['father_name'] as String?) ?? '',
    fatherPhone: (r['father_phone'] as String?) ?? '',
    motherName: (r['mother_name'] as String?) ?? '',
    motherPhone: (r['mother_phone'] as String?) ?? '',
    guardianName: (r['guardian_name'] as String?) ?? '',
    guardianPhone: (r['guardian_phone'] as String?) ?? '',
    guardianRelation: (r['guardian_relation'] as String?) ?? '',
    presentAddress: (r['present_address'] as String?) ?? '',
    permanentAddress: (r['permanent_address'] as String?) ?? '',
    nidNumber: (r['nid_number'] as String?) ?? '',
    monthlyFee: (r['monthly_fee'] as num? ?? 0).toDouble(),
    monthlySalary: (r['monthly_salary'] as num? ?? 0).toDouble(),
    attachments: _parseAttachmentsList(r['attachments'] as String?),
  );

  static Map<String, dynamic> _feeToRow(FeeRecord f) => {
    'id': f.id,
    'student_id': f.studentId,
    'amount': f.amount,
    'note': f.note,
    'created_at': f.createdAt.toIso8601String(),
    'month': f.month,
    'status': f.status.name,
  };

  static FeeRecord _feeFromRow(Map<String, dynamic> r) => FeeRecord(
    id: r['id'] as String,
    studentId: r['student_id'] as String,
    amount: (r['amount'] as num).toDouble(),
    note: (r['note'] as String?) ?? '',
    createdAt: DateTime.parse(r['created_at'] as String),
    month: (r['month'] as String?) ?? '',
    status: parseFinanceStatus((r['status'] as String?) ?? 'paid'),
  );

  static Map<String, dynamic> _attendanceToRow(AttendanceRecord a) => {
    'id': a.id,
    'user_id': a.userId,
    'present': a.present ? 1 : 0,
    'date': a.date.toIso8601String(),
  };

  static AttendanceRecord _attendanceFromRow(Map<String, dynamic> r) =>
      AttendanceRecord(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        present: (r['present'] as int) == 1,
        date: DateTime.parse(r['date'] as String),
      );

  static Map<String, dynamic> _expenseToRow(ExpenseRecord e) => {
    'id': e.id,
    'title': e.title,
    'amount': e.amount,
    'created_at': e.createdAt.toIso8601String(),
  };

  static ExpenseRecord _expenseFromRow(Map<String, dynamic> r) => ExpenseRecord(
    id: r['id'] as String,
    title: r['title'] as String,
    amount: (r['amount'] as num).toDouble(),
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  static Map<String, dynamic> _salaryToRow(SalaryRecord s) => {
    'id': s.id,
    'teacher_id': s.teacherId,
    'amount': s.amount,
    'month': s.month,
    'created_at': s.createdAt.toIso8601String(),
    'status': s.status.name,
  };

  static SalaryRecord _salaryFromRow(Map<String, dynamic> r) => SalaryRecord(
    id: r['id'] as String,
    teacherId: r['teacher_id'] as String,
    amount: (r['amount'] as num).toDouble(),
    month: r['month'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
    status: parseFinanceStatus((r['status'] as String?) ?? 'paid'),
  );

  static Map<String, dynamic> _fundToRow(FundRecord f) => {
    'id': f.id,
    'title': f.title,
    'amount': f.amount,
    'created_at': f.createdAt.toIso8601String(),
  };

  static FundRecord _fundFromRow(Map<String, dynamic> r) => FundRecord(
    id: r['id'] as String,
    title: r['title'] as String,
    amount: (r['amount'] as num).toDouble(),
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  static Map<String, dynamic> _resultToRow(ResultRecord r) => {
    'id': r.id,
    'student_id': r.studentId,
    'exam': r.exam,
    'marks': r.marks,
    'total_marks': r.totalMarks,
    'published_at': r.publishedAt.toIso8601String(),
  };

  static ResultRecord _resultFromRow(Map<String, dynamic> r) => ResultRecord(
    id: r['id'] as String,
    studentId: r['student_id'] as String,
    exam: r['exam'] as String,
    marks: (r['marks'] as num).toDouble(),
    totalMarks: (r['total_marks'] as num).toDouble(),
    publishedAt: DateTime.parse(r['published_at'] as String),
  );

  Future<void> _ensureUuidPrimaryKeys() async {
    final data = await loadAll();
    final normalized = _normalizeDataForUuid(data);
    if (normalized.changed) {
      await replaceAll(normalized.data);
    }
  }

  static ({AppData data, bool changed}) _normalizeDataForUuid(AppData data) {
    final userIdMap = <String, String>{};

    var changed = false;

    String normalizePk(String source) {
      if (_uuidPattern.hasMatch(source)) {
        return source;
      }
      changed = true;
      return _uuid.v4();
    }

    final users = data.users.map((u) {
      final newId = normalizePk(u.id);
      userIdMap[u.id] = newId;
      return AppUser(
        id: newId,
        name: u.name,
        username: u.username,
        password: u.password,
        role: u.role,
        phone: u.phone,
        group: u.group,
        createdAt: u.createdAt,
        fatherName: u.fatherName,
        fatherPhone: u.fatherPhone,
        motherName: u.motherName,
        motherPhone: u.motherPhone,
        guardianName: u.guardianName,
        guardianPhone: u.guardianPhone,
        guardianRelation: u.guardianRelation,
        presentAddress: u.presentAddress,
        permanentAddress: u.permanentAddress,
        nidNumber: u.nidNumber,
        monthlyFee: u.monthlyFee,
        monthlySalary: u.monthlySalary,
        attachments: u.attachments,
      );
    }).toList();

    String remapUserRef(String id) {
      final mapped = userIdMap[id];
      if (mapped != null && mapped != id) {
        changed = true;
      }
      return mapped ?? id;
    }

    final fees = data.fees
        .map(
          (f) => FeeRecord(
            id: normalizePk(f.id),
            studentId: remapUserRef(f.studentId),
            amount: f.amount,
            note: f.note,
            createdAt: f.createdAt,
            month: f.month,
            status: f.status,
          ),
        )
        .toList();

    final attendance = data.attendance
        .map(
          (a) => AttendanceRecord(
            id: normalizePk(a.id),
            userId: remapUserRef(a.userId),
            present: a.present,
            date: a.date,
          ),
        )
        .toList();

    final expenses = data.expenses
        .map(
          (e) => ExpenseRecord(
            id: normalizePk(e.id),
            title: e.title,
            amount: e.amount,
            createdAt: e.createdAt,
          ),
        )
        .toList();

    final salaries = data.salaries
        .map(
          (s) => SalaryRecord(
            id: normalizePk(s.id),
            teacherId: remapUserRef(s.teacherId),
            amount: s.amount,
            month: s.month,
            createdAt: s.createdAt,
            status: s.status,
          ),
        )
        .toList();

    final funds = data.funds
        .map(
          (f) => FundRecord(
            id: normalizePk(f.id),
            title: f.title,
            amount: f.amount,
            createdAt: f.createdAt,
          ),
        )
        .toList();

    final results = data.results
        .map(
          (r) => ResultRecord(
            id: normalizePk(r.id),
            studentId: remapUserRef(r.studentId),
            exam: r.exam,
            marks: r.marks,
            totalMarks: r.totalMarks,
            publishedAt: r.publishedAt,
          ),
        )
        .toList();

    return (
      data: AppData(
        users: users,
        fees: fees,
        attendance: attendance,
        expenses: expenses,
        salaries: salaries,
        funds: funds,
        results: results,
      ),
      changed: changed,
    );
  }
}
