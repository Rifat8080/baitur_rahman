import 'dart:convert';

enum AppRole { admin, manager, accountant, teacher, student }

enum FinanceStatus { pending, paid }

FinanceStatus parseFinanceStatus(String value) {
  return FinanceStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => FinanceStatus.paid,
  );
}

extension FinanceStatusLabel on FinanceStatus {
  String get label => this == FinanceStatus.pending ? 'Pending' : 'Paid';
  bool get isPending => this == FinanceStatus.pending;
  bool get isPaid => this == FinanceStatus.paid;
}

AppRole parseRole(String value) {
  return AppRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AppRole.student,
  );
}

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.admin:
        return 'Admin';
      case AppRole.manager:
        return 'Manager';
      case AppRole.accountant:
        return 'Accountant';
      case AppRole.teacher:
        return 'Teacher';
      case AppRole.student:
        return 'Student';
    }
  }
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    required this.phone,
    required this.group,
    required this.createdAt,
    // Student – parent info
    this.fatherName = '',
    this.fatherPhone = '',
    this.motherName = '',
    this.motherPhone = '',
    // Student – guardian info
    this.guardianName = '',
    this.guardianPhone = '',
    this.guardianRelation = '',
    // All roles – address
    this.presentAddress = '',
    this.permanentAddress = '',
    // Staff – identity
    this.nidNumber = '',
    // Finance auto-generation
    this.monthlyFee = 0.0,
    this.monthlySalary = 0.0,
    // Attachments (file paths / names)
    this.attachments = const [],
  });

  final String id;
  final String name;
  final String username;
  final String password;
  final AppRole role;
  final String phone;
  final String group;
  final DateTime createdAt;

  // Student – parent info
  final String fatherName;
  final String fatherPhone;
  final String motherName;
  final String motherPhone;

  // Student – guardian info
  final String guardianName;
  final String guardianPhone;
  final String guardianRelation;

  // All roles – address
  final String presentAddress;
  final String permanentAddress;

  // Staff – identity
  final String nidNumber;

  // Finance auto-generation
  final double monthlyFee; // student: auto-generate fee each month
  final double monthlySalary; // staff: auto-generate salary each month

  // Attachments
  final List<String> attachments;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'password': password,
    'role': role.name,
    'phone': phone,
    'group': group,
    'createdAt': createdAt.toIso8601String(),
    'fatherName': fatherName,
    'fatherPhone': fatherPhone,
    'motherName': motherName,
    'motherPhone': motherPhone,
    'guardianName': guardianName,
    'guardianPhone': guardianPhone,
    'guardianRelation': guardianRelation,
    'presentAddress': presentAddress,
    'permanentAddress': permanentAddress,
    'nidNumber': nidNumber,
    'monthlyFee': monthlyFee,
    'monthlySalary': monthlySalary,
    'attachments': attachments,
  };

  static List<String> _parseAttachments(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      username: (json['username'] ?? '') as String,
      password: (json['password'] ?? '') as String,
      role: parseRole((json['role'] ?? 'student') as String),
      phone: (json['phone'] ?? '') as String,
      group: (json['group'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fatherName: (json['fatherName'] ?? '') as String,
      fatherPhone: (json['fatherPhone'] ?? '') as String,
      motherName: (json['motherName'] ?? '') as String,
      motherPhone: (json['motherPhone'] ?? '') as String,
      guardianName: (json['guardianName'] ?? '') as String,
      guardianPhone: (json['guardianPhone'] ?? '') as String,
      guardianRelation: (json['guardianRelation'] ?? '') as String,
      presentAddress: (json['presentAddress'] ?? '') as String,
      permanentAddress: (json['permanentAddress'] ?? '') as String,
      nidNumber: (json['nidNumber'] ?? '') as String,
      monthlyFee: ((json['monthlyFee'] as num?) ?? 0).toDouble(),
      monthlySalary: ((json['monthlySalary'] as num?) ?? 0).toDouble(),
      attachments: _parseAttachments(json['attachments']),
    );
  }
}

class FeeRecord {
  FeeRecord({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.note,
    required this.createdAt,
    this.month = '',
    this.status = FinanceStatus.paid,
  });

