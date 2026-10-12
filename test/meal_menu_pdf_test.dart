import 'dart:io';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MealMenuPrintData sample({int dayCount = 22}) {
    return MealMenuPrintData(
      schoolName: 'Musabeyli Anadolu İmam Hatip Lisesi',
      year: 2026,
      month: 10,
      days: [
        for (var day = 1; day <= dayCount; day++)
          MealDay(
            date: DateTime(2026, 10, day),
            items: {
              MealType.breakfast: splitMealItems(
                'Domates-salatalık-peynir-tahin helva',
              ),
              MealType.lunch: splitMealItems(
                'Yayla çorbası-\nSoslu makarna-\nElma',
              ),
              MealType.dinner: splitMealItems('Ekşili köfte-\nPirinç pilavı'),
              MealType.snack: splitMealItems('Sütlaç-\nKuruyemiş'),
            },
          ),
      ],
    );
  }

  test('bir aylik menu pdf olarak uretilir', () async {
    final bytes = await buildMealMenuPdf(sample());

    expect(bytes.length, greaterThan(2000));
    // Geçerli bir PDF imzası.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('sayfa sayisi okunabilir', () async {
    final bytes = await buildMealMenuPdf(sample());
    final text = String.fromCharCodes(bytes);
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;

    expect(pages, greaterThan(0));
  });

  test('menu olmayan ayda da belge uretilir', () async {
    final bytes = await buildMealMenuPdf(sample(dayCount: 0));

    expect(bytes.length, greaterThan(1000));
  });

  test('cok gunluk menu cok sayfaya bolunur', () async {
    final bytes = await buildMealMenuPdf(sample(dayCount: 60));
    final text = String.fromCharCodes(bytes);
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;

    expect(pages, greaterThan(1));
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
