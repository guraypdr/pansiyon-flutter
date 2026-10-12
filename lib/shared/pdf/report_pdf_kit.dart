import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Rapor renkleri uygulamanın mavi paletini izler (AppColors.primary /
// primaryDark). Tema pembeden maviye döndüğünde buradaki tonlar da güncellendi;
// eski pembeler çıktılarda uyumsuz kalmıştı.
const reportGridColor = PdfColor.fromInt(0xFF94A3B8);
const reportHeaderFill = PdfColor.fromInt(0xFFDBEAFE);
const reportStripeFill = PdfColor.fromInt(0xFFF1F5F9);
const reportWhiteFill = PdfColor.fromInt(0xFFFFFFFF);
const reportTextColor = PdfColor.fromInt(0xFF0F172A);

/// Koyu başlık bandı; beyaz yazı kullanılır.
const reportAccentFill = PdfColor.fromInt(0xFF0F172A);

const double reportHeaderFontSize = 9;
const double reportTitleFontSize = 12;
const double reportRowHeight = 19;
const double reportCellHeight = 20;

const _dayNames = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String reportDayName(DateTime date) => _dayNames[date.weekday - 1];

/// Belgede gösterilen tarih: gg/aa/yyyy.
String reportDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String reportEducationYear(DateTime date) {
  final start = date.month >= 9 ? date.year : date.year - 1;
  return '$start-${start + 1}';
}

String reportSchoolTitle(String schoolName) {
  final trimmed = schoolName.trim();
  if (trimmed.toLowerCase().contains('müdürlüğ')) {
    return trimmed;
  }
  return trimmed.isEmpty ? 'Okul Müdürlüğü' : '$trimmed Müdürlüğü';
}

/// Metni verilen karakter sınırında sonundan keser.
String reportTruncate(String value, int maxLength) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return trimmed.substring(0, maxLength);
}

/// Telefon numarasını sütuna sığacak şekilde sıkıştırır.
String reportPhone(String? phone) {
  final raw = (phone ?? '').trim();
  if (raw.isEmpty) {
    return '';
  }
  return raw.replaceAll(RegExp(r'[\s\-()]'), '');
}

/// Türkçe karakterleri (ı, ğ, ş, İ) doğru basmak için gömülü Roboto fontlarını kullanır.
class ReportFonts {
  ReportFonts(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  static Future<ReportFonts> load() async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    return ReportFonts(regular, bold);
  }

  pw.TextStyle style(double fontSize, {bool bold = false}) {
    return pw.TextStyle(font: bold ? this.bold : regular, fontSize: fontSize);
  }
}

pw.Widget reportCell({
  required String text,
  required ReportFonts fonts,
  required double height,
  required double width,
  pw.Alignment alignment = pw.Alignment.centerLeft,
  bool bold = false,
  double fontSize = 8.5,
  PdfColor? color,
}) {
  return pw.Container(
    width: width,
    height: height,
    alignment: alignment,
    padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
    decoration: pw.BoxDecoration(
      color: color,
      border: pw.Border.all(color: reportGridColor),
    ),
    child: pw.Text(
      text,
      style: fonts.style(fontSize, bold: bold).copyWith(color: reportTextColor),
    ),
  );
}

/// Hücre içeriğini 90° saat yönünde döndürür (yukarıdan aşağı okunur).
pw.Widget reportVerticalCell({
  required String text,
  required ReportFonts fonts,
  required double height,
  required double width,
  double fontSize = reportHeaderFontSize,
  bool bold = false,
  PdfColor? color,
}) {
  return pw.Container(
    width: width,
    height: height,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      color: color,
      border: pw.Border.all(color: reportGridColor),
    ),
    child: text.isEmpty
        ? pw.SizedBox()
        : pw.Transform.rotate(
            angle: -1.5708,
            child: pw.Text(
              text,
              style: fonts
                  .style(fontSize, bold: bold)
                  .copyWith(color: reportTextColor),
            ),
          ),
  );
}

/// Koyu renklendirilmiş sütun başlığı hücresi.
pw.Widget reportHeadCell({
  required String text,
  required ReportFonts fonts,
  required double height,
  required double width,
  pw.Alignment alignment = pw.Alignment.center,
  bool vertical = false,
}) {
  if (vertical) {
    return reportVerticalCell(
      text: text,
      fonts: fonts,
      height: height,
      width: width,
      bold: true,
      color: reportHeaderFill,
    );
  }
  return reportCell(
    text: text,
    fonts: fonts,
    height: height,
    width: width,
    alignment: alignment,
    bold: true,
    fontSize: reportHeaderFontSize,
    color: reportHeaderFill,
  );
}

/// Raporların ortak üç satırlık başlığı ve tarih satırı.
///
/// Başlık ve tarih, tablodaki sütun başlıklarıyla aynı puntoda yazılır;
/// böylece belgede iki farklı başlık ölçeği oluşmaz.
pw.Widget buildReportHeader({
  required ReportFonts fonts,
  required String educationYear,
  required String schoolName,
  required String reportTitle,
  required String locationLabel,
  required DateTime date,
}) {
  final titleStyle = fonts
      .style(reportHeaderFontSize, bold: true)
      .copyWith(color: PdfColors.black);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 4),
      pw.Text(
        '$educationYear Eğitim Öğretim Yılı',
        textAlign: pw.TextAlign.center,
        style: titleStyle,
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        reportSchoolTitle(schoolName),
        textAlign: pw.TextAlign.center,
        style: titleStyle,
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        '$reportTitle ($locationLabel)',
        textAlign: pw.TextAlign.center,
        style: titleStyle,
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        // Gün adı normal yazılır: "Pazartesi". `toUpperCase()` Türkçede
        // noktasız "i"yi "I" yapar ve "PAZARTESI" gibi hatalı bir metin üretir.
        '${reportDate(date)} ${reportDayName(date)}',
        textAlign: pw.TextAlign.right,
        style: titleStyle,
      ),
      pw.SizedBox(height: 6),
    ],
  );
}