  final String id;
  final String studentId;
  final double amount;
  final String note;
  final DateTime createdAt;
  final String month;
  final FinanceStatus status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'amount': amount,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'month': month,
    'status': status.name,
  };

  factory FeeRecord.fromJson(Map<String, dynamic> json) {
    return FeeRecord(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: (json['note'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      month: (json['month'] ?? '') as String,
      status: parseFinanceStatus((json['status'] ?? 'paid') as String),
    );
  }
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.present,
    required this.date,
  });

  final String id;
  final String userId;
  final bool present;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'present': present,
    'date': date.toIso8601String(),
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      userId: json['userId'] as String,
      present: json['present'] as bool,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class SalaryRecord {
  SalaryRecord({
    required this.id,
    required this.teacherId,
    required this.amount,
    required this.month,
    required this.createdAt,
    this.status = FinanceStatus.paid,
  });

  final String id;
  final String teacherId;
  final double amount;
  final String month;
  final DateTime createdAt;
  final FinanceStatus status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'teacherId': teacherId,
    'amount': amount,
    'month': month,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory SalaryRecord.fromJson(Map<String, dynamic> json) {
    return SalaryRecord(
      id: json['id'] as String,
      teacherId: json['teacherId'] as String,
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: parseFinanceStatus((json['status'] ?? 'paid') as String),
    );
  }
}

class FundRecord {
  FundRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FundRecord.fromJson(Map<String, dynamic> json) {
    return FundRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ResultRecord {
  ResultRecord({
    required this.id,
    required this.studentId,
    required this.exam,
    required this.marks,
    required this.totalMarks,
    required this.publishedAt,
  });

  final String id;
  final String studentId;
  final String exam;
  final double marks;
  final double totalMarks;
  final DateTime publishedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'exam': exam,
    'marks': marks,
    'totalMarks': totalMarks,
    'publishedAt': publishedAt.toIso8601String(),
  };

  factory ResultRecord.fromJson(Map<String, dynamic> json) {
    return ResultRecord(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      exam: json['exam'] as String,
      marks: (json['marks'] as num).toDouble(),
      totalMarks: (json['totalMarks'] as num).toDouble(),
      publishedAt: DateTime.parse(json['publishedAt'] as String),
    );
  }
}

class AppData {
  AppData({
    required this.users,
    required this.fees,
    required this.attendance,
    required this.expenses,
    required this.salaries,
    required this.funds,
    required this.results,
  });

  final List<AppUser> users;
  final List<FeeRecord> fees;
  final List<AttendanceRecord> attendance;
  final List<ExpenseRecord> expenses;
  final List<SalaryRecord> salaries;
  final List<FundRecord> funds;
  final List<ResultRecord> results;

  AppData copyWith({
    List<AppUser>? users,
    List<FeeRecord>? fees,
    List<AttendanceRecord>? attendance,
    List<ExpenseRecord>? expenses,
    List<SalaryRecord>? salaries,
    List<FundRecord>? funds,
    List<ResultRecord>? results,
  }) {
    return AppData(
      users: users ?? this.users,
      fees: fees ?? this.fees,
      attendance: attendance ?? this.attendance,
      expenses: expenses ?? this.expenses,
      salaries: salaries ?? this.salaries,
      funds: funds ?? this.funds,
      results: results ?? this.results,
    );
  }

  factory AppData.empty() {
    return AppData(
      users: [],
      fees: [],
      attendance: [],
      expenses: [],
      salaries: [],
      funds: [],
      results: [],
    );
  }

