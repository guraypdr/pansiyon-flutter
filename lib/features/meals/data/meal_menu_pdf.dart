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
///
/// Menü yatay A4 sayfalarına **ölçekleme yapılmadan** yerleştirilir. Sayfa
/// kırılımı `MultiPage` tarafından yapılır: sığmayan hafta bölünmez, olduğu
/// gibi sonraki sayfaya taşınır. Bu sayede yemek adları hücrede ne kadar uzun
/// olursa olsun hiçbir hafta taşıp kaybolmaz.
Future<Uint8List> buildMealMenuPdf(MealMenuPrintData data) async {
  final fonts = await ReportFonts.load();
  final document = pw.Document();

  final weeks = menuWeeks(data.days);

  if (weeks.isEmpty) {
    document.addPage(_buildEmptyPage(fonts, data));
    return document.save();
  }

  // Haftalar sayfaya yerleştirilir: bir haftanın günleri sığmıyorsa sığan
  // kadarı bulunulan sayfaya, kalanı alt sayfaya aktarılır. Her yerleştirmeden
  // sonra sayfanın kalan alanı yeniden ölçülür ve sonraki hafta ona göre
  // konumlanır.
  final placement = menuWeekPlacement(weeks);

  final pageCount = placement.length;
  for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
    final isFirst = pageIndex == 0;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Başlık yalnızca ilk sayfada basılır.
            if (isFirst) ...[
              pw.SizedBox(height: 4),
              _buildTitle(fonts, data),
              pw.SizedBox(height: 8),
            ],
            for (var index = 0; index < placement[pageIndex].length; index++) ...[
              if (index > 0) pw.SizedBox(height: menuWeekGap),
              _buildWeekGroup(
                fonts,
                placement[pageIndex][index],
                number: weeks.indexOf(placement[pageIndex][index].week) + 1,
              ),
            ],
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Sayfa ${pageIndex + 1} / $pageCount',
                style: fonts.style(8).copyWith(color: _menuSubtitleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  return document.save();
}

/// Haftaların gün satırlarını sayfaya sığan kadar yerleştirir.
///
/// Kural: bulunulan sayfada yer kaldığı sürece haftanın sığan kadar günü
/// konur; kalan günler ve sonraki haftalar bir sonraki sayfaya aktarılır.
/// Böylece hiçbir gün kaybolmaz ve sayfadaki boşluk boşa harcanmaz.
List<List<MenuWeekChunk>> menuWeekPlacement(List<MenuWeek> weeks) {
  final pages = <List<MenuWeekChunk>>[[]];
  var used = 0.0;
  var isFirstPage = true;

  for (final week in weeks) {
    var dayIndex = 0;

    while (dayIndex < week.days.length) {
      final budget =
          isFirstPage ? menuAvailableHeight : menuContinuationHeight;
      var remaining = budget - used;

      // Devam parçaları yalnızca gün satırlarından oluşur; hafta bandı ve
      // sütun başlığı satırı yalnızca haftanın ilk parçasında basılır.
      final overhead = menuChunkOverhead(isFirstChunk: dayIndex == 0);
      // Parça sayfanın başında değilse araya hafta boşluğu girer.
      if (pages.last.isNotEmpty) {
        remaining -= menuWeekGap;
      }

      // En az bir gün satırı sığmıyorsa bu sayfada yer yoktur.
      final firstRow = _dayRowHeight(week.days[dayIndex]);
      if (remaining < overhead + firstRow) {
        pages.add([]);
        used = 0.0;
        isFirstPage = false;
        continue;
      }

      // Sığan gün satırı sayısını bul. Parçanın **ilk** günü de sayılır,
      // aksi hâlde her parça bir gün eksik hesaplanır ve sayfaya taşar.
      var end = dayIndex;
      var height = overhead + _dayRowHeight(week.days[dayIndex]);
      while (end + 1 < week.days.length) {
        final next = height + _dayRowHeight(week.days[end + 1]);
        if (next > remaining) break;
        height = next;
        end++;
      }

      // ignore: avoid_print
      pages.last.add(
        MenuWeekChunk(
          week: week,
          from: dayIndex,
          to: end,
          isFirst: dayIndex == 0,
        ),
      );
      used += height;

      // Kalan günler varsa alt sayfaya aktarılır.
      dayIndex = end + 1;
      if (dayIndex < week.days.length) {
        pages.add([]);
        used = 0.0;
        isFirstPage = false;
      }
    }
  }

  // Sondaki boş sayfayı at.
  while (pages.length > 1 && pages.last.isEmpty) {
    pages.removeLast();
  }
  return pages;
}

/// Menü kaydı olmayan aylar için tek sayfa.
pw.Page _buildEmptyPage(ReportFonts fonts, MealMenuPrintData data) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildTitle(fonts, data),
        pw.SizedBox(height: 24),
        pw.Text(
          'Bu ay için menü kaydı bulunmuyor.',
          textAlign: pw.TextAlign.center,
          style: fonts.style(11).copyWith(color: _menuSubtitleColor),
        ),
      ],
    ),
  );
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

