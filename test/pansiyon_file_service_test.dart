import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _boardingInfo = BoardingInfoDraft(
  schoolName: 'Şehit Ahmet Yılmaz Anadolu Lisesi Pansiyonu',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.girls,
  educationLevel: EducationLevel.highSchool,
  blocks: [
    BoardingBlockDraft(
      section: BoardingSection.girls,
      name: 'Kız Bloğu',
      standardRoomCapacity: 2,
      floors: [
        BoardingFloorDraft(
          floorNumber: 1,
          hasStudentRooms: true,
          studentRoomCount: 1,
          roomStartNumber: 101,
        ),
      ],
    ),
  ],
);

void main() {
  late PansiyonFileService service;

  setUp(() {
    service = PansiyonFileService();
  });

  test('geçerli pansiyon adından .pansiyon dosyası oluşturur', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_file_create_test',
    );
    addTearDown(() => directory.delete(recursive: true));

    final info = await service.createEmptyPansiyonFile(
      pansiyonName: _boardingInfo.schoolName,
      directory: directory,
    );
    final openedSession = await service.openSession(info.filePath);
    addTearDown(openedSession.close);

    expect(File(info.filePath).existsSync(), isTrue);
    expect(info.databaseVersion, 8);
    expect(info.integrityCheck, 'ok');
    expect(await openedSession.activePath(), info.filePath);
    expect((await service.validateFile(info.filePath)).integrityCheck, 'ok');
  });

  test('Windows geçersiz karakterlerini temizler', () {
    final fileName = service.fileNameForPansiyon(
      'Şehit <Ahmet>: "Yılmaz" / Pansiyon?',
    );

    expect(fileName, endsWith('.pansiyon'));
    expect(fileName, isNot(contains('<')));
    expect(fileName, isNot(contains('>')));
    expect(fileName, isNot(contains(':')));
    expect(fileName, isNot(contains('"')));
    expect(fileName, isNot(contains('/')));
    expect(fileName, isNot(contains('?')));
    expect(fileName, isNot(contains('*')));
  });

  test('boş ad için güvenli fallback kullanır', () {
    expect(service.fileNameForPansiyon('   '), 'pansiyon.pansiyon');
  });

  test('.pansiyon uzantısını iki kez eklemez', () {
    expect(service.fileNameForPansiyon('test.pansiyon'), 'test.pansiyon');
    expect(service.fileNameForPansiyon('test'), 'test.pansiyon');
  });

  test('mevcut dosyanın üzerine yazmaz', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_file_exists_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final target = File(path.join(directory.path, 'mevcut.pansiyon'));
    await target.writeAsString('korunacak');

    await expectLater(
      service.createEmptyPansiyonFile(
        pansiyonName: 'mevcut',
        directory: directory,
      ),
      throwsA(isA<PansiyonFileExistsException>()),
    );
    expect(await target.readAsString(), 'korunacak');
  });

  test('geçici dosya oluşturulamazsa hata verir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_file_failure_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final notDirectory = File(path.join(directory.path, 'dosya'));
    await notDirectory.writeAsString('dosya');

    await expectLater(
      service.createEmptyPansiyonFile(
        pansiyonName: 'test',
        directory: Directory(notDirectory.path),
      ),
      throwsA(isA<PansiyonFileCreationException>()),
    );
    expect(
      directory
          .listSync()
          .where((entity) => entity.path.contains('.tmp-'))
          .isEmpty,
      isTrue,
    );
  });

  test('bozuk SQLite dosyasını kabul etmez', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_file_invalid_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(path.join(directory.path, 'bozuk.pansiyon'));
    final bytes = <int>[
      ...'SQLite format 3'.codeUnits,
      0,
      ...List<int>.filled(2048, 1),
    ];
    await file.writeAsBytes(bytes);

    await expectLater(
      service.validateFile(file.path),
      throwsA(isA<PansiyonFileValidationException>()),
    );
  });

  test('mevcut pansiyon.db verisini .pansiyon olarak kopyalar', () async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_source_test',
    );
    final targetDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_target_test',
    );
    addTearDown(() => sourceDirectory.delete(recursive: true));
    addTearDown(() => targetDirectory.delete(recursive: true));
    final sourceSession = await _createSourceSession(sourceDirectory);
    addTearDown(sourceSession.close);
    final sourceFile = File(await sourceSession.activePath());

    final info = await service.convertExistingDatabase(
      sourceSession: sourceSession,
      directory: targetDirectory,
    );
    final openedSession = await service.openSession(info.filePath);
    addTearDown(openedSession.close);
    final database = await openedSession.database.database;

    expect(
      info.filePath,
      endsWith('Şehit Ahmet Yılmaz Anadolu Lisesi Pansiyonu.pansiyon'),
    );
    expect(info.databaseVersion, 8);
    expect(info.integrityCheck, 'ok');
    expect(sourceFile.existsSync(), isTrue);
    expect(await _count(database, 'boarding_school_info'), 1);
    expect(await _count(database, 'boarding_blocks'), greaterThan(0));
    expect(await _count(database, 'boarding_floors'), greaterThan(0));
    expect(await _count(database, 'boarding_rooms'), greaterThan(0));
    expect(await _count(database, 'room_assignments'), 1);
    expect(await _count(database, 'schools'), 1);
    expect(await _count(database, 'students'), 2);
    expect(await _count(database, 'student_attendance'), 1);
    expect(await _count(database, 'student_discipline_incidents'), 1);
  });

  test('bütünlük kontrolü başarısız dosyayı kabul etmez', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pansiyon_file_integrity_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(path.join(directory.path, 'bozuk.pansiyon'));
    await file.writeAsBytes([
      ...'SQLite format 3'.codeUnits,
      0,
      ...List<int>.filled(4096, 9),
    ]);

    await expectLater(
      service.validateFile(file.path),
      throwsA(isA<PansiyonFileValidationException>()),
    );
  });

  group('sürüm yükseltme geçişi', () {
    test('eski sürümlü dosya katı doğrulamada reddedilir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pansiyon_old_version_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filePath = await _createVersionedPansiyonFile(
        directory,
        version: 6,
        schoolName: 'Eski Sürüm Pansiyonu',
      );

      await expectLater(
        service.validateFile(filePath),
        throwsA(
          isA<PansiyonFileValidationException>().having(
            (error) => error.issue,
            'issue',
            PansiyonFileIssue.unsupportedVersion,
          ),
        ),
      );
    });

    test('eski sürümlü dosya esnek doğrulamada kabul edilir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pansiyon_old_version_soft_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filePath = await _createVersionedPansiyonFile(
        directory,
        version: 6,
        schoolName: 'Eski Sürüm Pansiyonu',
      );

      final info = await service.validateFile(
        filePath,
        requireCurrentVersion: false,
      );

      expect(info.databaseVersion, 6);
      expect(info.pansiyonName, 'Eski Sürüm Pansiyonu');
    });

    test('eski sürümlü dosya açılınca yükselir, veriler korunur', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pansiyon_old_version_open_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filePath = await _createVersionedPansiyonFile(
        directory,
        version: 6,
        schoolName: 'Eski Sürüm Pansiyonu',
      );
      final session = await service.openSession(filePath);
      addTearDown(session.close);

      final database = await session.database.database;
      final versionRows = await database.rawQuery('PRAGMA user_version');
      final schoolRows = await database.query('boarding_school_info');

      expect(versionRows.single.values.single, 8);
      expect(schoolRows.single['school_name'], 'Eski Sürüm Pansiyonu');
      expect(
        File(
          path.join(directory.path, 'Eski Sürüm Pansiyonu v6 yedek.pansiyon'),
        ).existsSync(),
        isTrue,
      );
      await session.close();

      // Yükseltilmiş dosya katı doğrulamayı da geçer.
      expect((await service.validateFile(filePath)).databaseVersion, 8);
    });

    test('uygulamadan yeni sürümlü dosya reddedilir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pansiyon_newer_version_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filePath = await _createVersionedPansiyonFile(
        directory,
        version: 8,
        schoolName: 'Gelecek Pansiyonu',
        extraVersion: 99,
      );

      await expectLater(
        service.validateFile(filePath, requireCurrentVersion: false),
        throwsA(
          isA<PansiyonFileValidationException>().having(
            (error) => error.issue,
            'issue',
            PansiyonFileIssue.unsupportedVersion,
          ),
        ),
      );
    });

    test('pansiyon dosyası olmayan SQLite reddedilir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pansiyon_not_pansiyon_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filePath = path.join(directory.path, 'baska.pansiyon');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final database = await openDatabase(
        filePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE not_defter (id INTEGER PRIMARY KEY)');
        },
      );
      await database.close();

      await expectLater(
        service.validateFile(filePath, requireCurrentVersion: false),
        throwsA(
          isA<PansiyonFileValidationException>().having(
            (error) => error.issue,
            'issue',
            PansiyonFileIssue.missingTables,
          ),
        ),
      );
    });
  });
}

