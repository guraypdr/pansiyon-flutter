import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_excel_importer.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_delivery_receipt_pdf.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kullanıcının Excel'iyle aynı düzende çalışma kitabı üretir.
Uint8List buildMenuWorkbook({
  String sheetName = 'EKİM',
  List<List<String>>? rows,
}) {
  final excel = Excel.createExcel();
  final sheet = excel[sheetName];
  final data =
      rows ??
      [
        ['MÜDÜRLÜĞÜ PANSİYON YEMEK MENÜSÜ', '', '', '', ''],
        ['TARİH', 'SABAH', 'ÖĞLE', 'AKŞAM', 'ARA ÖĞÜN'],
        [
          '01.10.2026  PERŞEMBE',
          'Domates-salatalık-peynir',
          'Yayla çorbası-\nSoslu makarna-\nElma',
          'Ekşili köfte',
          'Sütlaç',
        ],
        ['02.10.2026  CUMA', 'Domates-peynir', 'Etli kuru fasulye', '', ''],
        ['', '', '', '', ''],
        [
          '05.10.2026  PAZARTESİ',
          '',
          'Soslu makarna',
          'Kıymalı taze fasulye',
          'Süt-\n kuruyemiş',
        ],
        ['', '', '', '', ''],
        ['', 'Mehmet POLAT', '', 'Nihal Merve KARADENİZ', ''],
        ['', 'Aşçı', '', 'Aşçı', ''],
      ];
  for (final row in data) {
    sheet.appendRow([for (final value in row) TextCellValue(value)]);
  }
  excel.setDefaultSheet(sheetName);
  final bytes = excel.save();
  if (bytes == null) {
    throw StateError('Çalışma kitabı oluşturulamadı.');
  }
  return Uint8List.fromList(bytes);
}

