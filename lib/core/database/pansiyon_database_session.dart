import 'package:pansiyon_yonetim/core/database/app_database.dart';

class PansiyonDatabaseSession {
  PansiyonDatabaseSession({String? databasePath})
    : _database = AppDatabase(databasePath: databasePath),
      _configuredPath = databasePath;

  static const pansiyonFileExtension = '.pansiyon';

  AppDatabase _database;
  String? _configuredPath;

  AppDatabase get database => _database;

  String? get configuredPath => _configuredPath;

  bool get usesDefaultPath => _configuredPath == null;

  Future<String> activePath() => _database.filePath();

  Future<void> open() async {
    await _database.database;
  }

  Future<void> close() async {
    await _database.close();
  }

  Future<void> switchToPath(String databasePath) async {
    final nextPath = databasePath.trim();
    if (nextPath.isEmpty) {
      throw ArgumentError.value(
        databasePath,
        'databasePath',
        'Veritabanı yolu boş olamaz.',
      );
    }
    if (_configuredPath == nextPath) {
      await open();
      return;
    }

    final previousDatabase = _database;
    await previousDatabase.close();

    final nextDatabase = AppDatabase(databasePath: nextPath);
    try {
      await nextDatabase.database;
    } catch (_) {
      try {
        await previousDatabase.database;
      } catch (_) {}
      rethrow;
    }

    _database = nextDatabase;
    _configuredPath = nextPath;
  }
}
