import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/data/study_room_repository.dart';
import 'package:pansiyon_yonetim/features/study_rooms/domain/study_room_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _draft = BoardingInfoDraft(
  schoolName: 'Test Pansiyonu',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.girls,
  educationLevel: EducationLevel.middleSchool,
  blocks: [
    BoardingBlockDraft(
      section: BoardingSection.girls,
      name: 'A Blok',
      standardRoomCapacity: 4,
      floors: [
        BoardingFloorDraft(
          floorNumber: 1,
          studentRoomCount: 2,
          roomStartNumber: 101,
        ),
        BoardingFloorDraft(
          floorNumber: 2,
          studentRoomCount: 1,
          roomStartNumber: 201,
        ),
      ],
    ),
  ],
);

void main() {
  late AppDatabase database;
  late SqliteBoardingInfoRepository boardingInfoRepository;
  late SqliteStudentRepository studentRepository;
  late SqliteRoomRepository roomRepository;
  late SqliteStudyRoomRepository repository;

  setUp(() async {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    boardingInfoRepository = SqliteBoardingInfoRepository(database);
    studentRepository = SqliteStudentRepository(database);
    roomRepository = SqliteRoomRepository(database);
    repository = SqliteStudyRoomRepository(
      database,
      boardingInfoRepository: boardingInfoRepository,
    );
    await boardingInfoRepository.save(_draft);
    await roomRepository.syncRooms(_draft);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> addStudent(
    String name, {
    StudentGender gender = StudentGender.female,
  }) async {
    return studentRepository.saveStudent(
      Student(fullName: name, gender: gender),
    );
  }

  Future<int> addRoom(int roomNumber) async {
    return (await roomRepository.getRooms())
        .firstWhere((room) => room.roomNumber == roomNumber)
        .id;
  }

  Future<int> createRoom({
    String name = 'Etüt Salonu 1',
    StudyRoomLayout? layout,
    StudyRoomSeating seating = StudyRoomSeating.single,
    int? tableSize,
    bool tablesHaveStudents = false,
  }) {
    return repository.createStudyRoom(
      name: name,
      section: BoardingSection.girls,
      blockName: 'A Blok',
      floorLabel: 'Zemin Kat',
      floorNumber: 1,
      layout: layout,
      seating: seating,
      tableSize: tableSize,
      tablesHaveStudents: tablesHaveStudents,
    );
  }

  group('kat seçenekleri', () {
    test('pansiyon bilgilerinden bölüm, blok ve kat listeler', () async {
      final options = await repository.getFloorOptions();

      expect(options, hasLength(2));
      expect(options.first.section, BoardingSection.girls);
      expect(options.first.blockName, 'A Blok');
      expect(options.first.floorLabel, 'Zemin Kat');
      expect(options.last.floorLabel, '1. Kat');
      expect(options.last.floorNumber, 2);
    });

    test('bodrum katı olduğunda etiketler kaydırılır', () async {
      await boardingInfoRepository.save(
        const BoardingInfoDraft(
          schoolName: 'Test Pansiyonu',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.girls,
          educationLevel: EducationLevel.middleSchool,
          blocks: [
            BoardingBlockDraft(
              section: BoardingSection.girls,
              name: 'A Blok',
              standardRoomCapacity: 4,
              hasBasement: true,
              floors: [BoardingFloorDraft(floorNumber: 1, studentRoomCount: 1)],
            ),
          ],
        ),
      );

      final options = await repository.getFloorOptions();

      expect(options.single.floorLabel, 'Bodrum Kat');
    });
  });

  group('salon yönetimi', () {
    test('salon ekler ve listeler', () async {
      final id = await createRoom(
        name: 'Zemin Etüt',
        layout: const StudyRoomLayout(columns: 6, rows: 4),
      );

      final rooms = await repository.getStudyRooms();

      expect(rooms, hasLength(1));
      expect(rooms.single.id, id);
      expect(rooms.single.name, 'Zemin Etüt');
      expect(rooms.single.capacity, 24);
      expect(rooms.single.section, BoardingSection.girls);
      expect(rooms.single.blockName, 'A Blok');
      expect(rooms.single.floorLabel, 'Zemin Kat');
      expect(rooms.single.seating, StudyRoomSeating.single);
      expect(rooms.single.occupantCount, 0);
      expect(rooms.single.availableCapacity, 24);
    });

    test('grup düzeninde masa bilgisi saklanır', () async {
      await createRoom(
        seating: StudyRoomSeating.groupTables,
        tableSize: 6,
        tablesHaveStudents: true,
      );

      final room = (await repository.getStudyRooms()).single;

      expect(room.seating, StudyRoomSeating.groupTables);
      expect(room.tableSize, 6);
      expect(room.tablesHaveStudents, isTrue);
    });

    test('grup düzeninde masa kişiliği zorunludur', () async {
      expect(
        () => createRoom(seating: StudyRoomSeating.groupTables),
        throwsArgumentError,
      );
    });

    test('kapasite en fazla 300 olabilir', () async {
      await createRoom(layout: StudyRoomLayout(columns: 300, rows: 1));
      expect((await repository.getStudyRooms()).single.capacity, 300);

      expect(
        () => createRoom(layout: StudyRoomLayout(columns: 301, rows: 1)),
        throwsArgumentError,
      );
    });

    test('kapasite sıfır olamaz', () {
      expect(
        () => createRoom(layout: StudyRoomLayout(columns: 0, rows: 1)),
        throwsArgumentError,
      );
    });

    test('salon adı boş olamaz', () {
      expect(() => createRoom(name: '   '), throwsArgumentError);
    });

    test('salon güncellenir', () async {
      final id = await createRoom();

      await repository.updateStudyRoom(
        id: id,
        name: 'Yeni Ad',
        layout: const StudyRoomLayout(columns: 8, rows: 5),
        seating: StudyRoomSeating.pair,
      );

      final room = (await repository.getStudyRooms()).single;
      expect(room.name, 'Yeni Ad');
      // Çiftli sıra 8 x 5 x 2 = 80
      expect(room.capacity, 80);
      expect(room.seating, StudyRoomSeating.pair);
    });

    test('salon silinince yerleşimler de silinir', () async {
      final id = await createRoom(layout: StudyRoomLayout(columns: 2, rows: 1));
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Mert Demir');
      await roomRepository.assignStudent(
        roomId: await addRoom(101),
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: await addRoom(101),
        studentId: second,
      );
      expect(await repository.autoPlaceStudents(id), 2);

      await repository.deleteStudyRoom(id);

      expect(await repository.getStudyRooms(), isEmpty);
      expect(await repository.getAssignments(), isEmpty);
    });
  });

  group('havuz', () {
    test('salona yerleştirilmemiş öğrenciler havuzda görünür', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 1, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );

      expect(
        (await repository.getFloorPools()).single.studentIds,
        containsAll([first, second]),
      );

      await repository.autoPlaceStudents(roomId);

      final pool = (await repository.getFloorPools()).single;
      expect(pool.section, BoardingSection.girls);
      expect(pool.floorLabel, 'Zemin Kat');
      // Yerleşim ada göre yapılır; kapasite 1 olduğu için "Elif Şahin" yerleşir,
      // "Zeynep Kaya" havuzda kalır.
      expect(pool.studentIds, hasLength(1));
      expect(pool.studentIds.single, first);
    });

    test('iki katta iki salon varsa her kat kendi öğrencisini alır', () async {
      final firstFloorRoomId = await repository.createStudyRoom(
        name: 'Etüt Salonu 1',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        layout: const StudyRoomLayout(columns: 3, rows: 2),
        seating: StudyRoomSeating.single,
      );
      final secondFloorRoomId = await repository.createStudyRoom(
        name: 'Etüt Salonu 2',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: '1. Kat',
        floorNumber: 2,
        layout: const StudyRoomLayout(columns: 3, rows: 2),
        seating: StudyRoomSeating.single,
      );

      final zeynep = await addStudent('Zeynep Kaya');
      final elif = await addStudent('Elif Şahin');
      final deniz = await addStudent('Deniz Yıldız');

      await roomRepository.assignStudent(
        roomId: await addRoom(101),
        studentId: zeynep,
      );
      await roomRepository.assignStudent(
        roomId: await addRoom(102),
        studentId: deniz,
      );
      await roomRepository.assignStudent(
        roomId: await addRoom(201),
        studentId: elif,
      );

      final pools = await repository.getFloorPools();
      expect(pools, hasLength(2));
      final firstPool = pools.firstWhere((pool) => pool.floorNumber == 1);
      final secondPool = pools.firstWhere((pool) => pool.floorNumber == 2);
      expect(firstPool.studentIds, containsAll([zeynep, deniz]));
      expect(secondPool.studentIds, [elif]);

      // Kat havuzlarından ayrı ayrı yerleştirme yapılabilmeli.
      await repository.placeStudent(
        studyRoomId: firstFloorRoomId,
        studentId: zeynep,
      );
      expect(
        (await repository.getFloorPools())
            .firstWhere((pool) => pool.floorNumber == 1)
            .studentIds,
        [deniz],
      );
      expect(
        (await repository.getFloorPools())
            .firstWhere((pool) => pool.floorNumber == 2)
            .studentIds,
        [elif],
      );

      await repository.placeStudent(
        studyRoomId: secondFloorRoomId,
        studentId: elif,
      );
      expect(
        (await repository.getStudyRooms())
            .firstWhere((room) => room.id == firstFloorRoomId)
            .occupantCount,
        1,
      );
      expect(
        (await repository.getStudyRooms())
            .firstWhere((room) => room.id == secondFloorRoomId)
            .occupantCount,
        1,
      );
    });

    test('havuzdaki öğrenci salona yerleştirilir', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 2, rows: 1),
      );
      final studentId = await addStudent('Zeynep Kaya');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: studentId,
      );

      await repository.placeStudent(studyRoomId: roomId, studentId: studentId);

      expect((await repository.getStudyRooms()).single.occupantCount, 1);
      expect((await repository.getFloorPools()), isEmpty);
    });

    test('dolu salona öğrenci yerleştirilemez', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 1, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );
      await repository.placeStudent(studyRoomId: roomId, studentId: first);

      expect(
        () => repository.placeStudent(studyRoomId: roomId, studentId: second),
        throwsStateError,
      );
    });

    test('bölüme uymayan öğrenci yerleştirilemez', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 2, rows: 1),
      );
      final boy = await addStudent('Mert Demir', gender: StudentGender.male);

      expect(
        () => repository.placeStudent(studyRoomId: roomId, studentId: boy),
        throwsStateError,
      );
    });
  });

  group('düzen ve kapasite', () {
    test('kapasite otomatik hesaplanır', () async {
      await createRoom(); // Tekli sıra 5 x 4
      expect((await repository.getStudyRooms()).single.capacity, 20);

      await createRoom(name: 'Çiftli', seating: StudyRoomSeating.pair);
      final pair = (await repository.getStudyRooms()).last;
      expect(pair.capacity, 20);

      await createRoom(name: 'U Tipi', seating: StudyRoomSeating.horseshoe);
      final horseshoe = (await repository.getStudyRooms()).last;
      expect(horseshoe.capacity, 20);

      await createRoom(
        name: 'Grup',
        seating: StudyRoomSeating.groupTables,
        tableSize: 4,
      );
      final group = (await repository.getStudyRooms()).last;
      expect(group.capacity, 16);
    });

    test('artı butonu sıra ekler ve kapasiteyi büyütür', () async {
      final id = await createRoom();
      final before = (await repository.getStudyRooms()).single;

      await repository.growLayout(studyRoomId: id, columns: 1);
      var room = (await repository.getStudyRooms()).single;
      expect(room.layout.columns, before.layout.columns + 1);
      expect(room.capacity, before.capacity + before.layout.rows);

      await repository.growLayout(studyRoomId: id, rows: 2);
      room = (await repository.getStudyRooms()).single;
      expect(room.layout.rows, before.layout.rows + 2);
      expect(room.capacity, greaterThan(before.capacity));
    });

    test('eksi butonu sıra azaltır', () async {
      final id = await createRoom();
      final before = (await repository.getStudyRooms()).single;

      await repository.growLayout(studyRoomId: id, columns: -1);

      final room = (await repository.getStudyRooms()).single;
      expect(room.layout.columns, before.layout.columns - 1);
      expect(room.capacity, lessThan(before.capacity));
    });

    test('U düzeninde bacak ve taban eklenip azaltılabilir', () async {
      final id = await createRoom(seating: StudyRoomSeating.horseshoe);
      final before = (await repository.getStudyRooms()).single;

      await repository.growLayout(
        studyRoomId: id,
        uLeftSeats: 2,
        uBaseSeats: -3,
      );
      final room = (await repository.getStudyRooms()).single;
      expect(room.layout.uLeftSeats, before.layout.uLeftSeats + 2);
      expect(room.layout.uBaseSeats, before.layout.uBaseSeats - 3);
      expect(room.capacity, before.capacity - 1);
    });

    test('grup düzeninde yatay ve dikey masa eklenir', () async {
      final id = await createRoom(
        seating: StudyRoomSeating.groupTables,
        tableSize: 4,
        tablesHaveStudents: true,
      );
      final before = (await repository.getStudyRooms()).single;
      // Baş ucunda oturan varsa masa 4 + 2 = 6 kişilik sayılır.
      expect(before.capacity, 4 * 6);

      await repository.growLayout(studyRoomId: id, tableColumns: 1);

      final room = (await repository.getStudyRooms()).single;
      expect(room.layout.tableColumns, before.layout.tableColumns + 1);
      // Yeni sütun 2 masa ekler, her masa 6 kişilik.
      expect(room.capacity, before.capacity + 12);
    });

    test('sayaclar 1 altına inmez', () async {
      final id = await createRoom(
        layout: const StudyRoomLayout(columns: 1, rows: 1),
      );
      await repository.growLayout(studyRoomId: id, columns: -5, rows: -5);
      final room = (await repository.getStudyRooms()).single;
      expect(room.layout.columns, 1);
      expect(room.layout.rows, 1);
    });

    test('kapasite 300 sınırını aşamaz', () async {
      final id = await createRoom(
        layout: const StudyRoomLayout(columns: 10, rows: 10),
      );
      expect((await repository.getStudyRooms()).single.capacity, 100);

      expect(
        () => repository.growLayout(studyRoomId: id, columns: 30, rows: 30),
        throwsArgumentError,
      );
    });

    test('yerleşik öğrenci varken kapasite küçültülemez', () async {
      final id = await createRoom(
        layout: const StudyRoomLayout(columns: 2, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );
      await repository.autoPlaceStudents(id);
      expect((await repository.getStudyRooms()).single.occupantCount, 2);

      expect(
        () => repository.growLayout(studyRoomId: id, columns: -1),
        throwsStateError,
      );
    });
  });

  group('otomatik yerleştirme', () {
    test('kattaki öğrenciler kapasiteye göre yerleştirilir', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 2, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final third = await addStudent('Ayşe Demir');
      final sleepingRoomId = await addRoom(101);
      for (final studentId in [first, second, third]) {
        await roomRepository.assignStudent(
          roomId: sleepingRoomId,
          studentId: studentId,
        );
      }

      final placed = await repository.autoPlaceStudents(roomId);

      expect(placed, 2);
      final room = (await repository.getStudyRooms()).single;
      expect(room.occupantCount, 2);
      expect(room.availableCapacity, 0);
      final assignments = await repository.getAssignments();
      expect(assignments, hasLength(2));
      // Yerleşim ada göre sırayla yapılır; üçüncü öğrenci kapasite dışı kalır.
      final placedNames = [
        for (final assignment in assignments)
          (await studentRepository.getStudent(assignment.studentId))!.fullName,
      ];
      expect(placedNames, ['Ayşe Demir', 'Elif Şahin']);
    });

    test('başka kata uyan öğrenciler yerleştirilmez', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 5, rows: 1),
      );
      final onGround = await addStudent('Zeynep Kaya');
      final onFirst = await addStudent('Mert Demir');
      await roomRepository.assignStudent(
        roomId: await addRoom(101),
        studentId: onGround,
      );
      await roomRepository.assignStudent(
        roomId: await addRoom(201),
        studentId: onFirst,
      );

      final placed = await repository.autoPlaceStudents(roomId);

      expect(placed, 1);
      final assignment = (await repository.getAssignments()).single;
      expect(assignment.studentId, onGround);
    });

    test('kız bölümündeki salona erkek öğrenci yerleştirilmez', () async {
      // Erkek öğrenci erkek bölümüne atanır; kız salonunun havuzunda bulunmaz.
      await boardingInfoRepository.save(
        const BoardingInfoDraft(
          schoolName: 'Test Pansiyonu',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.mixed,
          educationLevel: EducationLevel.middleSchool,
          blocks: [
            BoardingBlockDraft(
              section: BoardingSection.girls,
              name: 'A Blok',
              standardRoomCapacity: 4,
              floors: [
                BoardingFloorDraft(
                  floorNumber: 1,
                  studentRoomCount: 1,
                  roomStartNumber: 101,
                ),
              ],
            ),
            BoardingBlockDraft(
              section: BoardingSection.boys,
              name: 'B Blok',
              standardRoomCapacity: 4,
              floors: [
                BoardingFloorDraft(
                  floorNumber: 1,
                  studentRoomCount: 1,
                  roomStartNumber: 101,
                ),
              ],
            ),
          ],
        ),
      );
      final mixedDraft = await boardingInfoRepository.load();
      await roomRepository.syncRooms(mixedDraft);

      final girl = await addStudent('Zeynep Kaya');
      final boy = await addStudent('Mert Demir', gender: StudentGender.male);
      final rooms = await roomRepository.getRooms();
      await roomRepository.assignStudent(
        roomId: rooms
            .firstWhere((room) => room.section == BoardingSection.girls)
            .id,
        studentId: girl,
      );
      await roomRepository.assignStudent(
        roomId: rooms
            .firstWhere((room) => room.section == BoardingSection.boys)
            .id,
        studentId: boy,
      );

      final roomId = await repository.createStudyRoom(
        name: 'Kız Etüt',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        layout: const StudyRoomLayout(columns: 5, rows: 1),
        seating: StudyRoomSeating.single,
      );

      final placed = await repository.autoPlaceStudents(roomId);

      expect(placed, 1);
      expect((await repository.getAssignments()).single.studentId, girl);
    });

    test('öğrenci katsız havuzdaysa yerleştirilmez', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 5, rows: 1),
      );
      await addStudent('Zeynep Kaya');

      expect(await repository.autoPlaceStudents(roomId), 0);
    });

    test('ikinci salon öğrenciyi ilk salondan devralmaz', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 1, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );

      expect(await repository.autoPlaceStudents(roomId), 1);
      final firstAssignment = (await repository.getAssignments()).single;

      // İkinci salonun yerleşimi kendi kapasitesine göre yapılır; öğrenci
      // başka salonda ise havuzdan atlanır.
      final secondRoomId = await createRoom(
        name: 'Etüt Salonu 2',
        layout: const StudyRoomLayout(columns: 1, rows: 1),
      );
      expect(await repository.autoPlaceStudents(secondRoomId), 1);
      final assignments = await repository.getAssignments();
      expect(assignments, hasLength(2));
      final secondPlaced = assignments.firstWhere(
        (a) => a.studyRoomId == secondRoomId,
      );
      expect(secondPlaced.studentId, isNot(firstAssignment.studentId));
    });

    test('salonun yerleşimi yeniden çalıştırılınca yeniden dağılır', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 2, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );
      await repository.autoPlaceStudents(roomId);
      final before = {
        for (final assignment in await repository.getAssignments())
          assignment.studentId,
      };

      await repository.releaseStudent(first);
      expect(await repository.autoPlaceStudents(roomId), 2);
      final after = {
        for (final assignment in await repository.getAssignments())
          assignment.studentId,
      };

      expect(after, before);
    });

    test('hazuya alınan öğrenci tekrar yerleştirilebilir', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 2, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );
      await repository.autoPlaceStudents(roomId);
      expect((await repository.getStudyRooms()).single.occupantCount, 2);

      await repository.releaseStudent(first);

      expect((await repository.getStudyRooms()).single.occupantCount, 1);
      expect(await repository.autoPlaceStudents(roomId), 2);
      expect((await repository.getStudyRooms()).single.occupantCount, 2);
    });

    test('kapasite içindeki öğrenciden azaltılamaz', () async {
      final roomId = await createRoom(
        layout: StudyRoomLayout(columns: 2, rows: 1),
      );
      final first = await addStudent('Zeynep Kaya');
      final second = await addStudent('Elif Şahin');
      final sleepingRoomId = await addRoom(101);
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: first,
      );
      await roomRepository.assignStudent(
        roomId: sleepingRoomId,
        studentId: second,
      );
      await repository.autoPlaceStudents(roomId);

      expect(
        () => repository.updateStudyRoom(
          id: roomId,
          name: 'Etüt Salonu 1',
          layout: const StudyRoomLayout(columns: 1, rows: 1),
          seating: StudyRoomSeating.single,
        ),
        throwsStateError,
      );
    });
  });
}
