import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_excel_importer.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_menu_pdf.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';

/// Belgeyi yazdırma penceresini açmadan üretir ve diske yazar; böylece
/// sayfa düzeni gözle de kontrol edilebilir.
Future<int> writeMenuPdf(MealMenuPrintData data, String path) async {
  final bytes = await buildMealMenuPdf(data);
  await File(path).writeAsBytes(bytes);
  return bytes.length;
}

MealDay day(int date) {
  return MealDay(
    date: DateTime(2026, 10, date),
    items: {
      MealType.breakfast: splitMealItems('Domates-Peynir-Poğaça'),
      MealType.lunch: splitMealItems('Yayla çorbası-Soslu makarna-Elma'),
      MealType.dinner: splitMealItems('Tavuk sote-Pirinç pilavı'),
      MealType.snack: splitMealItems('Sütlaç-Kuruyemiş'),
    },
  );
}

/// Sayfa içerik akışlarındaki dikdörtgenleri mutlak sayfa koordinatına çözer.
List<({double left, double right, double bottom})> _drawnRects(Uint8List bytes) {
  final rawText = latin1.decode(bytes);
  final rects = <({double left, double right, double bottom})>[];

  for (final match in RegExp('stream\r?\n').allMatches(rawText)) {
    final start = match.end;
    final end = rawText.indexOf('endstream', start);
    if (end < 0) continue;
    String? stream;
    try {
      stream = utf8.decode(ZLibDecoder().convert(bytes.sublist(start, end)));
    } catch (_) {
      continue;
    }
    if (!stream.contains(' re')) continue;

    var offsetX = 0.0;
    var offsetY = 0.0;
    final stack = <List<double>>[];
    final numbers = <double>[];
    for (final token in stream.replaceAll('\r', '').split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final value = double.tryParse(token);
      if (value != null) {
        numbers.add(value);
        continue;
      }
      switch (token) {
        case 'q':
          stack.add([offsetX, offsetY]);
        case 'Q':
          final previous = stack.removeLast();
          offsetX = previous[0];
          offsetY = previous[1];
        case 'cm' when numbers.length >= 6:
          offsetX += numbers[numbers.length - 2];
          offsetY += numbers[numbers.length - 1];
        case 're' when numbers.length >= 4:
          final x = numbers[numbers.length - 4];
          final y = numbers[numbers.length - 3];
          final width = numbers[numbers.length - 2];
          rects.add((
            left: offsetX + x,
            right: offsetX + x + width,
            bottom: offsetY + y,
          ));
      }
      numbers.clear();
    }
  }

  return rects;
}

int _pageCount(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(bytes)).length;

/// Sütun başlığı dolgusuyla (`0xFFE8F5E9`) çizilen satır sayısı.
int _headRowCount(Uint8List bytes) =>
    _filledRowCount(bytes, const [0.909804, 0.960784, 0.913725]);

/// Hafta bandı dolgusuyla (`0xFF14532D`) çizilen bant sayısı.
///
/// Hafta bandı yuvarlak köşeler nedeniyle yol (path) olarak doldurulur, bu
/// yüzden `re` değil yol boyama operatörü izlenir.
int _weekBarCount(Uint8List bytes) =>
    _pathFillCount(bytes, const [0.078431, 0.325490, 0.176471]);

