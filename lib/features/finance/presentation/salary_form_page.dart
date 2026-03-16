import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_repository.dart';
import '../../../core/router/app_router.dart';
import '../../shared/domain/app_models.dart';

class SalaryFormPage extends StatefulWidget {
  const SalaryFormPage({super.key, this.salaryId});

  final String? salaryId;

  @override
  State<SalaryFormPage> createState() => _SalaryFormPageState();
}

class _SalaryFormPageState extends State<SalaryFormPage> {
  static const _uuid = Uuid();
  static const _kColor = Color(0xFF7C3AED);

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();

  List<AppUser> _teachers = const [];
  SalaryRecord? _existingSalary;
  String? _selectedTeacherId;
  DateTime _selectedDate = DateTime.now();
  FinanceStatus _status = FinanceStatus.paid;
  bool _loading = true;
  bool _saving = false;
  bool _canManage = false;

  bool get _isEdit => widget.salaryId != null;
  String get _pageTitle => _isEdit ? 'Edit Salary' : 'Pay Salary';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthCtrl.text = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _monthCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await AppRepository.instance.loadAll();
    if (!mounted) return;

    final currentId = AppAuthNotifier.instance.currentUserId;
    AppUser? currentUser;
    for (final user in data.users) {
      if (user.id == currentId) {
        currentUser = user;
        break;
      }
    }

    final teachers = data.users
        .where((u) => u.role == AppRole.teacher)
        .toList();
    SalaryRecord? existingSalary;
    if (widget.salaryId != null) {
      for (final salary in data.salaries) {
        if (salary.id == widget.salaryId) {
          existingSalary = salary;
          break;
        }
      }
    }

    final role = currentUser?.role;
    setState(() {
      _canManage =
          role == AppRole.admin ||
          role == AppRole.manager ||
          role == AppRole.accountant;
      _teachers = teachers;
      _existingSalary = existingSalary;
      _selectedTeacherId =
          existingSalary?.teacherId ??
          (teachers.isEmpty ? null : teachers.first.id);
      _selectedDate = existingSalary?.createdAt ?? DateTime.now();
      _status = existingSalary?.status ?? FinanceStatus.paid;
      _amountCtrl.text = existingSalary == null
          ? ''
          : existingSalary.amount == 0
          ? ''
          : existingSalary.amount.toStringAsFixed(2);
      if ((existingSalary?.month ?? '').trim().isNotEmpty) {
        _monthCtrl.text = existingSalary!.month;
      }
      _loading = false;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _dateText(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null) {
      _showSnack('Please select a teacher.');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 0) {
      _showSnack('Enter a valid amount.');
      return;
    }

    setState(() => _saving = true);
    try {
      final salary = SalaryRecord(
        id: _existingSalary?.id ?? _uuid.v4(),
        teacherId: _selectedTeacherId!,
        amount: amount,
        month: _monthCtrl.text.trim(),
        createdAt: _selectedDate,
        status: _status,
      );

      if (_isEdit) {
        final data = await AppRepository.instance.loadAll();
        await AppRepository.instance.replaceAll(
          data.copyWith(
            salaries: data.salaries
                .map((item) => item.id == salary.id ? salary : item)
                .toList(),
          ),
        );
      } else {
        await AppRepository.instance.insertSalary(salary);
      }

      if (!mounted) return;
      context.pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: Text(_pageTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 10),
                const Text('Permission denied for finance module.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.finance),
                  child: const Text('Back to Finance'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_teachers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_pageTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group_off_outlined, size: 40),
                const SizedBox(height: 10),
                const Text('No teachers found. Add teachers first.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.finance),
                  child: const Text('Back to Finance'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(_pageTitle), centerTitle: false),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kColor.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
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
                          colors: [_kColor, _kColor.withValues(alpha: 0.70)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.badge_rounded,
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
                                child: Text(
                                  _isEdit ? 'Edit Salary' : 'Salary Payment',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _isEdit
                                ? 'Update a teacher salary transaction'
                                : 'Process a teacher salary payment',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select the teacher, set month, amount, date, and payment status.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment details',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTeacherId,
                            decoration: const InputDecoration(
                              labelText: 'Teacher *',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                            items: _teachers
                                .map(
                                  (teacher) => DropdownMenuItem(
                                    value: teacher.id,
                                    child: Text(
                                      teacher.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedTeacherId = value),
                            validator: (value) => value == null
                                ? 'Please select a teacher'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _monthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Salary month *',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                              hintText: 'e.g. 2026-03',
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Month is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount *',
                              prefixIcon: Icon(Icons.currency_exchange),
                              hintText: 'e.g. 12000.00',
                            ),
                            validator: (value) {
                              final n = double.tryParse(value?.trim() ?? '');
                              if (n == null || n < 0) {
                                return 'Enter a valid amount';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<FinanceStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status *',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: FinanceStatus.values
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Transaction date',
                                prefixIcon: Icon(Icons.event_outlined),
                              ),
                              child: Text(_dateText(_selectedDate)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kColor,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_alt_rounded),
                      label: Text(
                        _saving
                            ? 'Saving…'
                            : _isEdit
                            ? 'Update Salary Record'
                            : 'Save Salary Payment',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
