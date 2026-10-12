import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

class MealMenuPrintData {
  const MealMenuPrintData({
    required this.schoolName,
    required this.year,
    required this.month,
    required this.days,
  });

  final String schoolName;
  final int year;
  final int month;
  final List<MealDay> days;

  String get monthName => mealMonthName(month);
}

/// Seçili ayın menüsünü tablo hâlinde yazdırır.
///
/// Sütun sırası Excel ile aynıdır: tarih, kahvaltı, öğle, akşam, ara öğün.
/// Sütun başlıkları ikinci ve sonraki sayfalarda da tekrarlanır.
Future<void> printMealMenu({
  required BuildContext context,
  required MealMenuPrintData data,
}) async {
  final bytes = await buildMealMenuPdf(data);
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: '${data.monthName} ${data.year} Yemek Menüsü',
  );
}

/// Yazdırma penceresini açmadan menü belgesini üretir.
///
/// Belge üretimi yazdırmadan ayrıdır; testler yalnızca bu yolu çağırarak
/// içeriği ve sayfa yapısını denetleyebilir.
Future<Uint8List> buildMealMenuPdf(MealMenuPrintData data) async {
  final fonts = await ReportFonts.load();
  final document = pw.Document();

  final columnHeader = _buildColumnHeader(fonts);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(20, 16, 20, 18),
      header: (context) =>
          context.pageNumber == 1 ? pw.SizedBox() : columnHeader,
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: fonts.style(7.5).copyWith(color: reportTextColor),
        ),
      ),
      build: (context) => [
        _buildTitle(fonts, data),
        pw.SizedBox(height: 8),
        columnHeader,
        for (var index = 0; index < data.days.length; index++)
          _buildRow(fonts, data.days[index], stripe: index.isOdd),
      ],
    ),
  );

  return document.save();
}

/// Sütun genişlikleri toplamı sayfa genişliğini doldurur; iki sütunlu tablo
/// yazdırıldığında boşluk kalmaması için sabit hesaplanmıştır.
const _dateColumnWidth = 62.0;
const _mealColumnWidth = 123.0;

/// 8.5 punto yazının satır yüksekliği ve hücrenin dikey boşluğu.
const _lineHeight = 10.4;
const _cellPaddingV = 3.0;

pw.Widget _buildTitle(ReportFonts fonts, MealMenuPrintData data) {
  final titleStyle = fonts
      .style(reportTitleFontSize, bold: true)
      .copyWith(color: PdfColors.black);
  final subStyle = fonts.style(reportHeaderFontSize);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 2),
      pw.Text(
        reportSchoolTitle(data.schoolName),
        textAlign: pw.TextAlign.center,
        style: titleStyle,
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        // Türkçede toUpperCase() noktasız "i"yi "I" yapar ve "EKIM" gibi
        // hatalı bir başlık üretir; ayrı bir Türkçe büyütme kullanılır.
        '${mealMonthUpperName(data.month)} AYI PANSİYON YEMEK MENÜSÜ',
        textAlign: pw.TextAlign.center,
        style: titleStyle,
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        '${reportEducationYear(DateTime(data.year, data.month, 1))} '
        'Eğitim Öğretim Yılı',
        textAlign: pw.TextAlign.center,
        style: subStyle.copyWith(color: reportTextColor),
      ),
      pw.SizedBox(height: 4),
    ],
  );
}

pw.Widget _buildColumnHeader(ReportFonts fonts) {
  return pw.Container(
    height: 20,
    child: pw.Row(
      children: [
        reportHeadCell(
          text: 'TARİH',
          fonts: fonts,
          height: 20,
          width: _dateColumnWidth,
        ),
        for (final type in MealType.values)
          reportHeadCell(
            text: mealUpperCase(type.label),
            fonts: fonts,
            height: 20,
            width: _mealColumnWidth,
          ),
      ],
    ),
  );
}

/// Bir satırın yüksekliği, o günün en uzun öğünündeki yemek sayısından
/// hesaplanır; dört hücre bu yüzden aynı boyda çıkar.
double _rowHeight(MealDay day) {
  final itemCount = MealType.values.fold<int>(
    0,
    (max, type) =>
        day.mealsOf(type).length > max ? day.mealsOf(type).length : max,
  );
  // Tarih hücresi iki satır (gün ve gün adı) taşır; yemek olmayan günlerde de
  // okunur bir satır bırakılır.
  return _lineHeight * (itemCount < 2 ? 2 : itemCount) + _cellPaddingV * 2;
}

pw.Widget _buildRow(ReportFonts fonts, MealDay day, {required bool stripe}) {
  final background = stripe ? reportStripeFill : reportWhiteFill;
  final height = _rowHeight(day);
  return pw.Row(
    children: [
      _cell(
        width: _dateColumnWidth,
        height: height,
        background: background,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              '${day.date.day}.${day.date.month.toString().padLeft(2, '0')}'
              '.${day.date.year}',
              style: fonts
                  .style(8.5, bold: true)
                  .copyWith(color: reportTextColor),
            ),
            pw.Text(
              mealWeekdayName(day.date),
              style: fonts.style(7.5).copyWith(color: reportTextColor),
            ),
          ],
        ),
      ),
      for (final type in MealType.values)
        _cell(
          width: _mealColumnWidth,
          height: height,
          background: background,
          child: pw.Text(
            // Satır sonu ile birleştirilir; hücre zaten sabit yükseklikte
            // olduğu için uzun bir yemek adı ikinci satıra sığmaz.
            day.mealsOf(type).join('\n'),
            style: fonts
                .style(8.5)
                .copyWith(
                  color: day.mealsOf(type).isEmpty
                      ? reportGridColor
                      : reportTextColor,
                ),
          ),
        ),
    ],
  );
}

pw.Widget _cell({
  required double width,
  required double height,
  required PdfColor background,
  required pw.Widget child,
}) {
  return pw.Container(
    width: width,
    height: height,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    decoration: pw.BoxDecoration(
      color: background,
      border: pw.Border.all(color: reportGridColor),
    ),
    child: child,
  );
}
