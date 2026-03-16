part of '../home_screen.dart';

extension _AttendanceSection on _HomeScreenState {
  Widget _buildAttendancePage() {
    final canManage = _canManageAttendance();
    final scheme = Theme.of(context).colorScheme;

    final query = _attendanceSearchQuery.trim().toLowerCase();

    final filteredAttendance = _data.attendance.where((item) {
      final userName = (_userById(item.userId)?.name ?? 'Deleted user')
          .toLowerCase();
      final status = item.present ? 'present' : 'absent';
      final matchesQuery =
          query.isEmpty ||
          userName.contains(query) ||
          status.contains(query) ||
          _dateText(item.date).toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (_attendanceStatusFilter == 'present' && !item.present) {
        return false;
      }
      if (_attendanceStatusFilter == 'absent' && item.present) {
        return false;
      }

      return _matchesAttendanceDateRange(item.date);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    final total = _data.attendance.length;
    final presentCount = _data.attendance.where((item) => item.present).length;
    final absentCount = total - presentCount;
    final presentRate = total == 0 ? 0 : (presentCount * 100 / total);

    final visiblePresent = filteredAttendance
        .where((item) => item.present)
        .length;
    final visibleAbsent = filteredAttendance.length - visiblePresent;

    Widget summaryCard({
      required String label,
      required String value,
      required IconData icon,
      required Color color,
      String? subtitle,
    }) {
      return Container(
        width: 205,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.13),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget filterChip({
      required String label,
      required String value,
      required IconData icon,
      required Color color,
    }) {
      final selected = _attendanceStatusFilter == value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _updateState(() => _attendanceStatusFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    String dateText(DateTime dt) {
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    }

    Widget dateButton({
      required String label,
      required DateTime? value,
      required VoidCallback onTap,
    }) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.event_outlined),
        label: Text(value == null ? label : '$label: ${dateText(value)}'),
      );
    }

    Widget recordCard(AttendanceRecord item) {
      final user = _userById(item.userId);
      final statusColor = item.present
          ? const Color(0xFF16A34A)
          : const Color(0xFFDC2626);
      final statusLabel = item.present ? 'Present' : 'Absent';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    item.present
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Deleted user',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user == null
                            ? 'User no longer exists'
                            : '${user.role.label} • ${user.group}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0EA5E9,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 12,
                                  color: Color(0xFF0EA5E9),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  dateText(item.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0EA5E9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmAction(
                        title: 'Delete attendance?',
                        message:
                            'This attendance entry will be removed permanently.',
                        confirmLabel: 'Delete',
                        isDestructive: true,
                      );
                      if (!confirmed) return;
                      await _commitMutation(
                        _homeMutationUseCases.deleteAttendance(
                          data: _data,
                          attendanceId: item.id,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget attendanceForm() {
      return _glassCard(
        accentColor: const Color(0xFF0EA5E9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark Attendance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Select user and attendance status for today.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserForAttendance,
              items: _data.users
                  .map(
                    (user) => DropdownMenuItem(
                      value: user.id,
                      child: Text('${user.name} (${user.role.label})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _updateState(() => _selectedUserForAttendance = value),
              decoration: const InputDecoration(
                labelText: 'User',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _attendancePresent,
              onChanged: canManage
                  ? (value) => _updateState(() => _attendancePresent = value)
                  : null,
              title: const Text('Present today'),
              subtitle: Text(
                _attendancePresent
                    ? 'Will be marked present'
                    : 'Will be marked absent',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canManage ? _addAttendance : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Attendance'),
              ),
            ),
          ],
        ),
      );
    }

    final recordsWidget = filteredAttendance.isEmpty
        ? _emptyState(
            title: _data.attendance.isEmpty
                ? 'No attendance records yet'
                : 'No records for this filter',
            subtitle: _data.attendance.isEmpty
                ? 'Save attendance to start building timeline history.'
                : 'Try changing search, status, or date filters.',
            icon: Icons.event_busy_outlined,
          )
        : Column(
            children: [
              for (int i = 0; i < filteredAttendance.length; i++) ...[
                recordCard(filteredAttendance[i]),
                if (i != filteredAttendance.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          );

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0EA5E9), Color(0xFF0D9488)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 10),
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
                    final compact = constraints.maxWidth < 820;

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
                            'Attendance Center',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Track daily presence clearly.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Use search, status and date filters for quick attendance review.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    );

                    final quickAction = canManage
                        ? FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 42),
                            ),
                            onPressed: _addAttendance,
                            icon: const Icon(Icons.task_alt_rounded),
                            label: const Text('Save Today Attendance'),
                          )
                        : const SizedBox.shrink();

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          info,
                          if (canManage) ...[
                            const SizedBox(height: 14),
                            quickAction,
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: info),
                        if (canManage) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 280,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: quickAction,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      summaryCard(
                        label: 'Total Records',
                        value: '$total',
                        icon: Icons.fact_check_outlined,
                        color: const Color(0xFFFFFFFF),
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        label: 'Present',
                        value: '$presentCount',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFFD1FAE5),
                        subtitle: '$visiblePresent in current filter',
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        label: 'Absent',
                        value: '$absentCount',
                        icon: Icons.cancel_outlined,
                        color: const Color(0xFFFECACA),
                        subtitle: '$visibleAbsent in current filter',
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        label: 'Present Rate',
                        value: '${presentRate.toStringAsFixed(1)}%',
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFFBFDBFE),
                      ),
                    ],
                  ),
                ),
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
                'Search and filter attendance by status and date.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) {
                  _updateState(() => _attendanceSearchQuery = value.trim());
                },
                decoration: const InputDecoration(
                  labelText: 'Search attendance',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    filterChip(
                      label: 'All',
                      value: 'all',
                      icon: Icons.list_alt_rounded,
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    filterChip(
                      label: 'Present',
                      value: 'present',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    filterChip(
                      label: 'Absent',
                      value: 'absent',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      final now = DateTime.now();
                      _updateState(() {
                        _attendanceStartDate = DateTime(
                          now.year,
                          now.month,
                          now.day,
                        );
                        _attendanceEndDate = DateTime(
                          now.year,
                          now.month,
                          now.day,
                        );
                      });
                    },
                    child: const Text('Today'),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      final now = DateTime.now();
                      final start = DateTime(
                        now.year,
                        now.month,
                        now.day,
                      ).subtract(Duration(days: now.weekday - 1));
                      final end = start.add(const Duration(days: 6));
                      _updateState(() {
                        _attendanceStartDate = start;
                        _attendanceEndDate = end;
                      });
                    },
                    child: const Text('This Week'),
                  ),
                  dateButton(
                    label: 'From',
                    value: _attendanceStartDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _attendanceStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _updateState(() => _attendanceStartDate = picked);
                      }
                    },
                  ),
                  dateButton(
                    label: 'To',
                    value: _attendanceEndDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _attendanceEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _updateState(() => _attendanceEndDate = picked);
                      }
                    },
                  ),
                  if (_attendanceStartDate != null ||
                      _attendanceEndDate != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        _updateState(() {
                          _attendanceStartDate = null;
                          _attendanceEndDate = null;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear Date Filter'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1060;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: attendanceForm()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _glassCard(
                      accentColor: const Color(0xFF0D9488),
                      child: recordsWidget,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                attendanceForm(),
                const SizedBox(height: 12),
                _glassCard(
                  accentColor: const Color(0xFF0D9488),
                  child: recordsWidget,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