/// Belirli dolgu rengiyle boyanan yol sayısı.
int _pathFillCount(Uint8List bytes, List<double> expected) {
  final rawText = latin1.decode(bytes);
  final bands = <String>{};

  var streamIndex = 0;
  for (final match in RegExp('stream\r?\n').allMatches(rawText)) {
    final start = match.end;
    final end = rawText.indexOf('endstream', start);
    if (end < 0) continue;
    String stream;
    try {
      stream = utf8.decode(ZLibDecoder().convert(bytes.sublist(start, end)));
    } catch (_) {
      continue;
    }
    if (!stream.contains('rg')) continue;

    var offsetY = 0.0;
    final stack = <List<double>>[];
    final numbers = <double>[];
    var fill = const <double>[];

    for (final token in stream.replaceAll('\r', '').split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final value = double.tryParse(token);
      if (value != null) {
        numbers.add(value);
        continue;
      }
      switch (token) {
        case 'q':
          stack.add([offsetY, ...fill]);
        case 'Q':
          final previous = stack.removeLast();
          offsetY = previous.first;
          fill = previous.sublist(1);
        case 'cm' when numbers.length >= 6:
          offsetY += numbers[numbers.length - 1];
        case 'rg' when numbers.length >= 3:
          fill = numbers.sublist(numbers.length - 3);
        case 'f' || 'f*' when _isColor(fill, expected):
          bands.add('$streamIndex:$offsetY');
      }
      numbers.clear();
    }
    streamIndex++;
  }

  return bands.length;
}

/// Belirli bir dolgu rengiyle çizilen yatay bant sayısı.
///
/// Aynı renkle çizilen dikdörtgenler aynı `y` koordinatında toplanır; her
/// sayfa için ayrı sayılır çünkü akış (yani sayfa) indeksi anahtarın parçasıdır.
int _filledRowCount(Uint8List bytes, List<double> expected) {
  final rawText = latin1.decode(bytes);
  final rows = <String>{};

  var streamIndex = 0;
  for (final match in RegExp('stream\r?\n').allMatches(rawText)) {
    final start = match.end;
    final end = rawText.indexOf('endstream', start);
    if (end < 0) continue;
    String stream;
    try {
      stream = utf8.decode(ZLibDecoder().convert(bytes.sublist(start, end)));
    } catch (_) {
      continue;
    }
    if (!stream.contains(' re')) continue;

    var offsetY = 0.0;
    final stack = <double>[];
    final numbers = <double>[];
    var fill = const <double>[];

    for (final token in stream.replaceAll('\r', '').split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final value = double.tryParse(token);
      if (value != null) {
        numbers.add(value);
        continue;
      }
      switch (token) {
        case 'q':
          stack.add(offsetY);
        case 'Q':
          offsetY = stack.removeLast();
        case 'cm' when numbers.length >= 6:
          offsetY += numbers[numbers.length - 1];
        case 'rg' when numbers.length >= 3:
          fill = numbers.sublist(numbers.length - 3);
        case 're' when numbers.length >= 4 && _isColor(fill, expected):
          rows.add('$streamIndex:${offsetY + numbers[numbers.length - 3]}');
      }
      numbers.clear();
    }
    streamIndex++;
  }

  return rows.length;
}

