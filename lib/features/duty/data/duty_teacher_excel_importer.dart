import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

class DutyTeacherImportRow {
  const DutyTeacherImportRow({
    required this.rowNumber,
    required this.teacher,
    required this.missingFields,
  });

  final int rowNumber;
  final DutyTeacher teacher;
  final List<String> missingFields;
}

class DutyTeacherImportPreview {
  const DutyTeacherImportPreview({
    required this.rows,
    required this.headerWarnings,
  });

  final List<DutyTeacherImportRow> rows;
  final List<String> headerWarnings;

  int get validCount =>
      rows.where((row) => !row.missingFields.contains('Ad Soyad')).length;
}

class DutyTeacherExcelImporter {
  const DutyTeacherExcelImporter();

  static const _templateHeaders = <String>[
    'Ad Soyad',
    'T.C. Kimlik No',
    'Telefon',
    'Okul',
    'Branş',
    'Beletmenlik Eğitimi',
    'Nöbet İsteği',
    'Nöbet Müsait Günler',
  ];

  Uint8List buildTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Öğretmenler'];
    sheet.appendRow(_templateHeaders.map(TextCellValue.new).toList());
    excel.setDefaultSheet('Öğretmenler');

    final instructions = excel['Açıklama'];
    instructions.appendRow([TextCellValue('Nöbet Öğretmeni Excel Şablonu')]);
    instructions.appendRow([TextCellValue('Beletmenlik Eğitimi: Var / Yok')]);
    instructions.appendRow([
      TextCellValue('Nöbet İsteği: Minimum / Dengeli / Maksimum'),
    ]);
    instructions.appendRow([
      TextCellValue(
        'Nöbet Müsait Günler: Pazartesi, Salı, Çarşamba, Perşembe, Cuma, Cumartesi, Pazar',
      ),
    ]);

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel şablonu oluşturulamadı.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<DutyTeacherImportPreview> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const DutyTeacherImportPreview(
        rows: [],
        headerWarnings: ['Dosya bulunamadı.'],
      );
    }

    final fileName = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last;
    // Excel, açık olan çalışma kitabı için "~$ad.xlsx" adlı geçici kilit
    // dosyası bırakır. Dosya seçme penceresinde .xlsx olarak görünür ama
    // gerçek bir çalışma kitabı değildir.
    if (fileName.startsWith('~\$')) {
      return const DutyTeacherImportPreview(
        rows: [],
        headerWarnings: [
          'Excel kilit dosyası seçildi. Bu dosya Excel tarafından geçici '
              'olarak oluşturulur. Lütfen adı "~\$" ile başlamayan asıl '
              'dosyayı seçin.',
        ],
      );
    }

    late final List<List<String>> rows;
    try {
      final decoded = Excel.decodeBytes(await file.readAsBytes());
      if (decoded.tables.isEmpty) {
        return const DutyTeacherImportPreview(
          rows: [],
          headerWarnings: ['Excel dosyasında sayfa bulunamadı.'],
        );
      }
      rows = _readRows(decoded);
    } catch (error) {
      // Gerçek neden kullanıcıya iletilir. Yalnızca "okunamadı" demek
      // dosyanın neden açılmadığını söylemez ve tekrar denemeyi
      // imkânsız kılar.
      return DutyTeacherImportPreview(
        rows: const [],
        headerWarnings: [
          'Excel dosyası okunamadı. Dosya .xlsx biçiminde olmalı ve Excel '
              'tarafından kaydedilmiş olmalıdır. ($error)',
        ],
      );
    }

    final filtered = rows
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
    if (filtered.isEmpty) {
      return const DutyTeacherImportPreview(
        rows: [],
        headerWarnings: ['Excel boş.'],
      );
    }

    final headers = filtered.first.map(_normalize).toList(growable: false);
    final warnings = <String>[];
    final nameIndex = _findColumn(headers, const [
      'adsoyad',
      'ad soyad',
      'ad',
      'isim',
      'name',
    ]);
    if (nameIndex == null) {
      return const DutyTeacherImportPreview(
        rows: [],
        headerWarnings: ['"Ad Soyad" başlığı bulunamadı.'],
      );
    }
    if (_findColumn(headers, const [
          'tckimlikno',
          'tc',
          'kimlikno',
          'tc kimlik',
        ]) ==
        null) {
      warnings.add('T.C. Kimlik No sütunu bulunamadı.');
    }

    final nationalIdIndex = _findColumn(headers, const [
      'tckimlikno',
      'tc',
      'kimlikno',
      'tc kimlik',
    ]);
    final phoneIndex = _findColumn(headers, const [
      'telefon',
      'tel',
      'phone',
      'gsm',
    ]);
    final schoolIndex = _findColumn(headers, const [
      'okul',
      'okuladi',
      'school',
    ]);
    final branchIndex = _findColumn(headers, const [
      'branş',
      'brans',
      'branş',
      'branch',
      'alan',
    ]);
    final trainingIndex = _findColumn(headers, const [
      'belletmenlikegitimi',
      'belletmenlik',
      'egitim',
      'training',
    ]);
    final preferenceIndex = _findColumn(headers, const [
      'nöbetisteği',
      'nöbetisteği',
      'istek',
      'preference',
    ]);
    final daysIndex = _findColumn(headers, const [
      'nöbetmüsaitgünler',
      'müsaitgünler',
      'müsaitgün',
      'günler',
      'availableweekdays',
    ]);

    final parsed = <DutyTeacherImportRow>[];
    for (var index = 1; index < filtered.length; index++) {
      final row = filtered[index];
      String cell(int? columnIndex) =>
          columnIndex != null && columnIndex < row.length
          ? row[columnIndex].trim()
          : '';

      final fullName = cell(nameIndex);
      final missing = <String>[];
      if (fullName.isEmpty) {
        missing.add('Ad Soyad');
      }
      final weekdays = _parseWeekdays(cell(daysIndex));
      if (weekdays.isEmpty) {
        missing.add('Nöbet Müsait Günler');
      }

      parsed.add(
        DutyTeacherImportRow(
          rowNumber: index + 1,
          missingFields: missing,
          teacher: DutyTeacher(
            fullName: formatDutyTeacherName(fullName),
            nationalId: _nullable(cell(nationalIdIndex)),
            phone: _nullable(cell(phoneIndex)),
            school: _nullable(cell(schoolIndex)),
            branch: _nullable(cell(branchIndex)),
            hasDutyTraining: _parseBool(cell(trainingIndex)),
            dutyPreference: _parsePreference(cell(preferenceIndex)),
            availableWeekdays: weekdays.isEmpty
                ? const [1, 2, 3, 4, 5]
                : weekdays,
          ),
        ),
      );
    }

    return DutyTeacherImportPreview(rows: parsed, headerWarnings: warnings);
  }

  List<List<String>> _readRows(Excel excel) {
    final sheet = excel.tables.values.first;
    return [
      for (final row in sheet.rows)
        [for (final cell in row) cell?.value?.toString().trim() ?? ''],
    ];
  }

  String _normalize(String value) {
    final lowered = value.toLowerCase().replaceAll(RegExp(r'[\s_\-.]'), '');
    return switch (lowered) {
      'belletmenlik' || 'belletmenlikegitimi' => 'belletmenlikegitimi',
      'branş' || 'brans' => 'branş',
      'nöbetisteği' || 'nöbetistegi' => 'nöbetisteği',
      'müsaitgünler' ||
      'nöbetmüsaitgünler' ||
      'nöbetmüsaitgün' => 'nöbetmüsaitgünler',
      _ => lowered,
    };
  }

  int? _findColumn(List<String> headers, List<String> options) {
    for (final option in options) {
      final index = headers.indexOf(option);
      if (index >= 0) {
        return index;
      }
    }
    return null;
  }

  List<int> _parseWeekdays(String value) {
    if (value.trim().isEmpty) {
      return const [];
    }
    final days = <int>[];
    const names = {
      'pazartesi': DateTime.monday,
      'salı': DateTime.tuesday,
      'sali': DateTime.tuesday,
      'çarşamba': DateTime.wednesday,
      'carsamba': DateTime.wednesday,
      'perşembe': DateTime.thursday,
      'persembe': DateTime.thursday,
      'cuma': DateTime.friday,
      'cumartesi': DateTime.saturday,
      'pazar': DateTime.sunday,
    };
    for (final part in value.split(RegExp(r'[,;|]'))) {
      final token = _normalize(part);
      final day =
          names[token] ??
          (int.tryParse(token.trim()) != null &&
                  int.parse(token) >= 1 &&
                  int.parse(token) <= 7
              ? int.parse(token)
              : null);
      if (day != null && !days.contains(day)) {
        days.add(day);
      }
    }
    days.sort();
    return days;
  }

  DutyPreference _parsePreference(String value) {
    final token = _normalize(value);
    if (token.contains('min')) {
      return DutyPreference.minimum;
    }
    if (token.contains('max')) {
      return DutyPreference.maximum;
    }
    return DutyPreference.balanced;
  }

  bool _parseBool(String value) {
    final token = value.toLowerCase();
    return token.contains('var') ||
        token == 'evet' ||
        token == 'true' ||
        token == '1';
  }

  String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
