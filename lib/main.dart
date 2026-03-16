import 'package:flutter/material.dart';

import 'app/madrasah_app.dart';
import 'core/database/app_repository.dart';
import 'core/router/app_router.dart';
import 'features/shared/domain/monthly_record_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise database (SQLite on native, SharedPreferences JSON on web).
  await AppRepository.initialize();

  // Restore persisted auth state & theme preference.
  await Future.wait([
    AppAuthNotifier.instance.restore(),
    AppThemeNotifier.instance.restore(),
  ]);

  // Auto-generate pending fee / salary records for the current month.
  await MonthlyRecordService.generateCurrentMonth();

  runApp(const MadrasahApp());
}
