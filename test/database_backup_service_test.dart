import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/backup/database_backup_service.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

void main() {
  test('yedek oluşturur, listeler ve geri yükler', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pansiyon-yedek-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final livePath = path.join(temporaryDirectory.path, 'pansiyon.db');
    final database = AppDatabase(databasePath: livePath);
    addTearDown(database.close);
    final boardingInfoRepository = SqliteBoardingInfoRepository(database);
    final backupService = DatabaseBackupService(
      database,
      backupDirectoryPath: path.join(temporaryDirectory.path, 'yedekler'),
    );

    await boardingInfoRepository.save(
      const BoardingInfoDraft(
        schoolName: 'İlk Pansiyon',
        principalName: 'Ayşe Yılmaz',
        principalPhone: '0312 555 10 10',
        deputyName: 'Mehmet Demir',
        deputyPhone: '0312 555 10 11',
        boardingType: BoardingType.girls,
        educationLevel: EducationLevel.middleSchool,
        blocks: [],
      ),
    );
    final backup = await backupService.createBackup();
    expect(File(backup.path).existsSync(), isTrue);

    await boardingInfoRepository.save(
      const BoardingInfoDraft(
        schoolName: 'Değişmiş Pansiyon',
        principalName: 'Ayşe Yılmaz',
        principalPhone: '0312 555 10 10',
        deputyName: 'Mehmet Demir',
        deputyPhone: '0312 555 10 11',
        boardingType: BoardingType.girls,
        educationLevel: EducationLevel.middleSchool,
        blocks: [],
      ),
    );

    await backupService.restoreBackup(backup.path);
    final restored = await boardingInfoRepository.load();
    final backups = await backupService.listBackups();

    expect(restored?.schoolName, 'İlk Pansiyon');
    expect(backups.map((item) => item.path), contains(backup.path));
    expect(backups.length, greaterThanOrEqualTo(2));
  });

  test('geçersiz yedek dosyasını reddeder', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pansiyon-yedek-hatali-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final database = AppDatabase(
      databasePath: path.join(temporaryDirectory.path, 'pansiyon.db'),
    );
    addTearDown(database.close);
    final backupService = DatabaseBackupService(database);
    final invalidBackup = File(path.join(temporaryDirectory.path, 'bozuk.db'));
    await invalidBackup.writeAsString('bu bir sqlite dosyası değil');

    await expectLater(
      () => backupService.restoreBackup(invalidBackup.path),
      throwsFormatException,
    );
  });
}
