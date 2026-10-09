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
    this.principalName = '',
  });

  final String schoolName;

  /// Çıktının sağ altında imza satırında yazılacak okul müdürünün adı soyadı.
  ///
  /// Boşsa imza bloğu hiç basılmaz.
  final String principalName;
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

const double _nameWidth = 200;
const double _cellWidth = 150;
const double _cellHeight = 20;
const double _valueWidth = 120;

void _addReportPages(pw.Document document, pw.Widget Function() build) {
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
  final style = fonts
      .style(reportTitleFontSize, bold: true)
      .copyWith(color: PdfColors.black);
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
      pw.Text(
        '$title ($subtitle)',
        textAlign: pw.TextAlign.center,
        style: style,
      ),
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

/// Aylık nöbet listesini verilen belgeye yazar.
///
/// Diğer PDF üreticileriyle aynı düzeni kullanır; testler çıktının
/// oluşabildiğini ve sayfaya sığdığını doğrulamak için çağırır.
pw.Document buildMonthlyDutyRosterPdf(
  pw.Document document,
  DutyReportData report,
  ReportFonts fonts,
) {
  _buildMonthlyRoster(document, fonts, report);
  return document;
}

void _buildMonthlyRoster(
  pw.Document document,
  ReportFonts fonts,
  DutyReportData report,
) {
  final list = report.currentList;
  final now = DateTime.now();
  final year = list?.year ?? now.year;
  final month = list?.month ?? now.month;
  final subtitle = list == null
      ? '${dutyMonthName(month)} $year'
      : '${list.title} • ${list.sectionLabel}';

  final byDate = <DateTime, List<DutyAssignment>>{};
  for (final assignment in report.currentAssignments) {
    byDate.putIfAbsent(assignment.date, () => []).add(assignment);
  }
  final settings = report.settings;
  final slotsPerDay = settings.dailyCount < 2 ? 2 : settings.dailyCount;

  // Ekrandaki görünümle aynı gün kümesi ve hafta gruplaması.
  final weeks = rosterWeeks(year, month, settings);

  // Her hafta, ekrandaki gibi yuvarlak köşeli bir kart olarak çizilir.
  final body = <pw.Widget>[
    for (var weekIndex = 0; weekIndex < weeks.length; weekIndex++)
      _weekCard(
        fonts: fonts,
        weekNumber: weekIndex + 1,
        dates: weeks[weekIndex],
        slotsPerDay: slotsPerDay,
        settings: settings,
        report: report,
        byDate: byDate,
      ),
    // İmza listenin hemen altında, sağa yaslı; sayfa alt bilgisinde değil.
    if (report.principalName.trim().isNotEmpty) ...[
      pw.SizedBox(height: _signatureTopGap),
      _signatureBlock(fonts, report),
    ],
  ];

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 16),
      // Sayfa numarası yalnızca header/footer içinde okunabilir; bu yüzden
      // birinci sayfaya ait asıl başlık da burada verilir.
      // 2. ve sonraki sayfalarda okunabilirlik için kısa bir devam başlığı.
      header: (context) => context.pageNumber == 1
          ? _reportHeader(
              fonts: fonts,
              schoolName: report.schoolName,
              title: 'Nöbet Listesi',
              subtitle: subtitle,
            )
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.only(bottom: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: reportGridColor),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    reportSchoolTitle(report.schoolName),
                    style: pw.TextStyle(
                      font: fonts.bold,
                      fontSize: 8.5,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    'Nöbet Listesi ($subtitle) - devam',
                    style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
      // Alt satırda yalnızca sayfa numarası; imza listenin altındadır.
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
      ),
      // Çıktı, ekrandaki listeyle aynı düzendedir: üstteki özet kutuları ve
      // sağdaki nöbet dağılımı paneli yer almaz.
      build: (context) => body,
    ),
  );
}

DateTime _weekStart(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));

/// Nöbet listesinin hemen altında, sağa yaslı imza bloğu.
///
/// Ad ve ünvan alt alta yazılır; ikisi de aynı punto, font ve kalınlıktadır.
/// İmza çizgisi çizilmez. Müdür adı boşsa blok hiç basılmaz.
pw.Widget _signatureBlock(ReportFonts fonts, DutyReportData report) {
  final name = report.principalName.trim();
  if (name.isEmpty) {
    return pw.SizedBox();
  }
  // İmza çizgisi yok; ad ve ünvan alt alta, sağa yaslı.
  // İki satır da birebir aynı punto, font ve kalınlıkta yazılır; aralarındaki
  // tek fark konudur.
  final style = pw.TextStyle(
    font: fonts.regular,
    fontSize: 9,
    color: reportTextColor,
  );
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(name, textAlign: pw.TextAlign.center, style: style),
        pw.Text(_principalTitle, textAlign: pw.TextAlign.center, style: style),
      ],
    ),
  );
}

