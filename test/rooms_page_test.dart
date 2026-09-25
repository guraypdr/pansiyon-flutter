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
    expect(find.text('5-A'), findsNWidgets(2));

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

    expect(find.text('Ali Yılmaz'), findsOneWidget);
    expect(find.byKey(const ValueKey('student_pool_1')), findsNothing);
    expect(roomRepository.assignments, hasLength(1));
    AppNotifier.instance.hide();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _FakeRoomRepository implements RoomRepository {
  final rooms = <BoardingRoom>[
    const BoardingRoom(
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
  @override
  Future<BoardingInfoDraft?> load() async => null;

  @override
  Future<void> save(BoardingInfoDraft draft) async {}
}

class _FakeStudentRepository implements StudentRepository {
  final students = <Student>[
    const Student(id: 1, fullName: 'Ali Yılmaz', className: '5-A'),
  ];

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
