part of '../home_screen.dart';

extension _BackupSection on _HomeScreenState {
  Widget _buildBackupPage() {
    final scheme = Theme.of(context).colorScheme;
    final canBackup = _canUseBackup();
    final totalRecords =
        _data.users.length +
        _data.fees.length +
        _data.attendance.length +
        _data.expenses.length +
        _data.salaries.length +
        _data.funds.length +
        _data.results.length;

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

    Widget featureTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: scheme.surfaceContainerLow,
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
        ),
      );
    }

    Widget actionCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback? onPressed,
      required String buttonLabel,
      bool primary = true,
    }) {
      return _glassCard(
        accentColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: primary
                  ? FilledButton.icon(
                      onPressed: onPressed,
                      icon: Icon(icon),
                      label: Text(buttonLabel),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: onPressed,
                      icon: Icon(icon),
                      label: Text(buttonLabel),
                    ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.24),
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
                    'Secure Backup Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Protect your data with encrypted export and verified restore.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Backups are exported as encrypted files secured with your passphrase, and imports verify integrity before replacing live data.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                statStrip([
                  summaryCard(
                    title: 'Encrypted Exports',
                    value: 'AES-256',
                    icon: Icons.enhanced_encryption_outlined,
                    color: Colors.white,
                    subtitle: 'GCM authenticated encryption',
                  ),
                  summaryCard(
                    title: 'Stored Records',
                    value: '$totalRecords',
                    icon: Icons.dataset_linked_outlined,
                    color: const Color(0xFFBFDBFE),
                    subtitle: 'Across all backup modules',
                  ),
                  summaryCard(
                    title: 'Import Safety',
                    value: 'Verified',
                    icon: Icons.verified_user_outlined,
                    color: const Color(0xFF86EFAC),
                    subtitle: 'Passphrase + integrity checked',
                  ),
                  summaryCard(
                    title: 'Access Control',
                    value: canBackup ? 'Allowed' : 'Restricted',
                    icon: Icons.admin_panel_settings_outlined,
                    color: canBackup
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFFCA5A5),
                    subtitle: 'Admin / manager / accountant only',
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: actionCard(
                      title: 'Export Secure Backup',
                      subtitle:
                          'Create a password-protected encrypted backup file for transfer or archive.',
                      icon: Icons.file_download_outlined,
                      color: const Color(0xFF16A34A),
                      onPressed: canBackup ? _exportData : null,
                      buttonLabel: 'Create Encrypted Backup',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: actionCard(
                      title: 'Import & Restore',
                      subtitle:
                          'Decrypt a secure backup, verify it, and replace current data only after confirmation.',
                      icon: Icons.file_upload_outlined,
                      color: const Color(0xFF2563EB),
                      onPressed: canBackup ? _importData : null,
                      buttonLabel: 'Import Backup File',
                      primary: false,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                actionCard(
                  title: 'Export Secure Backup',
                  subtitle:
                      'Create a password-protected encrypted backup file for transfer or archive.',
                  icon: Icons.file_download_outlined,
                  color: const Color(0xFF16A34A),
                  onPressed: canBackup ? _exportData : null,
                  buttonLabel: 'Create Encrypted Backup',
                ),
                const SizedBox(height: 14),
                actionCard(
                  title: 'Import & Restore',
                  subtitle:
                      'Decrypt a secure backup, verify it, and replace current data only after confirmation.',
                  icon: Icons.file_upload_outlined,
                  color: const Color(0xFF2563EB),
                  onPressed: canBackup ? _importData : null,
                  buttonLabel: 'Import Backup File',
                  primary: false,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security & Recovery Notes',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Recommended practices for secure backup export and restore.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              featureTile(
                icon: Icons.lock_outline_rounded,
                title: 'Use a strong passphrase',
                subtitle:
                    'Every new export is encrypted. Keep the passphrase safe because the backup cannot be restored without it.',
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 12),
              featureTile(
                icon: Icons.sync_problem_outlined,
                title: 'Imports replace current data',
                subtitle:
                    'Before restore, the app shows a summary and asks for confirmation to prevent accidental overwrite.',
                color: const Color(0xFFEA580C),
              ),
              const SizedBox(height: 12),
              featureTile(
                icon: Icons.history_toggle_off_outlined,
                title: 'Legacy support kept',
                subtitle:
                    'Older unencrypted JSON backups can still be imported, but the app warns before using them.',
                color: const Color(0xFF2563EB),
              ),
              if (!canBackup) ...[
                const SizedBox(height: 14),
                Text(
                  'Only admin, manager, or accountant accounts can import or export backups.',
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backup Contents',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Everything included when a secure backup is exported.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Chip(label: Text('Users: ${_data.users.length}')),
                  Chip(label: Text('Fees: ${_data.fees.length}')),
                  Chip(label: Text('Attendance: ${_data.attendance.length}')),
                  Chip(label: Text('Expenses: ${_data.expenses.length}')),
                  Chip(label: Text('Salaries: ${_data.salaries.length}')),
                  Chip(label: Text('Funds: ${_data.funds.length}')),
                  Chip(label: Text('Results: ${_data.results.length}')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
