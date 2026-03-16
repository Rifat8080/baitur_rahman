part of '../home_screen.dart';

extension _DashboardSection on _HomeScreenState {
  Widget _buildDashboardPage() {
    final students = _students.length;
    final teachers = _teachers.length;
    final presentCount = _data.attendance.where((item) => item.present).length;
    final attendancePercent = _data.attendance.isEmpty
        ? 0.0
        : (presentCount / _data.attendance.length) * 100;

    const cardColors = [
      Color(0xFF0D9488),
      Color(0xFF16A34A),
      Color(0xFF0EA5E9),
      Color(0xFF7C3AED),
      Color(0xFFD97706),
      Color(0xFFDC2626),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(
          constraints.maxWidth,
          mobile: 1,
          tablet: 2,
          desktop: 3,
        );
        final gapTotal = (columns - 1) * 14.0;
        final itemWidth = (constraints.maxWidth - gapTotal) / columns;

        final cards = [
          _metricCard(
            title: 'Total Users',
            value: '${_data.users.length}',
            subtitle: '$students students • $teachers teachers',
            icon: Icons.groups_rounded,
            accentColor: cardColors[0],
          ),
          _metricCard(
            title: 'Current Balance',
            value: _money(_balance),
            subtitle: 'Funds + Fees − Expenses − Salaries',
            icon: Icons.account_balance_wallet_rounded,
            accentColor: cardColors[1],
          ),
          _metricCard(
            title: 'Attendance Rate',
            value: '${attendancePercent.toStringAsFixed(1)}%',
            subtitle: 'Present: $presentCount / ${_data.attendance.length}',
            icon: Icons.check_circle_rounded,
            accentColor: cardColors[2],
          ),
          _metricCard(
            title: 'Published Results',
            value: '${_data.results.length}',
            subtitle: 'Across all students',
            icon: Icons.workspace_premium_rounded,
            accentColor: cardColors[3],
          ),
          _metricCard(
            title: 'Monthly Income',
            value: _money(_totalFunds + _totalFees),
            subtitle: 'Fees + Funds',
            icon: Icons.trending_up_rounded,
            accentColor: cardColors[4],
          ),
          _metricCard(
            title: 'Monthly Expense',
            value: _money(_totalExpenses + _totalSalaries),
            subtitle: 'Expenses + Salaries',
            icon: Icons.trending_down_rounded,
            accentColor: cardColors[5],
          ),
        ];

        final quickActionsData =
            [
                  (
                    label: 'Users',
                    icon: Icons.groups_rounded,
                    color: cardColors[0],
                  ),
                  (
                    label: 'Finance',
                    icon: Icons.payments_rounded,
                    color: cardColors[1],
                  ),
                  (
                    label: 'Attendance',
                    icon: Icons.fact_check_rounded,
                    color: cardColors[2],
                  ),
                  (
                    label: 'Results',
                    icon: Icons.workspace_premium_rounded,
                    color: cardColors[3],
                  ),
                  (
                    label: 'Reports',
                    icon: Icons.print_rounded,
                    color: cardColors[4],
                  ),
                  (
                    label: 'Backup',
                    icon: Icons.backup_rounded,
                    color: cardColors[5],
                  ),
                ]
                .where(
                  (item) =>
                      _destinationsForRole().any((d) => d.label == item.label),
                )
                .toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            _buildGreetingBanner(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF0EA5E9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7C3AED,
                              ).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (int i = 0; i < quickActionsData.length; i++) ...[
                          SizedBox(
                            width: 132,
                            child: _quickAction(
                              title: quickActionsData[i].label,
                              icon: quickActionsData[i].icon,
                              color: quickActionsData[i].color,
                              onTap: () =>
                                  _openPageByLabel(quickActionsData[i].label),
                            ),
                          ),
                          if (i != quickActionsData.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final card in cards)
                  SizedBox(width: itemWidth, child: card),
              ],
            ),
            const SizedBox(height: 20),
            _activityListCard(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
