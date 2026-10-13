import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/students/data/student_duty_report_print.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

Student student(int id, String name) => Student(id: id, fullName: name);

/// PDF baytlarından sayfa sayısını bulur.
///
/// Sayfa nesneleri sıkıştırılmadan yazılır; `/Type /Pages` kök düğümü `[^s]`
/// ile elenir.
int countPdfPages(List<int> bytes) {
  final text = latin1.decode(bytes);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Öğrenci nöbet listesi çıktısı', () {
    final list = StudentDutyList(
      id: 1,
      startDate: DateTime(2026, 10, 5),
      entries: const [
        StudentDutyEntry(listId: 1, sequence: 1, studentId: 1),
        StudentDutyEntry(listId: 1, sequence: 1, studentId: 2),
        StudentDutyEntry(listId: 1, sequence: 2, studentId: 3),
        StudentDutyEntry(listId: 1, sequence: 2, studentId: 4),
        StudentDutyEntry(listId: 1, sequence: 3, studentId: 5),
      ],
    );

    final students = [
      student(1, 'Ali Veli'),
      student(2, 'Zeynep Kaya'),
      student(3, 'Mehmet Yılmaz'),
      student(4, 'Ayşe Demir'),
      student(5, 'Fatma Öz'),
    ];

    final report = StudentDutyReportData(
      schoolName: 'Mehmet Akif Ersoy',
      list: list,
      students: students,
      dates: [
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 7),
      ],
      roomNumberOf: (id) => switch (id) {
        1 => 101,
        2 => 101,
        3 => 102,
        4 => 102,
        _ => 103,
      },
    );

    test('geçerli bir PDF üretilir', () async {
      final bytes = await buildStudentDutyReportPdf(report);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('müdür adı verilmezse imza bloğu basılmaz', () async {
      final bytes = await buildStudentDutyReportPdf(report);

      expect(bytes, isNotEmpty);
    });

    test('müdür adı verilirse imza bloğu eklenir', () async {
      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Mehmet Akif Ersoy',
          list: list,
          students: students,
          dates: report.dates,
          principalName: 'Kemal Yıldız',
        ),
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('nöbet sorumlusu adı ikinci imza satırı olarak eklenir', () async {
      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Mehmet Akif Ersoy',
          list: list,
          students: students,
          dates: report.dates,
          dutyOfficerName: 'Ayşe Kara',
        ),
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('müdür ve nöbet sorumlusu birlikte verilirse iki imza basılır', () async {
      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Mehmet Akif Ersoy',
          list: list,
          students: students,
          dates: report.dates,
          principalName: 'Kemal Yıldız',
          dutyOfficerName: 'Ayşe Kara',
        ),
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('imza adı boşsa bloğu hiç basılmaz', () async {
      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Mehmet Akif Ersoy',
          list: list,
          students: students,
          dates: report.dates,
        ),
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('öğrenci olmayan liste de hatasız basılır', () async {
      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Okul',
          list: StudentDutyList(
            id: 1,
            startDate: DateTime(2026, 10, 5),
            entries: const [],
          ),
          students: const [],
          dates: const [],
        ),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('listeler tek sayfaya sığar', () async {
      final bytes = await buildStudentDutyReportPdf(report);

      expect(countPdfPages(bytes), 1);
    });

    test('çok uzun liste sayfalara bölünür', () async {
      final entries = <StudentDutyEntry>[
        for (var i = 1; i <= 120; i++)
          StudentDutyEntry(listId: 1, sequence: (i + 1) ~/ 2, studentId: i),
      ];
      final longStudents = [
        for (var i = 1; i <= 120; i++) student(i, 'Öğrenci $i'),
      ];
      final dates = [
        for (var i = 0; i < 60; i++)
          DateTime(2026, 10, 5).add(Duration(days: i)),
      ];

      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Okul',
          list: StudentDutyList(
            id: 1,
            startDate: DateTime(2026, 10, 5),
            entries: entries,
          ),
          students: longStudents,
          dates: dates,
        ),
      );

      expect(countPdfPages(bytes), greaterThan(1));
    });

    test('haftalar pazartesi başlayarak ayrılır', () {
      // 5 Ekim 2026 pazartesi; 7 günlük liste tam bir hafta, sonra yeni hafta.
      final weeks = studentDutyWeeks([
        for (var i = 0; i < 7; i++) DateTime(2026, 10, 5).add(Duration(days: i)),
      ]);

      expect(weeks.length, 1);
      expect(weeks.first.length, 7);
    });

    test('bir haftayı aşan liste haftalara bölünür', () {
      final weeks = studentDutyWeeks([
        for (var i = 0; i < 10; i++) DateTime(2026, 10, 5).add(Duration(days: i)),
      ]);

      expect(weeks.length, 2);
      expect(weeks.first.length, 7);
      expect(weeks.last.length, 3);
    });

    test('pazartesi başlamayan liste eksik günle başlar', () {
      // 7 Ekim 2026 çarşamba; 5 günlük liste çarşambadan pazara kadar sürer.
      final weeks = studentDutyWeeks([
        for (var i = 0; i < 5; i++) DateTime(2026, 10, 7).add(Duration(days: i)),
      ]);

      expect(weeks.length, 1);
      expect(weeks.first.length, 5);
      expect(weeks.first.first, DateTime(2026, 10, 7));
    });

    test('boş listede hafta yoktur', () {
      expect(studentDutyWeeks(const []), isEmpty);
    });

    test('hafta grupları çıktıda kullanılır', () async {
      final dates = [
        for (var i = 0; i < 10; i++)
          DateTime(2026, 10, 5).add(Duration(days: i)),
      ];
      final entries = <StudentDutyEntry>[
        for (var i = 1; i <= 10; i++)
          StudentDutyEntry(listId: 1, sequence: i, studentId: i),
      ];

      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Okul',
          list: StudentDutyList(
            id: 1,
            startDate: DateTime(2026, 10, 5),
            entries: entries,
          ),
          students: [for (var i = 1; i <= 10; i++) student(i, 'Öğrenci $i')],
          dates: dates,
        ),
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('öğrenci eşleşmezse kimlik yazılır', () async {
      final bytes = await buildStudentDutyReportPdf(
        StudentDutyReportData(
          schoolName: 'Okul',
          list: StudentDutyList(
            id: 1,
            startDate: DateTime(2026, 10, 5),
            entries: const [
              StudentDutyEntry(listId: 1, sequence: 1, studentId: 99),
            ],
          ),
          students: const [],
          dates: [DateTime(2026, 10, 5)],
        ),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}