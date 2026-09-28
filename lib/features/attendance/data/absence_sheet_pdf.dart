import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

const double _odaWidth = 34;
const double _adWidth = 165;
const double _sinifWidth = 34;
const double _okulNoWidth = 40;
const double _aciklamaWidth = 114;
const double _sessionWidth = 32;
const double _headerHeight = 20;

const List<String> _sessionLabels = [
  'Giriş',
  '1. Etüt',
  '2. Etüt',
  'Yat',
  'Sabah',
];

class AbsenceSheetEntry {
  const AbsenceSheetEntry({
    required this.studentName,
    required this.className,
    required this.schoolNumber,
    required this.roomLabel,
    required this.attendanceMark,
    required this.note,
  });

  final String studentName;
  final String? className;
  final String? schoolNumber;
  final String roomLabel;

  /// 'İ' evci izinli, 'R' raporlu, boşsa işaret yok.
  final String attendanceMark;
  final String? note;
}

class AbsenceSheetSummary {
  const AbsenceSheetSummary({
    required this.presentCount,
    required this.leaveCount,
    required this.reportCount,
    required this.absentCount,
    required this.totalCount,
  });

  final int presentCount;
  final int leaveCount;
  final int reportCount;
  final int absentCount;
  final int totalCount;

  int get leaveAndReportCount => leaveCount + reportCount;
}

class AbsenceSheetData {
  const AbsenceSheetData({
    required this.schoolName,
    required this.educationYear,
    required this.date,
    required this.locationLabel,
    required this.entries,
    required this.summary,
  });

  final String schoolName;
  final String educationYear;
  final DateTime date;
  final String locationLabel;
  final List<AbsenceSheetEntry> entries;
  final AbsenceSheetSummary summary;
}

String absenceSheetEducationYear(DateTime date) => reportEducationYear(date);

String formatAbsenceSheetDate(DateTime date) => reportDate(date);

String absenceSheetDayName(DateTime date) => reportDayName(date);

String formatAbsenceSheetDateWithDay(DateTime date) {
  return '${reportDayName(date)}, ${reportDate(date)}';
}

/// Ad soyad alanı 25 karakterle sınırlıdır; fazlası sondan kesilir.
String shortenAbsenceSheetName(String name) => reportTruncate(name, 25);

/// Dikey yazılan hücrelerde sığan karakter sayısı sınırlıdır.
String shortenAbsenceSheetVertical(String? value) =>
    reportTruncate(value ?? '', 5);

typedef AbsenceSheetFonts = ReportFonts;

pw.Widget _buildTableHeader(ReportFonts fonts) {
  final totalHeaderHeight = _headerHeight * 2;
  return pw.Row(
    children: [
      reportHeadCell(
        text: 'Oda No',
        fonts: fonts,
        height: totalHeaderHeight,
        width: _odaWidth,
      ),
      reportHeadCell(
        text: 'Ad Soyad',
        fonts: fonts,
        height: totalHeaderHeight,
        width: _adWidth,
        alignment: pw.Alignment.centerLeft,
      ),
      reportHeadCell(
        text: 'Sınıfı',
        fonts: fonts,
        height: totalHeaderHeight,
        width: _sinifWidth,
        vertical: true,
      ),
      reportHeadCell(
        text: 'Okul No',
        fonts: fonts,
        height: totalHeaderHeight,
        width: _okulNoWidth,
        vertical: true,
      ),
      pw.Column(
        children: [
          reportHeadCell(
            text: 'Yoklama Saatleri',
            fonts: fonts,
            height: _headerHeight,
            width: _sessionWidth * _sessionLabels.length,
          ),
          pw.Row(
            children: [
              for (final label in _sessionLabels)
                reportHeadCell(
                  text: label,
                  fonts: fonts,
                  height: _headerHeight,
                  width: _sessionWidth,
                ),
            ],
          ),
        ],
      ),
      reportHeadCell(
        text: 'Açıklamalar',
        fonts: fonts,
        height: totalHeaderHeight,
        width: _aciklamaWidth,
        alignment: pw.Alignment.centerLeft,
      ),
    ],
  );
}

pw.Widget _buildStudentRow(
  AbsenceSheetEntry entry,
  ReportFonts fonts, {
  required bool striped,
}) {
  final color = striped ? reportStripeFill : reportWhiteFill;
  return pw.Row(
    children: [
      reportCell(
        text: shortenAbsenceSheetName(entry.studentName),
        fonts: fonts,
        height: reportRowHeight,
        width: _adWidth,
        color: color,
      ),
      reportCell(
        text: shortenAbsenceSheetVertical(entry.className),
        fonts: fonts,
        height: reportRowHeight,
        width: _sinifWidth,
        alignment: pw.Alignment.center,
        fontSize: 8,
        color: color,
      ),
      reportCell(
        text: shortenAbsenceSheetVertical(entry.schoolNumber),
        fonts: fonts,
        height: reportRowHeight,
        width: _okulNoWidth,
        alignment: pw.Alignment.center,
        fontSize: 8,
        color: color,
      ),
      for (var index = 0; index < _sessionLabels.length; index++)
        reportCell(
          text: index == 0 ? entry.attendanceMark : '',
          fonts: fonts,
          height: reportRowHeight,
          width: _sessionWidth,
          alignment: pw.Alignment.center,
          bold: entry.attendanceMark.isNotEmpty && index == 0,
          fontSize: 9.5,
          color: color,
        ),
      reportCell(
        text: entry.note ?? '',
        fonts: fonts,
        height: reportRowHeight,
        width: _aciklamaWidth,
        fontSize: 8,
        color: color,
      ),
    ],
  );
}

