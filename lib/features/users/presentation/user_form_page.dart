import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_repository.dart';
import '../../../core/router/app_router.dart';
import '../../shared/domain/app_models.dart';
import '../../shared/domain/monthly_record_service.dart';
import '../domain/usecases/user_use_cases.dart';

class UserFormPage extends StatefulWidget {
  const UserFormPage({super.key, this.userId});

  final String? userId;

  bool get isEdit => userId != null;

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  static const _uuid = Uuid();
  final _userUseCases = UserUseCases(repository: AppRepository.instance);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  // Finance auto-gen
  final _monthlyFeeCtrl = TextEditingController();
  final _monthlySalaryCtrl = TextEditingController();

  // Student – parent info
  final _fatherNameCtrl = TextEditingController();
  final _fatherPhoneCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherPhoneCtrl = TextEditingController();

  // Student – guardian info
  final _guardianNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _guardianRelationCtrl = TextEditingController();

  // All roles – address
  final _presentAddressCtrl = TextEditingController();
  final _permanentAddressCtrl = TextEditingController();

  // Staff – NID
  final _nidNumberCtrl = TextEditingController();

  // Attachments
  List<String> _attachments = [];

  AppRole _role = AppRole.student;
  bool _saving = false;
  bool _loading = true;
  bool _canManage = false;
  bool _isAdmin = false;
  bool _obscurePassword = true;
  DateTime _joiningDate = DateTime.now();

  AppUser? _editingUser;
  List<AppUser> _allUsers = const [];

  bool get _isStudent => _role == AppRole.student;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _groupCtrl.dispose();
    _monthlyFeeCtrl.dispose();
    _monthlySalaryCtrl.dispose();
    _fatherNameCtrl.dispose();
    _fatherPhoneCtrl.dispose();
    _motherNameCtrl.dispose();
    _motherPhoneCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _guardianRelationCtrl.dispose();
    _presentAddressCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _nidNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _userUseCases.loadUserFormData(
        currentUserId: AppAuthNotifier.instance.currentUserId,
        editingUserId: widget.userId,
      );
      if (!mounted) return;

      final current = result.currentUser;

      _canManage =
          current?.role == AppRole.admin || current?.role == AppRole.manager;
      _isAdmin = current?.role == AppRole.admin;

      _editingUser = result.editingUser;
      _allUsers = result.allUsers;

      if (_editingUser != null) {
        final u = _editingUser!;
        _role = u.role;
        _nameCtrl.text = u.name;
        _usernameCtrl.text = u.username;
        _phoneCtrl.text = u.phone;
        _groupCtrl.text = u.group;
        if (u.monthlyFee > 0) {
          _monthlyFeeCtrl.text = u.monthlyFee.toStringAsFixed(2);
        }
        if (u.monthlySalary > 0) {
          _monthlySalaryCtrl.text = u.monthlySalary.toStringAsFixed(2);
        }
        _fatherNameCtrl.text = u.fatherName;
        _fatherPhoneCtrl.text = u.fatherPhone;
        _motherNameCtrl.text = u.motherName;
        _motherPhoneCtrl.text = u.motherPhone;
        _guardianNameCtrl.text = u.guardianName;
        _guardianPhoneCtrl.text = u.guardianPhone;
        _guardianRelationCtrl.text = u.guardianRelation;
        _presentAddressCtrl.text = u.presentAddress;
        _permanentAddressCtrl.text = u.permanentAddress;
        _nidNumberCtrl.text = u.nidNumber;
        _attachments = List<String>.from(u.attachments);
        _joiningDate = u.createdAt;
      } else {
        _joiningDate = DateTime.now();
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Failed to load user form data. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _requiredValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Color _roleColor(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const Color(0xFFDC2626);
      case AppRole.manager:
        return const Color(0xFF0D9488);
      case AppRole.accountant:
        return const Color(0xFF2563EB);
      case AppRole.teacher:
        return const Color(0xFF7C3AED);
      case AppRole.student:
        return const Color(0xFFD97706);
    }
  }