  static List<T> _parseList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = json[key];
    if (raw is! List<dynamic>) {
      return [];
    }
    return raw
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      users: _parseList(json, 'users', AppUser.fromJson),
      fees: _parseList(json, 'fees', FeeRecord.fromJson),
      attendance: _parseList(json, 'attendance', AttendanceRecord.fromJson),
      expenses: _parseList(json, 'expenses', ExpenseRecord.fromJson),
      salaries: _parseList(json, 'salaries', SalaryRecord.fromJson),
      funds: _parseList(json, 'funds', FundRecord.fromJson),
      results: _parseList(json, 'results', ResultRecord.fromJson),
    );
  }

  factory AppData.fromLegacyStudents(List<dynamic> studentsRaw) {
    final users = studentsRaw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        username:
            'student_${(map['id'] as String).substring(0, ((map['id'] as String).length >= 4 ? 4 : (map['id'] as String).length))}',
        password: '1234',
        role: AppRole.student,
        phone: (map['guardianPhone'] ?? '') as String,
        group: (map['className'] ?? '') as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();

    return AppData(
      users: users,
      fees: [],
      attendance: [],
      expenses: [],
      salaries: [],
      funds: [],
      results: [],
    );
  }

  factory AppData.fromBackup(Map<String, dynamic> backup) {
    if (backup['data'] is Map) {
      return AppData.fromJson(
        Map<String, dynamic>.from(backup['data'] as Map<dynamic, dynamic>),
      );
    }
    if (backup['users'] is List || backup['fees'] is List) {
      return AppData.fromJson(backup);
    }
    if (backup['students'] is List<dynamic>) {
      return AppData.fromLegacyStudents(backup['students'] as List<dynamic>);
    }
    throw const FormatException('Unsupported backup format');
  }

  static List<T> _deduplicateById<T>(
    Iterable<T> records,
    String Function(T record) idOf,
    DateTime Function(T record) timestampOf,
  ) {
    final latestById = <String, T>{};
    final latestTimestampById = <String, DateTime>{};

    for (final record in records) {
      final id = idOf(record).trim();
      if (id.isEmpty) {
        continue;
      }

      final timestamp = timestampOf(record);
      final previousTimestamp = latestTimestampById[id];
      if (previousTimestamp == null || timestamp.isAfter(previousTimestamp)) {
        latestById[id] = record;
        latestTimestampById[id] = timestamp;
      }
    }

    final values = latestById.values.toList();
    values.sort((left, right) {
      final timeCompare = timestampOf(right).compareTo(timestampOf(left));
      if (timeCompare != 0) {
        return timeCompare;
      }
      return idOf(left).compareTo(idOf(right));
    });
    return values;
  }

  AppData normalizedForImport() {
    final normalizedUsers = _deduplicateById(
      users,
      (record) => record.id,
      (record) => record.createdAt,
    );

    return AppData(
      users: normalizedUsers,
      fees: _deduplicateById(
        fees,
        (record) => record.id,
        (record) => record.createdAt,
      ),
      attendance: _deduplicateById(
        attendance,
        (record) => record.id,
        (record) => record.date,
      ),
      expenses: _deduplicateById(
        expenses,
        (record) => record.id,
        (record) => record.createdAt,
      ),
      salaries: _deduplicateById(
        salaries,
        (record) => record.id,
        (record) => record.createdAt,
      ),
      funds: _deduplicateById(
        funds,
        (record) => record.id,
        (record) => record.createdAt,
      ),
      results: _deduplicateById(
        results,
        (record) => record.id,
        (record) => record.publishedAt,
      ),
    );
  }

  void validateRelationalIntegrity() {
    final userIds = users.map((user) => user.id).toSet();

    final orphanFees = fees
        .where((record) => !userIds.contains(record.studentId))
        .length;
    final orphanAttendance = attendance
        .where((record) => !userIds.contains(record.userId))
        .length;
    final orphanSalaries = salaries
        .where((record) => !userIds.contains(record.teacherId))
        .length;
    final orphanResults = results
        .where((record) => !userIds.contains(record.studentId))
        .length;

    if (orphanFees == 0 &&
        orphanAttendance == 0 &&
        orphanSalaries == 0 &&
        orphanResults == 0) {
      return;
    }

    throw FormatException(
      'Backup references missing users (fees: $orphanFees, attendance: $orphanAttendance, salaries: $orphanSalaries, results: $orphanResults).',
    );
  }

  int get totalRecords =>
      users.length +
      fees.length +
      attendance.length +
      expenses.length +
      salaries.length +
      funds.length +
      results.length;

  Map<String, int> get recordCounts => {
    'users': users.length,
    'fees': fees.length,
    'attendance': attendance.length,
    'expenses': expenses.length,
    'salaries': salaries.length,
    'funds': funds.length,
    'results': results.length,
  };

  Map<String, dynamic> toJson() => {
    'users': users.map((e) => e.toJson()).toList(),
    'fees': fees.map((e) => e.toJson()).toList(),
    'attendance': attendance.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'salaries': salaries.map((e) => e.toJson()).toList(),
    'funds': funds.map((e) => e.toJson()).toList(),
    'results': results.map((e) => e.toJson()).toList(),
  };
}