/// Aynı odadaki öğrenciler gruplanır; oda numarası bir kez ve ortalanmış yazılır.
pw.Widget _buildRoomGroup(
  String roomLabel,
  List<AbsenceSheetEntry> entries,
  ReportFonts fonts, {
  required int startRowIndex,
}) {
  final groupHeight = reportRowHeight * entries.length;
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: reportGridColor)),
    child: pw.Row(
      children: [
        reportCell(
          text: shortenAbsenceSheetVertical(roomLabel),
          fonts: fonts,
          height: groupHeight,
          width: _odaWidth,
          alignment: pw.Alignment.center,
          bold: true,
          fontSize: 9.5,
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

pw.Widget _buildTable(AbsenceSheetData data, ReportFonts fonts) {
  final groups = <String, List<AbsenceSheetEntry>>{};
  for (final entry in data.entries) {
    groups.putIfAbsent(entry.roomLabel, () => []).add(entry);
  }

  final widgets = <pw.Widget>[];
  var rowIndex = 0;
  for (final group in groups.entries) {
    widgets.add(
      _buildRoomGroup(group.key, group.value, fonts, startRowIndex: rowIndex),
    );
    rowIndex += group.value.length;
  }
  return pw.Column(children: widgets);
}

pw.Widget _summaryTableRow({
  required String label,
  required ReportFonts fonts,
  String value = '',
  bool blank = false,
}) {
  return pw.Row(
    children: [
      reportCell(
        text: label,
        fonts: fonts,
        height: reportCellHeight,
        width: _odaWidth + _adWidth,
        fontSize: reportHeaderFontSize,
        bold: true,
        color: reportStripeFill,
      ),
      reportCell(
        text: blank ? '' : value,
        fonts: fonts,
        height: reportCellHeight,
        width: 140,
        alignment: pw.Alignment.center,
        fontSize: reportHeaderFontSize,
      ),
    ],
  );
}

pw.Widget _buildSummaryTable(AbsenceSheetData data, ReportFonts fonts) {
  final summary = data.summary;
  final leaveReportText = summary.leaveAndReportCount == 0
      ? '0'
      : '${summary.leaveAndReportCount} '
            '(evci izinli: ${summary.leaveCount}, raporlu: ${summary.reportCount})';

  final rows = <(String, String, bool)>[
    ('Mevcut öğrenci sayısı', '', true),
    ('Evci izinli ve raporlu öğrenci sayısı', leaveReportText, false),
    ('Pansiyonda bulunmayan öğrenci sayısı', '', true),
    ('Katta bulunan toplam öğrenci sayısı', '${summary.totalCount}', false),
  ];

  return pw.Column(
    children: [
      for (final row in rows)
        _summaryTableRow(
          label: row.$1,
          fonts: fonts,
          value: row.$2,
          blank: row.$3,
        ),
    ],
  );
}

pw.Widget _buildFooterBlock(AbsenceSheetData data, ReportFonts fonts) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _buildSummaryTable(data, fonts),
      pw.SizedBox(width: 22),
      pw.Container(
        width: 186,
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Nöbetçi Öğretmen',
              textAlign: pw.TextAlign.center,
              style: fonts
                  .style(reportHeaderFontSize, bold: true)
                  .copyWith(color: reportTextColor),
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              height: 13,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: reportGridColor),
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Ad Soyad',
              textAlign: pw.TextAlign.center,
              style: fonts.style(8.5).copyWith(color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Document buildAbsenceSheetPdf(
  pw.Document document,
  AbsenceSheetData data,
  ReportFonts fonts,
) {
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 16),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: _buildTableHeader(fonts),
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: fonts.style(7.5).copyWith(color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        buildReportHeader(
          fonts: fonts,
          educationYear: data.educationYear,
          schoolName: data.schoolName,
          reportTitle: 'Pansiyon Yoklama Çizelgesi',
          locationLabel: data.locationLabel,
          date: data.date,
        ),
        _buildTableHeader(fonts),
        _buildTable(data, fonts),
        pw.SizedBox(height: 10),
        _buildFooterBlock(data, fonts),
      ],
    ),
  );
  return document;
}
