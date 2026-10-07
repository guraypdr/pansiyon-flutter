import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

const double _odaWidth = 30;
const double _adWidth = 95;
const double _tcWidth = 72;
const double _chronicWidth = 52;
const double _medicationWidth = 52;
const double _bloodWidth = 48;
const double _studentPhoneWidth = 66;
const double _parentPhoneWidth = 62;
const double _headerHeight = 34;

/// Ad soyad sütununun karakter bütçesi.
///
/// Sütun 95pt, yatay dolgusu sonrası kullanılabilir alan 90pt. 8.5pt
/// Roboto'da ortalama karakter ~4.1pt; 18 karakter ~74pt tutar ve başlığa
/// sonuna kadar sığma payı bırakır. Fazlası hücreyi iki satıra böler ve
/// sabit 19pt yükseklikte ikinci satır sessizce düşer.
const int _nameMaxLength = 18;

/// Form sütunlarının genişlikleri (pt), soldan sağa.
///
/// Tek doğruluk noktasıdır: başlık ve gövde hücreleri bu değerlerden
/// beslenir, sayfa bütçesi de bunların toplamıyla ölçülür. Toplam A4'ün
/// kullanılabilir alanını (`a4 genişliği − 48pt kenar boşluğu`) aşmamalıdır;
/// `pdf` paketi yatay taşmada hücreleri sessizce kırpar.
const contactSheetColumnWidths = <double>[
  _odaWidth,
  _adWidth,
  _tcWidth,
  _chronicWidth,
  _medicationWidth,
  _bloodWidth,
  _studentPhoneWidth,
  _parentPhoneWidth,
  _parentPhoneWidth,
];

/// Kan grubu sütununun genişliği (pt).
///
/// "Bilinmiyor" 8.5pt Roboto'da 37.4pt tutar; yatay dolguyla birlikte
/// sütun en az 43pt olmalıdır. Daha dar bir sütunda hücre iki satıra bölünür
/// ve sabit 19pt yükseklikte ikinci satır sessizce düşer.
const double contactSheetBloodColumnWidth = _bloodWidth;

class ContactSheetEntry {
  const ContactSheetEntry({
    required this.roomLabel,
    required this.studentName,
    required this.nationalId,
    required this.hasChronicDisease,
    required this.hasRegularMedication,
    required this.bloodType,
    required this.studentPhone,
    required this.guardianPhone,
    required this.guardian2Phone,
  });

  final String roomLabel;
  final String studentName;
  final String? nationalId;

  final bool hasChronicDisease;
  final bool hasRegularMedication;
  final String? bloodType;
  final String? studentPhone;
  final String? guardianPhone;
  final String? guardian2Phone;

  String get chronicLabel => hasChronicDisease ? 'Var' : 'Yok';
  String get medicationLabel => hasRegularMedication ? 'Var' : 'Yok';
}

/// Her kat için ayrı çıktı üretilen form grubu.
class ContactSheetGroup {
  const ContactSheetGroup({required this.locationLabel, required this.entries});

  final String locationLabel;
  final List<ContactSheetEntry> entries;
}

class ContactSheetData {
  const ContactSheetData({
    required this.schoolName,
    required this.educationYear,
    required this.date,
    required this.groups,
  });

  final String schoolName;
  final String educationYear;
  final DateTime date;
  final List<ContactSheetGroup> groups;
}

/// Ad soyadı verilen karakter bütçesine sığdırır.
///
/// Ad(lar) korunur; **soyad(lar) baş harflerine kısaltılır**:
/// `Abdulkadir Mehmet Şahin Karabulut` -> `Abdulkadir Ş. K.`
/// Böylece öğrenci tanınır ve soyadı hâlâ okunur; önceki davranış 22.
/// karakterden sonra körlemesine kesiyordu ve soyadın ortasında bölüyordu
/// (`Abdulkadir Mehmet Ş`). Kısaltma yetmezse adların sonundan kısaltılır.
///
/// Ad soyad zaten bütçeye sığıyorsa hiçbir değişiklik yapılmaz.
String contactSheetName(String name, {int maxLength = _nameMaxLength}) {
  final trimmed = name.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }

  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    // Tek kelimelik ad soyad; kısaltılacak kısım yok.
    return reportTruncate(trimmed, maxLength);
  }

  // Türkçede ad/soyad ayrımı biçimsel bir kurala bağlı değil; son iki kelime
  // soyad kabul edilir. "Zeynep Kaya" gibi iki kelimelik adlarda ilk kelime
  // ad, ikincisi soyaddır.
  final surnames = parts.sublist(parts.length - 2);
  final givenNames = parts.sublist(0, parts.length - 2);

  String initials(Iterable<String> words) {
    return words.map((word) => '${word.substring(0, 1)}.').join(' ');
  }

  for (var keep = givenNames.length; keep >= 1; keep--) {
    final candidate = '${givenNames.take(keep).join(' ')} ${initials(surnames)}';
    if (candidate.length <= maxLength) {
      return candidate;
    }
  }

  // Hiçbir ad kalsaydı sığmıyorsa yalnızca baş harfler.
  return reportTruncate(initials(parts), maxLength);
}