/// Belirtilen `user_version` değerine sahip geçerli bir pansiyon dosyası üretir.
Future<String> _createVersionedPansiyonFile(
  Directory directory, {
  required int version,
  required String schoolName,
  int? extraVersion,
}) async {
  final filePath = path.join(directory.path, '$schoolName.pansiyon');
  final service = PansiyonFileService();
  final info = await service.createEmptyPansiyonFile(
    pansiyonName: schoolName,
    directory: directory,
  );
  final session = await service.openSession(info.filePath);
  final database = await session.database.database;
  await SqliteBoardingInfoRepository(session.database).save(
    BoardingInfoDraft(
      schoolName: schoolName,
      principalName: 'Ayşe Yılmaz',
      principalPhone: '0312 555 10 10',
      deputyName: 'Mehmet Demir',
      deputyPhone: '0312 555 10 11',
      boardingType: BoardingType.girls,
      educationLevel: EducationLevel.highSchool,
      blocks: const [],
    ),
  );
  await database.execute('PRAGMA user_version = ${extraVersion ?? version}');
  await session.close();
  return filePath;
}

Future<PansiyonDatabaseSession> _createSourceSession(
  Directory directory,
) async {
  final sourcePath = path.join(directory.path, 'pansiyon.db');
  final session = PansiyonDatabaseSession(databasePath: sourcePath);
  await session.open();
  final boardingInfoRepository = SqliteBoardingInfoRepository(session.database);
  final studentRepository = SqliteStudentRepository(session.database);
  final roomRepository = SqliteRoomRepository(session.database);
  final schoolId = await studentRepository.saveSchool(
    const School(name: 'Atatürk Lisesi'),
  );
  final firstStudentId = await studentRepository.saveStudent(
    Student(
      fullName: 'Ali Veli',
      gender: StudentGender.female,
      schoolId: schoolId,
      className: '9',
    ),
  );
  final secondStudentId = await studentRepository.saveStudent(
    Student(
      fullName: 'Deniz Kaya',
      gender: StudentGender.female,
      schoolId: schoolId,
      className: '10',
    ),
  );
  await boardingInfoRepository.save(_boardingInfo);
  await roomRepository.syncRooms(_boardingInfo);
  final rooms = await roomRepository.getRooms();
  await roomRepository.assignStudent(
    roomId: rooms.first.id,
    studentId: firstStudentId,
  );
  await studentRepository.saveAttendance(
    StudentAttendance(
      studentId: firstStudentId,
      date: DateTime(2026, 9, 26),
      status: StudentAttendanceStatus.homeLeave,
    ),
  );
  await studentRepository.saveDisciplineIncident(
    StudentDisciplineIncident(
      studentId: secondStudentId,
      date: DateTime(2026, 9, 26),
      description: 'Örnek kayıt',
    ),
  );
  return session;
}

Future<int> _count(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) FROM $table');
  return (rows.first.values.first as num).toInt();
}
