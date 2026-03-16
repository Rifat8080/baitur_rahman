part of '../home_screen.dart';

extension _UsersSection on _HomeScreenState {
  String _attachmentName(String path) {
    final normalized = path.replaceAll('\\\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? path : parts.last;
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  void _showUserAttachments(AppUser user) {
    final attachments = user.attachments;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${user.name} • Attachments'),
          content: SizedBox(
            width: 540,
            child: attachments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No attachments available for this user.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final path = attachments[index];
                      final isImage = _isImagePath(path);

                      Widget preview;
                      if (isImage && !kIsWeb && File(path).existsSync()) {
                        preview = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(path),
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 26,
                            ),
                          ),
                        );
                      } else {
                        preview = Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isImage
                                ? Icons.image_outlined
                                : Icons.insert_drive_file_outlined,
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            preview,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _attachmentName(path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersPage() {
    final canManage = _canManageUsers();
    final scheme = Theme.of(context).colorScheme;
    final roleCounts = <AppRole, int>{
      for (final role in AppRole.values)
        role: _data.users.where((user) => user.role == role).length,
    };
    final newThisMonth = _data.users
        .where(
          (user) =>
              user.createdAt.year == DateTime.now().year &&
              user.createdAt.month == DateTime.now().month,
        )
        .length;

    Color roleColor(AppRole role) => switch (role) {
      AppRole.admin => const Color(0xFFDC2626),
      AppRole.manager => const Color(0xFF0D9488),
      AppRole.accountant => const Color(0xFF2563EB),
      AppRole.teacher => const Color(0xFF7C3AED),
      AppRole.student => const Color(0xFFD97706),
    };

    IconData roleIcon(AppRole role) => switch (role) {
      AppRole.admin => Icons.shield_outlined,
      AppRole.manager => Icons.manage_accounts_outlined,
      AppRole.accountant => Icons.account_balance_wallet_outlined,
      AppRole.teacher => Icons.menu_book_outlined,
      AppRole.student => Icons.school_outlined,
    };

    final filteredUsers = _data.users.where((user) {
      final query = _userSearchQuery.trim().toLowerCase();
      final roleMatch = _userRoleFilter == null
          ? true
          : user.role == _userRoleFilter;
      if (!roleMatch) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          user.group.toLowerCase().contains(query) ||
          user.role.label.toLowerCase().contains(query);
    }).toList();

    Widget statCard({
      required String label,
      required String value,
      required IconData icon,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final usersList = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: filteredUsers.isEmpty
          ? _emptyState(
              title: _data.users.isEmpty ? 'No users yet' : 'No match found',
              subtitle: _data.users.isEmpty
                  ? 'Create users to get started.'
                  : 'Try changing your search or role filter.',
              icon: Icons.person_off_outlined,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = _columnsForWidth(
                  constraints.maxWidth,
                  mobile: 1,
                  tablet: 2,
                  desktop: 3,
                );
                final gap = 12.0;
                final itemWidth =
                    (constraints.maxWidth - ((columns - 1) * gap)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final user in filteredUsers)
                      SizedBox(
                        width: itemWidth,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: canManage
                                ? () => _openEditUserRoute(user.id)
                                : null,
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    scheme.surfaceContainerLow,
                                    scheme.surfaceContainerLowest,
                                  ],
                                ),
                                border: Border.all(
                                  color: roleColor(
                                    user.role,
                                  ).withValues(alpha: 0.22),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: roleColor(
                                      user.role,
                                    ).withValues(alpha: 0.10),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                roleColor(user.role),
                                                roleColor(
                                                  user.role,
                                                ).withValues(alpha: 0.68),
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              user.name.isEmpty
                                                  ? '?'
                                                  : user.name
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '@${user.username}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          enabled: true,
                                          tooltip: 'User actions',
                                          onSelected: (value) {
                                            if (value == 'attachments') {
                                              _showUserAttachments(user);
                                            }
                                            if (value == 'edit' && canManage) {
                                              _openEditUserRoute(user.id);
                                            }
                                            if (value == 'delete' &&
                                                canManage) {
                                              _deleteUser(user.id);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'attachments',
                                              child: ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                leading: Icon(
                                                  Icons.attach_file_outlined,
                                                ),
                                                title: Text('View attachments'),
                                              ),
                                            ),
                                            if (canManage)
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                  title: Text('Edit user'),
                                                ),
                                              ),
                                            if (canManage)
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  title: Text('Delete user'),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color: roleColor(
                                              user.role,
                                            ).withValues(alpha: 0.12),
                                            border: Border.all(
                                              color: roleColor(
                                                user.role,
                                              ).withValues(alpha: 0.24),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                roleIcon(user.role),
                                                size: 15,
                                                color: roleColor(user.role),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                user.role.label,
                                                style: TextStyle(
                                                  color: roleColor(user.role),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color:
                                                scheme.surfaceContainerHighest,
                                          ),
                                          child: Text(
                                            user.group.isEmpty
                                                ? 'No group assigned'
                                                : user.group,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: scheme.surface.withValues(
                                          alpha: 0.65,
                                        ),
                                        border: Border.all(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone_outlined,
                                                size: 16,
                                                color: scheme.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  user.phone,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today_outlined,
                                                size: 16,
                                                color: scheme.tertiary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Joined ${_dateText(user.createdAt)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _showUserAttachments(user),
                                            icon: const Icon(
                                              Icons.attach_file_outlined,
                                            ),
                                            label: Text(
                                              'Attachments (${user.attachments.length})',
                                            ),
                                          ),
                                        ),
                                        if (canManage) ...[
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: FilledButton.tonalIcon(
                                              onPressed: () =>
                                                  _openEditUserRoute(user.id),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              label: const Text('Edit'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _sectionHeader(
          title: 'User Management',
          subtitle: 'Create and manage role-based accounts.',
          icon: Icons.groups_outlined,
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D9488), Color(0xFF0EA5E9)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final infoBlock = Column(
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
                          'People Directory',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Beautifully manage every account in one modern workspace.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Monitor roles, refine access, and keep your madrasah team neatly organized.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.45,
                        ),
                      ),
                    ],
                  );

                  final actionButton = canManage
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D9488),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                            onPressed: _openCreateUserRoute,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('New User'),
                          ),
                        )
                      : null;

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoBlock,
                        if (actionButton != null) ...[
                          const SizedBox(height: 14),
                          actionButton,
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: infoBlock),
                      if (actionButton != null) ...[
                        const SizedBox(width: 12),
                        actionButton,
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final items = [
                    statCard(
                      label: 'Total Users',
                      value: '${_data.users.length}',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFFFFFFFF),
                    ),
                    statCard(
                      label: 'Filtered View',
                      value: '${filteredUsers.length}',
                      icon: Icons.filter_alt_outlined,
                      color: const Color(0xFFECFEFF),
                    ),
                    statCard(
                      label: 'Joined This Month',
                      value: '$newThisMonth',
                      icon: Icons.auto_awesome_outlined,
                      color: const Color(0xFFF5F3FF),
                    ),
                  ];

                  if (compact) {
                    return Column(
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          items[i],
                          if (i != items.length - 1) const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        Expanded(child: items[i]),
                        if (i != items.length - 1) const SizedBox(width: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search & refine',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) {
                  _updateState(() => _userSearchQuery = value.trim());
                },
                decoration: InputDecoration(
                  labelText: 'Search by name, username, role, or group',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _userSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () =>
                              _updateState(() => _userSearchQuery = ''),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _userRoleFilter == null,
                        label: Text('All • ${_data.users.length}'),
                        onSelected: (_) =>
                            _updateState(() => _userRoleFilter = null),
                      ),
                    ),
                    for (final role in AppRole.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            roleIcon(role),
                            size: 16,
                            color: roleColor(role),
                          ),
                          selected: _userRoleFilter == role,
                          label: Text(
                            '${role.label} • ${roleCounts[role] ?? 0}',
                          ),
                          onSelected: (_) =>
                              _updateState(() => _userRoleFilter = role),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        usersList,
      ],
    );
  }
}
