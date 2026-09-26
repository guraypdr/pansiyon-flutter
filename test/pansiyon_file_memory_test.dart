import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory rootDirectory;
  late FileSystemPansiyonFileMemory memory;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_file_memory_test',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return rootDirectory.path;
      }
      return null;
    });
    memory = FileSystemPansiyonFileMemory();
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  File memoryFile() => File(
    '${rootDirectory.path}\\${FileSystemPansiyonFileMemory.directoryName}\\'
    '${memory.fileName}',
  );

  test('ilk durumda kayıtlı dosya yoktur', () async {
    expect(await memory.readLastFilePath(), isNull);
  });

  test('dosya yolu yazılır ve okunur', () async {
    await memory.writeLastFilePath('C:\\Pansiyonlar\\aktif.pansiyon');

    expect(await memory.readLastFilePath(), 'C:\\Pansiyonlar\\aktif.pansiyon');
    expect(memoryFile().existsSync(), isTrue);
  });

  test('sonraki yazma önceki değeri değiştirir', () async {
    await memory.writeLastFilePath('C:\\Pansiyonlar\\bir.pansiyon');
    await memory.writeLastFilePath('C:\\Pansiyonlar\\iki.pansiyon');

    expect(await memory.readLastFilePath(), 'C:\\Pansiyonlar\\iki.pansiyon');
  });

  test('null yazmak kaydı temizler', () async {
    await memory.writeLastFilePath('C:\\Pansiyonlar\\bir.pansiyon');
    await memory.writeLastFilePath(null);

    expect(await memory.readLastFilePath(), isNull);
    expect(memoryFile().existsSync(), isFalse);
  });

  test('boş yol kaydedilmez', () async {
    await memory.writeLastFilePath('   ');

    expect(await memory.readLastFilePath(), isNull);
  });

  test('bellek içi uygulama hatırlamayı tutar', () async {
    final inMemory = InMemoryPansiyonFileMemory();
    expect(await inMemory.readLastFilePath(), isNull);

    await inMemory.writeLastFilePath('C:\\Pansiyonlar\\bir.pansiyon');
    expect(await inMemory.readLastFilePath(), 'C:\\Pansiyonlar\\bir.pansiyon');

    await inMemory.writeLastFilePath(null);
    expect(await inMemory.readLastFilePath(), isNull);
  });
}
