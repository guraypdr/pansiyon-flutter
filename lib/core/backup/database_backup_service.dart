import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';

class DatabaseBackup {
  const DatabaseBackup({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Geri yükleme sırasında oluşan hata.
class DatabaseRestoreException implements Exception {
  const DatabaseRestoreException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class DatabaseBackupService {
  DatabaseBackupService(
    this._appDatabase, {
    String? backupDirectoryPath,
    PansiyonFileService? fileService,
  }) : _backupDirectoryPath = backupDirectoryPath,
       fileService = fileService ?? PansiyonFileService();

  static const _sqliteHeader = 'SQLite format 3\x00';

  final AppDatabase _appDatabase;
  final String? _backupDirectoryPath;
  final PansiyonFileService fileService;

  /// Yedeği `.pansiyon` uzantısıyla, pansiyon adını dosya adına yazarak alır.
  ///
  /// Böylece yedek doğrudan bir pansiyon dosyası olarak açılabilir.
  Future<DatabaseBackup> createBackup({String? fileNamePrefix}) async {
    final livePath = await _appDatabase.filePath();
    final directory = await _backupDirectory(livePath);
    final timestamp = _timestamp();
    final prefix = fileNamePrefix ?? await _pansiyonNameOrFallback();
    final fileName = fileService.fileNameForPansiyon('$prefix $timestamp');
    final backupPath = path.join(directory.path, fileName);
    final database = await _appDatabase.database;
    await database.execute("VACUUM INTO '${_escapePath(backupPath)}'");
    return _backupFromFile(backupPath);
  }

  Future<List<DatabaseBackup>> listBackups() async {
    final livePath = await _appDatabase.filePath();
    final directory = await _backupDirectory(livePath);
    final backups = <DatabaseBackup>[];
    await for (final entity in directory.list()) {
      if (entity is File && _isBackupFile(entity.path)) {
        final backupFile = entity;
        backups.add(await _backupFromFile(backupFile.path));
      }
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// Yedeği aktif veritabanına geri yükler.
  ///
  /// Sıralama güvenliğin içindir:
  /// 1. Seçilen dosya **aktif dosyaya dokunulmadan** tam olarak doğrulanır.
  /// 2. Mevcut durumun yedeği alınır (geri dönüş noktası).
  /// 3. Aktif veritabanı kapatılır, yan dosyalar temizlenir, yedek kopyalanır.
  /// 4. Kopyalama sonrası tekrar doğrulanır; doğrulama başarısızsa yedek
  ///    otomatik olarak geri alınır.
  Future<void> restoreBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw const DatabaseRestoreException('Yedek dosyası bulunamadı.');
    }
    await _assertSqliteFile(backupFile);
    try {
      await fileService.validateFile(backupPath, requireCurrentVersion: false);
    } on PansiyonFileException catch (error) {
      throw DatabaseRestoreException(
        'Seçtiğiniz dosya geçerli bir pansiyon yedeği değil.',
        cause: error,
      );
    }

    final livePath = await _appDatabase.filePath();
    final safetyBackup = await createBackup(
      fileNamePrefix: 'geri-yukleme-oncesi',
    );

    await _appDatabase.close();
    await _removeSidecarFiles(livePath);
    try {
      await backupFile.copy(livePath);
      await _appDatabase.database;
      await fileService.validateFile(livePath, requireCurrentVersion: false);
    } catch (error) {
      await _rollback(livePath, safetyBackup);
      throw DatabaseRestoreException(
        'Yedek geri yüklenemedi. Mevcut verileriniz korundu.',
        cause: error,
      );
    }
  }

  Future<void> _rollback(String livePath, DatabaseBackup safetyBackup) async {
    try {
      await _appDatabase.close();
      await _removeSidecarFiles(livePath);
      await File(safetyBackup.path).copy(livePath);
      await _appDatabase.database;
    } catch (_) {
      // Geri alma da başarısız olursa yedek dosya kullanıcıda durur.
    }
  }

  Future<Directory> _backupDirectory(String livePath) async {
    if (_backupDirectoryPath != null) {
      final directory = Directory(_backupDirectoryPath);
      await directory.create(recursive: true);
      return directory;
    }
    final directory = Directory(path.join(path.dirname(livePath), 'backups'));
    await directory.create(recursive: true);
    return directory;
  }

  bool _isBackupFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.pansiyon' ||
        extension == '.db' ||
        extension == '.sqlite' ||
        extension == '.sqlite3';
  }

  Future<DatabaseBackup> _backupFromFile(String backupPath) async {
    final file = File(backupPath);
    final stat = await file.stat();
    return DatabaseBackup(
      path: backupPath,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<String> _pansiyonNameOrFallback() async {
    try {
      final database = await _appDatabase.database;
      final rows = await database.query(
        'boarding_school_info',
        columns: ['school_name'],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      final value = rows.isEmpty ? null : rows.first['school_name'] as String?;
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return 'pansiyon';
      }
      return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
    } catch (_) {
      return 'pansiyon';
    }
  }

  Future<void> _removeSidecarFiles(String livePath) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final file = File('$livePath$suffix');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _assertSqliteFile(File backupFile) async {
    final stat = await backupFile.stat();
    if (stat.size < 100) {
      throw const DatabaseRestoreException('Geçerli bir SQLite yedeği değil.');
    }
    final header = await backupFile.openRead(0, 16).first;
    final headerText = String.fromCharCodes(header);
    if (headerText != _sqliteHeader) {
      throw const DatabaseRestoreException('Geçerli bir SQLite yedeği değil.');
    }
  }

  String _timestamp() {
    return DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
  }

  String _escapePath(String value) {
    return value.replaceAll("'", "''");
  }
}