/// Tablodaki toplam sütun sayısı: tarih + dört öğün.
const _menuColumnCount = 5;

/// Sayfanın kenar boşluğu düşülmüş kullanılabilir genişliği.
final double _menuPageWidth = PdfPageFormat.a4.landscape.width - 40;

/// Tarih sütununun genişliği; kalan pay diğer sütunlara eşit dağılır.
///
/// `gg/aa/yyyy Pazartesi` yazacağı için önceki değerden geniştir.
const _menuDateColumnWidth = 104.0;

/// Hücre yazı punto.
///
/// Yatay A4 yüksekliği sınırlıdır; iki haftalık tabloyu sığdırmak yerine
/// haftalar satır sınırından bölünerek yerleştirilir. Okunabilirlik için
/// punto bilinçli olarak büyük tutulmuştur.
const double _menuCellFontSize = 9.0;

/// Sütun başlığı punto.
const double _menuHeadFontSize = 9.5;

const _menuCellPaddingV = 5.0;
const _menuHeadCellPaddingV = 6.0;

const _menuCellPadding = pw.EdgeInsets.symmetric(
  horizontal: 6,
  vertical: _menuCellPaddingV,
);
const _menuHeadCellPadding = pw.EdgeInsets.symmetric(
  horizontal: 6,
  vertical: _menuHeadCellPaddingV,
);

const _menuWeekBarHeight = 18.0;

/// Haftalar arası boşluk.
const menuWeekGap = 10.0;

/// Hafta kartının köşe yarıçapı; başlık bandı ve tablo birlikte yuvarlanır.
const double _menuTableRadius = 6.0;

// --- Başlık -------------------------------------------------------------------

// --- Sayfaya sığdırma ----------------------------------------------------------

/// Bir gün satırının basılma yüksekliği.
///
/// Kahvaltı yemekleri ikişerli satırlara bölündüğü için satır sayısı
/// doğrudan yemek sayısından hesaplanır; diğer öğünlerde her yemek kendi
/// satırında durur.
double _dayRowHeight(MealDay day) {
  var lines = 1;
  final breakfastLines = (day.mealsOf(MealType.breakfast).length + 1) ~/ 2;
  if (breakfastLines > lines) lines = breakfastLines;
  for (final type in MealType.values.skip(1)) {
    final count = day.mealsOf(type).length;
    if (count > lines) lines = count;
  }
  return _menuCellPaddingV * 2 + _menuCellFontSize * _menuLineHeightFactor * lines;
}

/// Metin satırının puntoya oranı; `pdf` paketinin satır yüksekliği.
const double _menuLineHeightFactor = 1.2;

/// Sütun başlığı satırının yüksekliği.
double get _menuHeadRowHeight =>
    _menuHeadCellPaddingV * 2 + _menuHeadFontSize * _menuLineHeightFactor;

/// Bir parçanın gün satırları dışında kalan sabit yüksekliği.
///
/// Hafta bandı ve sütun başlığı satırı yalnızca haftanın ilk parçasında
/// basılır; devam parçası sadece gün satırlarından oluşur ve fazladan
/// başlık yükü taşımaz.
double menuChunkOverhead({required bool isFirstChunk}) {
  return isFirstChunk ? _menuWeekBarHeight + _menuHeadRowHeight : 0.0;
}

