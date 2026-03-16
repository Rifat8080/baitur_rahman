part of '../home_screen.dart';

extension _FinanceSection on _HomeScreenState {
  Widget _buildFinancePage() {
    final scheme = Theme.of(context).colorScheme;
    final canManage = _canManageFinance();

    String userNameById(String id) {
      for (final user in _data.users) {
        if (user.id == id) return user.name;
      }
      return 'Unknown';
    }

    String dateText(DateTime value) {
      return '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/'
          '${value.year}';
    }

    final fees = _data.fees.where(_financeFeeFilter).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final expenses =
        _data.expenses
            .where((item) => _matchesFinanceDateRange(item.createdAt))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final salaries = _data.salaries.where(_financeSalaryFilter).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final funds =
        _data.funds
            .where((item) => _matchesFinanceDateRange(item.createdAt))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalVisibleRecords =
        fees.length + expenses.length + salaries.length + funds.length;

    final visibleCollectedFees = fees
        .where((item) => item.status.isPaid)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final visiblePendingFees = fees
        .where((item) => item.status.isPending)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final visiblePaidSalaries = salaries
        .where((item) => item.status.isPaid)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final visiblePendingSalaries = salaries
        .where((item) => item.status.isPending)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final visibleExpenses = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final visibleFunds = funds.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

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

    Widget sectionHeader({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      VoidCallback? onAdd,
      String addLabel = 'Add New',
      List<Widget> extraActions = const [],
    }) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final headerInfo = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...extraActions,
              if (onAdd != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(addLabel),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headerInfo, const SizedBox(height: 12), actions],
            );
          }

          final actionsWidth = constraints.maxWidth < 980 ? 260.0 : 340.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headerInfo),
              const SizedBox(width: 12),
              SizedBox(
                width: actionsWidth,
                child: Align(alignment: Alignment.topRight, child: actions),
              ),
            ],
          );
        },
      );
    }

    Widget statusChip(FinanceStatus status) {
      final color = status.isPaid
          ? const Color(0xFF16A34A)
          : const Color(0xFFF59E0B);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    Widget moduleChip({
      required String label,
      required String value,
      required IconData icon,
      required Color color,
    }) {
      final selected = _financeTypeFilter == value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _updateState(() => _financeTypeFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget dateButton({
      required String label,
      required DateTime? value,
      required VoidCallback onTap,
    }) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: onTap,
        icon: const Icon(Icons.event_outlined),
        label: Text(value == null ? label : '$label: ${dateText(value)}'),
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

    // ── Table helpers ─────────────────────────────────────────────────────

    Widget tableWrapper({
      required Color accentColor,
      required List<String> headers,
      required List<double> colWidths,
      required List<List<Widget>> rows,
      List<int> stretchColumns = const [],
      List<Widget>? mobileCards,
      double mobileBreakpoint = 860,
    }) {
      assert(headers.length == colWidths.length);
      const hPad = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
      final divColor = scheme.outlineVariant.withValues(alpha: 0.18);

      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < mobileBreakpoint &&
                mobileCards != null) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (int i = 0; i < mobileCards.length; i++) ...[
                      mobileCards[i],
                      if (i != mobileCards.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            }

            final baseTotal = colWidths.fold<double>(0, (s, w) => s + w);
            final targetWidth = constraints.maxWidth > baseTotal
                ? constraints.maxWidth
                : baseTotal;
            final effectiveWidths = List<double>.from(colWidths);
            final targets = stretchColumns.isEmpty
                ? List<int>.generate(colWidths.length, (i) => i)
                : stretchColumns;

            if (targetWidth > baseTotal && targets.isNotEmpty) {
              final extra = (targetWidth - baseTotal) / targets.length;
              for (final index in targets) {
                if (index >= 0 && index < effectiveWidths.length) {
                  effectiveWidths[index] += extra;
                }
              }
            }

            Widget th(String label, double w) => SizedBox(
              width: w,
              child: Padding(
                padding: hPad,
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            );

            Widget td(Widget child, double w) => SizedBox(
              width: w,
              child: Padding(padding: hPad, child: child),
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: targetWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.12),
                            accentColor.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          for (int h = 0; h < headers.length; h++)
                            th(headers[h], effectiveWidths[h]),
                        ],
                      ),
                    ),
                    Container(height: 1, color: divColor),
                    for (int r = 0; r < rows.length; r++) ...[
                      Container(
                        constraints: const BoxConstraints(minHeight: 74),
                        color: r.isOdd
                            ? accentColor.withValues(alpha: 0.025)
                            : scheme.surface,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (int c = 0; c < rows[r].length; c++)
                              td(rows[r][c], effectiveWidths[c]),
                          ],
                        ),
                      ),
                      if (r < rows.length - 1)
                        Container(height: 1, color: divColor),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    Widget statementIndexCell(int value, Color color) => Center(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    Widget statementTitleCell({
      required String title,
      required Color color,
      IconData? icon,
      String? subtitle,
    }) {
      return Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon ?? Icons.description_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    Widget statementPill(String text, Color color, {IconData? icon}) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget statementMutedText(String text) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );

    Widget amountText(String text, Color color) => Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 14.5,
      ),
    );

    Widget actionPopup(List<PopupMenuEntry<int>> items) => SizedBox(
      width: 38,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: PopupMenuButton<int>(
          tooltip: 'Actions',
          icon: Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          padding: EdgeInsets.zero,
          itemBuilder: (_) => items,
        ),
      ),
    );

    Widget recordMetaChip({
      required String label,
      required Color color,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget financeRecordCard({
      required Color accentColor,
      required IconData icon,
      required String title,
      String? subtitle,
      String? note,
      required String amount,
      required Color amountColor,
      required List<Widget> chips,
      Widget? trailing,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
            if (note != null && note.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: amountColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  amount,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget feeSection() {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              title: 'Collect Fees',
              subtitle:
                  'Monthly student fee records with pending and paid status.',
              icon: Icons.payments_rounded,
              color: const Color(0xFF0EA5E9),
              onAdd: canManage ? _openCreateFeeRoute : null,
              addLabel: 'Collect Fee',
            ),
            const SizedBox(height: 16),
            statStrip([
              summaryCard(
                title: 'Collected',
                value: _money(visibleCollectedFees),
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF16A34A),
                subtitle: '${fees.where((e) => e.status.isPaid).length} paid',
              ),
              summaryCard(
                title: 'Pending',
                value: _money(visiblePendingFees),
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFF59E0B),
                subtitle:
                    '${fees.where((e) => e.status.isPending).length} waiting',
              ),
            ]),
            const SizedBox(height: 16),
            if (fees.isEmpty)
              _emptyState(
                title: 'No fee records in this range',
                subtitle: 'Try a different date range or add a fee record.',
                icon: Icons.payments_outlined,
              )
            else
              tableWrapper(
                accentColor: const Color(0xFF0EA5E9),
                headers: canManage
                    ? [
                        '#',
                        'Student',
                        'Date',
                        'Month',
                        'Note',
                        'Status',
                        'Amount',
                        '',
                      ]
                    : [
                        '#',
                        'Student',
                        'Date',
                        'Month',
                        'Note',
                        'Status',
                        'Amount',
                      ],
                colWidths: canManage
                    ? [40, 160, 110, 100, 150, 90, 110, 44]
                    : [40, 160, 110, 100, 150, 90, 110],
                stretchColumns: const [1, 4],
                mobileCards: [
                  for (int i = 0; i < fees.length; i++)
                    financeRecordCard(
                      accentColor: const Color(0xFF0EA5E9),
                      icon: Icons.school_rounded,
                      title: userNameById(fees[i].studentId),
                      subtitle: fees[i].studentId,
                      note: fees[i].note,
                      amount: fees[i].status.isPaid
                          ? '+${_money(fees[i].amount)}'
                          : _money(fees[i].amount),
                      amountColor: fees[i].status.isPaid
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                      chips: [
                        recordMetaChip(
                          label: '#${i + 1}',
                          color: const Color(0xFF0EA5E9),
                          icon: Icons.tag_rounded,
                        ),
                        recordMetaChip(
                          label: dateText(fees[i].createdAt),
                          color: const Color(0xFF0EA5E9),
                          icon: Icons.calendar_today_outlined,
                        ),
                        recordMetaChip(
                          label: fees[i].month.isEmpty
                              ? 'No month'
                              : fees[i].month,
                          color: const Color(0xFF0EA5E9),
                          icon: Icons.event_note_outlined,
                        ),
                        statusChip(fees[i].status),
                      ],
                      trailing: canManage
                          ? actionPopup([
                              PopupMenuItem<int>(
                                value: 0,
                                onTap: () => _toggleFeeStatus(fees[i]),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    fees[i].status.isPaid
                                        ? Icons.undo_rounded
                                        : Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                                  title: Text(
                                    fees[i].status.isPaid
                                        ? 'Mark Pending'
                                        : 'Mark Paid',
                                  ),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 1,
                                onTap: () => _openEditFeeRoute(fees[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined, size: 18),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 2,
                                onTap: () => _deleteFee(fees[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ])
                          : null,
                    ),
                ],
                rows: [
                  for (int i = 0; i < fees.length; i++)
                    [
                      statementIndexCell(i + 1, const Color(0xFF0EA5E9)),
                      statementTitleCell(
                        title: userNameById(fees[i].studentId),
                        subtitle: fees[i].studentId,
                        color: const Color(0xFF0EA5E9),
                        icon: Icons.school_rounded,
                      ),
                      statementPill(
                        dateText(fees[i].createdAt),
                        const Color(0xFF0EA5E9),
                        icon: Icons.calendar_today_outlined,
                      ),
                      statementPill(
                        fees[i].month.isEmpty ? 'No month' : fees[i].month,
                        const Color(0xFF0EA5E9),
                        icon: Icons.event_note_outlined,
                      ),
                      statementMutedText(
                        fees[i].note.isEmpty ? '—' : fees[i].note,
                      ),
                      statusChip(fees[i].status),
                      Align(
                        alignment: Alignment.centerRight,
                        child: amountText(
                          fees[i].status.isPaid
                              ? '+${_money(fees[i].amount)}'
                              : _money(fees[i].amount),
                          fees[i].status.isPaid
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      if (canManage)
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionPopup([
                            PopupMenuItem<int>(
                              value: 0,
                              onTap: () => _toggleFeeStatus(fees[i]),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  fees[i].status.isPaid
                                      ? Icons.undo_rounded
                                      : Icons.check_circle_rounded,
                                  size: 18,
                                ),
                                title: Text(
                                  fees[i].status.isPaid
                                      ? 'Mark Pending'
                                      : 'Mark Paid',
                                ),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 1,
                              onTap: () => _openEditFeeRoute(fees[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined, size: 18),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 2,
                              onTap: () => _deleteFee(fees[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                ],
              ),
          ],
        ),
      );
    }

    Widget expenseSection() {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              title: 'Expenses',
              subtitle: 'Track every outgoing operational expense separately.',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFFDC2626),
              onAdd: canManage ? _openCreateExpenseRoute : null,
              addLabel: 'Add Expense',
            ),
            const SizedBox(height: 16),
            statStrip([
              summaryCard(
                title: 'Total Expenses',
                value: _money(visibleExpenses),
                icon: Icons.trending_down_rounded,
                color: const Color(0xFFDC2626),
                subtitle: '${expenses.length} record(s)',
              ),
            ]),
            const SizedBox(height: 16),
            if (expenses.isEmpty)
              _emptyState(
                title: 'No expenses in this range',
                subtitle: 'Add an expense or widen the date filter.',
                icon: Icons.receipt_long_outlined,
              )
            else
              tableWrapper(
                accentColor: const Color(0xFFDC2626),
                headers: canManage
                    ? ['#', 'Title', 'Date', 'Amount', '']
                    : ['#', 'Title', 'Date', 'Amount'],
                colWidths: canManage
                    ? [40, 260, 120, 130, 44]
                    : [40, 260, 120, 130],
                stretchColumns: const [1],
                mobileCards: [
                  for (int i = 0; i < expenses.length; i++)
                    financeRecordCard(
                      accentColor: const Color(0xFFDC2626),
                      icon: Icons.receipt_long_rounded,
                      title: expenses[i].title,
                      subtitle: 'Expense entry',
                      amount: '-${_money(expenses[i].amount)}',
                      amountColor: const Color(0xFFDC2626),
                      chips: [
                        recordMetaChip(
                          label: '#${i + 1}',
                          color: const Color(0xFFDC2626),
                          icon: Icons.tag_rounded,
                        ),
                        recordMetaChip(
                          label: dateText(expenses[i].createdAt),
                          color: const Color(0xFFDC2626),
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                      trailing: canManage
                          ? actionPopup([
                              PopupMenuItem<int>(
                                value: 0,
                                onTap: () =>
                                    _openEditExpenseRoute(expenses[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined, size: 18),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 1,
                                onTap: () => _deleteExpense(expenses[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ])
                          : null,
                    ),
                ],
                rows: [
                  for (int i = 0; i < expenses.length; i++)
                    [
                      statementIndexCell(i + 1, const Color(0xFFDC2626)),
                      statementTitleCell(
                        title: expenses[i].title,
                        subtitle: 'Expense entry',
                        color: const Color(0xFFDC2626),
                        icon: Icons.receipt_long_rounded,
                      ),
                      statementPill(
                        dateText(expenses[i].createdAt),
                        const Color(0xFFDC2626),
                        icon: Icons.calendar_today_outlined,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: amountText(
                          '-${_money(expenses[i].amount)}',
                          const Color(0xFFDC2626),
                        ),
                      ),
                      if (canManage)
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionPopup([
                            PopupMenuItem<int>(
                              value: 0,
                              onTap: () =>
                                  _openEditExpenseRoute(expenses[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined, size: 18),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 1,
                              onTap: () => _deleteExpense(expenses[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                ],
              ),
          ],
        ),
      );
    }

    Widget salarySection() {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              title: 'Salaries',
              subtitle:
                  'Monthly salary records with pending and paid payout status.',
              icon: Icons.badge_rounded,
              color: const Color(0xFF7C3AED),
              onAdd: canManage ? _openCreateSalaryRoute : null,
              addLabel: 'Add Salary',
            ),
            const SizedBox(height: 16),
            statStrip([
              summaryCard(
                title: 'Paid Salaries',
                value: _money(visiblePaidSalaries),
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF7C3AED),
                subtitle:
                    '${salaries.where((e) => e.status.isPaid).length} paid',
              ),
              summaryCard(
                title: 'Pending Salaries',
                value: _money(visiblePendingSalaries),
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFF59E0B),
                subtitle:
                    '${salaries.where((e) => e.status.isPending).length} waiting',
              ),
            ]),
            const SizedBox(height: 16),
            if (salaries.isEmpty)
              _emptyState(
                title: 'No salary records in this range',
                subtitle: 'Try a different date range or add a salary record.',
                icon: Icons.badge_outlined,
              )
            else
              tableWrapper(
                accentColor: const Color(0xFF7C3AED),
                headers: canManage
                    ? ['#', 'Teacher', 'Date', 'Month', 'Status', 'Amount', '']
                    : ['#', 'Teacher', 'Date', 'Month', 'Status', 'Amount'],
                colWidths: canManage
                    ? [40, 160, 110, 100, 90, 110, 44]
                    : [40, 160, 110, 100, 90, 110],
                stretchColumns: const [1, 3],
                mobileCards: [
                  for (int i = 0; i < salaries.length; i++)
                    financeRecordCard(
                      accentColor: const Color(0xFF7C3AED),
                      icon: Icons.badge_rounded,
                      title: userNameById(salaries[i].teacherId),
                      subtitle: salaries[i].teacherId,
                      amount: salaries[i].status.isPaid
                          ? '-${_money(salaries[i].amount)}'
                          : _money(salaries[i].amount),
                      amountColor: salaries[i].status.isPaid
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF59E0B),
                      chips: [
                        recordMetaChip(
                          label: '#${i + 1}',
                          color: const Color(0xFF7C3AED),
                          icon: Icons.tag_rounded,
                        ),
                        recordMetaChip(
                          label: dateText(salaries[i].createdAt),
                          color: const Color(0xFF7C3AED),
                          icon: Icons.calendar_today_outlined,
                        ),
                        recordMetaChip(
                          label: salaries[i].month,
                          color: const Color(0xFF7C3AED),
                          icon: Icons.event_note_outlined,
                        ),
                        statusChip(salaries[i].status),
                      ],
                      trailing: canManage
                          ? actionPopup([
                              PopupMenuItem<int>(
                                value: 0,
                                onTap: () => _toggleSalaryStatus(salaries[i]),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    salaries[i].status.isPaid
                                        ? Icons.undo_rounded
                                        : Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                                  title: Text(
                                    salaries[i].status.isPaid
                                        ? 'Mark Pending'
                                        : 'Mark Paid',
                                  ),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 1,
                                onTap: () =>
                                    _openEditSalaryRoute(salaries[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined, size: 18),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 2,
                                onTap: () => _deleteSalary(salaries[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ])
                          : null,
                    ),
                ],
                rows: [
                  for (int i = 0; i < salaries.length; i++)
                    [
                      statementIndexCell(i + 1, const Color(0xFF7C3AED)),
                      statementTitleCell(
                        title: userNameById(salaries[i].teacherId),
                        subtitle: salaries[i].teacherId,
                        color: const Color(0xFF7C3AED),
                        icon: Icons.badge_rounded,
                      ),
                      statementPill(
                        dateText(salaries[i].createdAt),
                        const Color(0xFF7C3AED),
                        icon: Icons.calendar_today_outlined,
                      ),
                      statementPill(
                        salaries[i].month,
                        const Color(0xFF7C3AED),
                        icon: Icons.event_note_outlined,
                      ),
                      statusChip(salaries[i].status),
                      Align(
                        alignment: Alignment.centerRight,
                        child: amountText(
                          salaries[i].status.isPaid
                              ? '-${_money(salaries[i].amount)}'
                              : _money(salaries[i].amount),
                          salaries[i].status.isPaid
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      if (canManage)
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionPopup([
                            PopupMenuItem<int>(
                              value: 0,
                              onTap: () => _toggleSalaryStatus(salaries[i]),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  salaries[i].status.isPaid
                                      ? Icons.undo_rounded
                                      : Icons.check_circle_rounded,
                                  size: 18,
                                ),
                                title: Text(
                                  salaries[i].status.isPaid
                                      ? 'Mark Pending'
                                      : 'Mark Paid',
                                ),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 1,
                              onTap: () => _openEditSalaryRoute(salaries[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined, size: 18),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 2,
                              onTap: () => _deleteSalary(salaries[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                ],
              ),
          ],
        ),
      );
    }

    Widget fundSection() {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              title: 'Funds',
              subtitle:
                  'Keep donations and direct fund contributions separate.',
              icon: Icons.volunteer_activism_rounded,
              color: const Color(0xFF16A34A),
              onAdd: canManage ? _openCreateFundRoute : null,
              addLabel: 'Add Fund',
            ),
            const SizedBox(height: 16),
            statStrip([
              summaryCard(
                title: 'Total Funds',
                value: _money(visibleFunds),
                icon: Icons.savings_outlined,
                color: const Color(0xFF16A34A),
                subtitle: '${funds.length} record(s)',
              ),
            ]),
            const SizedBox(height: 16),
            if (funds.isEmpty)
              _emptyState(
                title: 'No fund records in this range',
                subtitle: 'Add a fund or widen the date filter.',
                icon: Icons.account_balance_wallet_outlined,
              )
            else
              tableWrapper(
                accentColor: const Color(0xFF16A34A),
                headers: canManage
                    ? ['#', 'Title', 'Date', 'Amount', '']
                    : ['#', 'Title', 'Date', 'Amount'],
                colWidths: canManage
                    ? [40, 260, 120, 130, 44]
                    : [40, 260, 120, 130],
                stretchColumns: const [1],
                mobileCards: [
                  for (int i = 0; i < funds.length; i++)
                    financeRecordCard(
                      accentColor: const Color(0xFF16A34A),
                      icon: Icons.volunteer_activism_rounded,
                      title: funds[i].title,
                      subtitle: 'Fund contribution',
                      amount: '+${_money(funds[i].amount)}',
                      amountColor: const Color(0xFF16A34A),
                      chips: [
                        recordMetaChip(
                          label: '#${i + 1}',
                          color: const Color(0xFF16A34A),
                          icon: Icons.tag_rounded,
                        ),
                        recordMetaChip(
                          label: dateText(funds[i].createdAt),
                          color: const Color(0xFF16A34A),
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                      trailing: canManage
                          ? actionPopup([
                              PopupMenuItem<int>(
                                value: 0,
                                onTap: () => _openEditFundRoute(funds[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined, size: 18),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 1,
                                onTap: () => _deleteFund(funds[i].id),
                                child: const ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ])
                          : null,
                    ),
                ],
                rows: [
                  for (int i = 0; i < funds.length; i++)
                    [
                      statementIndexCell(i + 1, const Color(0xFF16A34A)),
                      statementTitleCell(
                        title: funds[i].title,
                        subtitle: 'Fund contribution',
                        color: const Color(0xFF16A34A),
                        icon: Icons.volunteer_activism_rounded,
                      ),
                      statementPill(
                        dateText(funds[i].createdAt),
                        const Color(0xFF16A34A),
                        icon: Icons.calendar_today_outlined,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: amountText(
                          '+${_money(funds[i].amount)}',
                          const Color(0xFF16A34A),
                        ),
                      ),
                      if (canManage)
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionPopup([
                            PopupMenuItem<int>(
                              value: 0,
                              onTap: () => _openEditFundRoute(funds[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined, size: 18),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 1,
                              onTap: () => _deleteFund(funds[i].id),
                              child: const ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                ],
              ),
          ],
        ),
      );
    }

    final sections = <Widget>[
      if (_financeTypeFilter == 'all' || _financeTypeFilter == 'fees')
        feeSection(),
      if (_financeTypeFilter == 'all' || _financeTypeFilter == 'expenses')
        expenseSection(),
      if (_financeTypeFilter == 'all' || _financeTypeFilter == 'salaries')
        salarySection(),
      if (_financeTypeFilter == 'all' || _financeTypeFilter == 'funds')
        fundSection(),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.26),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final info = Column(
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
                            'Finance Center',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Manage fees, salaries, funds, and expenses separately.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Monthly fee and salary records are auto-generated as pending. Use the sections below to filter by date, edit transactions, and mark pending records as paid.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    );

                    final quickActions = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (canManage)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: _openCreateFeeRoute,
                            icon: const Icon(Icons.payments_rounded),
                            label: const Text('Collect Fee'),
                          ),
                        if (canManage)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: _openCreateSalaryRoute,
                            icon: const Icon(Icons.badge_rounded),
                            label: const Text('Add Salary'),
                          ),
                        if (canManage)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _openCreateExpenseRoute,
                            icon: const Icon(Icons.shopping_bag_rounded),
                            label: const Text('Add Expense'),
                          ),
                        if (canManage)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _openCreateFundRoute,
                            icon: const Icon(Icons.volunteer_activism_rounded),
                            label: const Text('Add Fund'),
                          ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          info,
                          const SizedBox(height: 14),
                          quickActions,
                        ],
                      );
                    }

                    final quickActionsWidth = constraints.maxWidth < 980
                        ? 270.0
                        : 360.0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: info),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: quickActionsWidth,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: quickActions,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                statStrip([
                  summaryCard(
                    title: 'Collected Fees',
                    value: _money(_totalFees),
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF0EA5E9),
                    subtitle: 'Paid only',
                  ),
                  summaryCard(
                    title: 'Pending Fees',
                    value: _money(_pendingFeesAmount),
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFF59E0B),
                    subtitle: 'Auto-generated monthly dues',
                  ),
                  summaryCard(
                    title: 'Paid Salaries',
                    value: _money(_totalSalaries),
                    icon: Icons.badge_rounded,
                    color: const Color(0xFF7C3AED),
                    subtitle: 'Paid only',
                  ),
                  summaryCard(
                    title: 'Pending Salaries',
                    value: _money(_pendingSalariesAmount),
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFF59E0B),
                    subtitle: 'Awaiting payout',
                  ),
                  summaryCard(
                    title: 'Available Balance',
                    value: _money(_balance),
                    icon: Icons.account_balance_wallet_outlined,
                    color: _balance >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    subtitle: 'Uses paid transactions only',
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Narrow the finance view by module and transaction date.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    moduleChip(
                      label: 'All',
                      value: 'all',
                      icon: Icons.apps_rounded,
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    moduleChip(
                      label: 'Fees',
                      value: 'fees',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 8),
                    moduleChip(
                      label: 'Expenses',
                      value: 'expenses',
                      icon: Icons.shopping_bag_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    moduleChip(
                      label: 'Salaries',
                      value: 'salaries',
                      icon: Icons.badge_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    moduleChip(
                      label: 'Funds',
                      value: 'funds',
                      icon: Icons.volunteer_activism_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () {
                      final now = DateTime.now();
                      _updateState(() {
                        _financeStartDate = DateTime(now.year, now.month, 1);
                        _financeEndDate = DateTime(now.year, now.month + 1, 0);
                      });
                    },
                    child: const Text('This Month'),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () {
                      final now = DateTime.now();
                      _updateState(() {
                        _financeStartDate = DateTime(
                          now.year,
                          now.month,
                          now.day,
                        );
                        _financeEndDate = DateTime(
                          now.year,
                          now.month,
                          now.day,
                        );
                      });
                    },
                    child: const Text('Today'),
                  ),
                  dateButton(
                    label: 'From',
                    value: _financeStartDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _financeStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _updateState(() => _financeStartDate = picked);
                      }
                    },
                  ),
                  dateButton(
                    label: 'To',
                    value: _financeEndDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _financeEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _updateState(() => _financeEndDate = picked);
                      }
                    },
                  ),
                  if (_financeStartDate != null || _financeEndDate != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () {
                        _updateState(() {
                          _financeStartDate = null;
                          _financeEndDate = null;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear Date Filter'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$totalVisibleRecords record(s) found in current filters.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (totalVisibleRecords == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _emptyState(
              title: 'No finance records found',
              subtitle:
                  'Use the module cards below to add fee, expense, salary, or fund transactions.',
              icon: Icons.receipt_long_outlined,
            ),
          ),
        Column(
          children: [
            for (int i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  bool _financeFeeFilter(FeeRecord item) {
    return _matchesFinanceDateRange(item.createdAt);
  }

  bool _financeSalaryFilter(SalaryRecord item) {
    return _matchesFinanceDateRange(item.createdAt);
  }
}
