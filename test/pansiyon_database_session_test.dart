import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('özel .pansiyon yolunu açar ve mevcut sürümü kullanır', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_session_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = path.join(
      directory.path,
      'Ahmet Yılmaz Anadolu Lisesi.pansiyon',
    );
    final session = PansiyonDatabaseSession(databasePath: databasePath);
    addTearDown(session.close);

    await session.open();
    final database = await session.database.database;
    final versionRows = await database.rawQuery('PRAGMA user_version');

    expect(await session.activePath(), databasePath);
    expect(session.usesDefaultPath, isFalse);
    expect(PansiyonDatabaseSession.pansiyonFileExtension, '.pansiyon');
    expect(versionRows.single.values.single, 8);
  });

  test('varsayılan session mevcut pansiyon.db yolunu korur', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_session_default_path_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return directory.path;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathProviderChannel, null);
    });
    final session = PansiyonDatabaseSession();
    addTearDown(session.close);

    expect(session.usesDefaultPath, isTrue);
    expect(session.configuredPath, isNull);
    expect(await session.activePath(), endsWith('pansiyon.db'));
  });

  test('close await edilebilir ve session yeniden açılabilir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_session_close_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final session = PansiyonDatabaseSession(
      databasePath: path.join(directory.path, 'active.pansiyon'),
    );
    addTearDown(session.close);

    await session.open();
    await session.close();
    await session.open();

    expect(await session.activePath(), endsWith('active.pansiyon'));
  });

  test('gelecekte farklı .pansiyon dosyasına geçiş yapabilir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_session_switch_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final firstPath = path.join(directory.path, 'ortaokul.pansiyon');
    final secondPath = path.join(directory.path, 'lise.pansiyon');
    final session = PansiyonDatabaseSession(databasePath: firstPath);
    addTearDown(session.close);

    await session.open();
    await session.switchToPath(secondPath);
    final database = await session.database.database;
    final versionRows = await database.rawQuery('PRAGMA user_version');

    expect(await session.activePath(), secondPath);
    expect(File(firstPath).existsSync(), isTrue);
    expect(File(secondPath).existsSync(), isTrue);
    expect(versionRows.single.values.single, 8);
  });
}