/// Bir sayfada kullanılabilen dikey yükseklik.
///
/// Belge **yatay** A4 basılır; yükseklik `a4.landscape.height` üzerinden
/// hesaplanır. Sonraki sayfalarda başlık basılmadığı için daha çok yer kalır;
/// parçalama en dar durum olan ilk sayfayı esas alır.
double get menuAvailableHeight {
  final pageHeight = PdfPageFormat.a4.landscape.height;
  const margins = 28.0; // 14 üst + 14 alt
  const titleHeight = 56.0;
  const footerHeight = 12.0;
  return pageHeight - margins - titleHeight - footerHeight;
}

/// Başlıksız sayfalarda kullanılabilen yükseklik.
///
/// Devam sayfalarında başlık basılmaz; yalnızca alt bilgi satırı ve kenar
/// boşlukları düşülür. Bu bütçe ilk sayfadan geniş olduğu için sonraki
/// sayfalara daha çok hafta sığar.
double get menuContinuationHeight {
  final pageHeight = PdfPageFormat.a4.landscape.height;
  const margins = 28.0; // 14 üst + 14 alt
  const footerHeight = 10.0;
  return pageHeight - margins - footerHeight;
}

/// Bir parçanın basılma yüksekliği (başlık bandı dahil).
double menuChunkHeight(MenuWeekChunk chunk) {
  var height = menuChunkOverhead(isFirstChunk: chunk.isFirst);
  for (var index = chunk.from; index <= chunk.to; index++) {
    height += _dayRowHeight(chunk.week.days[index]);
  }
  return height;
}

/// Bir haftanın sayfalara bölünmüş tek parçası.
class MenuWeekChunk {
  const MenuWeekChunk({
    required this.week,
    required this.from,
    required this.to,
    required this.isFirst,
  });

  final MenuWeek week;

  /// Dahil edilen günlerin aralığı (her ikisi de).
  final int from;
  final int to;

  /// İlk parçada hafta başlığı bandı bulunur; devam parçalarında band
  /// "- devam" ibaresiyle tekrar basılır.
  final bool isFirst;
}

