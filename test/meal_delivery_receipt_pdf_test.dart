import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pansiyon_yonetim/features/meals/data/meal_delivery_receipt_pdf.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';

/// PDF'in çizilen dikdörtgenlerini mutlak sayfa koordinatlarına çözer.
///
/// Kenar çizgileri `pdf` paketinde kutunun tam kenarında çizilir; bu yüzden
/// bir hücrenin sağ kenarı tablo çerçevesinden içeride kalırsa çıktıda
/// kenarda ince bir beyaz boşluk görünür. Test bu boşluğu yakalar.
List<({double left, double right})> _drawnHorizontalSpans(Uint8List bytes) {
  final rawText = latin1.decode(bytes);
  String? content;
  for (final match in RegExp('stream\r?\n').allMatches(rawText)) {
    final start = match.end;
    final end = rawText.indexOf('endstream', start);
    if (end < 0) continue;
    try {
      final decoded = utf8.decode(
        ZLibDecoder().convert(bytes.sublist(start, end)),
      );
      if (decoded.contains(' re S')) {
        content = decoded;
        break;
      }
    } catch (_) {
      continue;
    }
  }
  expect(content, isNotNull, reason: 'Sayfa içerik akışı bulunamadı.');

  var offsetX = 0.0;
  var offsetY = 0.0;
  final stack = <List<double>>[];
  final numbers = <double>[];
  final spans = <({double left, double right})>[];

  for (final token in content!.replaceAll('\r', '').split(RegExp(r'\s+'))) {
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
        final width = numbers[numbers.length - 2];
        spans.add((left: offsetX + x, right: offsetX + x + width));
    }
    numbers.clear();
  }

  return spans;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tutanak numarası biçimi', () {
    test('yıl-ay-sıra olarak yazılır', () {
      final data = MealDeliveryReceiptData(
        schoolName: 'Okul',
        date: DateTime(2026, 10, 2),
        receiptNumber: 2,
      );

      expect(data.receiptNumberLabel, '2026-10-2');
    });

    test('tek haneli ay sıfır doldurularak yazılır', () {
      final data = MealDeliveryReceiptData(
        schoolName: 'Okul',
        date: DateTime(2026, 9, 1),
        receiptNumber: 1,
      );

      expect(data.receiptNumberLabel, '2026-09-1');
    });

    test('numara yoksa etiket de boştur', () {
      final data = MealDeliveryReceiptData(
        schoolName: 'Okul',
        date: DateTime(2026, 10, 2),
      );

      expect(data.receiptNumberLabel, isNull);
    });
  });

  group('Yemek Malzemesi Teslim Tutanağı PDF', () {
    test('Dikey formatta 25 satırlık resmi şablon tutanağı başarıyla üretilir', () async {
      final date = DateTime(2026, 10, 1);
      final day = MealDay(
        date: date,
        items: {
          MealType.breakfast: [
            'Domates',
            'Salatalık',
            'Siyah zeytin',
            'Yeşil zeytin',
            'Peynir',
            'Zeytinli poğaça',
            'Tereyağı',
            'Bal',
          ],
          MealType.lunch: ['Yayla çorbası', 'Soslu makarna', 'Elma', 'Kıymalı pide'],
          MealType.dinner: ['Ekşili köfte', 'Pirinç pilavı', 'Karışık turşu', 'Armut'],
          MealType.snack: ['Sütlaç', 'Kuruyemiş'],
        },
      );

      final bytes = await buildMealDeliveryReceiptPdf(
        MealDeliveryReceiptData(
          schoolName: 'Musabeyli Çok Programlı Anadolu Lisesi',
          date: date,
          day: day,
          rowCount: 25,
          orientation: MealDeliveryReceiptOrientation.portrait,
        ),
      );

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('Menü olmayan gün için de boş tutanak PDF üretilebilir', () async {
      final date = DateTime(2026, 10, 15);

      final bytes = await buildMealDeliveryReceiptPdf(
        MealDeliveryReceiptData(
          schoolName: 'Cumhuriyet Fen Lisesi',
          date: date,
          day: null,
          rowCount: 15,
          orientation: MealDeliveryReceiptOrientation.portrait,
        ),
      );

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('Yatay formatta tutanak başarıyla üretilir', () async {
      final date = DateTime(2026, 10, 20);

      final bytes = await buildMealDeliveryReceiptPdf(
        MealDeliveryReceiptData(
          schoolName: 'Atatürk Mesleki ve Teknik Anadolu Lisesi',
          date: date,
          day: null,
          rowCount: 12,
          orientation: MealDeliveryReceiptOrientation.landscape,
        ),
      );

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('Kayitli imza bilgileri tutanak uretilebilir', () async {
      final date = DateTime(2026, 10, 1);

      final bytes = await buildMealDeliveryReceiptPdf(
        MealDeliveryReceiptData(
          schoolName: 'Musabeyli Çok Programlı Anadolu Lisesi',
          date: date,
          day: null,
          signatures: const MealReceiptSignatures(
            delivererJobTitle: 'Ambar Memuru',
            delivererName: 'Ahmet Yılmaz',
            receiverJobTitle: 'Aşçı',
            receiverName: 'Ayşe Demir',
          ),
        ),
      );

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });
  });

  group('Çerçeve hizası', () {
    // Sayfa kenar boşluğu (18) + dış çerçeve ile iç çerçeve arasındaki boşluk
    // (3) + iç çerçevenin iç boşluğu (8). Tablolar bu sınırın sağına kadar
    // uzanmalı; hücre dolguları da aynı hizada bitmeli. Bir puan eksik kalan
    // hücre, kenarda ince beyaz bir boşluk bırakır.
    const frameInset = 18.0 + 3.0;
    const contentLeft = frameInset + 8.0;

    Future<({List<({double left, double right})> spans, double contentRight})>
    contentOf(MealDeliveryReceiptOrientation orientation) async {
      final pageWidth = orientation == MealDeliveryReceiptOrientation.landscape
          ? PdfPageFormat.a4.height
          : PdfPageFormat.a4.width;
      final contentRight = pageWidth - contentLeft;
      final spans = _drawnHorizontalSpans(
        await buildMealDeliveryReceiptPdf(
          MealDeliveryReceiptData(
            schoolName: 'Musabeyli Çok Programlı Anadolu Lisesi',
            date: DateTime(2026, 10, 1),
            orientation: orientation,
          ),
        ),
      ).where((span) => span.left > frameInset + 0.5).toList();
      return (spans: spans, contentRight: contentRight);
    }

    for (final orientation in MealDeliveryReceiptOrientation.values) {
      test('${orientation.label}: hücreler sağ kenarda boşluk bırakmaz', () async {
        final result = await contentOf(orientation);
        final contentRight = result.contentRight;

        final nearMisses = result.spans
            .where(
              (span) =>
                  span.right > contentRight - 4 &&
                  span.right < contentRight - 0.05,
            )
            .map((span) => span.right.toStringAsFixed(2))
            .toList();

        expect(
          nearMisses,
          isEmpty,
          reason: 'Çerçeve kenarı $contentRight iken $nearMisses '
              'noktasında duran hücreler var.',
        );
      });

      test('${orientation.label}: içerik çerçevenin dışına taşmaz', () async {
        final result = await contentOf(orientation);

        for (final span in result.spans) {
          expect(span.left, greaterThanOrEqualTo(contentLeft - 0.5));
          expect(span.right, lessThanOrEqualTo(result.contentRight + 0.6));
        }
      });
    }
  });
}
