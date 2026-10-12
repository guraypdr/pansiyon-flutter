import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

/// Belge sayfa yönü seçeneği.
enum MealDeliveryReceiptOrientation {
  /// Standart A4 Dikey format (resmi teslim tutanağı şablonu).
  portrait('Dikey (A4 Portrait)'),

  /// A4 Yatay format.
  landscape('Yatay (A4 Landscape)');

  const MealDeliveryReceiptOrientation(this.label);

  final String label;
}

/// Günlük Yemek Malzemesi Teslim Tutanağı verisi.
class MealDeliveryReceiptData {
  const MealDeliveryReceiptData({
    required this.schoolName,
    required this.date,
    this.district,
    this.day,
    this.rowCount = 17,
    this.orientation = MealDeliveryReceiptOrientation.portrait,
  });

  final String schoolName;
  final DateTime date;

  /// İlçe veya kaymakamlık adı (boş bırakılırsa okul adından türetilir).
  final String? district;

  /// Günün menüsü; yoksa öğünler boş görünür.
  final MealDay? day;

  /// Elle doldurulacak boş satır sayısı (resmi şablonda 17 satır).
  final int rowCount;

  final MealDeliveryReceiptOrientation orientation;

  String get dateFormatted =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

/// İlçe Kaymakamlığı başlığını türetir veya düzenler.
String reportDistrictAuthority(String schoolName, [String? explicitDistrict]) {
  if (explicitDistrict != null && explicitDistrict.trim().isNotEmpty) {
    final clean = explicitDistrict.trim();
    if (clean.toLowerCase().contains('kaymakam') ||
        clean.toLowerCase().contains('valilik')) {
      return mealUpperCase(clean);
    }
    return '${mealUpperCase(clean)} KAYMAKAMLIĞI';
  }
  final clean = schoolName.trim();
  if (clean.isEmpty) return 'İLÇE KAYMAKAMLIĞI';
  if (clean.toLowerCase().contains('kaymakamlığı') ||
      clean.toLowerCase().contains('valiliği')) {
    return mealUpperCase(clean);
  }
  final firstWord = clean.split(RegExp(r'\s+')).first;
  return '${mealUpperCase(firstWord)} KAYMAKAMLIĞI';
}

/// Günlük Yemek Malzemesi Teslim Tutanağını yazdırır.
Future<void> printMealDeliveryReceipt({
  required BuildContext context,
  required MealDeliveryReceiptData data,
}) async {
  final bytes = await buildMealDeliveryReceiptPdf(data);
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'Yemek Malzemesi Teslim Tutanağı - ${data.dateFormatted}',
  );
}

// Şablon stil sabitleri (Resmi tutanak formatı)
const _formBorderColor = PdfColors.black;
const _formHeaderFill = PdfColor.fromInt(0xFFECEFF1); // Açık gri dolgu
const _formWhiteFill = PdfColor.fromInt(0xFFFFFFFF);
const _formTextColor = PdfColor.fromInt(0xFF0F172A);

// Ekranda ve baskıda çizgilerin kaybolmasını önleyen sağlam çizgi kalınlıkları
const _borderTableWidth = 0.85;
const _borderCellWidth = 0.75;

