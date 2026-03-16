import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/finance/presentation/expense_form_page.dart';
import '../../features/finance/presentation/fee_form_page.dart';
import '../../features/finance/presentation/fund_form_page.dart';
import '../../features/finance/presentation/salary_form_page.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/users/presentation/user_form_page.dart';

// ─── Auth Notifier ────────────────────────────────────────────────────────────
// go_router listens to this to re-evaluate redirect guards on every change.

class AppAuthNotifier extends ChangeNotifier {
  static final instance = AppAuthNotifier._();

  AppAuthNotifier._();

  static const _prefKey = 'madrasah_active_user_id';

  String? _userId;

  String? get currentUserId => _userId;
  bool get isLoggedIn => _userId != null;

  /// Loads persisted auth state from SharedPreferences (called at startup).
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_prefKey);
    notifyListeners();
  }

  Future<void> login(String userId) async {
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, userId);
    notifyListeners();
  }

  Future<void> logout() async {
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    notifyListeners();
  }
}

// ─── Theme Notifier ───────────────────────────────────────────────────────────

class AppThemeNotifier extends ChangeNotifier {
  static final instance = AppThemeNotifier._();

  AppThemeNotifier._();

  static const _prefKey = 'madrasah_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, mode == ThemeMode.dark);
    notifyListeners();
  }
}

// ─── Router ───────────────────────────────────────────────────────────────────

/// Named route paths used throughout the app.
class AppRoutes {
  static const login = '/login';
  static const dashboard = '/app/dashboard';
  static const users = '/app/users';
  static const usersNew = '/app/users/new';
  static const finance = '/app/finance';
  static const feeNew = '/app/finance/fee/new';
  static const expenseNew = '/app/finance/expense/new';
  static const salaryNew = '/app/finance/salary/new';
  static const fundNew = '/app/finance/fund/new';
  static const attendance = '/app/attendance';
  static const results = '/app/results';
  static const reports = '/app/reports';
  static const backup = '/app/backup';

  static String usersEdit(String id) => '/app/users/$id/edit';
  static String feeEdit(String id) => '/app/finance/fee/$id/edit';
  static String expenseEdit(String id) => '/app/finance/expense/$id/edit';
  static String salaryEdit(String id) => '/app/finance/salary/$id/edit';
  static String fundEdit(String id) => '/app/finance/fund/$id/edit';

  // Maps nav-bar label → route path.
  static String sectionPath(String label) => '/app/${label.toLowerCase()}';

  // Maps route path → section name passed to HomeScreen.
  static String pathToSection(String path) {
    final parts = path.split('/');
    return parts.length >= 3 ? parts[2] : 'dashboard';
  }
}

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: AppAuthNotifier.instance,
    redirect: _guard,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),

      GoRoute(
        path: AppRoutes.usersNew,
        name: 'users_new',
        builder: (_, __) => const UserFormPage(),
      ),

      GoRoute(
        path: '/app/users/:id/edit',
        name: 'users_edit',
        builder: (_, state) => UserFormPage(userId: state.pathParameters['id']),
      ),

      GoRoute(
        path: AppRoutes.feeNew,
        name: 'fee_new',
        builder: (_, __) => const FeeFormPage(),
      ),
      GoRoute(
        path: '/app/finance/fee/:id/edit',
        name: 'fee_edit',
        builder: (_, state) => FeeFormPage(feeId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.expenseNew,
        name: 'expense_new',
        builder: (_, __) => const ExpenseFormPage(),
      ),
      GoRoute(
        path: '/app/finance/expense/:id/edit',
        name: 'expense_edit',
        builder: (_, state) =>
            ExpenseFormPage(expenseId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.salaryNew,
        name: 'salary_new',
        builder: (_, __) => const SalaryFormPage(),
      ),
      GoRoute(
        path: '/app/finance/salary/:id/edit',
        name: 'salary_edit',
        builder: (_, state) =>
            SalaryFormPage(salaryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.fundNew,
        name: 'fund_new',
        builder: (_, __) => const FundFormPage(),
      ),
      GoRoute(
        path: '/app/finance/fund/:id/edit',
        name: 'fund_edit',
        builder: (_, state) => FundFormPage(fundId: state.pathParameters['id']),
      ),

      // All authenticated pages share the same HomeScreen shell.
      // The `:section` path parameter drives which tab is visible.
      GoRoute(
        path: '/app/:section',
        name: 'app',
        builder: (context, state) {
          final section = state.pathParameters['section'] ?? 'dashboard';
          return HomeScreen(section: section);
        },
      ),

      // Root → redirect handled by guard below.
      GoRoute(path: '/', redirect: (_, __) => AppRoutes.login),
    ],
  );

  static String? _guard(BuildContext context, GoRouterState state) {
    final loggedIn = AppAuthNotifier.instance.isLoggedIn;
    final onLogin = state.matchedLocation == AppRoutes.login;

    if (!loggedIn && !onLogin) return AppRoutes.login;
    if (loggedIn && onLogin) return AppRoutes.dashboard;
    return null;
  }
}
