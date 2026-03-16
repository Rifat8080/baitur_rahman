part of '../home_screen.dart';

extension _ResultsSection on _HomeScreenState {
  Widget _buildResultsPage() {
    final scheme = Theme.of(context).colorScheme;
    final canManage = _canManageResults();
    final visibleResults = _visibleResults.where((result) {
      final query = _resultSearchQuery.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      final studentName =
          (_userById(result.studentId)?.name ?? 'Deleted student')
              .toLowerCase();
      return studentName.contains(query) ||
          result.exam.toLowerCase().contains(query) ||
          result.marks.toStringAsFixed(2).contains(query) ||
          result.totalMarks.toStringAsFixed(2).contains(query);
    }).toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    double percentageOf(ResultRecord result) {
      if (result.totalMarks <= 0) {
        return 0;
      }
      return ((result.marks / result.totalMarks) * 100)
          .clamp(0, 100)
          .toDouble();
    }

    Color scoreColor(double percentage) {
      if (percentage >= 80) return const Color(0xFF16A34A);
      if (percentage >= 50) return const Color(0xFFD97706);
      return const Color(0xFFDC2626);
    }

    String scoreLabel(double percentage) {
      if (percentage >= 80) return 'Excellent';
      if (percentage >= 65) return 'Good';
      if (percentage >= 50) return 'Average';
      return 'Needs Improvement';
    }

    final averagePercentage = visibleResults.isEmpty
        ? 0.0
        : visibleResults
                  .map(percentageOf)
                  .fold<double>(0, (sum, item) => sum + item) /
              visibleResults.length;
    final bestPercentage = visibleResults.isEmpty
        ? 0.0
        : visibleResults.map(percentageOf).reduce((a, b) => a > b ? a : b);
    final uniqueExamCount = visibleResults
        .map((item) => item.exam.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .length;

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

    Widget infoChip({
      required IconData icon,
      required String label,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    Widget resultRow(ResultRecord result) {
      final student = _userById(result.studentId);
      final percentage = percentageOf(result);
      final color = scoreColor(percentage);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student?.name ?? 'Deleted student',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.exam,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    scoreLabel(percentage),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    tooltip: 'Actions',
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem<int>(
                        value: 0,
                        onTap: () async {
                          final confirmed = await _confirmAction(
                            title: 'Delete result?',
                            message:
                                'This result entry will be removed permanently.',
                            confirmLabel: 'Delete',
                            isDestructive: true,
                          );
                          if (!confirmed) {
                            return;
                          }
                          await _commitMutation(
                            _homeMutationUseCases.deleteResult(
                              data: _data,
                              resultId: result.id,
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                infoChip(
                  icon: Icons.calendar_today_outlined,
                  label: _dateText(result.publishedAt),
                  color: const Color(0xFF7C3AED),
                ),
                infoChip(
                  icon: Icons.groups_rounded,
                  label: student?.group.isNotEmpty == true
                      ? student!.group
                      : 'No class',
                  color: const Color(0xFF0EA5E9),
                ),
                infoChip(
                  icon: Icons.calculate_outlined,
                  label:
                      '${result.marks.toStringAsFixed(0)}/${result.totalMarks.toStringAsFixed(0)}',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: percentage / 100,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget publishForm() {
      return _glassCard(
        accentColor: const Color(0xFF7C3AED),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.publish_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publish Result',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a polished result entry for any student in the system.',
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
            DropdownButtonFormField<String>(
              initialValue: _selectedStudentForResult,
              items: _students
                  .map(
                    (student) => DropdownMenuItem(
                      value: student.id,
                      child: Text('${student.name} (${student.group})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _updateState(() => _selectedStudentForResult = value),
              decoration: const InputDecoration(labelText: 'Student'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _resultExamController,
              decoration: const InputDecoration(
                labelText: 'Exam name',
                prefixIcon: Icon(Icons.assignment_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _resultMarksController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Obtained marks',
                      prefixIcon: Icon(Icons.scoreboard_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _resultTotalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total marks',
                      prefixIcon: Icon(Icons.functions_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _publishResult,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish Result'),
              ),
            ),
          ],
        ),
      );
    }

    Widget resultsList() {
      if (visibleResults.isEmpty) {
        return _emptyState(
          title: 'No results yet',
          subtitle: 'Published student results will appear here.',
          icon: Icons.query_stats_outlined,
        );
      }

      return Column(
        children: [
          for (int i = 0; i < visibleResults.length; i++) ...[
            resultRow(visibleResults[i]),
            if (i != visibleResults.length - 1) const SizedBox(height: 12),
          ],
        ],
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
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
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
                        'Results Center',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Review academic performance with a cleaner, faster workflow.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Search by student or exam, publish new marks, and keep report-card-ready results in one place.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    statStrip([
                      summaryCard(
                        title: 'Visible Results',
                        value: '${visibleResults.length}',
                        icon: Icons.fact_check_outlined,
                        color: Colors.white,
                        subtitle: 'Based on current search',
                      ),
                      summaryCard(
                        title: 'Average Score',
                        value: '${averagePercentage.toStringAsFixed(1)}%',
                        icon: Icons.timeline_rounded,
                        color: const Color(0xFF93C5FD),
                        subtitle: 'Across visible records',
                      ),
                      summaryCard(
                        title: 'Best Score',
                        value: '${bestPercentage.toStringAsFixed(1)}%',
                        icon: Icons.emoji_events_outlined,
                        color: const Color(0xFFFBBF24),
                        subtitle: 'Highest visible result',
                      ),
                      summaryCard(
                        title: 'Exam Types',
                        value: '$uniqueExamCount',
                        icon: Icons.school_outlined,
                        color: const Color(0xFFC4B5FD),
                        subtitle: 'Unique exams in view',
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
                    'Search & Filter',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search using student name, exam name, obtained marks, or total marks.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) {
                      _updateState(() => _resultSearchQuery = value.trim());
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search results',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (canManage && wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: publishForm()),
                  const SizedBox(width: 14),
                  Expanded(child: resultsList()),
                ],
              )
            else ...[
              if (canManage) publishForm(),
              if (canManage) const SizedBox(height: 14),
              resultsList(),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
