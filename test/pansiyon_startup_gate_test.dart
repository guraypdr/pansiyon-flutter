import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/pansiyon_file_memory.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_startup_gate.dart';

void main() {
  const gate = PansiyonStartupGate();
  late Directory rootDirectory;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_startup_gate_test',
    );
  });

  tearDown(() async {
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  test('hiç dosya seçilmemişse başlangıç ekranı gerekir', () async {
    final decision = await gate.resolve(memory: InMemoryPansiyonFileMemory());

    expect(decision.mode, PansiyonStartupMode.needsPansiyonFile);
    expect(decision.filePath, isNull);
    expect(decision.lastFileMissing, isFalse);
  });

  test('boş yol kayıtlıysa başlangıç ekranı gerekir', () async {
    final decision = await gate.resolve(
      memory: InMemoryPansiyonFileMemory('   '),
    );

    expect(decision.mode, PansiyonStartupMode.needsPansiyonFile);
  });

  test('seçilmiş geçerli dosya otomatik açılır', () async {
    final info = await PansiyonFileService().createEmptyPansiyonFile(
      pansiyonName: 'Aktif Pansiyon',
      directory: rootDirectory,
    );
    expect(info.filePath, endsWith('Aktif Pansiyon.pansiyon'));

    final decision = await gate.resolve(
      memory: InMemoryPansiyonFileMemory(info.filePath),
    );

    expect(decision.mode, PansiyonStartupMode.rememberedPansiyon);
    expect(decision.filePath, info.filePath);
    expect(decision.lastFileMissing, isFalse);
  });

  test('seçilmiş dosya silinmişse başlangıç ekranı gerekir', () async {
    final decision = await gate.resolve(
      memory: InMemoryPansiyonFileMemory(
        path.join(rootDirectory.path, 'yok.pansiyon'),
      ),
    );

    expect(decision.mode, PansiyonStartupMode.needsPansiyonFile);
    expect(decision.lastFileMissing, isTrue);
  });

  test('seçilmiş dosya bozulmuşsa başlangıç ekranı gerekir', () async {
    final brokenPath = path.join(rootDirectory.path, 'bozuk.pansiyon');
    await File(brokenPath).writeAsString('SQLite olmayan dosya');

    final decision = await gate.resolve(
      memory: InMemoryPansiyonFileMemory(brokenPath),
    );

    expect(decision.mode, PansiyonStartupMode.needsPansiyonFile);
    expect(decision.lastFileMissing, isTrue);
  });

  test(
    'varsayılan pansiyon.db varlığı otomatik açma sebebi değildir',
    () async {
      final legacyDirectory = Directory(
        path.join(rootDirectory.path, 'pansiyon_yonetim'),
      );
      await legacyDirectory.create(recursive: true);
      await File(path.join(legacyDirectory.path, 'pansiyon.db')).writeAsBytes([
        ...'SQLite format 3'.codeUnits,
        0,
        ...List<int>.filled(2048, 7),
      ]);

      final decision = await gate.resolve(memory: InMemoryPansiyonFileMemory());

      expect(decision.mode, PansiyonStartupMode.needsPansiyonFile);
    },
  );
}
