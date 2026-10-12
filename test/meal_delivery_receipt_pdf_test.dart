import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_delivery_receipt_pdf.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Yemek Malzemesi Teslim Tutanağı PDF', () {
    test('Dikey formatta 17 satırlık resmi şablon tutanağı başarıyla üretilir', () async {
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
          rowCount: 17,
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
  });
}
