import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

/// A4 kullanılabilir genişliği: 595.28 - 24 - 24 = 547.28.
///
/// Sütun genişlikleri bu değere göre seçildi; alt blok da kalan yerden
/// hesaplanarak sayfayı taşmaz.
const double _pageUsableWidth = 547;

const double _odaWidth = 34;

/// Okul numarası ayrı sütun yerine ada eklendiği için bu sütun genişledi.
///
/// Toplam: 34 (oda) + 168 (ad) + 34 (sınıf) + 160 (5 oturum) + 151 (açıklama)
const double _adWidth = 168;
const double _sinifWidth = 34;
const double _aciklamaWidth = 151;
const double _sessionWidth = 32;
const double _headerHeight = 20;

// Alt blok: özet tablo, aradaki boşluk ve imza alanı.
const double _summaryValueWidth = 120;
const double _gapWidth = 22;

/// Tablonun kapladığı toplam genişlik.
double get absenceSheetTableWidth =>
    _odaWidth +
    _adWidth +
    _sinifWidth +
    _sessionWidth * _sessionLabels.length +
    _aciklamaWidth;

/// Alt blokta imza için kalan genişlik.
///
/// Sabit değer verilmediği için özet tablo genişlerse imza alanı küçülür,
/// böylece blok sayfayı taşmaz. Regresyon: 186pt sabit verildiğinde toplam
/// 587pt'e çıkıp imza çizgisi sayfa dışına taşıyordu.
double get absenceSheetSignatureWidth =>
    _pageUsableWidth - (_odaWidth + _adWidth) - _summaryValueWidth - _gapWidth;

/// Alt bloğun toplam genişliği; sayfaya sığması gerekir.
double get absenceSheetFooterWidth =>
    (_odaWidth + _adWidth) +
    _summaryValueWidth +
    _gapWidth +
    absenceSheetSignatureWidth;

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
    this.dutyTeacherLines = const [],
  });

  final String schoolName;
  final String educationYear;
  final DateTime date;
  final String locationLabel;
  final List<AbsenceSheetEntry> entries;
  final AbsenceSheetSummary summary;

  /// İmza satırında yazılacak satırlar; her biri ayrı satırda basılır.
  ///
  /// - Kat bazında: `['1. Kat: Halil Oğuzhan Bal', '2. Kat: Sercan Sümbül']`
  /// - Tek satırda: `['Halil Oğuzhan Bal, Sercan Sümbül']`
  /// - Hiçbiri seçilmediyse boş; imza elle doldurulur.
  final List<String> dutyTeacherLines;
}

String absenceSheetEducationYear(DateTime date) => reportEducationYear(date);

String formatAbsenceSheetDate(DateTime date) => reportDate(date);

String absenceSheetDayName(DateTime date) => reportDayName(date);

String formatAbsenceSheetDateWithDay(DateTime date) {
  return '${reportDayName(date)}, ${reportDate(date)}';
}

/// Okul numarasıyla birlikte ad sütununa sığan en uzun ad uzunluğu.
///
/// Ölçüm: 8.5 punto Roboto'da en geniş harflerden oluşan bir ad 32 karakterde
/// 133pt tutuyor. " (1450)" eklenince toplam 166pt oluyor, oysa sütunun
/// kullanılabilir genişliği 163pt; bu yüzden sınır 29 karaktere çekildi.
///
/// Numara hiçbir zaman kesilmez; kırpma yalnızca ada uygulanır.
const int _absenceSheetNameLimit = 29;