/// Öğrenciler kat bazında gruplanır; her kat için ayrı çıktı üretilir.
/// Aynı odadaki öğrenciler yan yana gelir ve oda numarası gruplanmış yazılır.
List<ContactSheetGroup> buildContactSheetGroups({
  required List<Student> students,
  required BoardingRoom? Function(int studentId) roomOf,
}) {
  final roomByStudent = <int, BoardingRoom?>{
    for (final student in students)
      if (student.id != null) student.id!: roomOf(student.id!),
  };

  int sortKey(Student student) => roomByStudent[student.id]?.roomNumber ?? 9999;

  final sorted = [...students]
    ..sort((a, b) {
      final roomCompare = sortKey(a).compareTo(sortKey(b));
      if (roomCompare != 0) {
        return roomCompare;
      }
      return a.fullName.compareTo(b.fullName);
    });

  final byFloor = <String, List<ContactSheetEntry>>{};
  final order = <String>[];
  for (final student in sorted) {
    final room = roomByStudent[student.id];
    final floorKey = room == null
        ? 'Odasız Öğrenciler'
        : '${room.section.label} - ${room.blockName} - ${room.floorLabel}';
    if (!byFloor.containsKey(floorKey)) {
      order.add(floorKey);
    }
    byFloor
        .putIfAbsent(floorKey, () => [])
        .add(
          ContactSheetEntry(
            roomLabel: room == null ? '-' : '${room.roomNumber}',
            studentName: student.fullName,
            nationalId: student.nationalId,
            hasChronicDisease: student.hasChronicDisease,
            hasRegularMedication: (student.regularMedication ?? '')
                .trim()
                .isNotEmpty,
            bloodType: student.bloodType,
            studentPhone: student.phone,
            guardianPhone: student.guardianPhone,
            guardian2Phone: student.guardian2Phone,
          ),
        );
  }

  return [
    for (final key in order)
      ContactSheetGroup(locationLabel: key, entries: byFloor[key]!),
  ];
}

pw.Widget _buildTableHeader(ReportFonts fonts) {
  return pw.Row(
    children: [
      reportHeadCell(
        text: 'Oda No',
        fonts: fonts,
        height: _headerHeight,
        width: _odaWidth,
      ),
      reportHeadCell(
        text: 'Ad Soyad',
        fonts: fonts,
        height: _headerHeight,
        width: _adWidth,
        alignment: pw.Alignment.centerLeft,
      ),
      reportHeadCell(
        text: 'TC Kimlik No',
        fonts: fonts,
        height: _headerHeight,
        width: _tcWidth,
      ),
      reportHeadCell(
        text: 'Sürekli Hastalığı Var mı?',
        fonts: fonts,
        height: _headerHeight,
        width: _chronicWidth,
      ),
      reportHeadCell(
        text: 'Düzenli Kullandığı İlaç Var mı?',
        fonts: fonts,
        height: _headerHeight,
        width: _medicationWidth,
      ),
      reportHeadCell(
        text: 'Kan Grubu',
        fonts: fonts,
        height: _headerHeight,
        width: _bloodWidth,
      ),
      reportHeadCell(
        text: 'Öğrenci Telefonu',
        fonts: fonts,
        height: _headerHeight,
        width: _studentPhoneWidth,
      ),
      reportHeadCell(
        text: 'Veli Telefonu',
        fonts: fonts,
        height: _headerHeight,
        width: _parentPhoneWidth,
      ),
      reportHeadCell(
        text: '2. Veli İletişim Numarası',
        fonts: fonts,
        height: _headerHeight,
        width: _parentPhoneWidth,
      ),
    ],
  );
}

