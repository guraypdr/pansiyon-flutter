import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

/// Öğrenci nöbet listesi çıktısının verisi.
class StudentDutyReportData {
  const StudentDutyReportData({
    required this.schoolName,
    required this.list,
    required this.students,
    required this.dates,
    this.principalName = '',
    this.dutyOfficerName = '',
    this.roomNumberOf,
  });

  final String schoolName;

  /// Basılacak tur.
  final StudentDutyList list;

  /// Öğrenci kimliklerini ad bilgisine bağlayan liste.
  final List<Student> students;

  /// Nöbet günlerinin takvim tarihleri; kapalı günler atlanmış hâlde.
  final List<DateTime> dates;

  /// Çıktının sağ altındaki imza satırında yazılacak okul müdürü adı.
  ///
  /// Boşsa imza bloğu basılmaz.
  final String principalName;

  /// Nöbet sorumlusunun adı; sağdaki ikinci imza satırında yazılır.
  ///
  /// Boşsa bu imza satırı basılmaz.
  final String dutyOfficerName;

  /// Öğrencinin oda numarasını veren çağrı; bulunamazsa `null`.
  ///
  /// Oda bilgisi öğrenci kaydında değil, oda atama tablosunda tutulduğu
  /// için dışarıdan verilir.
  final int? Function(int studentId)? roomNumberOf;

  Student? studentOf(int studentId) {
    for (final student in students) {
      if (student.id == studentId) return student;
    }
    return null;
  }

  int? studentRoomOf(int studentId) => roomNumberOf?.call(studentId);
}

/// Öğrenci nöbet listesini yazdırma penceresini açar.
Future<void> printStudentDutyReport({
  required BuildContext context,
  required StudentDutyReportData report,
}) async {
  final bytes = await buildStudentDutyReportPdf(report);
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'Öğrenci Nöbet Listesi - ${report.schoolName}',
  );
}

// --- Çizim ölçüleri -------------------------------------------------------------
// Değerler öğretmen nöbet listesi çıktısıyla aynı seçilmiştir; iki liste
// yan yana karşılaştırıldığında satır ritmi aynı görünür.

/// Kart köşe yarıçapı; ekrandaki hafta kartıyla aynı hissi verir.
const double _cardRadius = 7;

/// Gün satırı yüksekliği; sıkı satır ritmi için düşük tutulur.
const double _rowHeight = 16;

/// Sol sütundaki tarih genişliği.
const double _dateWidth = 76;

// Yuva genişliği sınırları. Öğrenci adı sütunda okunması gereken asıl bilgi
// olduğundan kırpma payı adda bırakıldı.
const int _nameLimit = 26;

const double _nameFontSize = 8.2;

// Ölçü sabitleri
/// Listenin hemen altındaki müdür imza bloğuna giden boşluk.
const double _signatureTopGap = 24;

const String _principalTitle = 'Okul Müdürü';
const String _officerTitle = 'Nöbet Sorumlusu';

/// Öğrenci nöbet listesi PDF belgesini üretir.
///
/// Yazdırma penceresi açmadan belge üretilebilir; testler bu yolu çağırır.
Future<Uint8List> buildStudentDutyReportPdf(
  StudentDutyReportData report,
) async {
  final fonts = await ReportFonts.load();
  final document = pw.Document();

  // Ekran ve çıktı aynı günleri gösterir: gün sırası verilen `dates`
  // dizisinden okunur ve haftalara ayrılır.
  final weeks = studentDutyWeeks(report.dates);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 16),
      header: (context) => context.pageNumber == 1
          ? _reportHeader(fonts: fonts, report: report)
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
                    style: fonts
                        .style(8.5, bold: true)
                        .copyWith(color: PdfColors.black),
                  ),
                  pw.Text(
                    'Öğrenci Nöbet Listesi - devam',
                    style: fonts.style(8).copyWith(color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: fonts.style(7.5).copyWith(color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        for (var index = 0; index < weeks.length; index++)
          _weekCard(
            fonts: fonts,
            weekNumber: index + 1,
            dates: weeks[index],
            report: report,
          ),
        if (report.principalName.trim().isNotEmpty) ...[
          pw.SizedBox(height: _signatureTopGap),
          _signatureBlock(fonts, report),
        ],
      ],
    ),
  );

  return document.save();
}

/// Nöbet günlerini takvim haftalarına göre böler.
///
/// Haftalar pazartesi başlar ve listedeki sıraya göre 1'den numaralanır.
/// Liste başlangıç günüyle başlamak zorunda değildir; ilk hafta eksik günle
/// başlar. Çıktı ve ekran aynı yardımcıyı kullandığı için ikisi her zaman
/// aynı gruplamayı gösterir.
List<List<DateTime>> studentDutyWeeks(List<DateTime> dates) {
  if (dates.isEmpty) {
    return const [];
  }
  final weeks = <List<DateTime>>[];
  var current = <DateTime>[];
  DateTime? weekStart;

  for (final date in dates) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    if (weekStart != null && monday != weekStart) {
      weeks.add(current);
      current = <DateTime>[];
    }
    weekStart = monday;
    current.add(date);
  }
  weeks.add(current);

  return weeks;
}

/// Başlık: eğitim yılı, okul adı ve liste bilgisi.
pw.Widget _reportHeader({
  required ReportFonts fonts,
  required StudentDutyReportData report,
}) {
  final style = fonts
      .style(reportTitleFontSize, bold: true)
      .copyWith(color: PdfColors.black);
  final subtitle =
      '${report.list.studentCount} öğrenci • ${report.list.dayCount} nöbet günü';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 4),
      pw.Text(
        '${reportEducationYear(report.list.startDate)} Eğitim Öğretim Yılı',
        textAlign: pw.TextAlign.center,
        style: style,
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        reportSchoolTitle(report.schoolName),
        textAlign: pw.TextAlign.center,
        style: style,
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Öğrenci Nöbet Listesi ($subtitle)',
        textAlign: pw.TextAlign.center,
        style: style,
      ),
      pw.SizedBox(height: 8),
    ],
  );
}

