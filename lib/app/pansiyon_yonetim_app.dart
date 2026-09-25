import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/layout/app_shell.dart';

class PansiyonYonetimApp extends StatelessWidget {
  const PansiyonYonetimApp({super.key, this.database});

  final AppDatabase? database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pansiyon Yönetim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: AppShell(database: database),
    );
  }
}
