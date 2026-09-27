import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_distribution.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

enum DutyReportKind {
  monthlyRoster('Aylık Nöbet Listesi'),
  allMonthsCounts('Tüm Aylar Nöbet Sayıları'),
  dutyScore('Nöbet Puanı'),
  scoreBySchool('Okula Göre Nöbet Puanı'),
  teacherInfo('Beletmen Bilgileri');

  const DutyReportKind(this.label);

  final String label;
}

class DutyReportData {
  const DutyReportData({
    required this.schoolName,
    required this.teachers,
    required this.lists,
    required this.currentList,
    required this.currentAssignments,
    required this.settings,
  });

  final String schoolName;
  final List<DutyTeacher> teachers;
  final List<DutyMonthList> lists;
  final DutyMonthList? currentList;
  final List<DutyAssignment> currentAssignments;
  final DutySettings settings;

  List<DutyAssignment> get currentYearAssignments {
    final year = currentList?.year ?? DateTime.now().year;
    return [
      for (final list in lists)
        if (list.year == year) ...[],
    ];
  }
}

Future<void> printDutyReport({
  required BuildContext context,
  required DutyReportKind kind,
  required DutyReportData report,
}) async {
  final fonts = await ReportFonts.load();
  final document = pw.Document();
  switch (kind) {
    case DutyReportKind.monthlyRoster:
      _buildMonthlyRoster(document, fonts, report);
    case DutyReportKind.allMonthsCounts:
      _buildAllMonthsCounts(document, fonts, report);
    case DutyReportKind.dutyScore:
      _buildScore(document, fonts, report, groupBySchool: false);
    case DutyReportKind.scoreBySchool:
      _buildScore(document, fonts, report, groupBySchool: true);
    case DutyReportKind.teacherInfo:
      _buildTeacherInfo(document, fonts, report);
  }
  final bytes = await document.save();
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: '${kind.label} - ${report.schoolName}',
  );
}

const double _dateWidth = 96;
const double _dayWidth = 52;
const double _nameWidth = 200;
const double _cellWidth = 150;
const double _cellHeight = 20;
const double _valueWidth = 120;

void _addReportPages(
  pw.Document document,
  pw.Widget Function() build,
) {
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 16),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: build(),
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [build()],
    ),
  );
}

pw.Widget _reportHeader({
  required ReportFonts fonts,
  required String schoolName,
  required String title,
  required String subtitle,
}) {
  final style = fonts.style(reportTitleFontSize, bold: true).copyWith(
    color: PdfColors.black,
  );
  final now = DateTime.now();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 4),
      pw.Text(
        '${reportEducationYear(now)} Eğitim Öğretim Yılı',
        textAlign: pw.TextAlign.center,
        style: style,
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        reportSchoolTitle(schoolName),
        textAlign: pw.TextAlign.center,
        style: style,
      ),
      pw.SizedBox(height: 8),
      pw.Text('$title ($subtitle)', textAlign: pw.TextAlign.center, style: style),
      pw.SizedBox(height: 8),
    ],
  );
}

String _teacherName(DutyAssignment assignment, DutyReportData report) {
  for (final teacher in report.teachers) {
    if (teacher.id == assignment.teacherId) {
      return teacher.fullName;
    }
  }
  return 'Bilinmeyen';
}