pw.Widget _buildStudentRow(
  ContactSheetEntry entry,
  ReportFonts fonts, {
  required bool striped,
}) {
  final color = striped ? reportStripeFill : reportWhiteFill;
  return pw.Row(
    children: [
      reportCell(
        text: contactSheetName(entry.studentName),
        fonts: fonts,
        height: reportRowHeight,
        width: _adWidth,
        color: color,
      ),
      reportCell(
        text: entry.nationalId ?? '',
        fonts: fonts,
        height: reportRowHeight,
        width: _tcWidth,
        alignment: pw.Alignment.center,
        color: color,
      ),
      reportCell(
        text: entry.chronicLabel,
        fonts: fonts,
        height: reportRowHeight,
        width: _chronicWidth,
        alignment: pw.Alignment.center,
        color: color,
      ),
      reportCell(
        text: entry.medicationLabel,
        fonts: fonts,
        height: reportRowHeight,
        width: _medicationWidth,
        alignment: pw.Alignment.center,
        color: color,
      ),
      reportCell(
        text: entry.bloodType ?? '',
        fonts: fonts,
        height: reportRowHeight,
        width: _bloodWidth,
        alignment: pw.Alignment.center,
        color: color,
      ),
      reportCell(
        text: reportPhone(entry.studentPhone),
        fonts: fonts,
        height: reportRowHeight,
        width: _studentPhoneWidth,
        alignment: pw.Alignment.center,
        fontSize: 8,
        color: color,
      ),
      reportCell(
        text: reportPhone(entry.guardianPhone),
        fonts: fonts,
        height: reportRowHeight,
        width: _parentPhoneWidth,
        alignment: pw.Alignment.center,
        fontSize: 8,
        color: color,
      ),
      reportCell(
        text: reportPhone(entry.guardian2Phone),
        fonts: fonts,
        height: reportRowHeight,
        width: _parentPhoneWidth,
        alignment: pw.Alignment.center,
        fontSize: 8,
        color: color,
      ),
    ],
  );
}

