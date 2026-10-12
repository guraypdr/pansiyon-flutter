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

/// Seçili ayın menüsünü haftalık menü çizelgesi olarak yazdırır.
///
/// Sayfa yatay A4'tür. Günler Pazartesi başlayan haftalara ayrılır; her hafta
/// koyu yeşil bir başlık bandıyla ve dört öğünlü bir tabloyla gösterilir.
/// İki hafta bir sayfaya sığdığında yan yana, sığmadığında tek başına basılır.
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

  final weeks = menuWeeks(data.days);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: fonts.style(7.5).copyWith(color: _menuSubtitleColor),
        ),
      ),
      build: (context) => [
        _buildTitle(fonts, data),
        pw.SizedBox(height: 6),
        if (weeks.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 24),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Bu ay için menü kaydı bulunmuyor.',
              style: fonts.style(10).copyWith(color: _menuSubtitleColor),
            ),
          )
        else
          // Her hafta tek bir bileşen olarak verilir; sığmayan hafta bölünmez,
          // baştan sonraki sayfaya taşınır. Üçüncü haftadan itibaren sayfa
          // başına iki haftalık düzen korunur.
          for (var index = 0; index < weeks.length; index++) ...[
            if (index > 0 && index % _menuWeeksPerPage == 0) pw.NewPage(),
            _buildWeekGroup(fonts, weeks[index], number: index + 1),
          ],
      ],
    ),
  );

  return document.save();
}

// --- Renkler -----------------------------------------------------------------

/// Hafta başlık bandının koyu yeşili.
const _menuWeekBarFill = PdfColor.fromInt(0xFF14532D);

/// Sütun başlıklarının açık yeşil dolgusu.
const _menuHeadFill = PdfColor.fromInt(0xFFE8F5E9);

/// Tablo çizgileri ve sütun başlığı yazısı.
const _menuLineColor = PdfColor.fromInt(0xFF7CB185);

/// Başlık satırlarının mavi rengi.
const _menuTitleColor = PdfColor.fromInt(0xFF1B4F9C);

/// Eğitim öğretim yılı ve sayfa numarasının gri rengi.
const _menuSubtitleColor = PdfColor.fromInt(0xFF6B7280);

/// Hücre yazısı.
const _menuTextColor = PdfColor.fromInt(0xFF1F2937);

/// Yemek olmayan öğünlerde gösterilen tire.
const _menuEmptyColor = PdfColor.fromInt(0xFF9CA3AF);

// --- Ölçüler ------------------------------------------------------------------

/// Tarih sütununun genişliği; kalan pay dört öğün sütununa eşit dağılır.
const _menuDateColumnWidth = 78.0;

const _menuCellPadding = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5);
const _menuHeadCellPadding = pw.EdgeInsets.symmetric(
  horizontal: 6,
  vertical: 5.5,
);

const _menuWeekBarHeight = 16.0;

/// Sayfa başına basılan hafta sayısı. Yatay A4'e iki hafta rahat sığar; üçüncü
/// haftada sayfa kırılır ve düzen tekrarlanır.
const _menuWeeksPerPage = 2;

/// Haftalar arası boşluk.
const _menuWeekGap = 10.0;

// --- Başlık -------------------------------------------------------------------

pw.Widget _buildTitle(ReportFonts fonts, MealMenuPrintData data) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        reportSchoolTitle(data.schoolName),
        textAlign: pw.TextAlign.center,
        style: fonts
            .style(12.5, bold: true)
            .copyWith(color: _menuTitleColor),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        // Türkçede toUpperCase() noktasız "i"yi "I" yapar ve "EKIM" gibi
        // hatalı bir başlık üretir; ayrı bir Türkçe büyütme kullanılır.
        '${mealMonthUpperName(data.month)} AYI PANSİYON YEMEK MENÜSÜ',
        textAlign: pw.TextAlign.center,
        style: fonts
            .style(14, bold: true)
            .copyWith(color: _menuTitleColor),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        '${reportEducationYear(DateTime(data.year, data.month, 1))} '
        'Eğitim Öğretim Yılı',
        textAlign: pw.TextAlign.center,
        style: fonts.style(9.5).copyWith(color: _menuSubtitleColor),
      ),
    ],
  );
}

// --- Haftalar -----------------------------------------------------------------

/// Pazartesi başlayan haftaya düşen günler.
class MenuWeek {
  const MenuWeek({required this.start, required this.days});

  /// Haftanın Pazartesi günü.
  final DateTime start;

  /// Bu haftaya düşen, menüsü kayıtlı günler (tarih sırasında).
  final List<MealDay> days;