/// Belge başlığı.
///
/// Üç satır sırayla **eğitim öğretim yılı → okul adı → ay yemek menüsü**
/// şeklinde yazılır. Üçü de aynı punto, aynı kalınlık ve aynı renkte basılır;
/// her kelimenin ilk harfi büyüttürülür.
pw.Widget _buildTitle(ReportFonts fonts, MealMenuPrintData data) {
  const titleSize = 13.0;
  final style = fonts
      .style(titleSize, bold: true)
      .copyWith(color: _menuTitleColor);

  pw.Widget line(String text) => pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: style,
      );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      line(
        mealTitleCase(
          '${reportEducationYear(DateTime(data.year, data.month, 1))} '
          'Eğitim Öğretim Yılı',
        ),
      ),
      pw.SizedBox(height: 2),
      line(mealTitleCase(reportSchoolTitle(data.schoolName))),
      pw.SizedBox(height: 2),
      line(
        mealTitleCase(
          '${mealMonthName(data.month)} Ayı Yemek Menüsü',
        ),
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

/// Bir haftanın tek parçasını (başlık bandı + gün satırları) çizer.
///
/// Hafta sayfaya sığmıyorsa birden çok parçaya bölünür; her parça kendi
/// sayfasında ya da aynı sayfada yer alır. Devam parçaları yalnızca gün
/// satırlarından oluşur: ne hafta bandı ne de sütun başlıkları tekrarlanır.
pw.Widget _buildWeekGroup(
  ReportFonts fonts,
  MenuWeekChunk chunk, {
  required int number,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(_menuTableRadius),
      border: pw.Border.all(color: _menuLineColor, width: 0.8),
    ),
    child: pw.ClipRRect(
      horizontalRadius: _menuTableRadius,
      verticalRadius: _menuTableRadius,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (chunk.isFirst)
            _buildWeekBar(fonts, '$number. HAFTA (${chunk.week.label})'),
          _buildWeekTable(fonts, chunk),
        ],
      ),
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

pw.Widget _buildWeekTable(ReportFonts fonts, MenuWeekChunk chunk) {
  // Dış çerçeve hafta kartının kendi kenarlığıdır; tablo yalnızca iç
  // bölmeleri çizer, böylece köşeler kalınlaşmadan yuvarlak kalır.
  final border = pw.TableBorder(
    horizontalInside: const pw.BorderSide(color: _menuLineColor, width: 0.6),
    verticalInside: const pw.BorderSide(color: _menuLineColor, width: 0.6),
  );

  return pw.Table(
    border: border,
    columnWidths: menuColumnWidths(),
    children: [
      // Sütun başlıkları yalnızca ilk parçada basılır; devam sayfasındaki
      // gün satırları aynı sütunlara geldiği için tekrarı gerekmez.
      if (chunk.isFirst) _buildHeadRow(fonts),
      for (var index = chunk.from; index <= chunk.to; index++)
        _buildDayRow(fonts, chunk.week.days[index]),
    ],
  );
}

/// Tablonun sabit sütun genişlikleri.
///
/// Genişlikler `FlexColumnWidth` yerine sabit verilir: tablo bu sayede
/// sayfa ölçeğinden bağımsız olarak her zaman aynı genişliği kaplar.
Map<int, pw.TableColumnWidth> menuColumnWidths() {
  final pageWidth = _menuPageWidth;
  const dateWidth = _menuDateColumnWidth;
  // Kahvaltı iki yememi yan yana yazdığı için diğer öğünlerden biraz geniş
  // yer alır; kalan sütunlar eşit dağıtılır.
  final mealWidth = (pageWidth - dateWidth) / (_menuColumnCount - 1);
  return {
    0: const pw.FixedColumnWidth(dateWidth),
    for (var index = 1; index < _menuColumnCount; index++)
      index: pw.FixedColumnWidth(mealWidth),
  };
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
            .style(_menuHeadFontSize, bold: true)
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
  final dayPart = day.date.day.toString().padLeft(2, '0');
  final monthPart = day.date.month.toString().padLeft(2, '0');

  return pw.TableRow(
    verticalAlignment: pw.TableCellVerticalAlignment.top,
    children: [
      pw.Container(
        padding: _menuCellPadding,
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                // Tarih `gg/aa/yyyy` biçiminde; Türkçe ayraç olarak nokta
                // değil eğik çizgi kullanılır.
                text: '$dayPart/$monthPart/${day.date.year}',
                style: fonts
                    .style(_menuCellFontSize, bold: true)
                    .copyWith(color: _menuTextColor),
              ),
              pw.TextSpan(
                text: ' ${mealWeekdayName(day.date)}',
                style: fonts
                    .style(_menuCellFontSize)
                    .copyWith(color: _menuTextColor),
              ),
            ],
          ),
        ),
      ),
      for (final type in MealType.values) _buildMealCell(fonts, day, type),
    ],
  );
}

/// Bir öğünün hücresi.
///
/// Kahvaltı 7-8 çeşit yemek barındırabilir ve dar sütuna sığmadığı için
/// yemekler **ikişerli satırlara** bölünür. Kalan öğünlerde her yemek kendi
/// satırında, madde işaretiyle yazılır. Yemek olmayan öğünde tire basılır.
pw.Widget _buildMealCell(ReportFonts fonts, MealDay day, MealType type) {
  final meals = day.mealsOf(type);

  if (meals.isEmpty) {
    return pw.Container(
      padding: _menuCellPadding,
      child: pw.Text(
        '—',
        style: fonts
            .style(_menuCellFontSize)
            .copyWith(color: _menuEmptyColor),
      ),
    );
  }

  final itemStyle = fonts.style(_menuCellFontSize).copyWith(color: _menuTextColor);

  if (type == MealType.breakfast && meals.length > 1) {
    return pw.Container(
      padding: _menuCellPadding,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var row = 0; row * 2 < meals.length; row++)
            pw.Text(
              meals.skip(row * 2).take(2).map((m) => '• $m').join('    '),
              style: itemStyle,
            ),
        ],
      ),
    );
  }

  return pw.Container(
    padding: _menuCellPadding,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (final meal in meals) pw.Text('• $meal', style: itemStyle),
      ],
    ),
  );
}