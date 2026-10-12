import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';

/// Excel'den okunan menünün önizlemesi.
class MealImportPreview {
  const MealImportPreview({
    required this.days,
    required this.warnings,
    this.fileName = '',
  });

  final List<MealDay> days;
  final List<String> warnings;
  final String fileName;

  int get dayCount => days.length;

  int get itemCount => days.fold(0, (sum, day) => sum + day.itemCount);

  /// İçe aktarılacak aylar; sıra dosyadaki ilk görülme sırasıdır.
  List<String> get monthTitles {
    final seen = <String>[];
    for (final day in days) {
      final title = mealMonthTitle(day.date.year, day.date.month);
      if (!seen.contains(title)) {
        seen.add(title);
      }
    }
    return seen;
  }

  bool get canImport => days.isNotEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  /// İçe aktarma öncesi kullanıcıya gösterilen tek cümlelik özet.
  String get summaryLine {
    if (days.isEmpty) {
      return 'Bu dosyada menü bulunamadı.';
    }
    final months = monthTitles.join(', ');
    return '$dayCount gün, $itemCount yemek okundu ($months).';
  }
}

/// Yemek listesi Excel'ini okur.
///
/// Beklenen düzen: 1. sütun tarih (`01.10.2026 PERŞEMBE`), sonraki sütunlar
/// sırasıyla kahvaltı, öğle, akşam ve ara öğün. Başlıklar yazıma göre
/// eşleştirilir; bulunamazsa sütun sırasına göre konumlanılır.
class MealExcelImporter {
  const MealExcelImporter();

  static const _dateAliases = ['tarih', 'date', 'gun', 'gün', '菜单'];

  /// Başlık satırı sayfada en fazla bu kadar satır aşağıda aranır.
  static const _headerSearchLimit = 15;

