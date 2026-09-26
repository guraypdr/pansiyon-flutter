import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_memory.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_startup_gate.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/data/pansiyon_file_dialogs.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/presentation/pansiyon_start_page.dart';
import 'package:pansiyon_yonetim/shared/layout/app_shell.dart';

class PansiyonYonetimApp extends StatefulWidget {
  const PansiyonYonetimApp({
    super.key,
    this.database,
    this.session,
    this.pansiyonFileDialogs,
    this.pansiyonFileActions,
    this.pansiyonFileMemory,
  }) : assert(database == null || session == null);

  final AppDatabase? database;
  final PansiyonDatabaseSession? session;

  /// Test veya ilerideki platform özeliteleri için diyalog sağlayıcısı.
  final PansiyonFileDialogs? pansiyonFileDialogs;

  /// Test için dosya eylem sağlayıcısı. Verilmezse gerçek controller kullanılır.
  final PansiyonFileActions? pansiyonFileActions;

  /// Test için son kullanılan dosya hafızası.
  final PansiyonFileMemory? pansiyonFileMemory;

  @override
  State<PansiyonYonetimApp> createState() => _PansiyonYonetimAppState();
}

class _PansiyonYonetimAppState extends State<PansiyonYonetimApp> {
  static const _startupGate = PansiyonStartupGate();

  PansiyonDatabaseSession? _providedSession;
  PansiyonDatabaseSession? _ownedSession;
  AppDatabase? _providedDatabase;
  PansiyonStartupMode _startupMode = PansiyonStartupMode.rememberedPansiyon;
  bool _isLastFileMissing = false;
  int _shellGeneration = 0;

  PansiyonDatabaseSession? get _session => _providedSession ?? _ownedSession;

  @override
  void initState() {
    super.initState();
    final providedSession = widget.session;
    final providedDatabase = widget.database;
    if (providedSession != null) {
      _providedSession = providedSession;
    } else if (providedDatabase != null) {
      _providedDatabase = providedDatabase;
    } else {
      _startupMode = PansiyonStartupMode.checking;
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    unawaited(_ownedSession?.close());
    super.dispose();
  }

  /// Yalnızca daha önce seçilmiş pansiyon dosyası varsa otomatik açılır.
  Future<void> _bootstrap() async {
    final memory = widget.pansiyonFileMemory ?? FileSystemPansiyonFileMemory();
    var decision = const PansiyonStartupDecision.needsPansiyonFile();
    try {
      decision = await _startupGate.resolve(memory: memory);
    } catch (_) {
      decision = const PansiyonStartupDecision.needsPansiyonFile();
    }
    if (!mounted) {
      return;
    }

    final filePath = decision.filePath;
    if (decision.mode == PansiyonStartupMode.rememberedPansiyon &&
        filePath != null) {
      setState(() {
        _ownedSession = PansiyonDatabaseSession(databasePath: filePath);
        _startupMode = PansiyonStartupMode.rememberedPansiyon;
        _isLastFileMissing = false;
      });
      return;
    }

    setState(() {
      // Oturum başlangıç ekranının veritabanı işlemleri için gerekli.
      _ownedSession ??= PansiyonDatabaseSession();
      _startupMode = PansiyonStartupMode.needsPansiyonFile;
      _isLastFileMissing = decision.lastFileMissing;
    });
  }

  void _handlePansiyonActivated(PansiyonActivationResult result) {
    if (!mounted) {
      return;
    }
    final memory = widget.pansiyonFileMemory ?? FileSystemPansiyonFileMemory();
    unawaited(memory.writeLastFilePath(result.filePath));
    setState(() {
      _startupMode = PansiyonStartupMode.rememberedPansiyon;
      _isLastFileMissing = false;
      _shellGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pansiyon Yönetim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_startupMode == PansiyonStartupMode.checking) {
      return const _StartupSplash(key: Key('app_startup_splash'));
    }

    final session = _session;
    if (_startupMode == PansiyonStartupMode.needsPansiyonFile &&
        session != null) {
      final dialogs = widget.pansiyonFileDialogs;
      final actions = widget.pansiyonFileActions;
      return PansiyonStartPage(
        key: ValueKey('pansiyon_start_$_shellGeneration'),
        controller: actions ?? PansiyonFileController(session: session),
        boardingInfoRepository: SqliteBoardingInfoRepository(session.database),
        dialogs: dialogs ?? const FilePickerPansiyonFileDialogs(),
        lastFileMissing: _isLastFileMissing,
        onPansiyonActivated: _handlePansiyonActivated,
      );
    }

    return AppShell(
      key: ValueKey('app_shell_$_shellGeneration'),
      database: _providedDatabase,
      session: session,
      pansiyonFileActions: widget.pansiyonFileActions,
      pansiyonFileDialogs: widget.pansiyonFileDialogs,
      onPansiyonActivated: _handlePansiyonActivated,
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: AppColors.surface,
                size: 30,
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
