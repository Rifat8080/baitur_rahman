import 'package:flutter/material.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class MadrasahApp extends StatefulWidget {
  const MadrasahApp({super.key});

  @override
  State<MadrasahApp> createState() => _MadrasahAppState();
}

class _MadrasahAppState extends State<MadrasahApp> {
  @override
  void initState() {
    super.initState();
    // Rebuild whenever the theme changes.
    AppThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Madrasah Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: AppThemeNotifier.instance.themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
