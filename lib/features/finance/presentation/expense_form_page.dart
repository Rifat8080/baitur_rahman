import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_repository.dart';
import '../../../core/router/app_router.dart';
import '../../shared/domain/app_models.dart';

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({super.key, this.expenseId});

  final String? expenseId;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  static const _uuid = Uuid();
  static const _kColor = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  ExpenseRecord? _existingExpense;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  bool _canManage = false;

  bool get _isEdit => widget.expenseId != null;
  String get _pageTitle => _isEdit ? 'Edit Expense' : 'Record Expense';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
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

    ExpenseRecord? existingExpense;
    if (widget.expenseId != null) {
      for (final expense in data.expenses) {
        if (expense.id == widget.expenseId) {
          existingExpense = expense;
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
      _existingExpense = existingExpense;
      _selectedDate = existingExpense?.createdAt ?? DateTime.now();
      _titleCtrl.text = existingExpense?.title ?? '';
      _amountCtrl.text = existingExpense == null
          ? ''
          : existingExpense.amount.toStringAsFixed(2);
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
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount.');
      return;
    }

    setState(() => _saving = true);
    try {
      final expense = ExpenseRecord(
        id: _existingExpense?.id ?? _uuid.v4(),
        title: _titleCtrl.text.trim(),
        amount: amount,
        createdAt: _selectedDate,
      );

      if (_isEdit) {
        final data = await AppRepository.instance.loadAll();
        await AppRepository.instance.replaceAll(
          data.copyWith(
            expenses: data.expenses
                .map((item) => item.id == expense.id ? expense : item)
                .toList(),
          ),
        );
      } else {
        await AppRepository.instance.insertExpense(expense);
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
                                  Icons.shopping_bag_rounded,
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
                                  _isEdit ? 'Edit Expense' : 'Expense',
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
                                ? 'Update an expense transaction'
                                : 'Log an expenditure clearly',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Record the purpose, amount, and date of this expense.',
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
                            'Expense details',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Title / Purpose *',
                              prefixIcon: Icon(Icons.label_outline_rounded),
                            ),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Title is required'
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
                            ),
                            validator: (v) {
                              final n = double.tryParse(v?.trim() ?? '');
                              if (n == null || n <= 0) {
                                return 'Enter a valid positive amount';
                              }
                              return null;
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
                            ? 'Update Expense'
                            : 'Save Expense',
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
