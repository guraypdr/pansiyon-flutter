import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_edit_lock.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_type_change_impact.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/settings/presentation/pansiyon_ayarlari_page.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _mixedDraft = BoardingInfoDraft(
  schoolName: 'Karma Pansiyon',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.mixed,
  educationLevel: EducationLevel.middleSchool,
  blocks: [
    BoardingBlockDraft(
      section: BoardingSection.girls,
      name: 'Kız Bloğu',
      standardRoomCapacity: 2,
      floors: [
        BoardingFloorDraft(
          floorNumber: 1,
          hasStudentRooms: true,
          studentRoomCount: 2,
          roomStartNumber: 101,
          hasStudyRoom: false,
        ),
      ],
    ),
    BoardingBlockDraft(
      section: BoardingSection.boys,
      name: 'Erkek Bloğu',
      standardRoomCapacity: 2,
      floors: [
        BoardingFloorDraft(
          floorNumber: 1,
          hasStudentRooms: true,
          studentRoomCount: 2,
          roomStartNumber: 201,
          hasStudyRoom: false,
        ),
      ],
    ),
  ],
);

Future<void> _settleReal(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }
}

void main() {
  tearDown(AppNotifier.instance.hide);

  late AppDatabase database;
  late BoardingInfoRepository boardingInfoRepository;
  late RoomRepository roomRepository;
  late StudentRepository studentRepository;

  setUp(() {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    boardingInfoRepository = SqliteBoardingInfoRepository(database);
    roomRepository = SqliteRoomRepository(database);
    studentRepository = SqliteStudentRepository(database);
  });

  tearDown(() => database.close());

  Future<void> seedMixedPansiyon({bool withMaleStudent = false}) async {
    await boardingInfoRepository.save(_mixedDraft);
    await roomRepository.syncRooms(_mixedDraft);
    if (withMaleStudent) {
      await studentRepository.saveStudent(
        const Student(fullName: 'Ali Veli', gender: StudentGender.male),
      );
    }
  }

  Future<List<String>> roomSections() async {
    final rooms = await roomRepository.getRooms();
    return rooms.map((room) => room.section.value).toSet().toList()..sort();
  }

  group('tür değişikliği etki analizi', () {
    test('kayıt yoksa onay gerektirmez', () async {
      final impact = await BoardingTypeChangeAnalyzer(database).analyze(
        nextType: BoardingType.girls,
        removedSections: const [BoardingSection.boys],
      );

      expect(impact.removedSectionRoomCount, 0);
      expect(impact.conflictingStudentCount, 0);
      expect(impact.needsConfirmation, isFalse);
    });

    test('silinecek oda ve atamaları sayar', () async {
      await seedMixedPansiyon();
      final rooms = await roomRepository.getRooms();
      final boyRoom = rooms.firstWhere(
        (room) => room.section == BoardingSection.boys,
      );
      final studentId = await studentRepository.saveStudent(
        const Student(fullName: 'Ali Veli', gender: StudentGender.male),
      );
      await roomRepository.assignStudent(
        roomId: boyRoom.id,
        studentId: studentId,
      );

      final impact = await BoardingTypeChangeAnalyzer(database).analyze(
        nextType: BoardingType.girls,
        removedSections: const [BoardingSection.boys],
      );

      expect(impact.removedSectionRoomCount, 2);
      expect(impact.affectedAssignmentCount, 1);
      expect(impact.conflictingStudentCount, 1);
      expect(impact.needsConfirmation, isTrue);
      expect(impact.summary, contains('2 oda silinecek'));
      expect(impact.summary, contains('1 öğrencinin oda ataması'));
    });

    test('kız pansiyonuna geçişte erkek öğrenci uyarısı üretir', () async {
      await seedMixedPansiyon(withMaleStudent: true);

      final impact = await BoardingTypeChangeAnalyzer(database).analyze(
        nextType: BoardingType.girls,
        removedSections: const [BoardingSection.boys],
      );

      expect(impact.conflictingStudentCount, 1);
      expect(
        impact.summary,
        contains('cinsiyeti yeni pansiyon türüyle uyuşmuyor'),
      );
    });
  });

  group('Pansiyon Bilgileri ekranında tür değişimi', () {
    Future<void> pumpForm(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(seedMixedPansiyon);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonAyarlariPage(
              repository: boardingInfoRepository,
              startInFormMode: true,
              editLock: BoardingInfoEditLock(database),
              typeChangeAnalyzer: BoardingTypeChangeAnalyzer(database),
              roomRepository: roomRepository,
            ),
          ),
        ),
      );
      await tester.pump();
      await _settleReal(tester);
      await tester.tap(find.text('Devam'));
      await tester.pump();
      await _settleReal(tester);
    }

    Future<void> changeType(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButton<BoardingType>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(label).last);
      await tester.pump();
      // Tür değişimi etki analizi gerçek veritabanı sorgusu yapar.
      await _settleReal(tester);
    }

    testWidgets('onaylanan tür değişimi türe ait olmayan odaları temizler', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(await tester.runAsync(roomSections), ['boys', 'girls']);

      await changeType(tester, 'Kız');

      expect(find.text('Pansiyon türünü değiştir'), findsOneWidget);
      expect(find.textContaining('oda silinecek'), findsOneWidget);

      await tester.tap(find.text('Değiştir ve temizle'));
      await tester.pump();
      await _settleReal(tester);

      final typeDropdown = tester.widget<DropdownButton<BoardingType>>(
        find.byType(DropdownButton<BoardingType>),
      );
      expect(typeDropdown.value, BoardingType.girls);

      // Kaydedince odalar yalnızca aktif türe ait kalır.
      for (var step = 0; step < 2; step++) {
        await tester.tap(find.text('Devam'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Kaydet'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      await _settleReal(tester);
      AppNotifier.instance.hide();

      expect(await tester.runAsync(roomSections), ['girls']);
      final saved = await tester.runAsync(boardingInfoRepository.load);
      expect(saved?.boardingType, BoardingType.girls);
      expect(saved?.blocks.map((block) => block.section).toSet(), {
        BoardingSection.girls,
      });
    });

    testWidgets('vazgeçildiğinde tür değişmez', (tester) async {
      await pumpForm(tester);

      await changeType(tester, 'Kız');
      expect(find.text('Pansiyon türünü değiştir'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pump();
      await _settleReal(tester);

      final typeDropdown = tester.widget<DropdownButton<BoardingType>>(
        find.byType(DropdownButton<BoardingType>),
      );
      expect(typeDropdown.value, BoardingType.mixed);
      expect(await tester.runAsync(roomSections), ['boys', 'girls']);
    });

    testWidgets('aynı tür seçilince onay sorulmaz', (tester) async {
      await pumpForm(tester);

      await changeType(tester, 'Karma');

      expect(find.text('Pansiyon türünü değiştir'), findsNothing);
    });
  });
}
