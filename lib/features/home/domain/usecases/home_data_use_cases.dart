import '../../../shared/domain/app_models.dart';
import '../../../shared/domain/repositories/madrasah_repository.dart';

class HomeDataUseCases {
  HomeDataUseCases({required MadrasahRepository repository})
    : _repository = repository;

  final MadrasahRepository _repository;

  Future<AppData> loadData() {
    return _repository.loadAll();
  }

  Future<void> replaceAll(AppData data) {
    return _repository.replaceAll(data);
  }

  Future<Map<String, dynamic>> exportBackupJson() {
    return _repository.exportJson();
  }

  Future<void> importBackupJson(Map<String, dynamic> json) {
    return _repository.importJson(json);
  }
}