/// Ad soyad sütununda görünen metin.
///
/// Okul numarası ayrı sütun yerine ada eklenir: "Zeynep Kaya (1453)".
/// Numara yoksa ya da boşsa yalnızca ad soyad yazılır.
String absenceSheetDisplayName(String name, String? schoolNumber) {
  final number = schoolNumber?.trim() ?? '';
  // Kesme boşlukta denk gelirse sondaki boşluk kalmasın.
  final cut = reportTruncate(name, _absenceSheetNameLimit).trimRight();
  if (number.isEmpty) {
    return cut;
  }
  return '$cut ($number)';
}

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
  required double height,
}) {
  final color = striped ? reportStripeFill : reportWhiteFill;
  return pw.Row(
    children: [
      reportCell(
        text: absenceSheetDisplayName(entry.studentName, entry.schoolNumber),
        fonts: fonts,
        height: height,
        width: _adWidth,
        color: color,
      ),
      reportCell(
        text: shortenAbsenceSheetVertical(entry.className),
        fonts: fonts,
        height: height,
        width: _sinifWidth,
        alignment: pw.Alignment.center,
        fontSize: 8,
        color: color,
      ),
      for (var index = 0; index < _sessionLabels.length; index++)
        reportCell(
          text: index == 0 ? entry.attendanceMark : '',
          fonts: fonts,
          height: height,
          width: _sessionWidth,
          alignment: pw.Alignment.center,
          bold: entry.attendanceMark.isNotEmpty && index == 0,
          fontSize: 9.5,
          color: color,
        ),
      reportCell(
        text: entry.note ?? '',
        fonts: fonts,
        height: height,
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
  final heights = [for (final entry in entries) _rowHeightFor(entry)];
  final groupHeight = heights.fold<double>(0, (sum, h) => sum + h);
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
                  height: heights[index],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Bir öğrencinin satır yüksekliği; açıklaması iki satıra taşarsa satır da
/// büyür.
///
/// Not serbest yazılan bir alan. Sabit yükseklikte bırakılırsa uzun not
/// hücreden taşıp alttaki öğrencinin satırına biniyordu.
double _rowHeightFor(AbsenceSheetEntry entry) {
  final note = entry.note?.trim() ?? '';
  if (note.length > _noteCharsPerLine) {
    return _absenceRowHeight * 2;
  }
  return _absenceRowHeight;
}

/// Açıklama sütununa bir satırda sığan yaklaşık karakter sayısı.
///
/// Ölçüm: 151pt sütun, 8 punto Roboto, ~3.9pt ortalama karakter genişliği.
const int _noteCharsPerLine = 37;

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

/// Sınıf sütununda yazılacak kısa etiket.
///
/// Şubesi olmayan öğrenci için yalnızca sınıf düzeyi yazılır ("9", "10").
/// Kart görünümünde kullanılan [formatClassSectionLabel] ise eksik şubede
/// "9. Sınıf (Şube eklenmedi)" gibi uzun bir açıklama döndürür; 5 karaktere
/// sığan bu sütunda anlamsız kalıyor.
String absenceSheetClassLabel(String? className, String? sectionName) {
  final classLevel = className?.trim() ?? '';
  final section = sectionName?.trim() ?? '';
  if (section.isEmpty) {
    return classLevel;
  }
  if (classLevel.isEmpty) {
    return section;
  }
  if (section.toUpperCase().startsWith('$classLevel/')) {
    return section;
  }
  return '$classLevel/$section';
}

/// Yoklama tablosundaki bir satırın yüksekliği.
///
/// Rapor satır yüksekliğinden (19pt) kısadır: çizelge altındaki nöbetçi
/// kutusuyla birlikte tek sayfaya sığsın diye.
const double _absenceRowHeight = 16;

/// Sayı tablosu: yalnızca toplam otomatik hesaplanır, diğerleri elle yazılır.
pw.Widget _summaryCell({
  required String label,
  required String value,
  required ReportFonts fonts,
}) {
  final hasValue = value.isNotEmpty;
  return pw.Container(
    width: _summaryCellWidth,
    height: _summaryCellHeight,
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: pw.BoxDecoration(
      color: reportWhiteFill,
      border: pw.Border.all(color: reportGridColor),
    ),
    // Her hücrede etiketin sonunda iki nokta var; değer yalnızca toplamda
    // otomatik gelir, diğerleri elle doldurulur.
    child: pw.Row(
      children: [
        pw.Flexible(
          child: pw.Text(
            '$label:',
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: fonts
                .style(8.4)
                .copyWith(
                  color: hasValue ? reportTextColor : PdfColors.grey700,
                ),
          ),
        ),
        if (hasValue)
          pw.Text(
            ' $value',
            maxLines: 1,
            style: fonts
                .style(10.5, bold: true)
                .copyWith(color: reportTextColor),
          ),
      ],
    ),
  );
}

/// Yoklama sayıları 2 x 2 tabloda, çizelgenin altında.
///
/// Hücreler bitişik çizilir; aralarında boşluk yoktur. Yalnızca "Katta
/// bulunan toplam" otomatik hesaplanır, diğerleri öğretmenin elle yazması
/// için boş bırakılır.
pw.Widget _buildSummaryGrid(AbsenceSheetData data, ReportFonts fonts) {
  final summary = data.summary;
  final cells = <(String, String)>[
    ('Mevcut öğrenci sayısı', ''),
    ('Evci izinli öğrenci sayısı', ''),
    ('Raporlu öğrenci sayısı', ''),
    ('Katta bulunan toplam öğrenci sayısı', '${summary.totalCount}'),
  ];

  // İkişerli satırlar; hücre kenarları çizgi hâlinde birleşir.
  final rows = <pw.Widget>[];
  for (var index = 0; index < cells.length; index += 2) {
    final row = <pw.Widget>[
      _summaryCell(
        label: cells[index].$1,
        value: cells[index].$2,
        fonts: fonts,
      ),
    ];
    if (index + 1 < cells.length) {
      row.add(
        _summaryCell(
          label: cells[index + 1].$1,
          value: cells[index + 1].$2,
          fonts: fonts,
        ),
      );
    }
    rows.add(pw.Row(children: row));
  }
  return pw.Column(children: rows);
}

/// Çizelgenin alt bölümü: sayı kutuları ve en altta ortalanmış nöbetçi
/// öğretmen kutusu.
pw.Widget _buildFooterBlock(AbsenceSheetData data, ReportFonts fonts) {
  // Nöbetçi öğretmen nöbet listesinden gelir; kullanıcı basmadan önce bölüm,
  // kat ve gösterim biçimini seçer. Hiçbiri seçilmemişse kutu elle
  // doldurulabilir.
  final dutyLines = data.dutyTeacherLines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => reportTruncate(line, _dutyLineLimit))
      .toList(growable: false);

  return pw.Column(
    children: [
      pw.SizedBox(
        width: double.infinity,
        child: _buildSummaryGrid(data, fonts),
      ),
      pw.SizedBox(height: 22),
      // Kutu çizelgenin sağ köşesinde durur.
      pw.SizedBox(
        width: double.infinity,
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _buildDutyBox(fonts, dutyLines),
        ),
      ),
    ],
  );
}

/// "NÖBETÇİ BELLETMEN" başlıklı imza kutusu.
///
/// Başlık bandı, çizelgenin üst başlığıyla aynı dolgu ve metin rengini
/// kullanır. Kutu genişliği yazılacak en uzun satıra göre ayarlanır; kısa bir
/// isimde gereksiz yere geniş kalmaz.
///
/// İçinde üstte "(imza)" yazılır ve üst boşluk alttan fazladır; imza
/// yazılacak alan böylece ismin üstünde kalır.
pw.Widget _buildDutyBox(ReportFonts fonts, List<String> dutyLines) {
  return pw.Container(
    width: _dutyBoxWidthFor(dutyLines),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: reportGridColor)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: reportHeaderFill,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            'Nöbetçi Belletmen',
            textAlign: pw.TextAlign.center,
            style: fonts
                .style(reportHeaderFontSize, bold: true)
                .copyWith(color: reportTextColor),
          ),
        ),
        pw.Container(
          height: _dutyBoxBodyHeightFor(dutyLines.length),
          // Üst boşluk alttan fazla: elle imza yazılacak alan üstte kalır.
          padding: const pw.EdgeInsets.fromLTRB(
            7,
            _dutyBoxTop,
            7,
            _dutyBoxBottom,
          ),
          color: reportWhiteFill,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                '(imza)',
                style: fonts.style(8).copyWith(color: PdfColors.grey500),
              ),
              if (dutyLines.isNotEmpty) pw.SizedBox(height: 2),
              for (final line in dutyLines)
                pw.Text(
                  line,
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: fonts
                      .style(reportHeaderFontSize, bold: true)
                      .copyWith(color: reportTextColor),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Sayı tablosunun hücre ölçüleri; iki sütun yan yana gelince sayfayı doldurur.
const double _summaryCellWidth = _pageUsableWidth / 2;
const double _summaryCellHeight = 22;

/// İmza alanına sığan tek satır uzunluğu.
const int _dutyLineLimit = 34;

/// Yazılacak en uzun satıra göre kutu genişliği.
///
/// Ölçüm: 9 punto kalın Roboto'da ortalama karakter ~4.7pt. Yan boşluk ve
/// çerçeve için 18pt eklenir; sonuç makul sınırlar arasına kırpılır.
double _dutyBoxWidthFor(List<String> dutyLines) {
  if (dutyLines.isEmpty) {
    return _dutyBoxMinWidth;
  }
  var longest = 0;
  for (final line in dutyLines) {
    if (line.length > longest) {
      longest = line.length;
    }
  }
  return (longest * _dutyCharWidth + _dutyBoxPadding).clamp(
    _dutyBoxMinWidth,
    _dutyBoxMaxWidth,
  );
}

/// Nöbetçi öğretmen kutusunun ölçüleri.
const double _dutyBoxMinWidth = 150;
const double _dutyBoxMaxWidth = 260;
const double _dutyBoxPadding = 18;
const double _dutyCharWidth = 4.7;

/// Kutunun iç boşlukları; üstte el yazımı için daha çok yer var.
const double _dutyBoxTop = 22;
const double _dutyBoxBottom = 8;

/// Satır yükseklikleri: "(imza)" etiketi ve her isim satırı.
const double _dutyImzaHeight = 10;
const double _dutyLineHeight = 12;
const double _dutyNameGap = 3;

/// Kutunun gövde yüksekliği; isim sayısına göre büyür.
///
/// Sabit yükseklik kullanılırsa 2. ve sonraki isimler sessizce kesiliyordu.
double _dutyBoxBodyHeightFor(int lineCount) =>
    _dutyBoxTop +
    _dutyImzaHeight +
    (lineCount == 0 ? 0 : _dutyNameGap + lineCount * _dutyLineHeight) +
    _dutyBoxBottom;

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
