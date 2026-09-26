import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

class StudentImportRow {
  const StudentImportRow({
    required this.rowNumber,
    required this.student,
    required this.missingFields,
    this.schoolName,
  });

  final int rowNumber;
  final Student student;
  final String? schoolName;
  final List<String> missingFields;
}

class StudentImportPreview {
  const StudentImportPreview({
    required this.rows,
    required this.headerWarnings,
  });

  final List<StudentImportRow> rows;
  final List<String> headerWarnings;

  int get importableCount => rows
      .where((row) => row.missingFields.every((field) => field != 'Ad Soyad'))
      .length;
}

class StudentExcelImporter {
  const StudentExcelImporter();

  static const maxDataRows = 300;

  Uint8List createTemplateBytes() {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.tables.keys.first;
    excel.rename(defaultSheetName, 'Öğrenciler');
    final studentSheet = excel['Öğrenciler'];
    studentSheet.appendRow(_templateHeaders.map(TextCellValue.new).toList());
    excel.setDefaultSheet('Öğrenciler');

    final instructionsSheet = excel['Açıklama'];
    instructionsSheet.appendRow([TextCellValue('Öğrenci Excel şablonu')]);
    instructionsSheet.appendRow([
      TextCellValue('En fazla $maxDataRows öğrenci satırı eklenebilir.'),
    ]);
    instructionsSheet.appendRow([
      TextCellValue(
        'İlk sayfadaki başlıkları değiştirmeden verileri satırlara yazın.',
      ),
    ]);
    instructionsSheet.appendRow([
      TextCellValue(
        'T.C. Kimlik No ve aynı okuldaki okul numaraları benzersiz olmalıdır.',
      ),
    ]);

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel şablonu oluşturulamadı.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<StudentImportPreview> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException('Excel dosyası bulunamadı.');
    }

    late final Excel excel;
    try {
      final bytes = _normalizeWorkbookStyles(await file.readAsBytes());
      excel = Excel.decodeBytes(bytes);
    } catch (error) {
      throw FormatException('Excel dosyası okunamadı: $error');
    }
    if (excel.tables.isEmpty) {
      throw const FormatException('Excel dosyasında sayfa bulunamadı.');
    }

    final sheet = _findImportSheet(excel);
    final rows = sheet.rows;
    if (rows.isEmpty) {
      return const StudentImportPreview(
        rows: [],
        headerWarnings: ['Excel boş.'],
      );
    }

    final dataRowCount = rows
        .skip(1)
        .where((row) => row.any((cell) => _cellText(cell).isNotEmpty))
        .length;
    if (dataRowCount > maxDataRows) {
      throw FormatException(
        'Excel dosyası en fazla $maxDataRows öğrenci satırı içerebilir. '
        '$dataRowCount satır bulundu.',
      );
    }

    final headers = rows.first.map(_cellText).toList(growable: false);
    final normalizedHeaders = headers.map(_normalizeHeader).toList();
    final headerWarnings = <String>[];
    final fullNameIndex = _findColumn(normalizedHeaders, const [
      'adsoyad',
      'ad soyad',
      'ad_soyad',
      'fullname',
      'name',
      'öğrenciadı',
    ]);
    if (fullNameIndex == -1) {
      headerWarnings.add(
        'Ad Soyad sütunu bulunamadı. İçe aktarma için bu sütun zorunludur.',
      );
    }