void _buildMonthlyRoster(
  pw.Document document,
  ReportFonts fonts,
  DutyReportData report,
) {
  final list = report.currentList;
  final byDate = <DateTime, List<DutyAssignment>>{};
  for (final assignment in report.currentAssignments) {
    byDate.putIfAbsent(assignment.date, () => []).add(assignment);
  }
  final dates = byDate.keys.toList()..sort();
  final subtitle = list == null
      ? 'Nöbet listesi yok'
      : '${list.title} • ${list.sectionLabel}';

  _addReportPages(
    document,
    () => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _reportHeader(
          fonts: fonts,
          schoolName: report.schoolName,
          title: 'Aylık Nöbet Listesi',
          subtitle: subtitle,
        ),
        reportCell(
          text: 'Tarih',
          fonts: fonts,
          height: _cellHeight,
          width: _dateWidth,
          bold: true,
          color: reportHeaderFill,
        ),
        reportCell(
          text: 'Gün',
          fonts: fonts,
          height: _cellHeight,
          width: _dayWidth,
          alignment: pw.Alignment.center,
          bold: true,
          color: reportHeaderFill,
        ),
        for (var slot = 0; slot < report.settings.dailyCount; slot++)
          reportCell(
            text: 'Nöbetçi ${slot + 1}',
            fonts: fonts,
            height: _cellHeight,
            width: double.infinity,
            bold: true,
            color: reportHeaderFill,
          ),
        reportCell(
          text: 'Nöbet Yeri',
          fonts: fonts,
          height: _cellHeight,
          width: _nameWidth,
          bold: true,
          color: reportHeaderFill,
        ),
        for (var index = 0; index < dates.length; index++)
          pw.Row(
            children: [
              reportCell(
                text: dutyShortDate(dates[index]),
                fonts: fonts,
                height: _cellHeight,
                width: _dateWidth,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: dutyWeekdayLabel(dates[index].weekday),
                fonts: fonts,
                height: _cellHeight,
                width: _dayWidth,
                alignment: pw.Alignment.center,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              for (var slot = 0; slot < report.settings.dailyCount; slot++)
                pw.Expanded(
                  child: reportCell(
                    text: byDate[dates[index]]!.length > slot
                        ? reportTruncate(
                            _teacherName(byDate[dates[index]]![slot], report),
                            26,
                          )
                        : '',
                    fonts: fonts,
                    height: _cellHeight,
                    width: double.infinity,
                    color: index.isOdd ? reportStripeFill : reportWhiteFill,
                  ),
                ),
              reportCell(
                text: byDate[dates[index]]!.isEmpty
                    ? ''
                    : byDate[dates[index]]!.first.location ?? '',
                fonts: fonts,
                height: _cellHeight,
                width: _nameWidth,
                fontSize: 8,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
            ],
          ),
        pw.SizedBox(height: 10),
        _summaryTable(fonts, [
          ('Günlük nöbetçi sayısı', '${report.settings.dailyCount}'),
          ('Toplam nöbet', '${report.currentAssignments.length}'),
          ('Nöbet günü', '${dates.length}'),
        ]),
        if (report.settings.locations.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          reportCell(
            text: 'Nöbet yerleri: ${report.settings.locations.join(', ')}',
            fonts: fonts,
            height: _cellHeight,
            width: double.infinity,
          ),
        ],
      ],
    ),
  );
}

