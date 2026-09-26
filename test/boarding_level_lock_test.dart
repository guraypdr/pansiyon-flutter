import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_edit_lock.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/settings/presentation/pansiyon_ayarlari_page.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _draft = BoardingInfoDraft(
  schoolName: 'Atatürk Ortaokulu Pansiyonu',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.girls,
  educationLevel: EducationLevel.middleSchool,
  blocks: [
    BoardingBlockDraft(
      section: BoardingSection.girls,
      name: 'Kız Bloğu',
      standardRoomCapacity: 4,
      floors: [
        BoardingFloorDraft(
          floorNumber: 1,
          hasStudentRooms: true,
          studentRoomCount: 4,
          roomStartNumber: 101,
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
  late BoardingInfoRepository repository;

  setUp(() {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    repository = SqliteBoardingInfoRepository(database);
  });

  tearDown(() => database.close());

  group('kademe kilidi kuralları', () {
    test('kayıt yoksa kademe değiştirilebilir', () async {
      final usage = await BoardingInfoEditLock(database).loadUsage();

      expect(usage.hasData, isFalse);
      final decision = BoardingInfoEditLock.decide(
        usage: usage,
        storedLevel: EducationLevel.middleSchool,
        nextLevel: EducationLevel.highSchool,
      );
      expect(decision.isBlocked, isFalse);
    });

    test('aynı kademe seçilirse engel oluşmaz', () {
      const usage = PansiyonUsageInfo(studentCount: 3, roomCount: 2);
      final decision = BoardingInfoEditLock.decide(
        usage: usage,
        storedLevel: EducationLevel.middleSchool,
        nextLevel: EducationLevel.middleSchool,
      );

      expect(decision.isBlocked, isFalse);
    });

    test('öğrenci varsa kademe kilitlenir', () async {
      final studentRepository = SqliteStudentRepository(database);
      await repository.save(_draft);
      await studentRepository.saveStudent(
        const Student(fullName: 'Ali Veli', className: '7'),
      );

      final usage = await BoardingInfoEditLock(database).loadUsage();
      expect(usage.studentCount, 1);
      expect(usage.hasData, isTrue);

      final decision = BoardingInfoEditLock.decide(
        usage: usage,
        storedLevel: EducationLevel.middleSchool,
        nextLevel: EducationLevel.highSchool,
      );
      expect(decision.isBlocked, isTrue);
      expect(decision.message, contains('Kademe değiştirilemez'));
      expect(decision.message, contains('Yeni Pansiyon Oluştur'));
      expect(decision.message, contains('1 öğrenci kaydı var'));
    });

    test('oda varsa kademe kilitlenir', () async {
      final roomRepository = SqliteRoomRepository(database);
      await repository.save(_draft);
      await roomRepository.syncRooms(_draft);

      final usage = await BoardingInfoEditLock(database).loadUsage();
      expect(usage.roomCount, greaterThan(0));
      expect(usage.hasData, isTrue);

      final decision = BoardingInfoEditLock.decide(
        usage: usage,
        storedLevel: EducationLevel.middleSchool,
        nextLevel: EducationLevel.highSchool,
      );
      expect(decision.isBlocked, isTrue);
    });
  });

  group('Pansiyon Bilgileri ekranında kademe kilidi', () {
    Future<void> pumpPage(WidgetTester tester, {required bool withData}) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await database.database;
        await repository.save(_draft);
        if (withData) {
          await SqliteStudentRepository(
            database,
          ).saveStudent(const Student(fullName: 'Ali Veli', className: '7'));
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonAyarlariPage(
              startInFormMode: true,
              repository: repository,
              editLock: BoardingInfoEditLock(database),
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

    testWidgets('öğrenci varsa kademe alanı kilitli görünür', (tester) async {
      await pumpPage(tester, withData: true);

      expect(
        find.byKey(const Key('education_level_lock_notice')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Kademe kilitli. 1 öğrenci kaydı var.'),
        findsOneWidget,
      );
      final levelDropdown = tester.widget<DropdownButton<EducationLevel>>(
        find.byType(DropdownButton<EducationLevel>),
      );
      expect(levelDropdown.onChanged, isNull);
      expect(levelDropdown.value, EducationLevel.middleSchool);
    });

    testWidgets('kayıt yoksa kademe değiştirilebilir', (tester) async {
      await pumpPage(tester, withData: false);

      expect(
        find.byKey(const Key('education_level_lock_notice')),
        findsNothing,
      );
      final levelDropdown = tester.widget<DropdownButton<EducationLevel>>(
        find.byType(DropdownButton<EducationLevel>),
      );
      expect(levelDropdown.onChanged, isNotNull);

      await tester.tap(find.byType(DropdownButton<EducationLevel>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Lise').last);
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        tester
            .widget<DropdownButton<EducationLevel>>(
              find.byType(DropdownButton<EducationLevel>),
            )
            .value,
        EducationLevel.highSchool,
      );
    });
  });
}