  IconData _roleIcon(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return Icons.shield_outlined;
      case AppRole.manager:
        return Icons.manage_accounts_outlined;
      case AppRole.accountant:
        return Icons.account_balance_wallet_outlined;
      case AppRole.teacher:
        return Icons.menu_book_outlined;
      case AppRole.student:
        return Icons.school_outlined;
    }
  }

  Future<void> _save() async {
    if (!_canManage) {
      _showSnack('Permission denied for user management.');
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final username = _usernameCtrl.text.trim();
    final duplicate = _userUseCases.usernameExists(
      users: _allUsers,
      username: username,
      excludingUserId: _editingUser?.id,
    );
    if (duplicate) {
      _showSnack('Username already exists.');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final password = _passwordCtrl.text.trim();

      final monthlyFee = double.tryParse(_monthlyFeeCtrl.text.trim()) ?? 0.0;
      final monthlySalary =
          double.tryParse(_monthlySalaryCtrl.text.trim()) ?? 0.0;

      final user = AppUser(
        id: _editingUser?.id ?? _uuid.v4(),
        name: _nameCtrl.text.trim(),
        username: username,
        password: widget.isEdit
            ? (password.isEmpty ? _editingUser!.password : password)
            : password,
        role: _role,
        phone: _phoneCtrl.text.trim(),
        group: _groupCtrl.text.trim(),
        createdAt: _isAdmin ? _joiningDate : (_editingUser?.createdAt ?? now),
        monthlyFee: _isStudent ? monthlyFee : 0.0,
        monthlySalary: _isStudent ? 0.0 : monthlySalary,
        fatherName: _fatherNameCtrl.text.trim(),
        fatherPhone: _fatherPhoneCtrl.text.trim(),
        motherName: _motherNameCtrl.text.trim(),
        motherPhone: _motherPhoneCtrl.text.trim(),
        guardianName: _guardianNameCtrl.text.trim(),
        guardianPhone: _guardianPhoneCtrl.text.trim(),
        guardianRelation: _guardianRelationCtrl.text.trim(),
        presentAddress: _presentAddressCtrl.text.trim(),
        permanentAddress: _permanentAddressCtrl.text.trim(),
        nidNumber: _nidNumberCtrl.text.trim(),
        attachments: _attachments,
      );

      await _userUseCases.upsertUser(user);
      await MonthlyRecordService.generateForUser(user.id);
      if (!mounted) return;
      context.pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _dateText(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  Future<void> _pickJoiningDate() async {
    if (!_isAdmin) {
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _joiningDate = picked);
    }
  }

  // ── File / Photo Picker ──────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null && mounted) {
      setState(() {
        for (final f in result.files) {
          final entry = f.path ?? f.name;
          if (entry.isNotEmpty && !_attachments.contains(entry)) {
            _attachments.add(entry);
          }
        }
      });
    }
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null && mounted) {
      setState(() {
        for (final f in result.files) {
          final entry = f.path ?? f.name;
          if (entry.isNotEmpty && !_attachments.contains(entry)) {
            _attachments.add(entry);
          }
        }
      });
    }
  }

  // ── Section card helper ───────────────────────────────────────────────────

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _twoColWrap(
    BuildContext context,
    BoxConstraints constraints,
    List<Widget> fields,
  ) {
    final wide = constraints.maxWidth >= 640;
    final w = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [for (final f in fields) SizedBox(width: w, child: f)],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Form')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 10),
                const Text('Permission denied for user management.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.users),
                  child: const Text('Back to Users'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.isEdit && _editingUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit User')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 10),
                const Text('User not found.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.users),
                  child: const Text('Back to Users'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit User' : 'New User'),
        centerTitle: false,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _roleColor(_role).withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _roleColor(_role),
                          _roleColor(_role).withValues(alpha: 0.72),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _roleColor(_role).withValues(alpha: 0.26),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                widget.isEdit
                                    ? Icons.manage_accounts_rounded
                                    : Icons.person_add_alt_1_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _roleIcon(_role),
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _role.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          widget.isEdit
                              ? 'Refine the account beautifully'
                              : 'Create a polished new profile',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isEdit
                              ? 'Update access, identity, and profile details with a clean professional workflow.'
                              : 'Set up identity, access role, and credentials with a modern organized form.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile details',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add the essential identity and role information first.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 640;
                              final fields = [
                                SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: DropdownButtonFormField<AppRole>(
                                    initialValue: _role,
                                    items: AppRole.values
                                        .map(
                                          (role) => DropdownMenuItem(
                                            value: role,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _roleIcon(role),
                                                  size: 18,
                                                  color: _roleColor(role),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(role.label),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _role = value);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Role',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: TextFormField(
                                    controller: _groupCtrl,
                                    validator: (value) => _requiredValidator(
                                      value,
                                      'Class / Department',
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Class / Department',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    validator: (value) =>
                                        _requiredValidator(value, 'Name'),
                                    decoration: const InputDecoration(
                                      labelText: 'Full Name',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: TextFormField(
                                    controller: _usernameCtrl,
                                    validator: (value) =>
                                        _requiredValidator(value, 'Username'),
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: TextFormField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    validator: (value) =>
                                        _requiredValidator(value, 'Phone'),
                                    decoration: const InputDecoration(
                                      labelText: 'Phone',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: TextFormField(
                                    controller: _passwordCtrl,
                                    validator: (value) {
                                      if (!widget.isEdit) {
                                        return _requiredValidator(
                                          value,
                                          'Password',
                                        );
                                      }
                                      return null;
                                    },
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: widget.isEdit
                                          ? 'Password (leave blank to keep existing)'
                                          : 'Password',
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ];

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: fields,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Monthly Fee / Salary ──────────────────────────────────
                  _sectionCard(
                    context: context,
                    title: _isStudent ? 'Monthly Fee' : 'Monthly Salary',
                    subtitle: _isStudent
                        ? 'Set a fixed fee – the first pending fee will be generated one month after the joining date, then monthly.'
                        : 'Set a fixed salary – the first pending salary will be generated one month after the joining date, then monthly.',
                    icon: _isStudent
                        ? Icons.payments_outlined
                        : Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF059669),
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            _twoColWrap(context, constraints, [
                              if (_isStudent)
                                TextFormField(
                                  controller: _monthlyFeeCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Monthly Fee Amount (৳)',
                                    hintText: '0.00',
                                    prefixIcon: Icon(Icons.payments_outlined),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').trim().isEmpty) return null;
                                    final n = double.tryParse(v!.trim());
                                    if (n == null || n < 0)
                                      return 'Enter a valid positive amount';
                                    return null;
                                  },
                                )
                              else
                                TextFormField(
                                  controller: _monthlySalaryCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Monthly Salary Amount (৳)',
                                    hintText: '0.00',
                                    prefixIcon: Icon(
                                      Icons.account_balance_wallet_outlined,
                                    ),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').trim().isEmpty) return null;
                                    final n = double.tryParse(v!.trim());
                                    if (n == null || n < 0)
                                      return 'Enter a valid positive amount';
                                    return null;
                                  },
                                ),
                            ]),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF059669,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF059669,
                            ).withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_mode_outlined,
                              color: Color(0xFF059669),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'A pending ${_isStudent ? 'fee' : 'salary'} record will be auto-generated one month after the joining date and then every following month.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _sectionCard(
                    context: context,
                    title: 'Joining Date',
                    subtitle: _isAdmin
                        ? 'Admin can change the joining date of this user.'
                        : 'Only admin can change joining date.',
                    icon: Icons.event_outlined,
                    color: const Color(0xFF2563EB),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _dateText(_joiningDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isAdmin) ...[
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 96,
                                maxWidth: 180,
                              ),
                              child: FilledButton.tonalIcon(
                                onPressed: _pickJoiningDate,
                                icon: const Icon(Icons.edit_calendar_outlined),
                                label: const Text('Change'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // ─── Parent Info (students only) ───────────────────────────
                  if (_isStudent)
                    _sectionCard(
                      context: context,
                      title: "Parent's Information",
                      subtitle:
                          "Father's and mother's name and contact details.",
                      icon: Icons.family_restroom_outlined,
                      color: _roleColor(_role),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              _twoColWrap(context, constraints, [
                                TextFormField(
                                  controller: _fatherNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Father's Name",
                                  ),
                                ),
                                TextFormField(
                                  controller: _fatherPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: "Father's Phone",
                                  ),
                                ),
                                TextFormField(
                                  controller: _motherNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Mother's Name",
                                  ),
                                ),
                                TextFormField(
                                  controller: _motherPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: "Mother's Phone",
                                  ),
                                ),
                              ]),
                        ),
                      ],
                    ),

                  // ─── Guardian Info (students only) ─────────────────────────
                  if (_isStudent)
                    _sectionCard(
                      context: context,
                      title: "Guardian's Information",
                      subtitle:
                          "Legal guardian contact and relation to the student.",
                      icon: Icons.supervisor_account_outlined,
                      color: _roleColor(_role),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              _twoColWrap(context, constraints, [
                                TextFormField(
                                  controller: _guardianNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Guardian's Name",
                                  ),
                                ),
                                TextFormField(
                                  controller: _guardianPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: "Guardian's Phone",
                                  ),
                                ),
                                TextFormField(
                                  controller: _guardianRelationCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Relation to Student',
                                    hintText: 'e.g. Uncle, Elder Brother…',
                                  ),
                                ),
                              ]),
                        ),
                      ],
                    ),

                  // ─── NID / Identity (staff only) ───────────────────────────
                  if (!_isStudent)
                    _sectionCard(
                      context: context,
                      title: 'Identity (NID)',
                      subtitle: 'National ID card number for verification.',
                      icon: Icons.credit_card_outlined,
                      color: const Color(0xFF6366F1),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              _twoColWrap(context, constraints, [
                                TextFormField(
                                  controller: _nidNumberCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'NID Card Number',
                                    prefixIcon: Icon(
                                      Icons.credit_card_outlined,
                                    ),
                                  ),
                                ),
                              ]),
                        ),
                      ],
                    ),

                  // ─── Address ───────────────────────────────────────────────
                  _sectionCard(
                    context: context,
                    title: 'Address Information',
                    subtitle: 'Present and permanent residential addresses.',
                    icon: Icons.location_on_outlined,
                    color: const Color(0xFF0EA5E9),
                    children: [
                      TextFormField(
                        controller: _presentAddressCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Present Address',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _permanentAddressCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Permanent Address',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),

                  // ─── Attachments ───────────────────────────────────────────
                  _sectionCard(
                    context: context,
                    title: 'Attachments',
                    subtitle: 'Documents, photos, and supporting files.',
                    icon: Icons.attach_file_rounded,
                    color: const Color(0xFFEC4899),
                    children: [
                      if (_attachments.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < _attachments.length; i++)
                              _AttachmentChip(
                                path: _attachments[i],
                                onRemove: () =>
                                    setState(() => _attachments.removeAt(i)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickPhotos,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Add Photos'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Add Files'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ─── Hint box ──────────────────────────────────────────────
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _roleColor(_role).withValues(alpha: 0.08),
                      border: Border.all(
                        color: _roleColor(_role).withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          color: _roleColor(_role),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEdit
                                    ? 'Editing mode active'
                                    : 'Setup guidance',
                                style: TextStyle(
                                  color: _roleColor(_role),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isEdit
                                    ? 'Leave the password blank to keep existing credentials. Monthly records follow the joining date cycle.'
                                    : 'Fill in as much detail as possible. Monthly fee / salary records will start after one month from the joining date.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Actions ───────────────────────────────────────────────
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => context.pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _roleColor(_role),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saving ? null : _save,
                          icon: Icon(
                            _saving
                                ? Icons.hourglass_top_rounded
                                : (widget.isEdit
                                      ? Icons.save_outlined
                                      : Icons.person_add_alt_1_outlined),
                          ),
                          label: Text(
                            _saving
                                ? 'Saving...'
                                : (widget.isEdit
                                      ? 'Update User'
                                      : 'Create User'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Attachment chip ───────────────────────────────────────────────────────────

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  bool get _isImage {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.heic');
  }

  String get _fileName {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.last.isNotEmpty ? parts.last : path;
  }

  Widget _thumbnail() {
    if (kIsWeb || !_isImage) {
      return Icon(
        _isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
        size: 18,
        color: const Color(0xFFEC4899),
      );
    }
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(path),
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: Color(0xFFEC4899),
          ),
        ),
      );
    } catch (_) {
      return const Icon(
        Icons.broken_image_outlined,
        size: 18,
        color: Color(0xFFEC4899),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEC4899).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEC4899).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _thumbnail(),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              _fileName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFFEC4899),
            ),
          ),
        ],
      ),
    );
  }
}