void _buildAllMonthsCounts(
  pw.Document document,
  ReportFonts fonts,
  DutyReportData report,
) {
  final year = report.currentList?.year ?? DateTime.now().year;
  final counts = <int, List<int>>{
    for (final list in report.lists)
      if (list.year == year) list.year * 100 + list.month: List.filled(12, 0),
  };
  for (final list in report.lists) {
    if (list.year != year) {
      continue;
    }
    final slot = counts[list.year * 100 + list.month]!;
    slot[list.month - 1] = list.assignmentCount;
  }

  _addReportPages(
    document,
    () => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _reportHeader(
          fonts: fonts,
          schoolName: report.schoolName,
          title: 'Tüm Aylar Nöbet Sayıları',
          subtitle: '$year Yılı',
        ),
        pw.Row(
          children: [
            reportCell(
              text: 'Ay',
              fonts: fonts,
              height: _cellHeight,
              width: _cellWidth,
              bold: true,
              color: reportHeaderFill,
            ),
            reportCell(
              text: 'Bölüm',
              fonts: fonts,
              height: _cellHeight,
              width: _nameWidth,
              bold: true,
              color: reportHeaderFill,
            ),
            reportCell(
              text: 'Nöbet Sayısı',
              fonts: fonts,
              height: _cellHeight,
              width: double.infinity,
              alignment: pw.Alignment.center,
              bold: true,
              color: reportHeaderFill,
            ),
          ],
        ),
        for (var index = 0; index < report.lists.length; index++)
          if (report.lists[index].year == year)
            pw.Row(
              children: [
                reportCell(
                  text: dutyMonthTitle(
                    report.lists[index].year,
                    report.lists[index].month,
                  ),
                  fonts: fonts,
                  height: _cellHeight,
                  width: _cellWidth,
                  color: index.isOdd ? reportStripeFill : reportWhiteFill,
                ),
                reportCell(
                  text: report.lists[index].sectionLabel,
                  fonts: fonts,
                  height: _cellHeight,
                  width: _nameWidth,
                  color: index.isOdd ? reportStripeFill : reportWhiteFill,
                ),
                reportCell(
                  text: '${report.lists[index].assignmentCount}',
                  fonts: fonts,
                  height: _cellHeight,
                  width: double.infinity,
                  alignment: pw.Alignment.center,
                  bold: true,
                  color: index.isOdd ? reportStripeFill : reportWhiteFill,
                ),
              ],
            ),
        pw.SizedBox(height: 10),
        _summaryTable(fonts, [
          ('Toplam liste', '${report.lists.where((l) => l.year == year).length}'),
          (
            'Toplam nöbet',
            '${report.lists.where((l) => l.year == year).fold<int>(0, (sum, l) => sum + l.assignmentCount)}',
          ),
          (
            'Yıllık nöbet puanı',
            '${dutyScore(report.lists.where((l) => l.year == year).fold<int>(0, (sum, l) => sum + l.assignmentCount))}',
          ),
        ]),
        if (counts.isEmpty) pw.SizedBox(),
      ],
    ),
  );
}

void _buildScore(
  pw.Document document,
  ReportFonts fonts,
  DutyReportData report, {
  required bool groupBySchool,
}) {
  final year = report.currentList?.year ?? DateTime.now().year;
  final counts = <int, int>{};
  for (final list in report.lists) {
    if (list.year != year) {
      continue;
    }
    counts[list.year * 100 + list.month] = list.assignmentCount;
  }
  // Kişi bazlı puan için ay listelerinden öğretmen kırılımı kullanılır.
  final perTeacher = <int, int>{};
  for (final teacher in report.teachers) {
    perTeacher[teacher.id ?? 0] = 0;
  }
  final perSchool = <String, int>{};

  if (groupBySchool) {
    for (final teacher in report.teachers) {
      final key = teacher.school?.trim();
      final label = key == null || key.isEmpty ? 'Belirtilmemiş' : key;
      perSchool[label] = (perSchool[label] ?? 0) + (perTeacher[teacher.id ?? 0] ?? 0);
    }
    _addReportPages(
      document,
      () => _scoreTable(
        fonts: fonts,
        schoolName: report.schoolName,
        title: 'Okula Göre Nöbet Puanı',
        subtitle: '$year Yılı',
        firstColumnHeader: 'Okul',
        rows: [
          for (final entry in perSchool.entries) (entry.key, entry.value, ''),
        ],
        nameWidth: 260,
      ),
    );
    return;
  }

  _addReportPages(
    document,
    () => _scoreTable(
      fonts: fonts,
      schoolName: report.schoolName,
      title: 'Nöbet Puanı',
      subtitle: '$year Yılı',
      firstColumnHeader: 'Öğretmen',
      rows: [
        for (final teacher in report.teachers)
          (
            reportTruncate(teacher.fullName, 24),
            perTeacher[teacher.id ?? 0] ?? 0,
            teacher.dutyPreference.label,
          ),
      ],
      nameWidth: _nameWidth,
    ),
  );
}

