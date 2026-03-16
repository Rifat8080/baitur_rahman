part of '../home_screen.dart';

extension _ReportsSection on _HomeScreenState {
  Widget _buildReportsPage() {
    final scheme = Theme.of(context).colorScheme;
    final canPrintFinance = _canPrintFinanceReports();
    final canPrintCard = _canPrintReportCards();
    final user = _activeUser;
    final cardStudentId = user != null && user.role == AppRole.student
        ? user.id
        : _selectedStudentForReportCard;
    final currentMonth = _monthKey(DateTime.now());
    final previousMonth = _monthKey(
      DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
    );
    final paidFees = _data.fees
        .where((item) => item.status.isPaid)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final paidSalaries = _data.salaries
        .where((item) => item.status.isPaid)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final totalFunds = _data.funds.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalExpenses = _data.expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final balance = (paidFees + totalFunds) - (paidSalaries + totalExpenses);

    Widget summaryCard({
      required String title,
      required String value,
      required IconData icon,
      required Color color,
      String? subtitle,
    }) {
      return Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      );
    }

    Widget statStrip(List<Widget> children) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      );
    }

    Widget featureBullet({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget reportCardPanel() {
      return _glassCard(
        accentColor: const Color(0xFF7C3AED),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Card',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate an academic report card for an individual student.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (user != null && user.role != AppRole.student)
              DropdownButtonFormField<String>(
                initialValue: _selectedStudentForReportCard,
                items: _students
                    .map(
                      (student) => DropdownMenuItem(
                        value: student.id,
                        child: Text('${student.name} (${student.group})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    _updateState(() => _selectedStudentForReportCard = value),
                decoration: const InputDecoration(labelText: 'Student'),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: scheme.surfaceContainerLow,
                ),
                child: Text(
                  'Student: ${user?.name ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 16),
            featureBullet(
              icon: Icons.menu_book_rounded,
              title: 'Includes published results',
              subtitle:
                  'Only saved result entries appear in the report card output.',
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 10),
            featureBullet(
              icon: Icons.verified_user_outlined,
              title: canPrintCard ? 'Access available' : 'Access unavailable',
              subtitle: canPrintCard
                  ? 'Current user can print the selected report card.'
                  : 'Please sign in to access printable student documents.',
              color: canPrintCard
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPrintCard
                    ? () => _printReportCard(studentId: cardStudentId)
                    : null,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print Report Card'),
              ),
            ),
          ],
        ),
      );
    }

    Widget financialPanel() {
      return _glassCard(
        accentColor: const Color(0xFF0EA5E9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Financial Report',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Print a monthly summary covering fees, funds, salaries, and expenses.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: canPrintFinance
                      ? () => _reportMonthController.text = currentMonth
                      : null,
                  child: const Text('This Month'),
                ),
                FilledButton.tonal(
                  onPressed: canPrintFinance
                      ? () => _reportMonthController.text = previousMonth
                      : null,
                  child: const Text('Previous Month'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reportMonthController,
              enabled: canPrintFinance,
              decoration: const InputDecoration(
                labelText: 'Month (YYYY-MM)',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
            ),
            const SizedBox(height: 16),
            featureBullet(
              icon: Icons.insights_outlined,
              title: 'Finance access',
              subtitle: canPrintFinance
                  ? 'Current role can generate printable monthly financial reports.'
                  : 'Only admin, manager, or accountant can print finance reports.',
              color: canPrintFinance
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
            const SizedBox(height: 10),
            featureBullet(
              icon: Icons.description_outlined,
              title: 'Best for monthly closing',
              subtitle:
                  'Use this document to summarize income, expenses, payouts, and balance.',
              color: const Color(0xFF0EA5E9),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPrintFinance
                    ? _printMonthlyFinancialReport
                    : null,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print Monthly Financial Report'),
              ),
            ),
          ],
        ),
      );
    }

    Widget documentGuideCard() {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Guide',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Use the right printable document for the right task.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            featureBullet(
              icon: Icons.school_outlined,
              title: 'Report Card',
              subtitle:
                  'Ideal for student-by-student academic performance review and parent sharing.',
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 12),
            featureBullet(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Financial Report',
              subtitle:
                  'Best for monthly finance review, cash flow analysis, and bookkeeping snapshots.',
              color: const Color(0xFF0EA5E9),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1060;

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Reports Center',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Generate polished academic and financial documents in seconds.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Print student report cards and monthly finance statements from one organized workspace.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    statStrip([
                      summaryCard(
                        title: 'Students',
                        value: '${_students.length}',
                        icon: Icons.groups_rounded,
                        color: Colors.white,
                        subtitle: 'Eligible for report cards',
                      ),
                      summaryCard(
                        title: 'Results Published',
                        value: '${_data.results.length}',
                        icon: Icons.assessment_outlined,
                        color: const Color(0xFFC4B5FD),
                        subtitle: 'Academic records available',
                      ),
                      summaryCard(
                        title: 'Current Balance',
                        value: _money(balance),
                        icon: Icons.account_balance_wallet_outlined,
                        color: balance >= 0
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                        subtitle: 'Paid transactions only',
                      ),
                      summaryCard(
                        title: 'Report Month',
                        value: _reportMonthController.text.trim().isEmpty
                            ? currentMonth
                            : _reportMonthController.text.trim(),
                        icon: Icons.calendar_month_outlined,
                        color: const Color(0xFF93C5FD),
                        subtitle: 'Finance print target',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: reportCardPanel()),
                  const SizedBox(width: 14),
                  Expanded(child: financialPanel()),
                ],
              )
            else ...[
              reportCardPanel(),
              const SizedBox(height: 14),
              financialPanel(),
            ],
            const SizedBox(height: 14),
            documentGuideCard(),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
