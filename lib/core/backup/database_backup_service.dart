import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/app_database.dart';

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

class DatabaseBackupService {
  DatabaseBackupService(this._appDatabase, {String? backupDirectoryPath})
    : _backupDirectoryPath = backupDirectoryPath;

  static const _sqliteHeader = 'SQLite format 3\x00';

  final AppDatabase _appDatabase;
  final String? _backupDirectoryPath;

  Future<DatabaseBackup> createBackup({String? fileNamePrefix}) async {
    final livePath = await _appDatabase.filePath();
    final directory = await _backupDirectory(livePath);
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final fileName = '${fileNamePrefix ?? 'pansiyon'}-$timestamp.db';
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

  Future<void> restoreBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw const FileSystemException('Yedek dosyası bulunamadı.');
    }
    await _assertSqliteFile(backupFile);

    final livePath = await _appDatabase.filePath();
    await createBackup(fileNamePrefix: 'geri-yukleme-oncesi');
    await _appDatabase.close();
    try {
      await backupFile.copy(livePath);
    } finally {
      await _appDatabase.database;
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
    return extension == '.db' ||
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

  Future<void> _assertSqliteFile(File backupFile) async {
    final stat = await backupFile.stat();
    if (stat.size < 100) {
      throw const FormatException('Geçerli bir SQLite yedeği değil.');
    }
    final header = await backupFile.openRead(0, 16).first;
    final bytes = Uint8List.fromList(header);
    final headerText = String.fromCharCodes(bytes);
    if (headerText != _sqliteHeader) {
      throw const FormatException('Geçerli bir SQLite yedeği değil.');
    }
  }

  String _escapePath(String value) {
    return value.replaceAll("'", "''");
  }
}
