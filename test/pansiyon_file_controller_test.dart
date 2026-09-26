import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _draft = BoardingInfoDraft(
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

BoardingInfoDraft _draftWithName(String schoolName) {
  return BoardingInfoDraft(
    schoolName: schoolName,
    principalName: _draft.principalName,
    principalPhone: _draft.principalPhone,
    deputyName: _draft.deputyName,
    deputyPhone: _draft.deputyPhone,
    boardingType: _draft.boardingType,
    educationLevel: _draft.educationLevel,
    blocks: _draft.blocks,
  );
}

class _PassThroughFileService extends PansiyonFileService {
  _PassThroughFileService(this.info);

  final PansiyonFileInfo info;

  @override
  Future<PansiyonFileInfo> validateFile(
    String filePath, {
    bool requireCurrentVersion = true,
  }) async => info;
}

void main() {
  late Directory rootDirectory;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_controller_test',
    );
  });

  tearDown(() async {
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  Future<PansiyonDatabaseSession> openActiveSession(String name) async {
    final session = PansiyonDatabaseSession(
      databasePath: path.join(rootDirectory.path, name),
    );
    addTearDown(session.close);
    await session.open();
    return session;
  }

  Future<PansiyonFileInfo> createReadyPansiyonFile(String directoryName) async {
    final directory = Directory(path.join(rootDirectory.path, directoryName));
    final service = PansiyonFileService();
    final info = await service.createEmptyPansiyonFile(
      pansiyonName: _draft.schoolName,
      directory: directory,
    );
    final staging = await service.openSession(info.filePath);
    await SqliteBoardingInfoRepository(staging.database).save(_draft);
    await staging.close();
    return info;
  }

  test(
    'yeni pansiyon dosyası oluşturur, bilgileri kaydeder ve aktif yapar',
    () async {
      final session = await openActiveSession('pansiyon.db');
      final oldPath = await session.activePath();
      final controller = PansiyonFileController(session: session);

      final result = await controller.createPansiyonFile(
        draft: _draft,
        directory: Directory(path.join(rootDirectory.path, 'yeni')),
      );

      expect(result.kind, PansiyonActivationKind.created);
      expect(
        result.fileName,
        'Şehit Ahmet Yılmaz Anadolu Lisesi Pansiyonu.pansiyon',
      );
      expect(File(result.filePath).existsSync(), isTrue);
      expect(await session.activePath(), result.filePath);
      expect(File(oldPath).existsSync(), isTrue);
      expect(session.usesDefaultPath, isFalse);

      final savedDraft = await SqliteBoardingInfoRepository(
        session.database,
      ).load();
      expect(savedDraft?.schoolName, _draft.schoolName);
      expect(savedDraft?.educationLevel, EducationLevel.highSchool);
      expect(savedDraft?.blocks, hasLength(1));

      final reopened = await PansiyonFileService().openSession(result.filePath);
      addTearDown(reopened.close);
      expect(await reopened.activePath(), result.filePath);
      expect(
        (await SqliteBoardingInfoRepository(
          reopened.database,
        ).load())?.schoolName,
        _draft.schoolName,
      );
    },
  );

  test('geçerli .pansiyon dosyasını açar ve aktif yapar', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final readyFile = await createReadyPansiyonFile('hazir');
    final controller = PansiyonFileController(session: session);

    final result = await controller.openPansiyonFile(readyFile.filePath);

    expect(result?.kind, PansiyonActivationKind.opened);
    expect(result?.fileName, path.basename(readyFile.filePath));
    expect(await session.activePath(), readyFile.filePath);
    expect(File(oldPath).existsSync(), isTrue);
  });

  test('açılan dosyada eski DB kayıtları görünmez', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final oldRepository = SqliteStudentRepository(session.database);
    await oldRepository.saveStudent(const Student(fullName: 'Eski Öğrenci'));
    expect(await oldRepository.getStudents(), hasLength(1));

    final readyFile = await createReadyPansiyonFile('hazir_bos');
    final controller = PansiyonFileController(session: session);
    await controller.openPansiyonFile(readyFile.filePath);

    // Yeni aktif veritabanında eski kayıtlar görünmez.
    final activeRepository = SqliteStudentRepository(session.database);
    expect(await activeRepository.getStudents(), isEmpty);
    await activeRepository.saveStudent(const Student(fullName: 'Yeni Öğrenci'));
    expect(
      (await activeRepository.getStudents()).single.fullName,
      'Yeni Öğrenci',
    );

    // Eski veritabanı dosyası korunur, verileri kaybolmaz.
    final oldFileSession = PansiyonDatabaseSession(databasePath: oldPath);
    addTearDown(oldFileSession.close);
    expect(
      (await SqliteStudentRepository(
        oldFileSession.database,
      ).getStudents()).single.fullName,
      'Eski Öğrenci',
    );
  });

  test('bozuk dosyayı reddeder ve mevcut DB korunur', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final repository = SqliteStudentRepository(session.database);
    await repository.saveStudent(const Student(fullName: 'Korunan Öğrenci'));
    final brokenFile = File(path.join(rootDirectory.path, 'bozuk.pansiyon'));
    await brokenFile.writeAsString('bu bir SQLite dosyası değil');
    final controller = PansiyonFileController(session: session);

    await expectLater(
      controller.openPansiyonFile(brokenFile.path),
      throwsA(
        isA<PansiyonActivationException>().having(
          (error) => error.message,
          'message',
          contains('geçerli değil veya bozulmuş'),
        ),
      ),
    );

    expect(await session.activePath(), oldPath);
    expect(await repository.getStudents(), hasLength(1));
  });

  test('geçersiz SQLite dosyasını reddeder', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final emptyDatabaseFile = File(
      path.join(rootDirectory.path, 'tablolar_yok.pansiyon'),
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final database = await openDatabase(
      emptyDatabaseFile.path,
      version: 8,
      onCreate: (db, version) async {},
    );
    await database.close();
    final controller = PansiyonFileController(session: session);

    await expectLater(
      controller.openPansiyonFile(emptyDatabaseFile.path),
      throwsA(
        isA<PansiyonActivationException>().having(
          (error) => error.message,
          'message',
          contains('geçerli değil veya bozulmuş'),
        ),
      ),
    );

    expect(await session.activePath(), oldPath);
  });

  test('pansiyon tabloları olmayan eski dosyayı reddeder', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final oldVersionFile = File(
      path.join(rootDirectory.path, 'eski_surum.pansiyon'),
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final database = await openDatabase(
      oldVersionFile.path,
      version: 3,
      onCreate: (db, version) async {},
    );
    await database.close();
    final controller = PansiyonFileController(session: session);

    await expectLater(
      controller.openPansiyonFile(oldVersionFile.path),
      throwsA(
        isA<PansiyonActivationException>().having(
          (error) => error.message,
          'message',
          contains('geçerli değil veya bozulmuş'),
        ),
      ),
    );

    expect(await session.activePath(), oldPath);
  });

  test('uygulamadan yeni sürümlü dosya kullanıcı dostu reddedilir', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final newerFile = await createReadyPansiyonFile('gelecek');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final database = await openDatabase(
      newerFile.filePath,
      version: 99,
      singleInstance: false,
    );
    await database.execute('PRAGMA user_version = 99');
    await database.close();
    final controller = PansiyonFileController(session: session);

    await expectLater(
      controller.openPansiyonFile(newerFile.filePath),
      throwsA(
        isA<PansiyonActivationException>().having(
          (error) => error.message,
          'message',
          contains('daha yeni bir sürümde'),
        ),
      ),
    );

    expect(await session.activePath(), oldPath);
  });

  test('geçiş başarısız olursa eski DB korunur', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final repository = SqliteStudentRepository(session.database);
    await repository.saveStudent(const Student(fullName: 'Kalıcı Öğrenci'));
    // Doğrulama sahte olarak geçiyor, hedef yol açılabilir bir dosya değil.
    final brokenTarget = Directory(
      path.join(rootDirectory.path, 'klasor.pansiyon'),
    );
    await brokenTarget.create(recursive: true);
    final controller = PansiyonFileController(
      session: session,
      fileService: _PassThroughFileService(
        PansiyonFileInfo(
          filePath: brokenTarget.path,
          databaseVersion: 8,
          integrityCheck: 'ok',
        ),
      ),
    );

    await expectLater(
      controller.openPansiyonFile(brokenTarget.path),
      throwsA(isA<PansiyonActivationException>()),
    );

    expect(await session.activePath(), oldPath);
    expect(File(oldPath).existsSync(), isTrue);
    await repository.saveStudent(const Student(fullName: 'İkinci Öğrenci'));
    expect(await repository.getStudents(), hasLength(2));
  });

  test('pansiyon A → B → A → B geçişinde veriler doğru taşınır', () async {
    final session = await openActiveSession('pansiyon.db');
    final controller = PansiyonFileController(session: session);

    // Her geçişten sonra uygulamanın yaptığı gibi repository'ler yeniden kurulur.
    Future<List<String>> activeStudentNames() async {
      final repository = SqliteStudentRepository(session.database);
      return (await repository.getStudents())
          .map((student) => student.fullName)
          .toList();
    }

    Future<String?> activeSchoolName() async {
      final repository = SqliteBoardingInfoRepository(session.database);
      return (await repository.load())?.schoolName;
    }

    // Pansiyon A: mevcut aktif pansiyon, öğrencili.
    final repositoryA = SqliteStudentRepository(session.database);
    await SqliteBoardingInfoRepository(
      session.database,
    ).save(_draftWithName('Pansiyon A'));
    await repositoryA.saveStudent(const Student(fullName: 'A Öğrencisi'));
    final pathA = await session.activePath();

    // Pansiyon B: yeni ve boş.
    final createdB = await controller.createPansiyonFile(
      draft: _draftWithName('Pansiyon B'),
      directory: Directory(path.join(rootDirectory.path, 'pansiyon_b')),
    );
    final pathB = createdB.filePath;

    expect(await session.activePath(), pathB);
    expect(await activeStudentNames(), isEmpty);
    expect(await activeSchoolName(), 'Pansiyon B');

    // Pansiyon A'ya geri dönüş: veriler yerinde.
    await controller.openPansiyonFile(pathA);
    expect(await session.activePath(), pathA);
    expect(await activeStudentNames(), ['A Öğrencisi']);
    expect(await activeSchoolName(), 'Pansiyon A');

    // Yine Pansiyon B: boş.
    await controller.openPansiyonFile(pathB);
    expect(await session.activePath(), pathB);
    expect(await activeStudentNames(), isEmpty);
    expect(await activeSchoolName(), 'Pansiyon B');

    // Her iki dosya da bozulmadan duruyor.
    expect(File(pathA).existsSync(), isTrue);
    expect(File(pathB).existsSync(), isTrue);
    final reopenedA = await PansiyonFileService().openSession(pathA);
    addTearDown(reopenedA.close);
    expect(
      (await SqliteStudentRepository(
        reopenedA.database,
      ).getStudents()).single.fullName,
      'A Öğrencisi',
    );
  });

  test('oluşturma başarısız olursa eski DB korunur', () async {
    final session = await openActiveSession('pansiyon.db');
    final oldPath = await session.activePath();
    final controller = PansiyonFileController(session: session);
    final targetDirectory = Directory(
      path.join(rootDirectory.path, 'yeniden_adli'),
    );
    await targetDirectory.create(recursive: true);
    final targetFile = File(
      path.join(targetDirectory.path, '${_draft.schoolName}.pansiyon'),
    );
    await targetFile.writeAsString('korunacak');

    await expectLater(
      controller.createPansiyonFile(draft: _draft, directory: targetDirectory),
      throwsA(
        isA<PansiyonActivationException>().having(
          (error) => error.message,
          'message',
          contains('zaten var'),
        ),
      ),
    );

    expect(await targetFile.readAsString(), 'korunacak');
    expect(await session.activePath(), oldPath);
  });

  test('boş pansiyon adını reddeder', () async {
    final session = await openActiveSession('pansiyon.db');
    final controller = PansiyonFileController(session: session);

    await expectLater(
      controller.createPansiyonFile(
        draft: const BoardingInfoDraft(
          schoolName: '   ',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.girls,
          educationLevel: EducationLevel.highSchool,
          blocks: [],
        ),
        directory: Directory(rootDirectory.path),
      ),
      throwsA(isA<PansiyonActivationException>()),
    );
    expect(await session.activePath(), endsWith('pansiyon.db'));
  });
}
