import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/attendance/data/absence_sheet_pdf.dart';
import 'package:pansiyon_yonetim/features/attendance/presentation/attendance_page.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _draft = BoardingInfoDraft(
  schoolName: 'Atatürk Ortaokulu',
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
      floors: [BoardingFloorDraft(floorNumber: 1, studentRoomCount: 2)],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(AppNotifier.instance.hide);

  late AppDatabase database;
  late SqliteBoardingInfoRepository boardingInfoRepository;
  late SqliteStudentRepository studentRepository;
  late SqliteRoomRepository roomRepository;

  setUp(() async {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    boardingInfoRepository = SqliteBoardingInfoRepository(database);
    studentRepository = SqliteStudentRepository(database);
    roomRepository = SqliteRoomRepository(database);
    await boardingInfoRepository.save(_draft);
    await roomRepository.syncRooms(_draft);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendancePage(
            studentRepository: studentRepository,
            roomRepository: roomRepository,
            boardingInfoRepository: boardingInfoRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  Future<int> seedStudents() async {
    final rooms = await roomRepository.getRooms();
    final zeynep = await studentRepository.saveStudent(
      const Student(
        fullName: 'Zeynep Kaya',
        gender: StudentGender.female,
        className: '7-A',
        schoolNumber: '1452',
      ),
    );
    final elif = await studentRepository.saveStudent(
      const Student(
        fullName: 'Elif Şahin',
        gender: StudentGender.female,
        className: '7-B',
        schoolNumber: '1453',
      ),
    );
    final ayse = await studentRepository.saveStudent(
      const Student(
        fullName: 'Ayşe Kara',
        gender: StudentGender.female,
        className: '8-A',
        schoolNumber: '1454',
      ),
    );
    await roomRepository.assignStudent(
      roomId: rooms.first.id,
      studentId: zeynep,
    );
    await roomRepository.assignStudent(
      roomId: rooms.first.id,
      studentId: elif,
    );
    if (rooms.length > 1) {
      await roomRepository.assignStudent(
        roomId: rooms[1].id,
        studentId: ayse,
      );
    }
    return zeynep;
  }

  testWidgets('yoklama sayfası oda numarası ve üç ikon butonu gösterir', (
    tester,
  ) async {
    final zeynep = (await tester.runAsync<int>(seedStudents))!;
    await pumpPage(tester);

    expect(find.text('Yoklama'), findsOneWidget);
    expect(find.byKey(const Key('attendance_print_button')), findsOneWidget);
    expect(find.textContaining('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Oda 1 • Sınıf 7-A • Okul seçilmedi'), findsOneWidget);
    expect(find.byKey(Key('attendance_leave_$zeynep')), findsOneWidget);
    expect(find.byKey(Key('attendance_report_$zeynep')), findsOneWidget);
    expect(find.byKey(Key('attendance_history_$zeynep')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('evci izni eklenince kayıt durumu ve rozet güncellenir', (
    tester,
  ) async {
    final zeynep = (await tester.runAsync<int>(seedStudents))!;
    await pumpPage(tester);

    await tester.tap(find.byKey(Key('attendance_leave_$zeynep')));
    await tester.pump();
    await settle(tester);

    expect(find.text('Evci izni ekle • Zeynep Kaya'), findsOneWidget);
    await tester.tap(find.text('İzni ekle'));
    await tester.pump();
    await settle(tester);

    expect(find.text('Evci izinli'), findsWidgets);
    final records = (await tester.runAsync(
      () => studentRepository.getAttendance(studentId: zeynep),
    ))!;
    expect(records.length, 1);
    expect(records.first.status, StudentAttendanceStatus.homeLeave);
    expect(find.byKey(Key('attendance_clear_$zeynep')), findsOneWidget);
  });

  testWidgets('rapor ekleme geçmişi doldurur', (tester) async {
    final zeynep = (await tester.runAsync<int>(seedStudents))!;
    await pumpPage(tester);

    await tester.tap(find.byKey(Key('attendance_report_$zeynep')));
    await tester.pump();
    await settle(tester);
    expect(find.text('Rapor ekle • Zeynep Kaya'), findsOneWidget);
    await tester.tap(find.text('Raporu ekle'));
    await tester.pump();
    await settle(tester);

    final records = (await tester.runAsync(
      () => studentRepository.getAttendance(studentId: zeynep),
    ))!;
    expect(records.first.status, StudentAttendanceStatus.medicalReport);
  });

  testWidgets('devamsızlık detayları geçmişi listeler', (tester) async {
    final zeynep = (await tester.runAsync<int>(seedStudents))!;
    await pumpPage(tester);

    await tester.tap(find.byKey(Key('attendance_history_$zeynep')));
    await tester.pump();
    await settle(tester);

    expect(
      find.text('Devamsızlık detayları • Zeynep Kaya'),
      findsOneWidget,
    );
    expect(find.text('Kayıtlı izin veya rapor bulunmuyor.'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pump();
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  test('devamsızlık çizelgesi PDF verisi doğru üretilir', () async {
    await seedStudents();
    final rooms = await roomRepository.getRooms();
    final students = await studentRepository.getStudents();
    final assignments = await roomRepository.getAssignments();
    final roomById = {for (final room in rooms) room.id: room};

    final entries = students.map((student) {
      final assignment = assignments.firstWhere(
        (item) => item.studentId == student.id,
      );
      return AbsenceSheetEntry(
        studentName: student.fullName,
        className: student.className,
        schoolNumber: student.schoolNumber,
        roomLabel: '${roomById[assignment.roomId]!.roomNumber}',
        attendanceMark: student.fullName == 'Zeynep Kaya' ? 'İ' : '',
        note: student.fullName == 'Zeynep Kaya' ? 'Evci izni' : null,
      );
    }).toList();

    final data = AbsenceSheetData(
      schoolName: 'Atatürk Ortaokulu',
      educationYear: absenceSheetEducationYear(DateTime(2026, 9, 27)),
      date: DateTime(2026, 9, 27),
      locationLabel: 'Kız Bölümü - A Blok - Zemin Kat',
      entries: entries,
      summary: AbsenceSheetSummary(
        presentCount: 2,
        leaveCount: 1,
        reportCount: 0,
        absentCount: 0,
        totalCount: entries.length,
      ),
    );

    expect(data.educationYear, '2026-2027');
    expect(absenceSheetEducationYear(DateTime(2026, 5, 4)), '2025-2026');
    expect(formatAbsenceSheetDate(DateTime(2026, 9, 5)), '05.09.2026');
    expect(data.summary.leaveAndReportCount, 1);
    expect(
      shortenAbsenceSheetName('Abdulkadir Mehmet Şahin Karabulut'),
      'Abdulkadir Mehmet Şahin K',
    );
    expect(
      shortenAbsenceSheetName('Zeynep Kaya'),
      'Zeynep Kaya',
    );
    expect(shortenAbsenceSheetVertical('123456'), '12345');
    expect(shortenAbsenceSheetVertical(null), '');

    final fonts = await AbsenceSheetFonts.load();
    final bytes = await buildAbsenceSheetPdf(pw.Document(), data, fonts).save();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