  /// Bant yazısı: `01 - 02 EKİM 2026`. Hafta iki aya taşıyorsa iki gün de
  /// kendi ayının adıyla yazılır: `29 EKİM - 01 KASIM 2026`.
  String get label {
    final first = days.first.date;
    final last = days.last.date;
    final sameMonth = last.month == first.month;
    final from = sameMonth
        ? first.day.toString().padLeft(2, '0')
        : '${first.day.toString().padLeft(2, '0')} '
              '${mealMonthUpperName(first.month)}';
    final to = sameMonth
        ? last.day.toString().padLeft(2, '0')
        : '${last.day.toString().padLeft(2, '0')} '
              '${mealMonthUpperName(last.month)}';
    final month = sameMonth ? mealMonthUpperName(first.month) : '';
    return '$from - $to $month ${first.year}'.replaceAll('  ', ' ').trim();
  }
}

/// Günleri Pazartesi başlayan haftalara ayırır.
///
/// Yıl ve ay başında yarım kalan haftalar da kendi bandıyla gösterilir; menü
/// kaydı olmayan günler çizelgeye hiç girmez.
List<MenuWeek> menuWeeks(List<MealDay> days) {
  final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final weeks = <MenuWeek>[];
  DateTime? currentStart;
  var current = <MealDay>[];

  void flush() {
    if (current.isEmpty) return;
    weeks.add(MenuWeek(start: currentStart!, days: List.unmodifiable(current)));
    current = <MealDay>[];
  }

  for (final day in sorted) {
    final monday = _mondayOf(day.date);
    if (currentStart != null && monday != currentStart) {
      flush();
    }
    currentStart = monday;
    current.add(day);
  }
  flush();

  return weeks;
}

DateTime _mondayOf(DateTime date) =>
    DateTime(date.year, date.month, date.day).subtract(
      Duration(days: date.weekday - 1),
    );

pw.Widget _buildWeekGroup(
  ReportFonts fonts,
  MenuWeek week, {
  required int number,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: _menuWeekGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildWeekBar(fonts, '$number. HAFTA (${week.label})'),
        _buildWeekTable(fonts, week),
      ],
    ),
  );
}

pw.Widget _buildWeekBar(ReportFonts fonts, String label) {
  return pw.Container(
    height: _menuWeekBarHeight,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8),
    alignment: pw.Alignment.centerLeft,
    decoration: const pw.BoxDecoration(color: _menuWeekBarFill),
    child: pw.Text(
      label,
      style: fonts.style(9.5, bold: true).copyWith(color: PdfColors.white),
    ),
  );
}

pw.Widget _buildWeekTable(ReportFonts fonts, MenuWeek week) {
  final border = pw.TableBorder.all(color: _menuLineColor, width: 0.6);

  return pw.Table(
    border: border,
    columnWidths: {
      0: const pw.FixedColumnWidth(_menuDateColumnWidth),
      for (var index = 1; index <= MealType.values.length; index++)
        index: pw.FlexColumnWidth(),
    },
    children: [
      _buildHeadRow(fonts),
      for (final day in week.days) _buildDayRow(fonts, day),
    ],
  );
}

pw.TableRow _buildHeadRow(ReportFonts fonts) {
  pw.Widget headCell(String text) {
    return pw.Container(
      padding: _menuHeadCellPadding,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(color: _menuHeadFill),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: fonts
            .style(8.2, bold: true)
            .copyWith(color: _menuTitleColor),
      ),
    );
  }

  return pw.TableRow(
    decoration: const pw.BoxDecoration(color: _menuHeadFill),
    verticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      headCell('Tarih'),
      for (final type in MealType.values) headCell(type.label),
    ],
  );
}

pw.TableRow _buildDayRow(ReportFonts fonts, MealDay day) {
  final dateLabel =
      '${day.date.day.toString().padLeft(2, '0')}.'
      '${day.date.month.toString().padLeft(2, '0')}';

  return pw.TableRow(
    verticalAlignment: pw.TableCellVerticalAlignment.top,
    children: [
      pw.Container(
        padding: _menuCellPadding,
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: dateLabel,
                style: fonts
                    .style(8.2, bold: true)
                    .copyWith(color: _menuTextColor),
              ),
              pw.TextSpan(
                text: ' ${mealWeekdayName(day.date)}',
                style: fonts.style(8.2).copyWith(color: _menuTextColor),
              ),
            ],
          ),
        ),
      ),
      for (final type in MealType.values) _buildMealCell(fonts, day, type),
    ],
  );
}

pw.Widget _buildMealCell(ReportFonts fonts, MealDay day, MealType type) {
  final meals = day.mealsOf(type);
  final isEmpty = meals.isEmpty;

  return pw.Container(
    padding: _menuCellPadding,
    child: pw.Text(
      // Yemekler virgülle arka arkaya yazılır; hücre içinde kendiliğinden
      // satıra bölünür.
      isEmpty ? '—' : meals.join(', '),
      style: fonts
          .style(8.2)
          .copyWith(color: isEmpty ? _menuEmptyColor : _menuTextColor),
    ),
  );
}