import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
    test('sayfa basina iki hafta basilir', () async {
      // Ekim 2026 beş haftaya düşer: 2 + 2 + 1 -> üç sayfa.
      final bytes = await buildMealMenuPdf(sample());

      expect(menuWeeks(sample().days), hasLength(5));
      expect(_pageCount(bytes), 3);
    });

    test('iki haftalik sayfa yazdirilabilir', () async {
      final bytes = await buildMealMenuPdf(
        MealMenuPrintData(
          schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
          year: 2026,
          month: 10,
          days: [day(1), day(2), day(5)],
        ),
      );

      expect(_pageCount(bytes), 1);
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