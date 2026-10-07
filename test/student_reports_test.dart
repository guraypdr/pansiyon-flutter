import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/contact_sheet_pdf.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ContactSheetEntry entry(
    String room,
    String name,
    String tc,
    bool chronic,
    bool medication,
    String blood,
    String phone,
    String guardian,
    String guardian2,
  ) {
    return ContactSheetEntry(
      roomLabel: room,
      studentName: name,
      nationalId: tc,
      hasChronicDisease: chronic,
      hasRegularMedication: medication,
      bloodType: blood,
      studentPhone: phone,
      guardianPhone: guardian,
      guardian2Phone: guardian2,
    );
  }

  test('iletişim bilgileri formu her kat için ayrı sayfa üretir', () async {
    final fonts = await ReportFonts.load();
    final data = ContactSheetData(
      schoolName: 'Atatürk Ortaokulu',
      educationYear: reportEducationYear(DateTime(2026, 9, 27)),
      date: DateTime(2026, 9, 27),
      groups: [
        ContactSheetGroup(
          locationLabel: 'Kız Bölümü - A Blok - Zemin Kat',
          entries: [
            entry(
              '101',
              'Zeynep Kaya',
              '12345678901',
              true,
              true,
              '0 Rh+',
              '0532 111 22 33',
              '0533 222 33 44',
              '0535 333 44 55',
            ),
            entry(
              '101',
              'Elif Şahin',
              '12345678902',
              false,
              false,
              'A Rh-',
              '0532 444 55 66',
              '',
              '0535 555 66 77',
            ),
            entry(
              '102',
              'Ayşe Kara',
              '12345678904',
              false,
              false,
              'AB Rh+',
              '',
              '0533 888 99 00',
              '',
            ),
          ],
        ),
        ContactSheetGroup(
          locationLabel: 'Kız Bölümü - A Blok - 1. Kat',
          entries: [
            entry(
              '201',
              'Merve Aslan',
              '22345678901',
              false,
              false,
              '0 Rh+',
              '0532 333 44 55',
              '0533 444 55 66',
              '0535 555 66 77',
            ),
          ],
        ),
      ],
    );

    final document = buildContactSheetPdf(pw.Document(), data, fonts);
    final bytes = await document.save();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('cok sayida ogrenci sayfalara bolunur', () async {
    // Regresyon: form tek sayfaya sigmayan sutun halinde basiliordu;
    // 'pdf' paketi tasan kismi sessizce attigi icin form tamamen bos
    // cikiyordu. Oda atamasi olmayan ogrenciler tek grupta toplandigi
    // icin bu durum rutin olarak olusuyordu.
    final fonts = await ReportFonts.load();

    Future<List<int>> build(int count) async {
      final data = ContactSheetData(
        schoolName: 'Ataturk Ortaokulu',
        educationYear: reportEducationYear(DateTime(2026, 9, 27)),
        date: DateTime(2026, 9, 27),
        groups: [
          ContactSheetGroup(
            locationLabel: 'Odasiz Ogrenciler',
            entries: [
              for (var index = 0; index < count; index++)
                ContactSheetEntry(
                  roomLabel: '-',
                  studentName: 'Ogrenci $index',
                  nationalId: '123456789${index % 10}',
                  hasChronicDisease: false,
                  hasRegularMedication: false,
                  bloodType: '0 Rh+',
                  studentPhone: '0532 000 00 0$index',
                  guardianPhone: '0532 111 11 1$index',
                  guardian2Phone: null,
                ),
            ],
          ),
        ],
      );
      return buildContactSheetPdf(pw.Document(), data, fonts).save();
    }

    final small = await build(10);
    final large = await build(54);

    // Icerik kaybolmadigi, ogrenci eklendikce formun buyumesinden gorulur.
    expect(
      large.length,
      greaterThan(small.length),
      reason: 'ogrenci eklendiginde form da buyumeli',
    );

    // 54 ogrenci tek sayfaya sigmaz; bolunmeli.
    final pdfText = String.fromCharCodes(large);
    final pageCount = RegExp('/Type\\s*/Page[^s]').allMatches(pdfText).length;
    expect(pageCount, greaterThan(1));
  });

  test('form yardımcıları metni ve telefonu sınırlar', () {
    expect(reportEducationYear(DateTime(2026, 9, 27)), '2026-2027');
    expect(reportEducationYear(DateTime(2026, 5, 4)), '2025-2026');
    expect(reportDate(DateTime(2026, 9, 5)), '05.09.2026');
    expect(reportDayName(DateTime(2026, 9, 27)), 'Pazar');
    expect(
      reportSchoolTitle('Atatürk Ortaokulu'),
      'Atatürk Ortaokulu Müdürlüğü',
    );
    expect(
      reportSchoolTitle('Atatürk Ortaokulu Müdürlüğü'),
      'Atatürk Ortaokulu Müdürlüğü',
    );
    expect(reportPhone('0532 111 22 33'), '05321112233');
    expect(reportPhone(null), '');
    expect(
      reportTruncate('Abdulkadir Mehmet Şahin Karabulut', 25),
      'Abdulkadir Mehmet Şahin K',
    );
    expect(contactSheetName('Zeynep Kaya'), 'Zeynep Kaya');
  });

  test('öğrenciler kat bazında ve oda numarasına göre gruplanır', () {
    const room101 = BoardingRoom(
      id: 1,
      sourceKey: '101',
      blockName: 'A Blok',
      section: BoardingSection.girls,
      floorLabel: 'Zemin Kat',
      floorNumber: 1,
      roomNumber: 101,
      capacity: 4,
      occupantCount: 0,
    );
    const room102 = BoardingRoom(
      id: 2,
      sourceKey: '102',
      blockName: 'A Blok',
      section: BoardingSection.girls,
      floorLabel: 'Zemin Kat',
      floorNumber: 1,
      roomNumber: 102,
      capacity: 4,
      occupantCount: 0,
    );
    const room201 = BoardingRoom(
      id: 3,
      sourceKey: '201',
      blockName: 'A Blok',
      section: BoardingSection.girls,
      floorLabel: '1. Kat',
      floorNumber: 2,
      roomNumber: 201,
      capacity: 4,
      occupantCount: 0,
    );
    const rooms = {1: room101, 2: room101, 3: room102, 4: room201};

    const students = [
      Student(id: 1, fullName: 'Zeynep Kaya', nationalId: '1001'),
      Student(id: 2, fullName: 'Elif Şahin', nationalId: '1002'),
      Student(id: 3, fullName: 'Ayşe Kara', nationalId: '1003'),
      Student(id: 4, fullName: 'Merve Aslan', nationalId: '1004'),
      Student(id: 5, fullName: 'Odasız Öğrenci', nationalId: '1005'),
    ];

    final groups = buildContactSheetGroups(
      students: students,
      roomOf: (studentId) => rooms[studentId],
    );

    expect(groups.length, 3);
    expect(groups[0].locationLabel, 'Kız Bölümü - A Blok - Zemin Kat');
    expect(groups[1].locationLabel, 'Kız Bölümü - A Blok - 1. Kat');
    expect(groups[2].locationLabel, 'Odasız Öğrenciler');

    expect(
      groups[0].entries.map((item) => '${item.roomLabel} ${item.studentName}'),
      ['101 Elif Şahin', '101 Zeynep Kaya', '102 Ayşe Kara'],
    );
    expect(groups[1].entries.single.roomLabel, '201');
    expect(groups[1].entries.single.studentName, 'Merve Aslan');
    expect(groups[2].entries.single.roomLabel, '-');
    expect(groups[2].entries.single.studentName, 'Odasız Öğrenci');
  });
}