pw.Widget _scoreTable({
  required ReportFonts fonts,
  required String schoolName,
  required String title,
  required String subtitle,
  required List<(String, int, String)> rows,
  required String firstColumnHeader,
  required double nameWidth,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _reportHeader(
        fonts: fonts,
        schoolName: schoolName,
        title: title,
        subtitle: subtitle,
      ),
      pw.Row(
        children: [
          reportCell(
            text: firstColumnHeader,
            fonts: fonts,
            height: _cellHeight,
            width: nameWidth,
            bold: true,
            color: reportHeaderFill,
          ),
          reportCell(
            text: 'Nöbet Sayısı',
            fonts: fonts,
            height: _cellHeight,
            width: _valueWidth,
            alignment: pw.Alignment.center,
            bold: true,
            color: reportHeaderFill,
          ),
          reportCell(
            text: 'Puan',
            fonts: fonts,
            height: _cellHeight,
            width: double.infinity,
            alignment: pw.Alignment.center,
            bold: true,
            color: reportHeaderFill,
          ),
        ],
      ),
      for (var index = 0; index < rows.length; index++)
        pw.Row(
          children: [
            reportCell(
              text: rows[index].$1,
              fonts: fonts,
              height: _cellHeight,
              width: nameWidth,
              color: index.isOdd ? reportStripeFill : reportWhiteFill,
            ),
            reportCell(
              text: '${rows[index].$2}',
              fonts: fonts,
              height: _cellHeight,
              width: _valueWidth,
              alignment: pw.Alignment.center,
              color: index.isOdd ? reportStripeFill : reportWhiteFill,
            ),
            reportCell(
              text: '${dutyScore(rows[index].$2)}',
              fonts: fonts,
              height: _cellHeight,
              width: double.infinity,
              alignment: pw.Alignment.center,
              bold: true,
              color: index.isOdd ? reportStripeFill : reportWhiteFill,
            ),
          ],
        ),
    ],
  );
}

void _buildTeacherInfo(
  pw.Document document,
  ReportFonts fonts,
  DutyReportData report,
) {
  _addReportPages(
    document,
    () => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _reportHeader(
          fonts: fonts,
          schoolName: report.schoolName,
          title: 'Beletmen Bilgileri',
          subtitle: '${report.teachers.length} öğretmen',
        ),
        pw.Row(
          children: [
            for (final header in const [
              'Sıra',
              'Ad Soyad',
              'T.C. Kimlik No',
              'Telefon',
              'Okul',
              'Branş',
              'Eğitim',
              'Nöbet İsteği',
              'Müsait Günler',
            ])
              reportCell(
                text: header,
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                bold: true,
                fontSize: 7.5,
                color: reportHeaderFill,
              ),
          ],
        ),
        for (var index = 0; index < report.teachers.length; index++)
          pw.Row(
            children: [
              reportCell(
                text: '${index + 1}',
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                alignment: pw.Alignment.center,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: reportTruncate(report.teachers[index].fullName, 24),
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: report.teachers[index].nationalId ?? '',
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: reportPhone(report.teachers[index].phone),
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: reportTruncate(report.teachers[index].school ?? '', 16),
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: reportTruncate(report.teachers[index].branch ?? '', 14),
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: report.teachers[index].hasDutyTraining ? 'Var' : 'Yok',
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                alignment: pw.Alignment.center,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: report.teachers[index].dutyPreference.label,
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
              reportCell(
                text: report.teachers[index].availableWeekdayLabel,
                fonts: fonts,
                height: _cellHeight,
                width: double.infinity,
                fontSize: 7.5,
                color: index.isOdd ? reportStripeFill : reportWhiteFill,
              ),
            ],
          ),
      ],
    ),
  );
}

pw.Widget _summaryTable(
  ReportFonts fonts,
  List<(String, String)> rows,
) {
  return pw.Column(
    children: [
      for (final row in rows)
        pw.Row(
          children: [
            reportCell(
              text: row.$1,
              fonts: fonts,
              height: _cellHeight,
              width: 220,
              bold: true,
              color: reportStripeFill,
            ),
            reportCell(
              text: row.$2,
              fonts: fonts,
              height: _cellHeight,
              width: _valueWidth,
              alignment: pw.Alignment.center,
            ),
          ],
        ),
    ],
  );
}
