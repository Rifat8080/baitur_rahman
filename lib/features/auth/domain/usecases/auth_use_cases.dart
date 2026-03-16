import 'package:uuid/uuid.dart';

import '../../../shared/domain/app_models.dart';
import '../../../shared/domain/repositories/madrasah_repository.dart';

class AuthUseCases {
  AuthUseCases({required MadrasahRepository repository})
    : _repository = repository;

  final MadrasahRepository _repository;
  static const _uuid = Uuid();

  Future<void> ensureDefaultAdminExists() async {
    final data = await _repository.loadAll();
    final hasAdmin = data.users.any(
      (user) => user.role == AppRole.admin && user.username.trim().isNotEmpty,
    );
    if (hasAdmin) {
      return;
    }

    await _repository.upsertUser(
      AppUser(
        id: _uuid.v4(),
        name: 'System Admin',
        username: 'admin',
        password: 'admin123',
        role: AppRole.admin,
        phone: 'N/A',
        group: 'Administration',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<AppUser?> authenticate({
    required String username,
    required String password,
  }) async {
    await ensureDefaultAdminExists();
    final data = await _repository.loadAll();

    for (final user in data.users) {
      if (user.username == username && user.password == password) {
        return user;
      }
    }
    return null;
  }
}
