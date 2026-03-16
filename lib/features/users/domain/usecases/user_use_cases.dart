import '../../../shared/domain/app_models.dart';
import '../../../shared/domain/repositories/madrasah_repository.dart';

class UserFormLoadResult {
  const UserFormLoadResult({
    required this.allUsers,
    required this.currentUser,
    required this.editingUser,
  });

  final List<AppUser> allUsers;
  final AppUser? currentUser;
  final AppUser? editingUser;
}

class UserUseCases {
  UserUseCases({required MadrasahRepository repository})
    : _repository = repository;

  final MadrasahRepository _repository;

  Future<UserFormLoadResult> loadUserFormData({
    required String? currentUserId,
    required String? editingUserId,
  }) async {
    final data = await _repository.loadAll();

    AppUser? currentUser;
    if (currentUserId != null) {
      for (final user in data.users) {
        if (user.id == currentUserId) {
          currentUser = user;
          break;
        }
      }
    }

    AppUser? editingUser;
    if (editingUserId != null) {
      for (final user in data.users) {
        if (user.id == editingUserId) {
          editingUser = user;
          break;
        }
      }
    }

    return UserFormLoadResult(
      allUsers: data.users,
      currentUser: currentUser,
      editingUser: editingUser,
    );
  }

  bool usernameExists({
    required List<AppUser> users,
    required String username,
    String? excludingUserId,
  }) {
    for (final user in users) {
      if (user.id == excludingUserId) {
        continue;
      }
      if (user.username.toLowerCase() == username.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Future<void> upsertUser(AppUser user) {
    return _repository.upsertUser(user);
  }
}
