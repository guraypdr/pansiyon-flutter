import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/backup/database_backup_service.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _firstDraft = BoardingInfoDraft(
  schoolName: 'İlk Pansiyon',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.girls,
  educationLevel: EducationLevel.middleSchool,
  blocks: [],
);

const _secondDraft = BoardingInfoDraft(
  schoolName: 'Değişmiş Pansiyon',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.girls,
  educationLevel: EducationLevel.middleSchool,
  blocks: [],
);

void main() {
  late Directory temporaryDirectory;
  late String livePath;
  late AppDatabase database;
  late BoardingInfoRepository boardingInfoRepository;
  late DatabaseBackupService backupService;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'pansiyon-yedek-',
    );
    livePath = path.join(temporaryDirectory.path, 'pansiyon.db');
    database = AppDatabase(databasePath: livePath);
    boardingInfoRepository = SqliteBoardingInfoRepository(database);
    backupService = DatabaseBackupService(
      database,
      backupDirectoryPath: path.join(temporaryDirectory.path, 'yedekler'),
    );
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      try {
        await temporaryDirectory.delete(recursive: true);
      } on FileSystemException {
        // Dosya kilitleri geçici olarak tutulabilir.
      }
    }
  });

  test('yedek .pansiyon uzantısıyla ve pansiyon adıyla oluşur', () async {
    await boardingInfoRepository.save(_firstDraft);

    final backup = await backupService.createBackup();

    expect(File(backup.path).existsSync(), isTrue);
    expect(path.extension(backup.path), '.pansiyon');
    expect(path.basename(backup.path), contains('İlk Pansiyon'));
  });

  test('yedek oluşturur, listeler ve geri yükler', () async {
    await boardingInfoRepository.save(_firstDraft);
    final backup = await backupService.createBackup();

    await boardingInfoRepository.save(_secondDraft);
    expect(
      (await boardingInfoRepository.load())?.schoolName,
      'Değişmiş Pansiyon',
    );

    await backupService.restoreBackup(backup.path);
    final restored = await boardingInfoRepository.load();
    final backups = await backupService.listBackups();

    expect(restored?.schoolName, 'İlk Pansiyon');
    expect(backups.map((item) => item.path), contains(backup.path));
    expect(
      backups.where(
        (item) => path.basename(item.path).startsWith('geri-yukleme-oncesi'),
      ),
      isNotEmpty,
    );
  });

  test('eski .db yedekleri de listelenir', () async {
    await boardingInfoRepository.save(_firstDraft);
    await backupService.createBackup();
    final legacyBackup = File(
      path.join(temporaryDirectory.path, 'yedekler', 'eski-yedek.db'),
    );
    final source = await backupService.createBackup();
    await File(source.path).copy(legacyBackup.path);

    final backups = await backupService.listBackups();

    expect(backups.map((item) => item.path), contains(legacyBackup.path));
  });

  test('geçersiz yedek dosyasını reddeder', () async {
    final invalidBackup = File(
      path.join(temporaryDirectory.path, 'bozuk.pansiyon'),
    );
    await invalidBackup.writeAsString('bu bir sqlite dosyası değil');

    await expectLater(
      () => backupService.restoreBackup(invalidBackup.path),
      throwsA(isA<DatabaseRestoreException>()),
    );
  });

  test('pansiyon şeması olmayan SQLite dosyasını reddeder', () async {
    await boardingInfoRepository.save(_firstDraft);
    final foreignFile = File(
      path.join(temporaryDirectory.path, 'yabanci.pansiyon'),
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final foreign = await openDatabase(
      foreignFile.path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE baska (id INTEGER PRIMARY KEY)');
      },
    );
    await foreign.close();

    await expectLater(
      () => backupService.restoreBackup(foreignFile.path),
      throwsA(
        isA<DatabaseRestoreException>().having(
          (error) => error.message,
          'message',
          contains('geçerli bir pansiyon yedeği değil'),
        ),
      ),
    );

    // Aktif veri korunur.
    expect((await boardingInfoRepository.load())?.schoolName, 'İlk Pansiyon');
  });

  test('geri yükleme sonrası öğrenci kayıtları da geri gelir', () async {
    await boardingInfoRepository.save(_firstDraft);
    final studentRepository = SqliteStudentRepository(database);
    await studentRepository.saveStudent(
      const Student(fullName: 'Korunan Öğrenci'),
    );
    final backup = await backupService.createBackup();

    await studentRepository.saveStudent(
      const Student(fullName: 'Sonradan Eklenen'),
    );
    expect(await studentRepository.getStudents(), hasLength(2));

    await backupService.restoreBackup(backup.path);

    final restoredStudents = await studentRepository.getStudents();
    expect(restoredStudents, hasLength(1));
    expect(restoredStudents.single.fullName, 'Korunan Öğrenci');
  });

  test('yedek dosyası doğrudan pansiyon dosyası olarak açılabilir', () async {
    await boardingInfoRepository.save(_firstDraft);
    final backup = await backupService.createBackup();

    final fileService = DatabaseBackupService(database).fileService;
    final info = await fileService.validateFile(backup.path);

    expect(info.pansiyonName, 'İlk Pansiyon');
    expect(info.databaseVersion, 8);
  });
}
