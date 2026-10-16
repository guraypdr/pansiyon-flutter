import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/home/data/dashboard_repository.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('dashboard özetini gerçek kayıtlardan hesaplar', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);
    final boardingInfoRepository = SqliteBoardingInfoRepository(database);
    final studentRepository = SqliteStudentRepository(database);
    final roomRepository = SqliteRoomRepository(database);
    final dashboardRepository = RepositoryDashboardRepository(
      boardingInfoRepository: boardingInfoRepository,
      studentRepository: studentRepository,
      roomRepository: roomRepository,
      mealRepository: SqliteMealRepository(database),
      dutyRepository: SqliteDutyRepository(database),
    );

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
            name: 'Kız Bloğu',
            standardRoomCapacity: 2,
            floors: [
              BoardingFloorDraft(
                floorNumber: 1,
                hasStudentRooms: true,
                studentRoomCount: 2,
                roomStartNumber: 101,
              ),
            ],
          ),
        ],
      ),
    );
    final firstStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Elif Kaya', gender: StudentGender.female),
    );
    final secondStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Zeynep Demir', gender: StudentGender.female),
    );

    await roomRepository.syncRooms(await boardingInfoRepository.load());
    final rooms = await roomRepository.getRooms();
    await roomRepository.assignStudent(
      roomId: rooms.first.id,
      studentId: firstStudentId,
    );

    final summary = await dashboardRepository.load();

    expect(summary.schoolName, 'Test Pansiyonu');
    expect(summary.studentCount, 2);
    expect(summary.roomCount, 2);
    expect(summary.blockCount, 1);
    expect(summary.totalCapacity, 4);
    expect(summary.occupiedBeds, 1);
    expect(summary.emptyBeds, 3);
    expect(summary.occupancyRate, closeTo(0.25, 0.0001));
    expect(secondStudentId, isNotNull);
  });

  test('günün menüsünü ve nöbetçi öğretmenleri özete ekler', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);
    final boardingInfoRepository = SqliteBoardingInfoRepository(database);
    final studentRepository = SqliteStudentRepository(database);
    final roomRepository = SqliteRoomRepository(database);
    final mealRepository = SqliteMealRepository(database);
    final dutyRepository = SqliteDutyRepository(database);
    final dashboardRepository = RepositoryDashboardRepository(
      boardingInfoRepository: boardingInfoRepository,
      studentRepository: studentRepository,
      roomRepository: roomRepository,
      mealRepository: mealRepository,
      dutyRepository: dutyRepository,
    );

    final today = DateTime.now();
    await mealRepository.saveDay(
      MealDay(
        date: DateTime(today.year, today.month, today.day),
        items: const {
          MealType.breakfast: ['Domates', 'Peynir'],
          MealType.lunch: ['Yayla çorbası'],
          MealType.dinner: ['Tavuk sote'],
        },
      ),
    );

    await dutyRepository.saveTeacher(
      DutyTeacher(fullName: 'Ahmet Yılmaz', nationalId: '1'),
    );
    await dutyRepository.replaceAssignments(
      year: today.year,
      month: today.month,
      assignments: [
        DutyAssignment(
          year: today.year,
          month: today.month,
          date: DateTime(today.year, today.month, today.day),
          teacherId: 1,
          location: 'Nöbet Odası',
        ),
      ],
    );

    final summary = await dashboardRepository.load();

    expect(summary.hasTodayMeal, isTrue);
    expect(summary.todayMeal?.mealsOf(MealType.lunch), ['Yayla çorbası']);
    expect(summary.todayMealDate, isNotNull);
    expect(summary.todayDutySlots, hasLength(1));
    expect(summary.todayDutySlots.single.teacher.fullName, 'Ahmet Yılmaz');
    expect(summary.todayDutySlots.single.location, 'Nöbet Odası');
  });

  test('menü veya nöbet verisi yoksa özet boş döner', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);
    final dashboardRepository = RepositoryDashboardRepository(
      boardingInfoRepository: SqliteBoardingInfoRepository(database),
      studentRepository: SqliteStudentRepository(database),
      roomRepository: SqliteRoomRepository(database),
      mealRepository: SqliteMealRepository(database),
      dutyRepository: SqliteDutyRepository(database),
    );

    final summary = await dashboardRepository.load();

    expect(summary.hasTodayMeal, isFalse);
    expect(summary.todayMeal, isNull);
    expect(summary.todayDutySlots, isEmpty);
  });

  test('nöbet verisi okunamazsa pano yine de yüklenir', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);
    final dashboardRepository = RepositoryDashboardRepository(
      boardingInfoRepository: SqliteBoardingInfoRepository(database),
      studentRepository: SqliteStudentRepository(database),
      roomRepository: SqliteRoomRepository(database),
      mealRepository: SqliteMealRepository(database),
      dutyRepository: _FailingDutyRepository(),
    );

    final summary = await dashboardRepository.load();

    // Nöbet hatası özeti sıfırmamalı.
    expect(summary.todayDutySlots, isEmpty);
    expect(summary.studentCount, 0);
  });
}

/// Nöbet okuması hata veren depo.
class _FailingDutyRepository implements DutyRepository {
  @override
  Future<List<DutyDutySlot>> getDutySlotsForDate(DateTime date) async =>
      throw StateError('nöbet okunamadı');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