    final columnIndexes = <String, int>{
      'gender': _findColumn(normalizedHeaders, const [
        'cinsiyet',
        'cinsiyetbilgisi',
        'gender',
        'sex',
      ]),
      'nationalId': _findColumn(normalizedHeaders, const [
        'tckimlik',
        'tc kimlik',
        'tckn',
        'nationalid',
      ]),
      'schoolName': _findColumn(normalizedHeaders, const [
        'okul',
        'okulu',
        'school',
      ]),
      'className': _findColumn(normalizedHeaders, const [
        'sınıf',
        'sinif',
        'class',
        'classname',
      ]),
      'sectionName': _findColumn(normalizedHeaders, const [
        'şube',
        'sube',
        'section',
      ]),
      'schoolNumber': _findColumn(normalizedHeaders, const [
        'okulno',
        'öğrencino',
        'schoolnumber',
        'studentnumber',
      ]),
      'birthDate': _findColumn(normalizedHeaders, const [
        'doğumtarihi',
        'dogumtarihi',
        'birthdate',
        'dateofbirth',
      ]),
      'address': _findColumn(normalizedHeaders, const ['adres', 'address']),
      'phone': _findColumn(normalizedHeaders, const [
        'telefon',
        'phone',
        'tel',
      ]),
      'motherName': _findColumn(normalizedHeaders, const [
        'anneadı',
        'anneadi',
        'mothername',
      ]),
      'fatherName': _findColumn(normalizedHeaders, const [
        'babaadı',
        'babaadi',
        'fathername',
      ]),
      'motherPhone': _findColumn(normalizedHeaders, const [
        'annetelefonu',
        'motherphone',
      ]),
      'fatherPhone': _findColumn(normalizedHeaders, const [
        'babatelefonu',
        'fatherphone',
      ]),
      'chronicDisease': _findColumn(normalizedHeaders, const [
        'sürekli hastalık',
        'süreklihastalık',
        'chronicdisease',
      ]),
      'allergy': _findColumn(normalizedHeaders, const ['alerji', 'allergy']),
      'medication': _findColumn(normalizedHeaders, const [
        'ilaç',
        'ilac',
        'medication',
      ]),
      'psychological': _findColumn(normalizedHeaders, const [
        'psikolojikrahatsızlık',
        'psikolojikrahatsizlik',
        'psychologicalcondition',
      ]),
      'guardianName': _findColumn(normalizedHeaders, const [
        'veliadı',
        'veliadi',
        'guardianname',
      ]),
      'guardianRelation': _findColumn(normalizedHeaders, const [
        'yakınlık',
        'yakinlik',
        'relation',
      ]),
      'guardianPhone': _findColumn(normalizedHeaders, const [
        'velitelefonu',
        'guardianphone',
      ]),
      'emergencyContactName': _findColumn(normalizedHeaders, const [
        'acilkişi',
        'acilulasılacakkişi',
        'emergencycontact',
      ]),
      'emergencyContactPhone': _findColumn(normalizedHeaders, const [
        'aciltelefon',
        'emergencyphone',
      ]),
      'livingArrangement': _findColumn(normalizedHeaders, const [
        'kiminleyaşıyor',
        'kimlerleyaşıyor',
        'livingarrangement',
      ]),
      'motherAlive': _findColumn(normalizedHeaders, const [
        'annehayattamı',
        'annehayatta',
        'motheralive',
      ]),
      'fatherAlive': _findColumn(normalizedHeaders, const [
        'babahayattamı',
        'babahayatta',
        'fatheralive',
      ]),
      'parentsLiveTogether': _findColumn(normalizedHeaders, const [
        'annebababirlikte',
        'annebababirliktemiyaşıyor',
        'parentslivetogether',
      ]),
      'boardingRegistrationDate': _findColumn(normalizedHeaders, const [
        'pansiyon kayıt tarihi',
        'pansiyonkayıttarihi',
        'boardingregistrationdate',
      ]),
      'chronicDiseaseDetails': _findColumn(normalizedHeaders, const [
        'hastalıkdetayı',
        'hastalikdetayi',
        'chronicdiseasedetails',
      ]),
      'allergyDetails': _findColumn(normalizedHeaders, const [
        'alerjidetayı',
        'alerjidetayi',
        'allergydetails',
      ]),
      'psychologicalDetails': _findColumn(normalizedHeaders, const [
        'psikolojikdetay',
        'psychologicaldetails',
      ]),
    };

    for (final entry in columnIndexes.entries) {
      if (entry.value == -1 && _importantColumns.contains(entry.key)) {
        headerWarnings.add(_columnDisplayName(entry.key));
      }
    }