void main() {
  group('Yemek ayrıştırma', () {
    test('tire ile ayrilmis yemekleri tek tek listeler', () {
      expect(splitMealItems('Domates-salatalık-s.zeytin-peynir'), [
        'Domates',
        'Salatalık',
        'S.zeytin',
        'Peynir',
      ]);
    });

    test('satir sonu ile ayrilmis yemekleri tek tek listeler', () {
      expect(splitMealItems('Pirinç pilavı-\nYoğurt-\nArmut'), [
        'Pirinç pilavı',
        'Yoğurt',
        'Armut',
      ]);
    });

    test('tire ve satir sonu birlikte kullanilabilir', () {
      expect(
        splitMealItems('Tavuk sote-\nFırında patates-\nPirinç pilavı-\nCacık'),
        ['Tavuk sote', 'Fırında patates', 'Pirinç pilavı', 'Cacık'],
      );
    });

    test('ayirac olmayan duz satir tek yemektir', () {
      expect(splitMealItems('Cacık\nMandalina'), ['Cacık', 'Mandalina']);
    });

    test('bos hucre ve ayirac artigi yok sayilir', () {
      expect(splitMealItems('   '), isEmpty);
      expect(splitMealItems('Süt-\n-'), ['Süt']);
    });

    test('yemek sonundaki nokta ve bosluk temizlenir', () {
      expect(splitMealItems('Elma.'), ['Elma']);
      expect(splitMealItems('  Kuruyemiş '), ['Kuruyemiş']);
    });

    test('ilk harf buyutulur, yazim stili korunur', () {
      // Her kelimeyi buyutmek "Peynirli Tepsi Boregine" gibi yazim
      // uretiyordu; yemek adlari cumle basi buyuk kalir.
      expect(splitMealItems('peynirli tepsi böreği'), [
        'Peynirli tepsi böreği',
      ]);
      expect(splitMealItems('pirinç pilavı'), ['Pirinç pilavı']);
    });

    test('turkce i harfi dogru buyutulur', () {
      expect(splitMealItems('irmik helvası'), ['İrmik helvası']);
      expect(splitMealItems('ıslak köfte'), ['Islak köfte']);
    });
  });

test('malzeme teslim tutanağı pdfi olusturulur', () async {
    final bytes = await buildMealDeliveryReceiptPdf(
      MealDeliveryReceiptData(
        schoolName: 'Mehmet Akif Ersoy',
        date: DateTime(2026, 10, 1),
        day: MealDay(
          date: DateTime(2026, 10, 1),
          items: {
            MealType.breakfast: ['Domates', 'Peynir'],
            MealType.lunch: ['Yayla çorbası'],
            MealType.dinner: ['Ekşili köfte'],
            MealType.snack: ['Sütlaç'],
          },
        ),
      ),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  group('Tarih ayrıştırma', () {
    test('gun adli hucre okunur', () {
      expect(parseMenuDate('01.10.2026  PERŞEMBE'), DateTime(2026, 10, 1));
    });

    test('bosluk sayisi degismez', () {
      expect(parseMenuDate(' 06.10.2026        SALI'), DateTime(2026, 10, 6));
    });

    test('kesme ve tire ayiraclari kabul edilir', () {
      expect(parseMenuDate('01/10/2026'), DateTime(2026, 10, 1));
      expect(parseMenuDate('01-10-2026'), DateTime(2026, 10, 1));
    });

    test('tarih olmayan hucre reddedilir', () {
      expect(parseMenuDate(''), isNull);
      expect(parseMenuDate('Mehmet POLAT'), isNull);
      expect(parseMenuDate('Aşçı'), isNull);
      expect(parseMenuDate('Okul Müdürü'), isNull);
    });

    test('olmayan tarih reddedilir', () {
      expect(parseMenuDate('31.02.2026'), isNull);
      expect(parseMenuDate('01.13.2026'), isNull);
    });
  });

  group('Excel içe aktarma', () {
    test('menuler gun gun okunur', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());

      expect(preview.dayCount, 3);
      expect(preview.days.first.date, DateTime(2026, 10, 1));
      expect(preview.monthTitles, ['Ekim 2026']);
    });

    test('dort ogun ayri ayri okunur', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());
      final first = preview.days.first;

      expect(first.mealsOf(MealType.breakfast), [
        'Domates',
        'Salatalık',
        'Peynir',
      ]);
      expect(first.mealsOf(MealType.lunch), [
        'Yayla çorbası',
        'Soslu makarna',
        'Elma',
      ]);
      expect(first.mealsOf(MealType.dinner), ['Ekşili köfte']);
      expect(first.mealsOf(MealType.snack), ['Sütlaç']);
    });

    test('bos ogun bos liste olur', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());
      // Cuma akşam yemeği ve ara öğün Excel'de boş.
      final friday = preview.days[1];

      expect(friday.date, DateTime(2026, 10, 2));
      expect(friday.mealsOf(MealType.dinner), isEmpty);
      expect(friday.mealsOf(MealType.snack), isEmpty);
    });

    test('imza blogu ve bos satirlar menule girmez', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());

      // "Mehmet POLAT / Aşçı" satırları tarih içermez.
      expect(preview.dayCount, 3);
      expect(
        preview.days.any(
          (day) => day.allItems.any(
            (item) => item.contains('POLAT') || item.contains('KARADENİZ'),
          ),
        ),
        isFalse,
      );
    });

    test('tarihsiz satir oldugu icin uyari verilir', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());

      expect(preview.hasWarnings, isTrue);
      expect(
        preview.warnings.any((w) => w.contains('tarih içermediği')),
        isTrue,
      );
    });

    test('baslik satiri ve kurum adi menule karismaz', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());

      expect(
        preview.days.any(
          (day) => day.allItems.any(
            (item) => item.contains('MENÜSÜ') || item.contains('MÜDÜRLÜĞÜ'),
          ),
        ),
        isFalse,
      );
    });

    test('gunler tarih sirasiyla siralanir', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());
      final dates = preview.days.map((day) => mealDateKey(day.date)).toList();

      expect(dates, ['2026-10-01', '2026-10-02', '2026-10-05']);
    });

    test('basliklar Turkce buyuk kucuk harf duyarsiz eslesir', () {
      final preview = const MealExcelImporter().parseBytes(
        buildMenuWorkbook(
          rows: [
            ['tarih', 'sabah', 'ogle', 'aksam', 'araogun'],
            ['01.10.2026', 'Domates', 'Çorba', 'Köfte', 'Süt'],
          ],
        ),
      );

      expect(preview.dayCount, 1);
      expect(preview.days.first.mealsOf(MealType.breakfast), ['Domates']);
    });

    test('menu olmayan dosya reddedilir', () {
      final preview = const MealExcelImporter().parseBytes(
        buildMenuWorkbook(
          rows: [
            ['Ad Soyad', 'Sınıf'],
            ['Ali Yılmaz', '9/B'],
          ],
        ),
      );

      expect(preview.canImport, isFalse);
      expect(preview.warnings, isNotEmpty);
    });
  });

  group('Depo', () {
    late AppDatabase database;
    late SqliteMealRepository repository;

    setUp(() {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      repository = SqliteMealRepository(database);
    });

    tearDown(() => database.close());

    MealDay sample(int day, {String breakfast = 'Domates'}) {
      return MealDay(
        date: DateTime(2026, 10, day),
        items: {
          MealType.breakfast: [breakfast],
          MealType.lunch: ['Çorba', 'Pilav'],
        },
      );
    }

    test('gun kaydedilip okunur', () async {
      await repository.importDays([sample(1)]);

      final days = await repository.getMonth(2026, 10);
      expect(days, hasLength(1));
      expect(days.first.mealsOf(MealType.breakfast), ['Domates']);
      expect(days.first.mealsOf(MealType.lunch), ['Çorba', 'Pilav']);
      expect(days.first.id, isNotNull);
    });

    test('menu sirası korunur', () async {
      await repository.importDays([
        MealDay(
          date: DateTime(2026, 10, 1),
          items: {
            MealType.dinner: ['Tavuk sote', 'Fırında patates', 'Ayran'],
          },
        ),
      ]);

      final days = await repository.getMonth(2026, 10);
      expect(days.first.mealsOf(MealType.dinner), [
        'Tavuk sote',
        'Fırında patates',
        'Ayran',
      ]);
    });

    test('ay listesi yalnizca secilen ayi dondurur', () async {
      await repository.importDays([
        sample(1),
        sample(2),
        MealDay(date: DateTime(2026, 11, 3)),
      ]);

      expect(await repository.getMonth(2026, 10), hasLength(2));
      expect(await repository.getMonth(2026, 11), hasLength(1));
      expect(await repository.getMonth(2026, 12), isEmpty);
    });

    test('aylar gun sayisiyla birlikte listelenir', () async {
      await repository.importDays([
        sample(1),
        sample(2),
        MealDay(date: DateTime(2026, 11, 3)),
      ]);

      final months = await repository.getMonths();
      expect(months, hasLength(2));
      expect(months.first.year, 2026);
      expect(months.first.month, 11);
      expect(months.last.dayCount, 2);
      expect(months.last.title, 'Ekim 2026');
    });

    test('ay sonu gunleri kapsanir', () async {
      // Aralık 31 gün olduğu için ay sonu anahtarı taşmamalı.
      await repository.importDays([
        MealDay(date: DateTime(2026, 12, 31)),
        MealDay(date: DateTime(2027, 1, 1)),
      ]);

      expect(await repository.getMonth(2026, 12), hasLength(1));
      expect(await repository.getMonth(2027, 1), hasLength(1));
    });

    test('ayni tarihe tekrar aktarim ustune yazar', () async {
      await repository.importDays([sample(1)]);
      final result = await repository.importDays([
        sample(1, breakfast: 'Peynir'),
      ]);

      expect(result.updated, 1);
      expect(result.added, 0);
      final days = await repository.getMonth(2026, 10);
      expect(days, hasLength(1));
      // Eski yemek kalırsa gün içinde tekrarlar oluşurdu.
      expect(days.first.mealsOf(MealType.breakfast), ['Peynir']);
    });

    test('gun silinince yemekleri de silinir', () async {
      await repository.importDays([sample(1)]);
      await repository.deleteDay(DateTime(2026, 10, 1));

      expect(await repository.getMonth(2026, 10), isEmpty);
      final raw = await database.database;
      final items = await raw.query('meal_items');
      expect(items, isEmpty);
    });

    test('ay temizlenir', () async {
      await repository.importDays([
        sample(1),
        sample(2),
        MealDay(date: DateTime(2026, 11, 3)),
      ]);

      await repository.clearMonth(2026, 10);

      expect(await repository.getMonth(2026, 10), isEmpty);
      expect(await repository.getMonth(2026, 11), hasLength(1));
    });

    test('excelden gelen menu kalici olarak saklanir', () async {
      // Uctan uca: oku -> yaz -> oku
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());
      final result = await repository.importDays(preview.days);

      expect(result.added, 3);
      expect(result.updated, 0);

      final days = await repository.getMonth(2026, 10);
      expect(days, hasLength(3));
      expect(days.first.mealsOf(MealType.lunch), [
        'Yayla çorbası',
        'Soslu makarna',
        'Elma',
      ]);
      expect(days.last.mealsOf(MealType.breakfast), isEmpty);
    });

    test('tutanak imza bilgileri kaydedilip okunur', () async {
      const signatures = MealReceiptSignatures(
        delivererJobTitle: 'Ambar Memuru',
        delivererName: 'Ahmet Yılmaz',
        receiverJobTitle: 'Aşçı',
        receiverName: 'Ayşe Demir',
      );

      await repository.saveReceiptSignatures(signatures);

      final stored = await repository.loadReceiptSignatures();
      expect(stored.delivererJobTitle, 'Ambar Memuru');
      expect(stored.delivererName, 'Ahmet Yılmaz');
      expect(stored.receiverJobTitle, 'Aşçı');
      expect(stored.receiverName, 'Ayşe Demir');
    });

    test('imza bilgileri her kelimenin bas harfi buyutulerek saklanir', () async {
      await repository.saveReceiptSignatures(
        const MealReceiptSignatures(
          delivererJobTitle: '  ambar   memuru  ',
          delivererName: 'ahmet yılmaz',
          receiverName: 'AYŞE demir',
        ),
      );

      final stored = await repository.loadReceiptSignatures();
      expect(stored.delivererJobTitle, 'Ambar Memuru');
      expect(stored.delivererName, 'Ahmet Yılmaz');
      // Tamamen büyük yazılan "AYŞE" de büyük harfli kalır.
      expect(stored.receiverName, 'AYŞE Demir');
    });

    test('imza bilgileri kaydedilince tek satir kalir', () async {
      await repository.saveReceiptSignatures(
        const MealReceiptSignatures(delivererName: 'Ahmet Yılmaz'),
      );
      await repository.saveReceiptSignatures(
        const MealReceiptSignatures(
          delivererName: 'Ali Veli',
          receiverName: 'Ayşe Demir',
        ),
      );

      final raw = await database.database;
      final rows = await raw.query('meal_receipt_signatures');
      expect(rows, hasLength(1));
      final stored = await repository.loadReceiptSignatures();
      expect(stored.delivererName, 'Ali Veli');
      expect(stored.receiverName, 'Ayşe Demir');
    });

    test('hic kayit yokken imza bilgileri bos doner', () async {
      final stored = await repository.loadReceiptSignatures();

      expect(stored.isEmpty, isTrue);
      expect(stored.delivererName, isEmpty);
      // Kayıt yokken formda örnek unvan görünür.
      expect(
        stored.displayJobTitle(MealSignatureRole.deliverer),
        'Ambar Memuru / Nöbetçi Belletmen',
      );
    });
  });

  group('Model', () {
    test('ogun tipleri veritabani degerinden cozulur', () {
      expect(MealType.fromValue('breakfast'), MealType.breakfast);
      expect(MealType.fromValue('araogun'), MealType.snack);
      expect(MealType.fromValue('bilinmeyen'), isNull);
    });

    test('bos ogun ve oge sayisi', () {
      final day = MealDay(
        date: DateTime(2026, 10, 1),
        items: {
          MealType.breakfast: ['Domates', 'Peynir'],
          MealType.lunch: ['Çorba'],
        },
      );

      expect(day.itemCount, 3);
      expect(day.hasAnyMeal, isTrue);
      expect(day.mealsOf(MealType.dinner), isEmpty);
      expect(MealDay(date: DateTime(2026, 10, 1)).hasAnyMeal, isFalse);
    });

    test('tarih anahtarlari donusumlu', () {
      final date = DateTime(2026, 10, 1);

      expect(mealDateKey(date), '2026-10-01');
      expect(parseMealDateKey('2026-10-01'), date);
      expect(parseMealDateKey('2026-13-01'), isNull);
      expect(parseMealDateKey('bozuk'), isNull);
    });

    test('ay ve gun etiketleri Turkce', () {
      expect(mealMonthTitle(2026, 10), 'Ekim 2026');
      expect(mealWeekdayName(DateTime(2026, 10, 1)), 'Perşembe');
    });

    test('ayilmis gun bulunur', () {
      final days = [
        MealDay(date: DateTime(2026, 10, 1)),
        MealDay(date: DateTime(2026, 10, 15)),
      ];

      expect(
        findMealDay(days, DateTime(2026, 10, 15))?.date,
        DateTime(2026, 10, 15),
      );
      expect(findMealDay(days, DateTime(2026, 10, 16)), isNull);
    });

    test('her kelimenin bas harfi Turkce olarak buyutulur', () {
      expect(mealTitleCase('ahmet yılmaz'), 'Ahmet Yılmaz');
      expect(mealTitleCase('  ambar   memuru  '), 'Ambar Memuru');
      expect(mealTitleCase('ibrahim'), 'İbrahim');
      expect(mealTitleCase('AYŞE demir'), 'AYŞE Demir');
      expect(mealTitleCase('   '), '');
    });
  });

  group('Önizleme özeti', () {
    test('gun ve yemek sayisi yazilir', () {
      final preview = const MealExcelImporter().parseBytes(buildMenuWorkbook());

      expect(preview.summaryLine, contains('3 gün'));
      expect(preview.summaryLine, contains('Ekim 2026'));
    });

    test('menu yoksa okunabilir mesaj verir', () {
      final preview = const MealExcelImporter().parseBytes(
        Uint8List.fromList(const <int>[0, 1, 2, 3]),
      );

      expect(preview.canImport, isFalse);
      expect(preview.summaryLine, isNotEmpty);
    });
  });

  // utf8 çözümleyicisinin erişilebilir kaldığını doğrular.
  test('dart:convert kullanılabilir', () {
    expect(utf8.decode(const <int>[0x41]), 'A');
  });
}
