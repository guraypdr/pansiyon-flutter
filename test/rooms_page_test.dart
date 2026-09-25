import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/rooms/presentation/rooms_page.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

void main() {
  testWidgets('odaları oluşturur ve öğrenciyi sürükleyerek yerleştirir', (
    tester,
  ) async {
    addTearDown(AppNotifier.instance.hide);
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final roomRepository = _FakeRoomRepository();
    final studentRepository = _FakeStudentRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RoomsPage(
            roomRepository: roomRepository,
            boardingInfoRepository: _FakeBoardingInfoRepository(),
            studentRepository: studentRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Oda 101'), findsOneWidget);
    expect(find.text('Öğrenci Havuzu'), findsOneWidget);
    expect(find.text('Dolu odaları göster'), findsOneWidget);
    expect(find.text('Hazırlık'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('5-A'), findsOneWidget);

    final studentFinder = find.byKey(const ValueKey('student_pool_1'));
    final roomFinder = find.byKey(const ValueKey('room_1'));
    expect(studentFinder, findsOneWidget);
    expect(roomFinder, findsOneWidget);
    await tester.ensureVisible(studentFinder);
    await tester.ensureVisible(roomFinder);
    final gesture = await tester.startGesture(tester.getCenter(studentFinder));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(roomFinder));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }
    expect(roomRepository.assignments, hasLength(1));
    AppNotifier.instance.hide();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('yanlış cinsiyetteki öğrenci bırakılınca uyarı gösterir', (
    tester,
  ) async {
    addTearDown(AppNotifier.instance.hide);
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final roomRepository = _FakeRoomRepository(
      rooms: const [
        BoardingRoom(
          id: 1,
          sourceKey: 'girls|0|Kız|0|101',
          blockName: 'Kız Bloğu',
          section: BoardingSection.girls,
          floorLabel: 'Zemin Kat',
          floorNumber: 1,
          roomNumber: 101,
          capacity: 2,
          occupantCount: 0,
        ),
        BoardingRoom(
          id: 2,
          sourceKey: 'boys|0|Erkek|0|101',
          blockName: 'Erkek Bloğu',
          section: BoardingSection.boys,
          floorLabel: 'Zemin Kat',
          floorNumber: 1,
          roomNumber: 101,
          capacity: 2,
          occupantCount: 0,
        ),
      ],
    );
    final studentRepository = _FakeStudentRepository(
      students: const [
        Student(
          id: 1,
          fullName: 'Kız Öğrenci',
          gender: StudentGender.female,
          className: '9',
        ),
        Student(
          id: 2,
          fullName: 'Erkek Öğrenci',
          gender: StudentGender.male,
          className: '9',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RoomsPage(
            roomRepository: roomRepository,
            boardingInfoRepository: _FakeBoardingInfoRepository(
              boardingType: BoardingType.mixed,
            ),
            studentRepository: studentRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final maleStudent = find.byKey(const ValueKey('student_pool_2'));
    final girlsRoom = find.byKey(const ValueKey('room_1'));
    await tester.ensureVisible(maleStudent);
    await tester.ensureVisible(girlsRoom);
    final gesture = await tester.startGesture(tester.getCenter(maleStudent));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(girlsRoom));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(
      find.text('Bu oda kız bölümüne ait. Kız öğrenci yerleştirilmelidir.'),
      findsOneWidget,
    );
    expect(roomRepository.assignments, isEmpty);
    AppNotifier.instance.hide();
    await tester.pump();
  });
}

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository({List<BoardingRoom>? rooms})
    : rooms =
          rooms ??
          const [
            BoardingRoom(
              id: 1,
              sourceKey: 'girls|0|Kız Bloğu|0|Zemin Kat|101',
              blockName: 'Kız Bloğu',
              section: BoardingSection.girls,
              floorLabel: 'Zemin Kat',
              floorNumber: 1,
              roomNumber: 101,
              capacity: 2,
              occupantCount: 0,
            ),
          ];

  final List<BoardingRoom> rooms;
  final assignments = <RoomAssignment>[];

  @override
  Future<void> assignStudent({
    required int roomId,
    required int studentId,
  }) async {
    assignments.add(RoomAssignment(roomId: roomId, studentId: studentId));
    final index = rooms.indexWhere((room) => room.id == roomId);
    final room = rooms[index];
    rooms[index] = BoardingRoom(
      id: room.id,
      sourceKey: room.sourceKey,
      blockName: room.blockName,
      section: room.section,
      floorLabel: room.floorLabel,
      floorNumber: room.floorNumber,
      roomNumber: room.roomNumber,
      capacity: room.capacity,
      occupantCount: room.occupantCount + 1,
    );
  }

  @override
  Future<List<RoomAssignment>> getAssignments() async => List.of(assignments);

  @override
  Future<List<BoardingRoom>> getRooms() async => List.of(rooms);

  @override
  Future<void> syncRooms(BoardingInfoDraft? boardingInfo) async {}

  @override
  Future<void> unassignStudent(int studentId) async {
    assignments.removeWhere((assignment) => assignment.studentId == studentId);
  }

  @override
  Future<void> updateRoomCapacity({
    required int roomId,
    required int capacity,
  }) async {
    final index = rooms.indexWhere((room) => room.id == roomId);
    final room = rooms[index];
    rooms[index] = BoardingRoom(
      id: room.id,
      sourceKey: room.sourceKey,
      blockName: room.blockName,
      section: room.section,
      floorLabel: room.floorLabel,
      floorNumber: room.floorNumber,
      roomNumber: room.roomNumber,
      capacity: capacity,
      occupantCount: room.occupantCount,
    );
  }
}

class _FakeBoardingInfoRepository implements BoardingInfoRepository {
  _FakeBoardingInfoRepository({this.boardingType = BoardingType.girls});

  final BoardingType boardingType;

  @override
  Future<BoardingInfoDraft?> load() async => BoardingInfoDraft(
    schoolName: 'Test',
    principalName: 'Test',
    principalPhone: '0312 555 10 10',
    deputyName: 'Test',
    deputyPhone: '0312 555 10 11',
    boardingType: boardingType,
    educationLevel: EducationLevel.highSchool,
    blocks: const [],
  );

  @override
  Future<void> save(BoardingInfoDraft draft) async {}
}

class _FakeStudentRepository implements StudentRepository {
  _FakeStudentRepository({List<Student>? students})
    : students =
          students ??
          const [
            Student(
              id: 1,
              fullName: 'Ali Yılmaz',
              gender: StudentGender.female,
              className: '5-A',
            ),
          ];

  final List<Student> students;

  @override
  Future<int> importStudents(List<Student> students) async => students.length;

  @override
  Future<List<StudentAttendance>> getAttendance({
    int? studentId,
    DateTime? date,
  }) async => const [];

  @override
  Future<List<StudentDisciplineIncident>> getDisciplineIncidents(
    int studentId,
  ) async => const [];

  @override
  Future<Student?> getStudent(int id) async {
    for (final student in students) {
      if (student.id == id) return student;
    }
    return null;
  }

  @override
  Future<List<Student>> getStudents({String query = ''}) async =>
      List.of(students);

  @override
  Future<List<School>> getSchools() async => const [];

  @override
  Future<void> saveAttendance(StudentAttendance attendance) async {}

  @override
  Future<int> saveSchool(School school) async => school.id ?? 1;

  @override
  Future<int> saveStudent(Student student) async => student.id ?? 1;

  @override
  Future<void> saveDisciplineIncident(
    StudentDisciplineIncident incident,
  ) async {}

  @override
  Future<void> deleteStudent(int id) async {}
}
