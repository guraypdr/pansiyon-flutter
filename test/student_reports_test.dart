import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/contact_sheet_pdf.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';
import 'package:pdf/pdf.dart';
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

  test('bir sayfaya sigan ogrenci iki sayfaya bolunmez', () {
    // Regresyon: sayfa kapasitesi 28 yazilmisken gercek kapasite 35-36
    // satirdi. Tek sayfaya rahatca sigan bir kat (29-35 ogrenci) gereksiz
    // yere iki sayfaya bolunuyor ve her iki sayfaya da "Sayfa 1/2" yaziliyordu.
    // Ölçüm: A4 kullanılabilir 807.89pt - başlık 83.91pt - tablo başlığı 34pt
    // = 690pt / 19pt = 36 satır.
    for (final count in const [29, 30, 31, 32, 33, 34, 35]) {
      final entries = <ContactSheetEntry>[
        for (var index = 0; index < count; index++)
          entry('101', 'O$index', '1', false, false, '0 Rh+', '', '', ''),
      ];

      final pages = paginateByRoom(entries);

      expect(
        pages,
        hasLength(1),
        reason: '$count ogrenci tek sayfaya sigmaliydi',
      );
      expect(pages.single, hasLength(count));
    }
  });

test('bir oda iki sayfaya bolunmez', () {
    // Regresyon: satirlar 28'lik bloklara bolunuyordu. Bir odanin
    // ogrencileri sayfa sinirinin ortasina denk gelince o oca iki sayfaya
    // bölunuyor ve ayni oda numarasi formda iki kez, yarim listeyle basiliyordu.
    final entries = <ContactSheetEntry>[];
    // 101 odasina 25, 102 odasina 25 ogrenci: 28'lik sinir 101'in ortasina
    // denk gelir.
    for (var index = 0; index < 25; index++) {
      entries.add(entry('101', 'A$index', '1', false, false, '0 Rh+', '', '', ''));
    }
    for (var index = 0; index < 25; index++) {
      entries.add(entry('102', 'B$index', '1', false, false, '0 Rh+', '', '', ''));
    }

    final pages = paginateByRoom(entries);

    expect(pages, hasLength(2));
    // Her sayfada tek oda bulunmali ve oda listesi butun olmali.
    expect(pages[0].map((item) => item.roomLabel).toSet(), {'101'});
    expect(pages[1].map((item) => item.roomLabel).toSet(), {'102'});
    expect(pages[0], hasLength(25));
    expect(pages[1], hasLength(25));
  });

  test('sayfalar hicbir zaman 35 satiri asmaz', () {
    // Dikey tasma olursa 'pdf' paketi tasan kismi sessizce attigi icin
    // form bos cikiyordu.
    final entries = <ContactSheetEntry>[];
    // Dengesiz doluluk: 2, 4, 1, 3, 4, 2 oda basina ogrenci.
    var counter = 0;
    for (final fill in const [2, 4, 1, 3, 4, 2, 3, 4, 1, 2, 4, 3, 2, 4]) {
      for (var index = 0; index < fill; index++) {
        entries.add(
          entry('10$counter', 'O$counter-$index', '1', false, false, '0 Rh+', '', '', ''),
        );
      }
      counter++;
    }

    final pages = paginateByRoom(entries);

    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      expect(page.length, lessThanOrEqualTo(35));
    }
    // hicbir oda iki sayfaya tasmamali
    final seen = <String, Set<int>>{};
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final item in pages[pageIndex]) {
        seen.putIfAbsent(item.roomLabel, () => <int>{}).add(pageIndex);
      }
    }
    expect(
      seen.values.every((pageIndexes) => pageIndexes.length == 1),
      isTrue,
      reason: 'her oda yalnizca tek sayfada gorunmeli',
    );
    // tum ogrenciler korunmali
    expect(
      pages.expand((page) => page).map((item) => item.studentName).toSet(),
      hasLength(entries.length),
    );
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

  test('ad soyad soyadlar kisaltilarak sutuna sigar', () {
    // Adlar korunur, soyadlar bas harfe indirilir. Onceki davranis 22.
    // karakterden sonra kor kesiyor ve soyadin ortasinda boluyordu
    // ("Abdulkadir Mehmet S"), ogrenci taninmiyordu.
    expect(contactSheetName('Zeynep Kaya'), 'Zeynep Kaya');
    expect(contactSheetName('Muhammed G.'), 'Muhammed G.');
    expect(contactSheetName('Hatice Şahin'), 'Hatice Şahin');
    expect(contactSheetName('Abdulkadir Mehmet Şahin Karabulut'),
        'Abdulkadir Ş. K.');
    expect(contactSheetName('Zeynep Kaya Karabulut'), 'Zeynep K. K.');

    // Kisa adlar hicbir degisiklik ugramaz.
    expect(contactSheetName('  Mehmet  '), 'Mehmet');
  });

  test('ad soyad kisaltmasi butceyi hicbir zaman asmaz', () {
    for (final isim in const [
      'Abdulkadir Mehmet Şahin Karabulut Yılmaz',
      'Zeynep Kaya Karabulut Şahin',
      'Osman Yılmaz Çelik',
      'A',
      '   ',
      'Çok Çok Uzun Bir Ad Soyad Daha Var',
    ]) {
      expect(
        contactSheetName(isim).length,
        lessThanOrEqualTo(18),
        reason: '"$isim" kısaltması bütçeye sığmalı',
      );
    }
  });

  test('kan grubu sutunu "Bilinmiyor" icin yeterli genislikte', () {
    // 32pt sutun "Bilinmiyor"a (37.4pt) dar geliyordu; hucre iki satira
    // bolunuyor ve sabit 19pt yukseklikte ikinci satir sessizce duserdi.
    expect(contactSheetBloodColumnWidth, greaterThanOrEqualTo(43));
  });

  test('sutun genislikleri sayfa alanini asmaz', () {
    final toplam = contactSheetColumnWidths.fold<double>(0, (a, b) => a + b);
    final sayfaIcerik = PdfPageFormat.a4.width - 48;

    // Baslik 9 hücre, govde 9 sutun olmalidir; sayi tutmazsa bir sutun
    // eklenmis ve genislik listesine islenmemis demektir.
    expect(contactSheetColumnWidths, hasLength(9));
    expect(
      toplam,
      lessThanOrEqualTo(sayfaIcerik),
      reason: 'tablo sayfa içeriğinden geniş olmamalı',
    );
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