/// Bir haftayı yuvarlak köşeli bir kart olarak çizer.
///
/// Kartın üstünde koyu bir hafta başlığı şeridi, altında gün satırları
/// vardır. Günler sırayla açık ve açık gri boyanır (zebra) ve aralarında ince
/// çizgi bulunur; böylece göz satır kaydırmadan günü takip edebilir.
pw.Widget _weekCard({
  required ReportFonts fonts,
  required int weekNumber,
  required List<DateTime> dates,
  required StudentDutyReportData report,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 5),
    padding: const pw.EdgeInsets.only(bottom: 2),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(_cardRadius),
      border: pw.Border.all(color: reportGridColor, width: 0.7),
    ),
    // Zebra boyalar ve koyu başlık da kartın yuvarlak köşelerine uysun.
    child: pw.ClipRRect(
      horizontalRadius: _cardRadius,
      verticalRadius: _cardRadius,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _weekHeader(fonts, weekNumber),
          for (var index = 0; index < dates.length; index++)
            _dayRow(
              fonts: fonts,
              date: dates[index],
              sequence: _sequenceOf(report, dates[index]),
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
    decoration: const pw.BoxDecoration(color: reportAccentFill),
    child: pw.Text(
      '$weekNumber. Hafta',
      style: fonts.style(10, bold: true).copyWith(color: PdfColors.white),
    ),
  );
}

/// Tarihin listenin kaçıncı nöbet gününe denk geldiğini bulur.
int _sequenceOf(StudentDutyReportData report, DateTime date) {
  for (var index = 0; index < report.dates.length; index++) {
    if (report.dates[index] == date) {
      return report.list.days.length > index ? report.list.days[index].sequence : index + 1;
    }
  }
  return 1;
}

/// Bir günün satırı: solda "1. Gün • 05 Eki Paz", sağda iki nöbetçi.
pw.Widget _dayRow({
  required ReportFonts fonts,
  required DateTime date,
  required int sequence,
  required StudentDutyReportData report,
  bool striped = false,
  bool isLast = false,
}) {
  final students = sequence <= report.list.days.length
      ? report.list.days[sequence - 1].studentIds
      : const <int>[];

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
    decoration: pw.BoxDecoration(
      // Zebra: tek sayılı satırlar hafif koyu tona boyanır.
      color: striped ? reportStripeFill : reportWhiteFill,
      border: isLast
          ? null
          : const pw.Border(
              bottom: pw.BorderSide(color: reportGridColor, width: 0.5),
            ),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: _dateWidth,
          height: _rowHeight,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            '${date.day} ${_monthName(date.month)} ${date.year}',
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: fonts.style(8.6, bold: true).copyWith(color: reportTextColor),
          ),
        ),
        pw.SizedBox(width: 3),
        for (var slot = 0; slot < studentDutyDailyCount; slot++)
          pw.Expanded(
            child: _slotText(
              fonts: fonts,
              report: report,
              studentId: slot < students.length ? students[slot] : null,
            ),
          ),
      ],
    ),
  );
}

/// Yuva içeriği: öğrenci adı ve yanında daha küçük puntolu oda bilgisi.
///
/// Ad okunması gereken ana bilgi olduğundan belirgin yazılır; oda numarası
/// yardımcı not olduğu için aynı satırda, daha küçük ve açık tonda durur.
/// İkisi birlikte ölçülerek sütuna sığdırılır.
pw.Widget _slotText({
  required ReportFonts fonts,
  required StudentDutyReportData report,
  required int? studentId,
}) {
  if (studentId == null) {
    return pw.Container(
      height: _rowHeight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        '—',
        style: fonts.style(_nameFontSize).copyWith(color: PdfColors.grey500),
      ),
    );
  }

  final student = report.studentOf(studentId);
  final name = reportTruncate(
    student?.fullName ?? 'Öğrenci #$studentId',
    _nameLimit,
  );

  return pw.Container(
    height: _rowHeight,
    padding: const pw.EdgeInsets.symmetric(horizontal: 2),
    alignment: pw.Alignment.centerLeft,
    child: pw.Text(
      name,
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
      style: fonts.style(_nameFontSize, bold: true).copyWith(color: reportTextColor),
    ),
  );
}

/// Listenin altındaki imza bloğu: okul müdürü ve nöbet sorumlusu.
///
/// İki imza alanı yan yana basılır; adı boş olan alan atlanır. İmza
/// çizgisi çizilmez; ad ve unvan alt alta, aynı puntoda yazılır.
pw.Widget _signatureBlock(ReportFonts fonts, StudentDutyReportData report) {
  final principal = report.principalName.trim();
  final officer = report.dutyOfficerName.trim();
  if (principal.isEmpty && officer.isEmpty) {
    return pw.SizedBox();
  }

  final style = fonts.style(9).copyWith(color: reportTextColor);

  pw.Widget signatureCell(String name, String title) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(name, textAlign: pw.TextAlign.center, style: style),
        pw.Text(title, textAlign: pw.TextAlign.center, style: style),
      ],
    );
  }

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      if (principal.isNotEmpty) ...[
        signatureCell(principal, _principalTitle),
        pw.SizedBox(width: 40),
      ],
      if (officer.isNotEmpty) signatureCell(officer, _officerTitle),
    ],
  );
}

const _monthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _monthName(int month) => _monthNames[month - 1];