/// Aynı odadaki öğrenciler gruplanır; oda numarası bir kez ve ortalanmış yazılır.
///
/// Dış çerçeve kullanılmaz: oda hücresi ve öğrenci hücreleri zaten kendi
/// kenarlıklarını taşır. Bir çerçeve daha eklenirse tablo gövdesi sayfa
/// içeriğinden geniş kalır ve en sağdaki sütun hem başlık satırından hem de
/// sağ kenar boşluğundan taşar.
pw.Widget _buildRoomGroup(
  String roomLabel,
  List<ContactSheetEntry> entries,
  ReportFonts fonts, {
  required int startRowIndex,
}) {
  final groupHeight = reportRowHeight * entries.length;
  return pw.Row(
    children: [
      reportCell(
        text: roomLabel,
        fonts: fonts,
        height: groupHeight,
        width: _odaWidth,
        alignment: pw.Alignment.center,
        bold: true,
        fontSize: 9,
      ),
      pw.Expanded(
        child: pw.Column(
          children: [
            for (var index = 0; index < entries.length; index++)
              _buildStudentRow(
                entries[index],
                fonts,
                striped: (startRowIndex + index).isOdd,
              ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildGroupTable(
  List<ContactSheetEntry> entries,
  ReportFonts fonts, {
  int startRowIndex = 0,
}) {
  final groups = <String, List<ContactSheetEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.roomLabel, () => []).add(entry);
  }

  final widgets = <pw.Widget>[];
  var rowIndex = 0;
  for (final group in groups.entries) {
    widgets.add(
      _buildRoomGroup(
        group.key,
        group.value,
        fonts,
        startRowIndex: startRowIndex + rowIndex,
      ),
    );
    rowIndex += group.value.length;
  }
  return pw.Column(children: widgets);
}

/// Bir sayfaya sığan öğrenci satırı sayısı.
///
/// Bu form oda gruplarını korumak için `pw.MultiPage` yerine elle sayfalanır;
/// bu yüzden sayfa kapasitesi burada hesaplanmalıdır. Ölçülen değerler:
///
/// - A4 yüksekliği 841.89pt, üst/alt kenar boşluğu 18+16pt → kullanılabilir
///   807.89pt
/// - Rapor başlığı bloğu 83.91pt, tablo başlığı 34pt
/// - Satır yüksekliği 19pt
///
/// 807.89 − 83.91 − 34 = 690pt → 36 satır tam olarak sığar (801.91pt). 36
/// seçilirse sayfada 5.98pt pay kalır; okul adı ya da rapor başlığı bir satır
/// uzadığında başlık bloğu 97.97pt olur ve sayfa taşar. `pdf` paketi dikey
/// taşmada içeriği sessizce attığı için 35 seçilmiştir: 782.91pt kullanılır,
/// 24.98pt pay kalır ve başlık bir satır büyüse bile 10.92pt ile sığar.
const _rowsPerPage = 35;

/// Girdileri sayfalara böler; **bir oda asla iki sayfaya bölünmez**.
///
/// Satır satır bölme, bir odanın öğrencilerini iki sayfaya dağıtıyor ve aynı
/// oda numarası formda iki kez (her biri yarım listeyle) basılıyordu. Oda
/// numarası dosyalanan bir formda tek yerde ve tam listeyle görünmelidir.
///
/// Doldurma kuralı: oluşturulan sayfaların hiçbiri [maxRowsPerPage] satırı
/// aşmaz; dikey taşma olursa `pdf` paketi taşan kısmı sessizce attığı için
/// bu sınır korunmalıdır. Bir oda tek başına sınırı aşarsa (gerçekçi değil,
/// kapasite çok büyükse) o oda kendi başına bölmeye tabi tutulur.
List<List<ContactSheetEntry>> paginateByRoom(
  List<ContactSheetEntry> entries, {
  int maxRowsPerPage = _rowsPerPage,
}) {
  final buckets = <String, List<ContactSheetEntry>>{};
  for (final entry in entries) {
    buckets.putIfAbsent(entry.roomLabel, () => []).add(entry);
  }

  final pages = <List<ContactSheetEntry>>[];
  var current = <ContactSheetEntry>[];
  for (final bucket in buckets.values) {
    if (bucket.length > maxRowsPerPage) {
      if (current.isNotEmpty) {
        pages.add(current);
        current = <ContactSheetEntry>[];
      }
      for (var start = 0; start < bucket.length; start += maxRowsPerPage) {
        final end = start + maxRowsPerPage;
        pages.add(
          bucket.sublist(start, end > bucket.length ? bucket.length : end),
        );
      }
      continue;
    }
    if (current.isNotEmpty && current.length + bucket.length > maxRowsPerPage) {
      pages.add(current);
      current = <ContactSheetEntry>[];
    }
    current.addAll(bucket);
  }
  if (current.isNotEmpty) {
    pages.add(current);
  }
  return pages;
}

pw.Document buildContactSheetPdf(
  pw.Document document,
  ContactSheetData data,
  ReportFonts fonts,
) {
  for (final group in data.groups) {
    if (group.entries.isEmpty) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 16),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(fonts, data, group.locationLabel),
              _buildTableHeader(fonts),
              reportCell(
                text: 'Bu katta kayıtlı öğrenci yok',
                fonts: fonts,
                height: 24,
                width: double.infinity,
                alignment: pw.Alignment.center,
              ),
            ],
          ),
        ),
      );
      continue;
    }

    // Oda blokları bütün olarak sayfalara yerleştirilir; hiçbir oda iki
    // sayfaya bölünmez.
    final pages = paginateByRoom(group.entries);
    var printedRows = 0;
    for (var index = 0; index < pages.length; index++) {
      final chunk = pages[index];
      final pageNumber = index + 1;
      final locationLabel = pages.length > 1
          ? '${group.locationLabel} (Sayfa $pageNumber/${pages.length})'
          : group.locationLabel;

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 16),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(fonts, data, locationLabel),
              _buildTableHeader(fonts),
              _buildGroupTable(chunk, fonts, startRowIndex: printedRows),
            ],
          ),
        ),
      );
      printedRows += chunk.length;
    }
  }
  return document;
}

pw.Widget _header(
  ReportFonts fonts,
  ContactSheetData data,
  String locationLabel,
) {
  return buildReportHeader(
    fonts: fonts,
    educationYear: data.educationYear,
    schoolName: data.schoolName,
    reportTitle: 'Öğrenci İletişim Bilgileri Formu',
    locationLabel: locationLabel,
    date: data.date,
  );
}
