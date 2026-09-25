import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late SqliteStudentRepository repository;

  setUp(() {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    repository = SqliteStudentRepository(database);
  });

  tearDown(() => database.close());

  test('okul ve öğrenci bilgilerini kaydedip listeler', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );
    final studentId = await repository.saveStudent(
      Student(
        fullName: 'Ahmet Yılmaz',
        nationalId: '12345678901',
        schoolId: schoolId,
        className: '11',
        sectionName: 'A',
        schoolNumber: '2026-001',
        birthDate: DateTime(2010, 5, 12),
        phone: '05321234567',
        motherName: 'Ayşe Yılmaz',
        fatherName: 'Mehmet Yılmaz',
        motherPhone: '05321234567',
        fatherPhone: '05327654321',
        boardingRegistrationDate: DateTime(2026, 9, 1),
      ),
    );

    final students = await repository.getStudents(query: 'ahmet');
    final student = await repository.getStudent(studentId);

    expect(students, hasLength(1));
    expect(student!.fullName, 'Ahmet Yılmaz');
    expect(student.schoolName, 'Atatürk Lisesi');
    expect(student.className, '11');
    expect(student.birthDate, DateTime(2010, 5, 12));
    expect(student.motherPhone, '05321234567');
  });

  test('günlük izin ve disiplin kayıtlarını saklar', () async {
    final studentId = await repository.saveStudent(
      const Student(fullName: 'Deniz Kaya'),
    );
    final date = DateTime(2026, 9, 25);

    await repository.saveAttendance(
      StudentAttendance(
        studentId: studentId,
        date: date,
        status: StudentAttendanceStatus.homeLeave,
        note: 'Aile izni',
      ),
    );
    await repository.saveDisciplineIncident(
      StudentDisciplineIncident(
        studentId: studentId,
        date: date,
        description: 'Örnek disiplin kaydı',
      ),
    );

    final attendance = await repository.getAttendance(
      studentId: studentId,
      date: date,
    );
    final incidents = await repository.getDisciplineIncidents(studentId);

    expect(attendance.single.status, StudentAttendanceStatus.homeLeave);
    expect(attendance.single.note, 'Aile izni');
    expect(incidents.single.description, 'Örnek disiplin kaydı');
  });

  test('aynı öğrenci ve tarih için yoklama kaydını günceller', () async {
    final studentId = await repository.saveStudent(
      const Student(fullName: 'Elif Demir'),
    );
    final date = DateTime(2026, 9, 25);

    await repository.saveAttendance(
      StudentAttendance(
        studentId: studentId,
        date: date,
        status: StudentAttendanceStatus.present,
      ),
    );
    await repository.saveAttendance(
      StudentAttendance(
        studentId: studentId,
        date: date,
        status: StudentAttendanceStatus.medicalReport,
      ),
    );

    final attendance = await repository.getAttendance(
      studentId: studentId,
      date: date,
    );

    expect(attendance, hasLength(1));
    expect(attendance.single.status, StudentAttendanceStatus.medicalReport);
  });
}