    final importedRows = <StudentImportRow>[];
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every((cell) => _cellText(cell).isEmpty)) {
        continue;
      }
      final fullName = _valueAt(row, fullNameIndex);
      if (fullName.isEmpty && fullNameIndex == -1) {
        continue;
      }
      final values = <String, String>{
        for (final entry in columnIndexes.entries)
          entry.key: _valueAt(row, entry.value),
      };
      String value(String key) => values[key] ?? '';
      final missingFields = <String>[];
      if (fullName.isEmpty) {
        missingFields.add('Ad Soyad');
      }
      for (final entry in _optionalColumns.entries) {
        if ((values[entry.key] ?? '').isEmpty) {
          missingFields.add(entry.value);
        }
      }
      importedRows.add(
        StudentImportRow(
          rowNumber: rowIndex + 1,
          schoolName: _formatText(value('schoolName')),
          student: Student(
            fullName: capitalizeWords(fullName),
            gender: _parseGender(value('gender')),
            nationalId: _nullIfEmpty(value('nationalId')),
            className: _formatText(value('className')),
            sectionName: _formatText(value('sectionName')),
            schoolNumber: _nullIfEmpty(value('schoolNumber')),
            birthDate: _parseDate(value('birthDate')),
            address: _formatText(value('address')),
            phone: _formatImportedPhone(value('phone')),
            motherName: _formatText(value('motherName')),
            fatherName: _formatText(value('fatherName')),
            motherPhone: _formatImportedPhone(value('motherPhone')),
            fatherPhone: _formatImportedPhone(value('fatherPhone')),
            hasChronicDisease: _parseBool(value('chronicDisease')),
            chronicDiseaseDetails: _formatText(value('chronicDiseaseDetails')),
            hasAllergy: _parseBool(value('allergy')),
            allergyDetails: _formatText(value('allergyDetails')),
            regularMedication: _formatText(value('medication')),
            hasPsychologicalCondition: _parseBool(value('psychological')),
            psychologicalConditionDetails: _formatText(
              value('psychologicalDetails'),
            ),
            livingArrangement: _parseLivingArrangement(
              value('livingArrangement'),
            ),
            motherAlive: _parseOptionalBool(
              value('motherAlive'),
              defaultValue: true,
            ),
            fatherAlive: _parseOptionalBool(
              value('fatherAlive'),
              defaultValue: true,
            ),
            parentsLiveTogether: _parseParentLivingStatus(
              value('parentsLiveTogether'),
            ),
            guardianName: _formatText(value('guardianName')),
            guardianRelation: _formatText(value('guardianRelation')),
            guardianPhone: _formatImportedPhone(value('guardianPhone')),
            emergencyContactName: _formatText(value('emergencyContactName')),
            emergencyContactPhone: _formatImportedPhone(
              value('emergencyContactPhone'),
            ),
            boardingRegistrationDate: _parseDate(
              value('boardingRegistrationDate'),
            ),
          ),
          missingFields: missingFields,
        ),
      );
    }

    return StudentImportPreview(
      rows: importedRows,
      headerWarnings: headerWarnings,
    );
  }

  static const _templateHeaders = <String>[
    'Ad Soyad',
    'Cinsiyet',
    'T.C. Kimlik No',
    'Okul',
    'Sınıf',
    'Şube',
    'Okul No',
    'Doğum Tarihi',
    'Adres',
    'Telefon',
    'Anne Adı',
    'Baba Adı',
    'Anne Telefonu',
    'Baba Telefonu',
    'Veli Adı',
    'Yakınlık',
    'Veli Telefonu',
    'Acil Kişi',
    'Acil Telefon',
    'Kiminle Yaşıyor',
    'Anne Hayatta mı',
    'Baba Hayatta mı',
    'Anne Baba Birlikte mi',
    'Sürekli Hastalık',
    'Hastalık Detayı',
    'Alerji',
    'Alerji Detayı',
    'İlaç',
    'Psikolojik Rahatsızlık',
    'Psikolojik Detay',
    'Pansiyon Kayıt Tarihi',
  ];

  static const _importantColumns = {
    'gender',
    'nationalId',
    'schoolName',
    'className',
    'sectionName',
    'schoolNumber',
    'birthDate',
    'address',
    'phone',
  };

  static const _optionalColumns = {
    'gender': 'Cinsiyet',
    'nationalId': 'T.C. Kimlik No',
    'schoolName': 'Okul',
    'className': 'Sınıf',
    'sectionName': 'Şube',
    'schoolNumber': 'Okul No',
    'birthDate': 'Doğum Tarihi',
    'address': 'Adres',
    'phone': 'Telefon',
    'motherName': 'Anne Adı',
    'fatherName': 'Baba Adı',
    'motherPhone': 'Anne Telefonu',
    'fatherPhone': 'Baba Telefonu',
    'guardianName': 'Veli Adı',
    'guardianRelation': 'Yakınlık',
    'guardianPhone': 'Veli Telefonu',
    'emergencyContactName': 'Acil Kişi',
    'emergencyContactPhone': 'Acil Telefon',
    'livingArrangement': 'Kiminle Yaşıyor',
    'motherAlive': 'Anne Hayatta mı',
    'fatherAlive': 'Baba Hayatta mı',
    'parentsLiveTogether': 'Anne Baba Birlikte mi',
    'boardingRegistrationDate': 'Pansiyon Kayıt Tarihi',
    'chronicDiseaseDetails': 'Hastalık Detayı',
    'allergyDetails': 'Alerji Detayı',
    'medication': 'İlaç',
    'psychologicalDetails': 'Psikolojik Detay',
  };

  static List<int> _normalizeWorkbookStyles(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return bytes;
    }
    final stylesFile = archive.findFile('xl/styles.xml');
    if (stylesFile == null) {
      return bytes;
    }
    final stylesXml = utf8.decode(stylesFile.content as List<int>);
    final normalizedXml = _normalizeCustomNumberFormats(stylesXml);
    if (normalizedXml == stylesXml) {
      return bytes;
    }
    final encodedStyles = utf8.encode(normalizedXml);
    archive.addFile(
      ArchiveFile('xl/styles.xml', encodedStyles.length, encodedStyles),
    );
    return ZipEncoder().encode(archive) ?? bytes;
  }

  static String _normalizeCustomNumberFormats(String xml) {
    final numberFormatPattern = RegExp(
      r'<numFmt\b[^>]*\bnumFmtId="(\d+)"[^>]*/>',
    );
    final invalidIds = <String>{};
    for (final match in numberFormatPattern.allMatches(xml)) {
      final id = int.parse(match.group(1)!);
      if (id < 164) {
        invalidIds.add(match.group(1)!);
      }
    }

    var normalized = xml;
    for (final id in invalidIds) {
      normalized = normalized.replaceAll(
        RegExp('<numFmt\\b[^>]*\\bnumFmtId="$id"[^>]*/>'),
        '',
      );
      normalized = normalized.replaceAll('numFmtId="$id"', 'numFmtId="0"');
    }
    return normalized;
  }

  static Sheet _findImportSheet(Excel excel) {
    final preferredSheet = excel.tables['Öğrenciler'];
    if (preferredSheet != null) {
      return preferredSheet;
    }
    for (final sheet in excel.tables.values) {
      if (sheet.rows.isEmpty) {
        continue;
      }
      final hasNameHeader = sheet.rows.first
          .map(_cellText)
          .map(_normalizeHeader)
          .contains('adsoyad');
      if (hasNameHeader) {
        return sheet;
      }
    }
    return excel.tables.values.first;
  }

  static int _findColumn(List<String> headers, List<String> aliases) {
    for (var index = 0; index < headers.length; index++) {
      if (aliases.contains(headers[index])) {
        return index;
      }
    }
    return -1;
  }

  static String? _formatText(String value) {
    final formatted = capitalizeWords(value.trim());
    return formatted.isEmpty ? null : formatted;
  }

  static String? _formatImportedPhone(String value) {
    final digits = normalizePhoneNumber(value);
    return digits.isEmpty ? null : formatPhoneNumber(digits);
  }

  static String _cellText(Data? cell) {
    return cell?.value?.toString().trim() ?? '';
  }

  static String _valueAt(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return _cellText(row[index]);
  }

  static String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşü]'), '');
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static StudentGender? _parseGender(String value) {
    final normalized = value.trim().toLowerCase();
    if (const {'kız', 'kiz', 'k', 'female', 'f', '女'}.contains(normalized)) {
      return StudentGender.female;
    }
    if (const {'erkek', 'erk', 'e', 'male', 'm', '男'}.contains(normalized)) {
      return StudentGender.male;
    }
    return null;
  }

  static StudentLivingArrangement _parseLivingArrangement(String value) {
    final normalized = value.trim().toLowerCase();
    return StudentLivingArrangement.values.firstWhere(
      (item) =>
          item.value.toLowerCase() == normalized ||
          item.label.toLowerCase() == normalized ||
          (item == StudentLivingArrangement.other &&
              (normalized == 'diğer' || normalized == 'diger')),
      orElse: () => StudentLivingArrangement.withMotherFather,
    );
  }

  static ParentLivingStatus _parseParentLivingStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return ParentLivingStatus.values.firstWhere(
      (item) =>
          item.value.toLowerCase() == normalized ||
          item.label.toLowerCase() == normalized,
      orElse: () => ParentLivingStatus.together,
    );
  }

  static bool _parseOptionalBool(String value, {required bool defaultValue}) {
    return value.trim().isEmpty ? defaultValue : _parseBool(value);
  }

  static bool _parseBool(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'evet' ||
        normalized == 'var' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1';
  }

  static DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return direct;
    }
    final parts = trimmed.split(RegExp(r'[./-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year < 100 ? 2000 + year : year, month, day);
      }
    }
    return null;
  }

  static String _columnDisplayName(String key) {
    return _optionalColumns[key] ?? key;
  }
}