  Future<MealImportPreview> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const MealImportPreview(days: [], warnings: ['Dosya bulunamadı.']);
    }

    final fileName = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last;
    // Excel, açık çalışma kitabı için "~$ad.xlsx" geçici kilit dosyası
    // bırakır; dosya seçme penceresinde .xlsx olarak görünür.
    if (fileName.startsWith('~\$')) {
      return const MealImportPreview(
        days: [],
        warnings: [
          'Excel kilit dosyası seçildi. Bu dosya Excel tarafından geçici '
              'olarak oluşturulur; adı "~\$" ile başlamayan asıl dosyayı '
              'seçin.',
        ],
      );
    }

    try {
      return parseBytes(await file.readAsBytes(), fileName: fileName);
    } catch (error) {
      return MealImportPreview(
        days: const [],
        fileName: fileName,
        warnings: [
          'Excel dosyası okunamadı. Dosya .xlsx biçiminde olmalı ve Excel '
              'tarafından kaydedilmiş olmalıdır. ($error)',
        ],
      );
    }
  }

  /// Ham dosya içeriğini okur. Testler dosya yazmadan bu yolu kullanır.
  MealImportPreview parseBytes(Uint8List bytes, {String fileName = ''}) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (error) {
      return MealImportPreview(
        days: const [],
        fileName: fileName,
        warnings: ['Excel dosyası okunamadı. ($error)'],
      );
    }
    if (excel.tables.isEmpty) {
      return const MealImportPreview(
        days: [],
        warnings: ['Excel dosyasında sayfa bulunamadı.'],
      );
    }

    final days = <MealDay>[];
    final warnings = <String>[];
    // Aynı tarih iki sayfada varsa ilk sayfa esas alınır; ikinci yok sayılır.
    final seenKeys = <String>{};

    for (final entry in excel.tables.entries) {
      days.addAll(_readSheet(entry.key, entry.value, seenKeys, warnings));
    }

    days.sort((a, b) => a.date.compareTo(b.date));
    return MealImportPreview(
      days: days,
      warnings: warnings,
      fileName: fileName,
    );
  }

  List<MealDay> _readSheet(
    String sheetName,
    Sheet sheet,
    Set<String> seenKeys,
    List<String> warnings,
  ) {
    final rows = [
      for (final row in sheet.rows)
        [for (final cell in row) cell?.value?.toString().trim() ?? ''],
    ];
    if (rows.isEmpty) {
      return const [];
    }

    final headerRowIndex = _findHeaderRow(rows);
    final bool hasHeader = headerRowIndex >= 0;
    final headers = hasHeader
        ? rows[headerRowIndex].map(_normalize).toList(growable: false)
        : const <String>[];
    // Başlık bulunamadıysa tüm satırlar taranır; tarih çözülemeyen satırlar
    // aşağıda elenir.
    final bodyStart = hasHeader ? headerRowIndex + 1 : 0;

    if (!hasHeader) {
      warnings.add(
        '$sheetName: "TARİH" başlığı bulunamadı; sütunlar Excel '
        'sırasına göre okundu.',
      );
    }

    int? columnFor(List<String> options) {
      if (!hasHeader) {
        return null;
      }
      for (final option in options) {
        final index = headers.indexOf(option);
        if (index >= 0) {
          return index;
        }
      }
      return null;
    }

    final dateColumn = columnFor(_dateAliases) ?? 0;

    // Öğün sütunları önce başlıktan, bulunamazsa Excel'deki konumundan
    // belirlenir. Bir sütun iki öğüne atanamaz; ikinci öğün atlanır.
    final mealColumns = <MealType, int>{};
    final used = <int>{dateColumn};
    for (final type in MealType.values) {
      final byHeader = columnFor(type.aliases);
      if (byHeader != null) {
        if (used.add(byHeader)) {
          mealColumns[type] = byHeader;
        } else {
          warnings.add(
            '$sheetName: "${type.label}" sütunu çakıştı, bu öğün okunmadı.',
          );
        }
        continue;
      }
      final positional = MealType.values.indexOf(type) + 1;
      if (used.add(positional)) {
        mealColumns[type] = positional;
        warnings.add(
          '$sheetName: "${type.label}" başlığı bulunamadı; '
          '${type.shortLabel} sütunu konumuna göre okundu.',
        );
      } else {
        warnings.add('$sheetName: "${type.label}" sütunu okunamadı, atlandı.');
      }
    }

    final days = <MealDay>[];
    var undatedRows = 0;
    var duplicateRows = 0;

    for (var index = bodyStart; index < rows.length; index++) {
      final row = rows[index];
      String cell(int? column) =>
          column != null && column >= 0 && column < row.length
          ? row[column].trim()
          : '';

      final date = parseMenuDate(cell(dateColumn));
      if (date == null) {
        // İmza bloğu, hafta sonu boş satırları ve başlık satırları burada
        // elenir: tarih sütunu boş olan satır menü günü değildir.
        if (row.any((cell) => cell.trim().isNotEmpty)) {
          undatedRows++;
        }
        continue;
      }

      final key = mealDateKey(date);
      if (!seenKeys.add(key)) {
        duplicateRows++;
        continue;
      }

      final items = <MealType, MealItems>{};
      for (final entry in mealColumns.entries) {
        final meals = splitMealItems(cell(entry.value));
        if (meals.isNotEmpty) {
          items[entry.key] = meals;
        }
      }
      days.add(MealDay(date: date, items: items));
    }

    if (days.isEmpty) {
      warnings.add('$sheetName: Bu sayfada menü bulunamadı.');
    }
    if (undatedRows > 0) {
      warnings.add(
        '$sheetName: $undatedRows satır tarih içermediği için atlandı.',
      );
    }
    if (duplicateRows > 0) {
      warnings.add(
        '$duplicateRows satır daha önce okunmuş bir tarihi gösterdiği için '
        'atlandı.',
      );
    }
    return days;
  }

  /// "TARİH" yazan satırı bulur; bulunamazsa -1 döner.
  int _findHeaderRow(List<List<String>> rows) {
    final limit = rows.length < _headerSearchLimit
        ? rows.length
        : _headerSearchLimit;
    for (var index = 0; index < limit; index++) {
      final normalized = rows[index].map(_normalize).toList(growable: false);
      if (!normalized.any(_dateAliases.contains)) {
        continue;
      }
      // Gerçek başlık, en az bir öğün başlığıyla birlikte bulunmalıdır;
      // aksi hâlde sayfa üstündeki uzun kurum adı "tarih" içerebilir.
      final hasMealHeader = MealType.values.any(
        (type) => normalized.any(type.aliases.contains),
      );
      if (hasMealHeader) {
        return index;
      }
    }
    return -1;
  }

  /// Başlık karşılaştırması için: küçük harf, Türkçe korunur, ayraçlar silinir.
  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşü]'), '');
  }
}

final _isoDate = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})');
final _dayFirstDate = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})');

/// "01.10.2026  PERŞEMBE" gibi hücreleri tarihe çevirir.
///
/// Hücrede gün adı bulunabilir, aralarda boşluk olabilir; bunlar yok sayılır.
/// Tarih ayrıştırılamazsa null döner ve o satır menü günü sayılmaz.
DateTime? parseMenuDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }

  final iso = _isoDate.firstMatch(text);
  if (iso != null) {
    return _buildDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final dayFirst = _dayFirstDate.firstMatch(text);
  if (dayFirst != null) {
    var year = int.parse(dayFirst.group(3)!);
    if (year < 100) {
      // Excel iki haneli yılı 2000'li olarak yazar.
      year += 2000;
    }
    return _buildDate(
      year,
      int.parse(dayFirst.group(2)!),
      int.parse(dayFirst.group(1)!),
    );
  }

  return null;
}

/// Geçersiz tarihleri (31.02 gibi) reddeder.
DateTime? _buildDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