/// Listenin bittiği yer ile imza arasındaki boşluk (yaklaşık iki satır).
const double _signatureTopGap = 24;

const String _principalTitle = 'Okul Müdürü';

/// Bir ayın nöbet günlerini haftalara böler.
///
/// Kurallar:
/// - Ayın tüm günleri listelenir; kapatılmış günler çıkarılır.
/// - Hafta pazartesi başlar ve listedeki sıraya göre 1'den numaralanır;
///   yılın ISO hafta numarası (örn. 41) kullanılmaz.
/// - Bir haftanın 7'den az günü olabilir (ayın başı ve sonu).
///
/// Çıktı ve ekran aynı yardımcıyı kullandığı için ikisi her zaman aynı
/// günleri gösterir.
List<List<DateTime>> rosterWeeks(int year, int month, DutySettings settings) {
  final dates = [
    for (final date in dutyMonthDates(year, month))
      if (!settings.blackouts.contains(dutyDateKey(date))) date,
  ];
  final weeks = <List<DateTime>>[];
  DateTime? lastWeekStart;
  for (final date in dates) {
    final start = _weekStart(date);
    if (lastWeekStart == null || start != lastWeekStart) {
      weeks.add([date]);
      lastWeekStart = start;
    } else {
      weeks.last.add(date);
    }
  }
  return weeks;
}

/// Bir haftayı yuvarlak köşeli bir kart olarak çizer.
///
/// Ekrandaki hafta kartıyla aynı fikir: üstte koyu bir hafta başlığı şeridi,
/// altında gün satırları. Günler bir beyaz bir hafif koyu olmak üzere sırayla
/// boyanır (zebra) ve aralarında ince çizgi vardır; böylece göz satır
/// kaydırmadan günü takip edebilir. Kartın köşeleri yuvarlak, iç çizgiler
/// düzdür.
pw.Widget _weekCard({
  required ReportFonts fonts,
  required int weekNumber,
  required List<DateTime> dates,
  required int slotsPerDay,
  required DutySettings settings,
  required DutyReportData report,
  required Map<DateTime, List<DutyAssignment>> byDate,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 5),
    padding: const pw.EdgeInsets.only(bottom: 2),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(_rosterCardRadius),
      border: pw.Border.all(color: reportGridColor, width: 0.7),
    ),
    // Zebra boyalar ve koyu başlık da kartın yuvarlak köşelerine uysun.
    child: pw.ClipRRect(
      horizontalRadius: _rosterCardRadius,
      verticalRadius: _rosterCardRadius,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _weekHeader(fonts, weekNumber),
          for (var index = 0; index < dates.length; index++)
            _rosterDayRow(
              fonts: fonts,
              date: dates[index],
              assignments: byDate[dates[index]] ?? const [],
              slotsPerDay: slotsPerDay,
              settings: settings,
              report: report,
              striped: index.isOdd,
              isLast: index == dates.length - 1,
            ),
        ],
      ),
    ),
  );
}

/// Kartın üst şeridi: koyu zemin üzerinde açık renkli hafta numarası.
pw.Widget _weekHeader(ReportFonts fonts, int weekNumber) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 3.5),
    decoration: const pw.BoxDecoration(color: _rosterHeaderFill),
    child: pw.Text(
      '$weekNumber. Hafta',
      style: pw.TextStyle(
        font: fonts.bold,
        fontSize: 10,
        color: PdfColors.white,
      ),
    ),
  );
}