/// Günlük Yemek Malzemesi Teslim Tutanağı PDF belgesini üretir.
Future<Uint8List> buildMealDeliveryReceiptPdf(
  MealDeliveryReceiptData data,
) async {
  final fonts = await ReportFonts.load();
  final document = pw.Document();

  final isLandscape =
      data.orientation == MealDeliveryReceiptOrientation.landscape;
  final pageFormat =
      isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  // Sayfa kenar boşluğu (yazıcı ve görüntüleyici sınırları için güvenli aralık)
  const pageMarginH = 18.0;
  const pageMarginV = 16.0;

  // Dış çift çerçeve ve iç boşluklar düşüldüğünde kullanılabilir içerik genişliği:
  // outer border (1.2) + gap (2.0) + inner border (0.8) + inner pad (8.0 * 2) = 24.0 pt
  final fullPageWidth =
      isLandscape ? PdfPageFormat.a4.height : PdfPageFormat.a4.width;
  final contentWidth = fullPageWidth - (2 * pageMarginH) - 24.0;

  // Öğünlerdeki en yüksek yemek sayısını hesaplayarak menü kutusunun
  // yüksekliğini tüm yemeklerin rahatça sığacağı şekilde esnetiriz.
  var maxMealsCount = 1;
  for (final type in MealType.values) {
    final count = data.day?.mealsOf(type).length ?? 0;
    if (count > maxMealsCount) {
      maxMealsCount = count;
    }
  }
  final menuBoxHeight = (maxMealsCount * 8.6 + 6.0).clamp(48.0, 78.0);

  document.addPage(
    pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.symmetric(
        horizontal: pageMarginH,
        vertical: pageMarginV,
      ),
      build: (context) {
        return pw.Container(
          // Dış Çerçeve 1: Kalın Dış Çizgi
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _formBorderColor, width: 1.2),
          ),
          padding: const pw.EdgeInsets.all(2.0),
          child: pw.Container(
            // Dış Çerçeve 2: İç Çizgi (Çift Çerçeve)
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _formBorderColor, width: 0.8),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. En Üst Başlık (T.C., Kaymakamlık, Okul Müdürlüğü)
                _buildHeader(fonts, data),
                pw.SizedBox(height: 3),

                // 2. Tutanak Başlığı (Alt ve Üst Çizgili)
                _buildTitleBanner(fonts),
                pw.SizedBox(height: 4),

                // 3. Tarih ve Üst Bilgi Tablosu (2 Satır x 4 Sütun)
                _buildMetaTable(fonts, data, contentWidth),
                pw.SizedBox(height: 4),

                // 4. Günün Menüsü (4 Öğün Yan Yana Bitişik Tablo)
                _buildMenuTable(fonts, data, contentWidth, menuBoxHeight),
                pw.SizedBox(height: 4),

                // 5. Malzeme Tablosu (Sıra, Malzeme, Miktar, Birim, Öğün, SKT, Açıklama)
                _buildMaterialsTable(fonts, data, contentWidth),
                pw.SizedBox(height: 4),

                // 6. Teslim Alma Metni ve Noktalı Boşluklar
                _buildDeliveryStatementAndNotes(fonts, data),
                pw.SizedBox(height: 4),

                // 7. İmza Tablosu (Teslim Eden, Teslim Alan, Kontrol Eden)
                _buildSignaturesTable(fonts, contentWidth),
                pw.SizedBox(height: 2),

                // 8. Alt Bilgi / Nüsha Notu
                pw.Text(
                  'Bu tutanak iki nüsha düzenlenmiş olup bir nüshası ambar dosyasında, bir nüshası mutfakta saklanır.',
                  style: fonts.style(5.8).copyWith(color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  return document.save();
}

/// 1. Üst Kurum Başlığı:
/// T.C.
/// MUSABEYLİ KAYMAKAMLIĞI
/// MUSABEYLİ ÇOK PROGRAMLI ANADOLU LİSESİ MÜDÜRLÜĞÜ
pw.Widget _buildHeader(ReportFonts fonts, MealDeliveryReceiptData data) {
  final authority = reportDistrictAuthority(data.schoolName, data.district);
  final schoolTitle = mealUpperCase(reportSchoolTitle(data.schoolName));

  final headerStyle = fonts
      .style(8.5, bold: true)
      .copyWith(color: _formTextColor);

  return pw.Column(
    children: [
      pw.Text('T.C.', textAlign: pw.TextAlign.center, style: headerStyle),
      pw.SizedBox(height: 1.0),
      pw.Text(authority, textAlign: pw.TextAlign.center, style: headerStyle),
      pw.SizedBox(height: 1.0),
      pw.Text(schoolTitle, textAlign: pw.TextAlign.center, style: headerStyle),
    ],
  );
}

/// 2. Tutanak Başlık Bandı:
/// Çizgiler arasında kalın ortalı başlık
pw.Widget _buildTitleBanner(ReportFonts fonts) {
  return pw.Column(
    children: [
      pw.Container(height: 0.8, color: _formBorderColor),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Text(
          'PANSİYON YEMEK MALZEMESİ TESLİM TUTANAĞI',
          textAlign: pw.TextAlign.center,
          style: fonts
              .style(10.5, bold: true)
              .copyWith(color: _formTextColor),
        ),
      ),
      pw.Container(height: 0.8, color: _formBorderColor),
    ],
  );
}

/// 3. Tarih ve Üst Bilgi Tablosu (2 Satır x 4 Sütun):
/// | Tarih        | 01.10.2026 Perşembe | Tutanak No                 |    |
/// | Teslim Saati |                     | Yemek Yiyecek Kişi Sayısı  |    |
pw.Widget _buildMetaTable(
  ReportFonts fonts,
  MealDeliveryReceiptData data,
  double totalWidth,
) {
  final weekday = mealWeekdayName(data.date);
  final formattedDate = '${data.dateFormatted} $weekday';

  // Sütun genişlikleri
  const label1Width = 72.0;
  final val1Width = (totalWidth * 0.32).clamp(140.0, 200.0);
  const label2Width = 118.0;
  final val2Width = totalWidth - (label1Width + val1Width + label2Width);

  const rowH = 14.0;

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _formBorderColor, width: _borderTableWidth),
    ),
    child: pw.Column(
      children: [
        // 1. Satır: Tarih & Tutanak No
        pw.Container(
          height: rowH,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Row(
            children: [
              _buildTableCell(fonts, 'Tarih', label1Width, isHeader: true),
              _buildTableCell(fonts, formattedDate, val1Width, bold: true),
              _buildTableCell(fonts, 'Tutanak No', label2Width, isHeader: true),
              _buildTableCell(fonts, '', val2Width, isLast: true),
            ],
          ),
        ),
        // 2. Satır: Teslim Saati & Yemek Yiyecek Kişi Sayısı
        pw.Container(
          height: rowH,
          child: pw.Row(
            children: [
              _buildTableCell(fonts, 'Teslim Saati', label1Width, isHeader: true),
              _buildTableCell(fonts, '', val1Width),
              _buildTableCell(
                fonts,
                'Yemek Yiyecek Kişi Sayısı',
                label2Width,
                isHeader: true,
              ),
              _buildTableCell(fonts, '', val2Width, isLast: true),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 4. Günün Menüsü (4 Öğün Yan Yana Bitişik Tablo)
pw.Widget _buildMenuTable(
  ReportFonts fonts,
  MealDeliveryReceiptData data,
  double totalWidth,
  double menuBoxHeight,
) {
  final colWidth = totalWidth / 4;

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _formBorderColor, width: _borderTableWidth),
    ),
    child: pw.Column(
      children: [
        // Başlık Satırı: KAHVALTI | ÖĞLE YEMEĞİ | AKŞAM YEMEĞİ | ARA ÖĞÜN
        pw.Container(
          height: 14.0,
          decoration: const pw.BoxDecoration(
            color: _formHeaderFill,
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Row(
            children: [
              for (var i = 0; i < MealType.values.length; i++)
                pw.Container(
                  width: colWidth,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: i < 3
                        ? const pw.Border(
                            right: pw.BorderSide(
                              color: _formBorderColor,
                              width: _borderCellWidth,
                            ),
                          )
                        : null,
                  ),
                  child: pw.Text(
                    MealType.values[i].label.toUpperCase(),
                    style: fonts
                        .style(7.5, bold: true)
                        .copyWith(color: _formTextColor),
                  ),
                ),
            ],
          ),
        ),
        // Yemek Listesi Satırı (4 Sütun)
        pw.Container(
          height: menuBoxHeight,
          decoration: const pw.BoxDecoration(color: _formWhiteFill),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < MealType.values.length; i++) ...[
                _buildSingleMealColumnBox(
                  fonts,
                  data,
                  MealType.values[i],
                  colWidth,
                  isLast: i == MealType.values.length - 1,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSingleMealColumnBox(
  ReportFonts fonts,
  MealDeliveryReceiptData data,
  MealType type,
  double colWidth, {
  bool isLast = false,
}) {
  final meals = data.day?.mealsOf(type) ?? const <String>[];

  return pw.Container(
    width: colWidth,
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: pw.BoxDecoration(
      border: isLast
          ? null
          : const pw.Border(
              right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
    ),
    child: meals.isEmpty
        ? pw.Center(
            child: pw.Text(
              '—',
              style: fonts.style(7).copyWith(color: PdfColors.grey500),
            ),
          )
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < meals.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1.0),
                  child: pw.Text(
                    '- ${meals[i]}',
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: fonts
                        .style(6.8, bold: true)
                        .copyWith(color: _formTextColor),
                  ),
                ),
            ],
          ),
  );
}

/// 5. Malzeme Tablosu:
/// Sıra | Malzeme Adı / Cinsi | ÖĞÜNLERDE KULLANILACAK MİKTAR (Kahvaltı, Öğle, Akşam, Ara Öğün) | Birim | Açıklama
pw.Widget _buildMaterialsTable(
  ReportFonts fonts,
  MealDeliveryReceiptData data,
  double totalWidth,
) {
  final isLandscape =
      data.orientation == MealDeliveryReceiptOrientation.landscape;

  // Sütun genişlikleri
  final colNoW = isLandscape ? 30.0 : 24.0;
  final colNameW = isLandscape ? 240.0 : 160.0;
  final mealSubW = isLandscape ? 58.0 : 44.0; // 4 öğün alt sütunları
  final colMealsTotalW = mealSubW * 4;
  final colUnitW = isLandscape ? 55.0 : 42.0;
  final colNotesW =
      totalWidth - (colNoW + colNameW + colMealsTotalW + colUnitW);

  const headerTotalH = 25.0;
  const rowHeight = 15.0;

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _formBorderColor, width: _borderTableWidth),
    ),
    child: pw.Column(
      children: [
        // Sütun Başlıkları (2 Seviyeli Birleşik Başlık)
        pw.Container(
          height: headerTotalH,
          decoration: const pw.BoxDecoration(
            color: _formHeaderFill,
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Row(
            children: [
              _buildMergedHeaderCell(fonts, 'Sıra', colNoW, headerTotalH),
              _buildMergedHeaderCell(fonts, 'Malzeme Adı / Cinsi', colNameW, headerTotalH),
              _buildMealsHeaderGroup(fonts, mealSubW, headerTotalH),
              _buildMergedHeaderCell(fonts, 'Birim', colUnitW, headerTotalH),
              _buildMergedHeaderCell(fonts, 'Açıklama', colNotesW, headerTotalH, isLast: true),
            ],
          ),
        ),
        // Boş Satırlar (1'den rowCount'a kadar)
        for (var rowIndex = 1; rowIndex <= data.rowCount; rowIndex++)
          pw.Container(
            height: rowHeight,
            decoration: pw.BoxDecoration(
              color: _formWhiteFill,
              border: pw.Border(
                bottom: rowIndex < data.rowCount
                    ? const pw.BorderSide(color: _formBorderColor, width: _borderCellWidth)
                    : pw.BorderSide.none,
              ),
            ),
            child: pw.Row(
              children: [
                _buildRowCell(fonts, '$rowIndex', colNoW, isNumber: true),
                _buildRowCell(fonts, '', colNameW),
                _buildRowCell(fonts, '', mealSubW), // Kahvaltı
                _buildRowCell(fonts, '', mealSubW), // Öğle
                _buildRowCell(fonts, '', mealSubW), // Akşam
                _buildRowCell(fonts, '', mealSubW), // Ara Öğün
                _buildRowCell(fonts, '', colUnitW), // Birim
                _buildRowCell(fonts, '', colNotesW, isLast: true), // Açıklama
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _buildMergedHeaderCell(
  ReportFonts fonts,
  String text,
  double width,
  double height, {
  bool isLast = false,
  bool alignLeft = false,
}) {
  return pw.Container(
    width: width,
    height: height,
    alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(horizontal: 3),
    decoration: pw.BoxDecoration(
      border: isLast
          ? null
          : const pw.Border(
              right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
    ),
    child: pw.Text(
      text,
      textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      style: fonts.style(7.0, bold: true).copyWith(color: _formTextColor),
    ),
  );
}

pw.Widget _buildMealsHeaderGroup(
  ReportFonts fonts,
  double mealSubW,
  double headerTotalH,
) {
  final groupW = mealSubW * 4;
  final topH = headerTotalH / 2;
  final btmH = headerTotalH - topH;

  return pw.Container(
    width: groupW,
    height: headerTotalH,
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
      ),
    ),
    child: pw.Column(
      children: [
        // Üst Başlık: ÖĞÜNLERDE KULLANILACAK MİKTAR
        pw.Container(
          height: topH,
          width: groupW,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Text(
            'ÖĞÜNLERDE KULLANILACAK MİKTAR',
            textAlign: pw.TextAlign.center,
            style: fonts.style(6.6, bold: true).copyWith(color: _formTextColor),
          ),
        ),
        // Alt 4 Öğün Başlığı: Kahvaltı | Öğle | Akşam | Ara Öğün
        pw.Container(
          height: btmH,
          width: groupW,
          child: pw.Row(
            children: [
              _buildSubMealColHeader(fonts, 'Kahvaltı', mealSubW),
              _buildSubMealColHeader(fonts, 'Öğle', mealSubW),
              _buildSubMealColHeader(fonts, 'Akşam', mealSubW),
              _buildSubMealColHeader(fonts, 'Ara Öğün', mealSubW, isLast: true),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSubMealColHeader(
  ReportFonts fonts,
  String text,
  double width, {
  bool isLast = false,
}) {
  return pw.Container(
    width: width,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: isLast
          ? null
          : const pw.Border(
              right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
    ),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: fonts.style(6.2, bold: true).copyWith(color: _formTextColor),
    ),
  );
}

pw.Widget _buildRowCell(
  ReportFonts fonts,
  String text,
  double width, {
  bool isNumber = false,
  bool isLast = false,
}) {
  return pw.Container(
    width: width,
    height: 15.0,
    alignment: isNumber ? pw.Alignment.center : pw.Alignment.centerLeft,
    decoration: pw.BoxDecoration(
      border: isLast
          ? null
          : const pw.Border(
              right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
    ),
    child: isNumber
        ? pw.Text(
            text,
            style: fonts
                .style(6.8, bold: true)
                .copyWith(color: PdfColors.grey700),
          )
        : null,
  );
}

/// 6. Teslim Alma Metni ve Noktalı Boşluklar
pw.Widget _buildDeliveryStatementAndNotes(
  ReportFonts fonts,
  MealDeliveryReceiptData data,
) {
  final year = data.date.year;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        'Yukarıda cinsi ve miktarı yazılı malzemeler, yukarıda belirtilen menülerde kullanılmak üzere, '
        'son kullanma tarihi ve saklama koşulları açısından kontrol edilerek ..... / ..... / $year tarihinde '
        'saat ..... \'de eksiksiz ve uygun olarak teslim alınmıştır. Eksik veya uygunsuz bulunan malzemeler aşağıda belirtilmiştir.',
        style: fonts.style(6.8).copyWith(color: _formTextColor),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '....................................................................................................................................................................................................................................',
        maxLines: 1,
        style: fonts.style(6.5).copyWith(color: PdfColors.grey500),
      ),
      pw.SizedBox(height: 1.5),
      pw.Text(
        '....................................................................................................................................................................................................................................',
        maxLines: 1,
        style: fonts.style(6.5).copyWith(color: PdfColors.grey500),
      ),
    ],
  );
}

/// 7. İmza Tablosu (3 Sütunlu Kutu):
/// TESLİM EDEN | TESLİM ALAN | KONTROL EDEN
pw.Widget _buildSignaturesTable(ReportFonts fonts, double totalWidth) {
  final colWidth = totalWidth / 3;

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _formBorderColor, width: _borderTableWidth),
    ),
    child: pw.Column(
      children: [
        // Başlık Satırı
        pw.Container(
          height: 13.0,
          decoration: const pw.BoxDecoration(
            color: _formHeaderFill,
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Row(
            children: [
              _buildSigCell(fonts, 'TESLİM EDEN', colWidth, bold: true),
              _buildSigCell(fonts, 'TESLİM ALAN', colWidth, bold: true),
              _buildSigCell(fonts, 'KONTROL EDEN', colWidth, bold: true, isLast: true),
            ],
          ),
        ),
        // Unvan Satırı
        pw.Container(
          height: 12.0,
          decoration: const pw.BoxDecoration(
            color: _formWhiteFill,
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Row(
            children: [
              _buildSigCell(fonts, 'Ambar Memuru / Nöbetçi Belletmen', colWidth),
              _buildSigCell(fonts, 'Aşçı / Mutfak Görevlisi', colWidth),
              _buildSigCell(fonts, 'Pansiyon Müdür Yardımcısı', colWidth, isLast: true),
            ],
          ),
        ),
        // İmza Alanı
        pw.Container(
          height: 28.0,
          decoration: const pw.BoxDecoration(
            color: _formWhiteFill,
            border: pw.Border(
              bottom: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
          ),
          child: pw.Row(
            children: [
              _buildSigCell(fonts, '(İmza)', colWidth, isSignPlaceholder: true),
              _buildSigCell(fonts, '(İmza)', colWidth, isSignPlaceholder: true),
              _buildSigCell(fonts, '(İmza)', colWidth, isSignPlaceholder: true, isLast: true),
            ],
          ),
        ),
        // Adı Soyadı Satırı
        pw.Container(
          height: 13.5,
          decoration: const pw.BoxDecoration(color: _formWhiteFill),
          child: pw.Row(
            children: [
              _buildSigCell(fonts, 'Adı Soyadı:', colWidth, alignLeft: true),
              _buildSigCell(fonts, 'Adı Soyadı:', colWidth, alignLeft: true),
              _buildSigCell(fonts, 'Adı Soyadı:', colWidth, alignLeft: true, isLast: true),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSigCell(
  ReportFonts fonts,
  String text,
  double width, {
  bool bold = false,
  bool alignLeft = false,
  bool isSignPlaceholder = false,
  bool isLast = false,
}) {
  return pw.Container(
    width: width,
    padding: pw.EdgeInsets.symmetric(
      horizontal: alignLeft ? 4 : 2,
      vertical: 1.5,
    ),
    alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: isLast
          ? null
          : const pw.Border(
              right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
    ),
    child: pw.Text(
      text,
      style: fonts
          .style(
            isSignPlaceholder ? 6.2 : (bold ? 7.2 : 6.4),
            bold: bold,
          )
          .copyWith(
            color: isSignPlaceholder ? PdfColors.grey600 : _formTextColor,
          ),
    ),
  );
}

pw.Widget _buildTableCell(
  ReportFonts fonts,
  String text,
  double width, {
  bool isHeader = false,
  bool bold = false,
  bool isLast = false,
}) {
  return pw.Container(
    width: width,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
    alignment: pw.Alignment.centerLeft,
    decoration: pw.BoxDecoration(
      color: isHeader ? _formHeaderFill : _formWhiteFill,
      border: isLast
          ? null
          : const pw.Border(
              right: pw.BorderSide(color: _formBorderColor, width: _borderCellWidth),
            ),
    ),
    child: pw.Text(
      text,
      style: fonts
          .style(7.2, bold: isHeader || bold)
          .copyWith(color: _formTextColor),
    ),
  );
}
