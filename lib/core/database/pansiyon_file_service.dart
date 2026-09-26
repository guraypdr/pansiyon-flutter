import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:pansiyon_yonetim/core/database/sqflite_bootstrap.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PansiyonFileException implements Exception {
  const PansiyonFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PansiyonFileExistsException extends PansiyonFileException {
  PansiyonFileExistsException(this.filePath)
    : super('Pansiyon dosyası zaten mevcut: $filePath');

  final String filePath;
}

class PansiyonFileCreationException extends PansiyonFileException {
  PansiyonFileCreationException(String filePath, Object error)
    : super('Pansiyon dosyası oluşturulamadı ($filePath): $error');
}

enum PansiyonFileIssue {
  missingFile,
  invalidHeader,
  unsupportedVersion,
  missingTables,
  integrityCheckFailed,
  unknown,
}

class PansiyonFileValidationException extends PansiyonFileException {
  PansiyonFileValidationException(
    String filePath,
    this.reason, {
    this.issue = PansiyonFileIssue.unknown,
  }) : super('Pansiyon dosyası doğrulanamadı ($filePath): $reason');

  final String reason;
  final PansiyonFileIssue issue;
}

class PansiyonFileInfo {
  const PansiyonFileInfo({
    required this.filePath,
    required this.databaseVersion,
    required this.integrityCheck,
    this.pansiyonName,
  });

  final String filePath;
  final int databaseVersion;
  final String integrityCheck;
  final String? pansiyonName;
}

class PansiyonFileService {
  static const fileExtension = PansiyonDatabaseSession.pansiyonFileExtension;

  static const _requiredTables = <String>{
    'boarding_school_info',
    'boarding_blocks',
    'boarding_floors',
    'boarding_rooms',
    'room_assignments',
    'schools',
    'students',
    'student_attendance',
    'student_discipline_incidents',
  };

  /// Sürüm 1'den itibaren var olan temel tablolar.
  static const _legacyRequiredTables = <String>{
    'boarding_school_info',
    'boarding_blocks',
    'boarding_floors',
  };

  static const _reservedWindowsNames = <String>{
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  String fileNameForPansiyon(String pansiyonName) {
    var baseName = pansiyonName.trim().replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '-',
    );
    baseName = baseName.replaceAll(RegExp(r'\s+'), ' ').trim();
    baseName = baseName.replaceAll(RegExp(r'^[.]+'), '');
    baseName = baseName.replaceAll(RegExp(r'[ .]+$'), '');
    if (baseName.isEmpty) {
      baseName = 'pansiyon';
    }
    if (_reservedWindowsNames.contains(baseName.toUpperCase())) {
      baseName = 'pansiyon_$baseName';
    }
    if (baseName.toLowerCase().endsWith(fileExtension)) {
      return baseName;
    }
    return '$baseName$fileExtension';
  }

  Future<PansiyonFileInfo> createEmptyPansiyonFile({
    required String pansiyonName,
    required Directory directory,
  }) async {
    final fileName = fileNameForPansiyon(pansiyonName);
    final targetPath = path.join(directory.path, fileName);
    final targetFile = File(targetPath);
    final temporaryPath = _temporaryPath(targetPath);
    final temporaryFile = File(temporaryPath);

    try {
      await directory.create(recursive: true);
      if (await targetFile.exists()) {
        throw PansiyonFileExistsException(targetPath);
      }

      final database = AppDatabase(databasePath: temporaryPath);
      try {
        await database.database;
      } finally {
        await database.close();
      }

      final info = await validateFile(temporaryPath);
      await temporaryFile.rename(targetPath);
      return PansiyonFileInfo(
        filePath: targetPath,
        databaseVersion: info.databaseVersion,
        integrityCheck: info.integrityCheck,
        pansiyonName: pansiyonName,
      );
    } catch (error) {
      await _deleteDatabaseFiles(temporaryPath);
      if (error is PansiyonFileException) {
        rethrow;
      }
      throw PansiyonFileCreationException(targetPath, error);
    }
  }

  Future<PansiyonFileInfo> convertExistingDatabase({
    required PansiyonDatabaseSession sourceSession,
    required Directory directory,
    String? pansiyonName,
  }) async {
    final sourcePath = await sourceSession.activePath();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw PansiyonFileValidationException(
        sourcePath,
        'Kaynak dosya bulunamadı.',
        issue: PansiyonFileIssue.missingFile,
      );
    }

    final sourceDatabase = await sourceSession.database.database;
    final name = pansiyonName ?? await _readPansiyonName(sourceDatabase);
    final fileName = fileNameForPansiyon(name);
    final targetPath = path.join(directory.path, fileName);
    final targetFile = File(targetPath);
    final temporaryPath = _temporaryPath(targetPath);
    final temporaryFile = File(temporaryPath);

    if (path.equals(path.normalize(sourcePath), path.normalize(targetPath))) {
      throw const PansiyonFileException(
        'Kaynak ve hedef pansiyon dosyası aynı olamaz.',
      );
    }

    try {
      await directory.create(recursive: true);
      if (await targetFile.exists()) {
        throw PansiyonFileExistsException(targetPath);
      }
      await sourceDatabase.execute(
        "VACUUM INTO '${_escapeSqlPath(temporaryPath)}'",
      );
      final info = await validateFile(temporaryPath);
      await temporaryFile.rename(targetPath);
      return PansiyonFileInfo(
        filePath: targetPath,
        databaseVersion: info.databaseVersion,
        integrityCheck: info.integrityCheck,
        pansiyonName: name,
      );
    } catch (error) {
      await _deleteDatabaseFiles(temporaryPath);
      if (error is PansiyonFileException) {
        rethrow;
      }
      throw PansiyonFileCreationException(targetPath, error);
    }
  }

  /// Bir `.pansiyon` dosyasını doğrular.
  ///
  /// [requireCurrentVersion] `false` ise uygulamanın kendi sürümünden eski
  /// dosyalar da kabul edilir; bu durumda dosya açılırken `AppDatabase`
  /// `onUpgrade` zinciri ile yükseltilir.
  Future<PansiyonFileInfo> validateFile(
    String filePath, {
    bool requireCurrentVersion = true,
  }) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) {
        throw PansiyonFileValidationException(
          filePath,
          'Dosya bulunamadı.',
          issue: PansiyonFileIssue.missingFile,
        );
      }
      final header = await file.openRead(0, 16).first;
      const expectedHeader = 'SQLite format 3\x00';
      if (header.length != 16 ||
          String.fromCharCodes(header) != expectedHeader) {
        throw PansiyonFileValidationException(
          filePath,
          'Geçerli bir SQLite dosyası değil.',
          issue: PansiyonFileIssue.invalidHeader,
        );
      }

      ensureSqfliteFfiInitialized();
      Database? database;
      try {
        database = await openDatabase(
          filePath,
          readOnly: true,
          singleInstance: false,
        );
        final versionRows = await database.rawQuery('PRAGMA user_version');
        final version = _asInt(versionRows.single.values.single);
        if (version == null || version <= 0) {
          throw PansiyonFileValidationException(
            filePath,
            'Bu dosya bir pansiyon veritabanı değil.',
            issue: PansiyonFileIssue.missingTables,
          );
        }
        if (version > AppDatabase.databaseVersion) {
          throw PansiyonFileValidationException(
            filePath,
            'Dosya sürümü uygulamadan yeni: $version.',
            issue: PansiyonFileIssue.unsupportedVersion,
          );
        }
        final isOlderVersion = version < AppDatabase.databaseVersion;
        if (isOlderVersion && requireCurrentVersion) {
          throw PansiyonFileValidationException(
            filePath,
            'Desteklenmeyen veritabanı sürümü: $version.',
            issue: PansiyonFileIssue.unsupportedVersion,
          );
        }

        final integrityRows = await database.rawQuery('PRAGMA integrity_check');
        final integrityCheck = integrityRows.first.values.first.toString();
        if (integrityCheck != 'ok') {
          throw PansiyonFileValidationException(
            filePath,
            'SQLite bütünlük kontrolü başarısız: $integrityCheck.',
            issue: PansiyonFileIssue.integrityCheckFailed,
          );
        }

        final tableRows = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        );
        final tables = tableRows.map((row) => row['name'] as String).toSet();
        // Eski sürümlerde tam tablo listesi geçerli olmayabilir; yükseltme
        // sonrasında tam doğrulama yapılır.
        final requiredTables = isOlderVersion
            ? _legacyRequiredTables
            : _requiredTables;
        final missingTables = requiredTables.difference(tables);
        if (missingTables.isNotEmpty) {
          throw PansiyonFileValidationException(
            filePath,
            'Eksik tablolar: ${missingTables.join(', ')}.',
            issue: PansiyonFileIssue.missingTables,
          );
        }

        final name = await _readPansiyonName(database);
        return PansiyonFileInfo(
          filePath: filePath,
          databaseVersion: version,
          integrityCheck: integrityCheck,
          pansiyonName: name,
        );
      } finally {
        await database?.close();
      }
    } on PansiyonFileException {
      rethrow;
    } catch (error) {
      throw PansiyonFileValidationException(filePath, error.toString());
    }
  }

  /// Doğrulanmış dosyayı açar; eski sürümlüyse önce yedek alıp yükseltir.
  Future<PansiyonDatabaseSession> openSession(String filePath) async {
    final info = await validateFile(filePath, requireCurrentVersion: false);
    if (info.databaseVersion >= AppDatabase.databaseVersion) {
      return _openSessionAtCurrentVersion(filePath);
    }

    await _createVersionBackup(filePath, info.databaseVersion);
    final session = await _openSessionAtCurrentVersion(filePath);
    // Yükseltme sonrası tam doğrulama.
    await validateFile(filePath);
    return session;
  }

  Future<PansiyonDatabaseSession> _openSessionAtCurrentVersion(
    String filePath,
  ) async {
    final session = PansiyonDatabaseSession(databasePath: filePath);
    try {
      await session.open();
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  /// Yükseltmeden önce dosyanın yanına yedek kopyası oluşturur.
  ///
  /// Yedek asla üzerine yazılmaz; kullanıcı verisi için geri dönüş noktasıdır.
  Future<void> _createVersionBackup(String filePath, int oldVersion) async {
    try {
      final source = File(filePath);
      if (!await source.exists()) {
        return;
      }
      final baseName = path.basenameWithoutExtension(filePath);
      final backupPath = path.join(
        path.dirname(filePath),
        '$baseName v$oldVersion yedek$fileExtension',
      );
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        return;
      }
      await source.copy(backupPath);
    } catch (_) {
      // Yedek alınamazsa yükseltme yine de denenir.
    }
  }

  Future<String> _readPansiyonName(Database database) async {
    final rows = await database.query(
      'boarding_school_info',
      columns: ['school_name'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return 'pansiyon';
    }
    final value = rows.first['school_name'] as String?;
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'pansiyon' : trimmed;
  }

  String _temporaryPath(String targetPath) {
    return '$targetPath.tmp-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _escapeSqlPath(String value) {
    return value.replaceAll("'", "''");
  }

  Future<void> _deleteDatabaseFiles(String databasePath) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