/// Bir günün satırı: solda "14 Eylül Paz", sağda yuvalar.
pw.Widget _rosterDayRow({
  required ReportFonts fonts,
  required DateTime date,
  required List<DutyAssignment> assignments,
  required int slotsPerDay,
  required DutySettings settings,
  required DutyReportData report,
  bool striped = false,
  bool isLast = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
    decoration: pw.BoxDecoration(
      // Zebra: tek sayılı satırlar hafif koyu tona boyanır.
      color: striped ? _rosterStripeFill : reportWhiteFill,
      border: isLast
          ? null
          : const pw.Border(
              bottom: pw.BorderSide(color: reportGridColor, width: 0.5),
            ),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: _rosterDateWidth,
          height: _rosterRowHeight,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            '${date.day} ${dutyMonthName(date.month)} '
            '${dutyWeekdayShortLabel(date.weekday)}',
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              font: fonts.bold,
              fontSize: 8.6,
              color: reportTextColor,
            ),
          ),
        ),
        pw.SizedBox(width: 3),
        for (var slot = 0; slot < slotsPerDay; slot++)
          pw.Expanded(
            child: _rosterSlotText(
              fonts: fonts,
              assignment: assignments.length > slot ? assignments[slot] : null,
              slot: slot,
              settings: settings,
              report: report,
            ),
          ),
      ],
    ),
  );
}

/// Yuva içeriği: nöbet yeri ve nöbetçi **aynı satırda**.
///
/// Nöbet yeri okunması gereken bir bilgi olduğu için koyu ve belirgin yazılır;
/// öğretmen adı ondan sonra kalın gelir. Taşma olmaması için ikisi de
/// kırpılır.
pw.Widget _rosterSlotText({
  required ReportFonts fonts,
  required DutyAssignment? assignment,
  required int slot,
  required DutySettings settings,
  required DutyReportData report,
}) {
  final location = assignment?.location?.trim().isNotEmpty == true
      ? assignment!.location!.trim()
      : settings.locationForSlot(slot).trim();
  final empty = assignment == null;
  final name = empty
      ? '—'
      : reportTruncate(_teacherName(assignment, report), _rosterNameLimit);

  return pw.Container(
    height: _rosterRowHeight,
    padding: const pw.EdgeInsets.symmetric(horizontal: 2),
    alignment: pw.Alignment.centerLeft,
    child: pw.RichText(
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
      text: pw.TextSpan(
        children: [
          if (location.isNotEmpty)
            pw.TextSpan(
              text: '${reportTruncate(location, _rosterLocationLimit)}: ',
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: _rosterLocationFontSize,
                color: _rosterLocationColor,
              ),
            ),
          pw.TextSpan(
            text: name,
            style: empty
                ? pw.TextStyle(
                    font: fonts.regular,
                    fontSize: _rosterNameFontSize,
                    color: PdfColors.grey500,
                  )
                : pw.TextStyle(
                    font: fonts.bold,
                    fontSize: _rosterNameFontSize,
                    color: reportTextColor,
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Kart köşe yarıçapı; ekrandaki hafta kartıyla aynı hissi verir.
const double _rosterCardRadius = 7;

/// Tek satırlık yuvaya göre seçildi; 31 günlük bir ay 6 hafta kartıyla ve
/// listenin altındaki imza bloğuyla birlikte tek sayfaya sığar.
const double _rosterRowHeight = 16;
const double _rosterDateWidth = 68;

// Yuva genişliği sınırları. Nöbet yeri her gün aynen tekrarlar, öğretmen
// adı ise farklıdır; bu yüzden kırpma payı addan çok yere bırakıldı.
const int _rosterLocationLimit = 20;
const int _rosterNameLimit = 26;

// Nöbet yeri artık okunması gereken bir bilgi olduğu için puntoyu ve koyuluğu
// artırdık. Sütun genişliği sınırlı olduğundan öğretmen adının punyosu
// düşük tutuldu; ikisi birlikte ölçülerek sığdırıldı.
const double _rosterLocationFontSize = 7.2;
const double _rosterNameFontSize = 8.2;

/// Hafta başlığı zemin rengi; uygulamanın koyu moru.
const PdfColor _rosterHeaderFill = PdfColor.fromInt(0xFF3E0C28);

/// Zebra desende tek sayılı satırların hafif koyu tonu.
const PdfColor _rosterStripeFill = PdfColor.fromInt(0xFFF2F2F4);

/// Nöbet yeri metninin rengi; öğretmen adından açık ama gri değil.
const PdfColor _rosterLocationColor = PdfColor.fromInt(0xFF3E0C28);

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
          (
            'Toplam liste',
            '${report.lists.where((l) => l.year == year).length}',
          ),
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
      perSchool[label] =
          (perSchool[label] ?? 0) + (perTeacher[teacher.id ?? 0] ?? 0);
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

pw.Widget _summaryTable(ReportFonts fonts, List<(String, String)> rows) {
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
