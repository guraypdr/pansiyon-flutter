import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

const double _odaWidth = 30;
const double _adWidth = 119;
const double _tcWidth = 72;
const double _chronicWidth = 52;
const double _medicationWidth = 52;
const double _bloodWidth = 32;
const double _studentPhoneWidth = 66;
const double _parentPhoneWidth = 62;
const double _headerHeight = 34;

const int _titleMaxLength = 22;

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

String contactSheetName(String name) => reportTruncate(name, _titleMaxLength);

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
        text: 'Baba Telefonu',
        fonts: fonts,
        height: _headerHeight,
        width: _parentPhoneWidth,
      ),
      reportHeadCell(
        text: 'Anne Telefonu',
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
pw.Widget _buildRoomGroup(
  String roomLabel,
  List<ContactSheetEntry> entries,
  ReportFonts fonts, {
  required int startRowIndex,
}) {
  final groupHeight = reportRowHeight * entries.length;
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: reportGridColor)),
    child: pw.Row(
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
    ),
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
/// A4 yüksekliği 842pt; üst/alt kenar boşlukları ve rapor başlığı
/// düşüldüğünde tablo için ~680pt kalıyor. Satır yüksekliği 19pt olduğu
/// için ~35 satır sığar; güvenlik payı bırakılmıştır.
const _rowsPerPage = 28;

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

    // Satırlar sayfaya bölünür. Tek sayfaya sığmayan bir sütun, `pdf`
    // paketinde sessizce atılır ve form boş görünürdü.
    final total = group.entries.length;
    final pageCount = (total + _rowsPerPage - 1) ~/ _rowsPerPage;
    for (var start = 0; start < total; start += _rowsPerPage) {
      final end = start + _rowsPerPage > total ? total : start + _rowsPerPage;
      final chunk = group.entries.sublist(start, end);
      final pageNumber = start ~/ _rowsPerPage + 1;
      final locationLabel = pageCount > 1
          ? '${group.locationLabel} (Sayfa $pageNumber/$pageCount)'
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
              _buildGroupTable(chunk, fonts, startRowIndex: start),
            ],
          ),
        ),
      );
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