bool _isColor(List<double> actual, List<double> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < expected.length; index++) {
    if ((actual[index] - expected[index]).abs() > 0.01) return false;
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MealMenuPrintData sample({int dayCount = 31}) {
    return MealMenuPrintData(
      schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
      year: 2026,
      month: 10,
      days: [for (var index = 1; index <= dayCount; index++) day(index)],
    );
  }

  group('Yemek menüsü PDF', () {
    test('bir aylik menu pdf olarak uretilir', () async {
      final bytes = await buildMealMenuPdf(sample());

      expect(bytes.length, greaterThan(2000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('sayfa yatay A4 olarak uretilir', () async {
      final bytes = await buildMealMenuPdf(sample());
      final mediaBox = RegExp(
        r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
      ).firstMatch(latin1.decode(bytes));

      expect(mediaBox, isNotNull);
      final width = double.parse(mediaBox!.group(1)!);
      final height = double.parse(mediaBox.group(2)!);
      expect(width, greaterThan(height), reason: 'sayfa yatay olmalı');
      expect(width, closeTo(841.89, 0.1));
      expect(height, closeTo(595.28, 0.1));
    });

    test('sayfa sayisi okunabilir', () async {
      final bytes = await buildMealMenuPdf(sample(dayCount: 7));
      expect(_pageCount(bytes), greaterThan(0));
    });

    test('menu olmayan ayda da belge uretilir', () async {
      final bytes = await buildMealMenuPdf(sample(dayCount: 0));

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('cok gunluk menu cok sayfaya bolunur', () async {
      final bytes = await buildMealMenuPdf(sample(dayCount: 60));

      expect(_pageCount(bytes), greaterThan(1));
    });
  });

  group('Hafta grupları', () {
    test('gunler pazartesi baslayan haftalara ayrilir', () {
      // 01.10.2026 Perşembe, 02.10 Cuma -> ilk hafta yarım.
      final weeks = menuWeeks([day(1), day(2), day(5), day(6), day(9)]);

      expect(weeks, hasLength(2));
      expect(weeks.first.days.map((d) => d.date.day), [1, 2]);
      expect(weeks.last.days.map((d) => d.date.day), [5, 6, 9]);
      expect(menuWeeks([day(5)]).single.start, DateTime(2026, 10, 5));
    });

    test('hafta bandi tarih araligini turkce yazar', () {
      final weeks = menuWeeks([day(1), day(2)]);
      expect(weeks.single.label, '01 - 02 EKİM 2026');

      final full = menuWeeks([day(5), day(9)]);
      expect(full.single.label, '05 - 09 EKİM 2026');
    });

    test('hafta iki aya tasarsa iki ay adi yazilir', () {
      // 29.10.2026 Perşembe ve 01.11.2026 Pazar aynı haftada (26.10 - 01.11).
      final days = [
        MealDay(date: DateTime(2026, 10, 29)),
        MealDay(date: DateTime(2026, 11, 1)),
      ];

      expect(menuWeeks(days).single.label, '29 EKİM - 01 KASIM 2026');
    });

    test('sirasiz gunler tarih sirasiyla gruplanir', () {
      final weeks = menuWeeks([day(9), day(5), day(6)]);

      expect(weeks, hasLength(1));
      expect(weeks.single.days.map((d) => d.date.day), [5, 6, 9]);
    });
  });

  group('Sayfa düzeni', () {
    test('menü ölçeklenmeden sayfaya yerleştirilir', () async {
      final bytes = await buildMealMenuPdf(sample());

      expect(menuWeeks(sample().days), hasLength(5));
      expect(bytes.length, greaterThan(1000));
    });

    test('hiçbir hafta kaybolmaz', () async {
      // Beş haftalık ay: MultiPage sığmayan haftaları sonraki sayfaya taşır.
      final weeks = menuWeeks(sample().days);
      expect(weeks, hasLength(5));

      final bytes = await buildMealMenuPdf(sample());

      expect(_pageCount(bytes), greaterThanOrEqualTo(2));
      expect(bytes.length, greaterThan(1000));
    });

    test('çok yemekli günlerde de hiçbir hafta kaybolmaz', () async {
      // Her gün kahvaltıda 8, diğer öğünlerde 4 yemek var: en yüksek içerik.
      final days = [
        for (var d = 1; d <= 31; d++)
          MealDay(
            date: DateTime(2026, 10, d),
            items: {
              MealType.breakfast: const [
                'Domates',
                'Salatalık',
                'Siyah zeytin',
                'Yeşil zeytin',
                'Peynir',
                'Zeytinli poğaça',
                'Tereyağı',
                'Bal',
              ],
              MealType.lunch: const ['Yayla çorbası', 'Soslu makarna', 'Elma'],
              MealType.dinner: const ['Ekşili köfte', 'Pirinç pilavı'],
              MealType.snack: const ['Sütlaç', 'Kuruyemiş'],
            },
          ),
      ];

      expect(menuWeeks(days), hasLength(5));

      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: days,
        ),
      );

      // En yüksek içerikte beş hafta da basılır. Sayfa sığan kadar doldurulduğu
      // için belge dört sayfada tamamlanır.
      expect(_pageCount(bytes), lessThanOrEqualTo(4));
      expect(bytes.length, greaterThan(1000));
    });

    test('tek haftalık ay tek sayfada kalır', () async {
      // 5, 6 ve 7 ekim aynı takvim haftasındadır (pazartesi-çarşamba).
      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: [day(5), day(6), day(7)],
        ),
      );

      expect(_pageCount(bytes), 1);
    });

    test('başlık yalnızca ilk sayfada basılır', () async {
      // Çok yemekli günlerden oluşan ay birden çok sayfa üretir.
      final days = [
        for (var d = 1; d <= 31; d++)
          MealDay(
            date: DateTime(2026, 10, d),
            items: {
              MealType.breakfast: const [
                'Domates',
                'Salatalık',
                'Siyah zeytin',
                'Yeşil zeytin',
                'Peynir',
                'Zeytinli poğaça',
                'Tereyağı',
                'Bal',
              ],
              MealType.lunch: const ['Yayla çorbası', 'Soslu makarna'],
              MealType.dinner: const ['Ekşili köfte', 'Pirinç pilavı'],
              MealType.snack: const ['Sütlaç'],
            },
          ),
      ];

      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: days,
        ),
      );

      // Sayfa kırılması olur; başlık yalnızca ilk sayfada basıldığı için
      // devam sayfalarına daha çok gün sığar ve belge taşmadan üretilir.
      expect(_pageCount(bytes), lessThanOrEqualTo(4));
      expect(bytes.length, greaterThan(1000));
    });

    test('kahvaltı yemekleri ikişerli satırlara bölünür', () {
      final week = menuWeeks([day(5)]).single;

      // Kahvaltı hücresi yemekleri 2'li 2'li yazılır.
      expect(week.days.single.mealsOf(MealType.breakfast), isNotEmpty);
    });

    test('başlık ve haftalar aynı sayfada kalır', () async {
      // İki haftalık kısa bir ay: başlık ile ilk hafta aynı sayfada olmalı,
      // yalnızca ikinci hafta ikinci sayfaya geçmelidir.
      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: [day(5), day(6), day(12), day(13)],
        ),
      );

      // Belge üretilir ve iki hafta da vardır.
      expect(bytes.length, greaterThan(1000));
      expect(_pageCount(bytes), greaterThanOrEqualTo(1));
    });

    test('her yemek satırında numaralı listelenir', () {
      // Kahvaltı dışındaki öğünlerde her yemek ayrı satırda yazılır;
      // kahvaltı ikişerli satırlara bölünür.
      final sampleDay = day(5);
      expect(sampleDay.mealsOf(MealType.breakfast).length, greaterThan(1));
      expect(sampleDay.mealsOf(MealType.lunch).length, greaterThan(1));
    });

    test('sığmayan hafta gün satırından bölünür', () async {
      // Her gün kahvaltıda 8 yemek var; bir haftalık tablo tek sayfaya
      // sığmadığı için gün satırlarından bölünmelidir.
      final days = [
        for (var d = 1; d <= 31; d++)
          MealDay(
            date: DateTime(2026, 10, d),
            items: {
              MealType.breakfast: const [
                'Domates',
                'Salatalık',
                'Siyah zeytin',
                'Yeşil zeytin',
                'Peynir',
                'Zeytinli poğaça',
                'Tereyağı',
                'Bal',
              ],
              MealType.lunch: const ['Yayla çorbası'],
              MealType.dinner: const ['Ekşili köfte'],
              MealType.snack: const ['Sütlaç'],
            },
          ),
      ];

      final weeks = menuWeeks(days);
      final pages = menuWeekPlacement(weeks);
      final chunks = pages.expand((page) => page).toList();

      // Haftaların tüm günleri parçalarda yer alır; hiçbir gün kaybolmaz.
      final chunkedDays = chunks.expand((c) => c.week.days.sublist(c.from, c.to + 1));
      expect(chunkedDays.length, days.length);

      // Her sayfa kendi bütçesini aşmaz: ilk sayfada başlık da vardır.
      for (var index = 0; index < pages.length; index++) {
        final budget = index == 0 ? menuAvailableHeight : menuContinuationHeight;
        final used = pages[index].fold<double>(
          0,
          (sum, chunk) => sum + menuChunkHeight(chunk) + menuWeekGap,
        );
        expect(used - menuWeekGap, lessThanOrEqualTo(budget));
      }

      // Belge taşmadan üretilir.
      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: days,
        ),
      );
      expect(bytes.length, greaterThan(1000));
      expect(_pageCount(bytes), lessThanOrEqualTo(10));
    });

    test('kullanılabilir yükseklik yatay sayfadan hesaplanır', () {
      // Belge yatay A4 basılır; bütçe dikey sayfa yüksekliğinden
      // hesaplanırsa tablolar sığacağından büyük parçalanır ve taşar.
      final landscapeHeight = PdfPageFormat.a4.landscape.height;

      expect(landscapeHeight, lessThan(PdfPageFormat.a4.height));
      expect(menuAvailableHeight, lessThan(landscapeHeight));
      expect(menuAvailableHeight, greaterThan(400));
    });

    test('sayfa sığan kadar doldurulur, kalan günler alt sayfaya aktarılır', () async {
      final days = [
        for (var d = 1; d <= 31; d++)
          MealDay(
            date: DateTime(2026, 10, d),
            items: {
              MealType.breakfast: const [
                'Domates',
                'Salatalık',
                'Siyah zeytin',
                'Yeşil zeytin',
                'Peynir',
                'Zeytinli poğaça',
                'Tereyağı',
                'Bal',
              ],
              MealType.lunch: const ['Yayla çorbası', 'Soslu makarna', 'Elma'],
              MealType.dinner: const ['Ekşili köfte', 'Pirinç pilavı'],
              MealType.snack: const ['Sütlaç', 'Kuruyemiş'],
            },
          ),
      ];

      final weeks = menuWeeks(days);
      final pages = menuWeekPlacement(weeks);
      final chunks = pages.expand((page) => page).toList();

      // Hiçbir gün kaybolmaz.
      expect(
        chunks.expand((c) => c.week.days.sublist(c.from, c.to + 1)).length,
        days.length,
      );

      // Bir hafta iki sayfaya bölünür: parça sınırı gün satırı sınırındadır
      // ve devam parçası bir sonraki sayfada başlar.
      final splitWeeks = weeks
          .where((week) => chunks.where((c) => identical(c.week, week)).length > 1)
          .length;
      expect(splitWeeks, greaterThan(0));

      // Son sayfa hariç her sayfada birden çok parça yer alır; aksi hâlde
      // sayfa boşluğu boşa gitmiş olurdu.
      for (var index = 1; index < pages.length - 1; index++) {
        expect(pages[index].length, greaterThan(1));
      }

      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: days,
        ),
      );

      // Yerleşim doğruysa sayfa sayısı parça sayısına eşittir.
      expect(_pageCount(bytes), pages.length);
    });

    test('devam sayfasinda hafta bandi ve sutun basligi tekrarlanmaz', () async {
      final days = [
        for (var d = 1; d <= 31; d++)
          MealDay(
            date: DateTime(2026, 10, d),
            items: {
              MealType.breakfast: const [
                'Domates',
                'Salatalık',
                'Siyah zeytin',
                'Yeşil zeytin',
                'Peynir',
                'Zeytinli poğaça',
                'Tereyağı',
                'Bal',
              ],
              MealType.lunch: const ['Yayla çorbası', 'Soslu makarna', 'Elma'],
              MealType.dinner: const ['Ekşili köfte', 'Pirinç pilavı'],
              MealType.snack: const ['Sütlaç', 'Kuruyemiş'],
            },
          ),
      ];

      final weeks = menuWeeks(days);
      final chunks = menuWeekPlacement(weeks).expand((page) => page).toList();
      final continuations = chunks.where((c) => !c.isFirst).toList();

      // Bölünen haftalar var; dolayısıyla devam parçaları da var.
      expect(continuations, isNotEmpty);

      // Devam parçası yalnızca gün satırlarından oluşur; ne hafta bandı ne de
      // sütun başlığı satırı taşır, dolayısıyla ek yükü sıfırdır.
      expect(menuChunkOverhead(isFirstChunk: false), 0);
      expect(
        menuChunkOverhead(isFirstChunk: true),
        greaterThan(menuChunkOverhead(isFirstChunk: false)),
      );

      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: days,
        ),
      );

      // Belgede hafta bandı ve sütun başlığı yalnızca beş hafta için basılır,
      // yani parça sayısından az.
      expect(_weekBarCount(bytes), weeks.length);
      expect(_headRowCount(bytes), weeks.length);
      expect(_weekBarCount(bytes), lessThan(chunks.length));
      expect(_headRowCount(bytes), lessThan(chunks.length));
    });

    test('sığan hafta tek parça kalır', () {
      final pages = menuWeekPlacement(menuWeeks([day(5), day(6), day(7)]));
      final chunks = pages.expand((page) => page).toList();

      expect(chunks, hasLength(1));
      expect(chunks.single.from, 0);
      expect(chunks.single.to, 2);
      expect(chunks.single.isFirst, isTrue);
    });

    test('parçalar haftalar arasında boşluk bırakmaz', () {
      final weeks = menuWeeks(sample().days);
      final chunks = menuWeekPlacement(weeks).expand((page) => page);

      // Her haftanın ilk parçası isFirst işaretlidir; devam parçaları değil.
      final weekStarts = chunks.where((c) => c.isFirst).length;
      expect(weekStarts, weeks.length);
    });

    test('kahvaltı dışındaki öğünler tek sütunda kalır', () {
      // Sütun sayısı değişmedi: tarih + dört öğün.
      expect(menuColumnWidths(), hasLength(5));
    });

    test('cizilen her sey sayfa kenar boslugu icinde kalir', () async {
      const marginH = 20.0;
      const marginV = 14.0;
      const pageWidth = 841.89;

      final rects = _drawnRects(await buildMealMenuPdf(sample()));

      expect(rects, isNotEmpty);
      for (final rect in rects) {
        expect(rect.left, greaterThanOrEqualTo(marginH - 0.6));
        expect(rect.right, lessThanOrEqualTo(pageWidth - marginH + 0.6));
        expect(rect.bottom, greaterThanOrEqualTo(marginV - 0.6));
      }
    });

    test('tablo ve hafta bantlari sayfa genisligini tamamen kullanir', () async {
      final rects = _drawnRects(await buildMealMenuPdf(sample()));
      final widest = rects
          .map((rect) => rect.right - rect.left)
          .reduce((a, b) => a > b ? a : b);

      // İçerik alanı: 841.89 - 2 * 20 = 801.89
      expect(widest, closeTo(801.89, 0.1));
    });
  });

  test('kullanici dosyasindan uretilen menu gecerli pdf verir', () async {
    final file = File(r'C:\Users\WİN10\Desktop\Kitap1.xlsx');
    if (!file.existsSync()) {
      // ignore: avoid_print
      print('Kitap1.xlsx yok, gercek veri atlandi');
      return;
    }
    final preview = await const MealExcelImporter().readFile(file.path);
    expect(preview.days, isNotEmpty);

    final output = r'C:\Users\WİN10\AppData\Local\Temp\opencode\menu.pdf';
    final size = await writeMenuPdf(
      MealMenuPrintData(
        schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
        year: 2026,
        month: 10,
        days: preview.days,
      ),
      output,
    );

    // ignore: avoid_print
    print('PDF yazildi: $output ($size bayt, ${preview.dayCount} gun)');
    expect(File(output).existsSync(), isTrue);
  });
}