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

  /// Şablonun veri sayfası.
  static const studentsSheetName = 'Öğrenciler';

  /// Şablonun kullanım kuralları ve örnek satır içeren sayfası.
  ///
  /// Veri sayfası değildir; içe aktarımda yok sayılır.
  static const instructionsSheetName = 'Açıklama';

  Uint8List createTemplateBytes() {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.tables.keys.first;
    excel.rename(defaultSheetName, 'Öğrenciler');
    final studentSheet = excel['Öğrenciler'];
    studentSheet.appendRow(_templateHeaders.map(TextCellValue.new).toList());
    excel.setDefaultSheet('Öğrenciler');

    final instructionsSheet = excel['Açıklama'];
    _buildInstructionsSheet(instructionsSheet);
    for (var column = 0; column < _templateHeaders.length; column++) {
      instructionsSheet.setColumnWidth(column, 22);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel şablonu oluşturulamadı.');
    }
    return Uint8List.fromList(bytes);
  }

  /// `Açıklama` sayfasını kurar: kullanım kuralları ve tam bir örnek satır.
  ///
  /// Örnek satır bilinçli olarak bu sayfaya yazılır. `Öğrenciler`
  /// sayfasına örnek satır eklenseydi içe aktarım onu gerçek bir öğrenci
  /// sanıp kaydederdi.
  void _buildInstructionsSheet(Sheet sheet) {
    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final headingStyle = CellStyle(bold: true, fontSize: 12);
    final headerStyle = CellStyle(bold: true);

    sheet.appendRow([TextCellValue('Öğrenci Excel şablonu')]);
    sheet.appendRow([
      TextCellValue('En fazla $maxDataRows öğrenci satırı eklenebilir.'),
    ]);
    sheet.appendRow([
      TextCellValue(
        'Verileri "Öğrenciler" sayfasına, başlık satırının altına yazın.',
      ),
    ]);
    sheet.appendRow([
      TextCellValue(
        'T.C. Kimlik No ve aynı okuldaki okul numaraları benzersiz olmalıdır.',
      ),
    ]);
    sheet.appendRow([
      TextCellValue(
        'Acil iletişim bilgisi birinci veliden otomatik alınır; ayrı '
        'sütun yoktur.',
      ),
    ]);

    sheet.appendRow([null]);
    final headingRow = sheet.maxRows;
    sheet.appendRow([TextCellValue('Örnek satır')]);

    // Başlık satırı şablonun birebir kendisidir; sütun eşleşmesi bozulursa
    // örnek de güncellenmez, ama başlık kaymaz.
    sheet.appendRow([
      for (final header in _templateHeaders) TextCellValue(header),
    ]);
    final exampleRow = sheet.maxRows;
    sheet.appendRow([
      for (final header in _templateHeaders)
        TextCellValue(_exampleRowValues[header] ?? ''),
    ]);

    sheet.appendRow([null]);
    final rulesRow = sheet.maxRows;
    sheet.appendRow([TextCellValue('Yazım kuralları')]);
    for (final rule in _writingRules) {
      sheet.appendRow([TextCellValue(rule)]);
    }

    // Stiller appendRow sonrası atanır; hücre değerleri değişmez.
    _styleRow(sheet, 0, 1, titleStyle);
    _styleRow(sheet, headingRow, 1, headingStyle);
    _styleRow(sheet, rulesRow, 1, headingStyle);
    _styleRow(sheet, exampleRow - 1, _templateHeaders.length, headerStyle);
  }

  /// Satırın ilk [count] hücresine stil uygular; hücre yoksa atlar.
  static void _styleRow(Sheet sheet, int rowIndex, int count, CellStyle style) {
    final row = sheet.rows[rowIndex];
    if (rowIndex >= row.length) {
      return;
    }
    for (var column = 0; column < count && column < row.length; column++) {
      final cell = row[column];
      if (cell != null) {
        cell.cellStyle = style;
      }
    }
  }

  /// Örnek satır değerleri; anahtarlar [_templateHeaders] ile eşleşir.
  ///
  /// Eksik anahtarlar boş hücre olur; yeni sütun eklendiğinde örnek
  /// sessizce eksik kalır, bu yüzden test her başlığı doldurulmuş
  /// buluyor.
  static const _exampleRowValues = <String, String>{
    'Ad Soyad': 'Ali Yılmaz',
    'Cinsiyet': 'Kız',
    'T.C. Kimlik No': '12345678901',
    'Okul': 'Atatürk Lisesi',
    'Sınıf': '9',
    'Şube': 'A',
    'Okul No': '1453',
    'Doğum Tarihi': '12.05.2010',
    'Adres': 'Atatürk Mah. 1. Sok. No: 5',
    'Telefon': '0532 123 45 67',
    'Veli Adı': 'Ayşe Yılmaz',
    'Yakınlık': 'Anne',
    'Veli Telefonu': '0532 111 22 33',
    'Veli Adresi': 'Atatürk Mah. 1. Sok. No: 5',
    'Diğer Veli Adı': 'Mehmet Yılmaz',
    'Diğer Veli Yakınlığı': 'Baba',
    'Diğer Veli Telefonu': '0532 555 66 77',
    'Diğer Veli Adresi': 'Cumhuriyet Mah. 2. Cad. No: 3',
    'Sürekli Hastalık': 'Evet',
    'Sürekli Hastalık Detayı': 'Astım',
    'Alerji': 'Evet',
    'Alerji Detayı': 'Fındık alerjisi',
    'Düzenli İlaç Kullanımı': 'Evet',
    'İlaç Detayı': 'Ventolin, sabah akşam',
    'Kan Grubu': '0 Rh+',
    'Psikolojik Rahatsızlık': 'Hayır',
    'Psikolojik Detayı': '',
    'Pansiyon Kayıt Tarihi': '01.09.2026',
  };

  static const _writingRules = <String>[
    'Zorunlu alan: Ad Soyad. Diğer alanlar boş bırakılabilir.',
    'Cinsiyet: Kız veya Erkek.',
    'Doğum Tarihi ve Pansiyon Kayıt Tarihi: 12.05.2010 biçiminde.',
    'Evet/Hayır sütunları yalnızca Evet, Hayır, Var, Yok, 1 veya 0 '
        'yazabilir; boş bırakılırsa Hayır kabul edilir.',
    'Sürekli Hastalık, Alerji ve Psikolojik Rahatsızlık için anahtar '
        'sütununa Evet yazıp yanındaki Detay sütununu doldurun.',
    'Düzenli İlaç Kullanımı Hayır ise İlaç Detayı yok sayılır.',
    'Telefon numaraları boşluklu da yazılabilir; 0532 123 45 67 biçimi '
        'kullanılır.',
    'Sağlık detayı yazılmayacaksa o sütun boş bırakılır.',
  ];

  Future<StudentImportPreview> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException('Excel dosyası bulunamadı.');
    }

    final fileName = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last;
    // Excel, açık olan bir çalışma kitabı için "~$ad.xlsx" adlı bir
    // kilit dosyası bırakır. Bu dosya gerçek bir çalışma kitabı değil
    // (yaklaşık 165 bayt) ama dosya seçme penceresinde .xlsx olarak
    // listelenir. Kullanıcı yanlışlıkla onu seçerse anlaşılır bir
    // uyarı göstermek, genel "okunamadı" mesajından çok daha iyidir.
    if (fileName.startsWith('~\$')) {
      throw const FormatException(
        'Excel kilit dosyası seçildi. Bu dosya Excel tarafından geçici '
        'olarak oluşturulur. Lütfen adı "~\$" ile başlamayan asıl '
        'dosyayı seçin.',
      );
    }

    late final Excel excel;
    try {
      final bytes = _normalizeWorkbookStyles(await file.readAsBytes());
      excel = Excel.decodeBytes(bytes);
    } catch (error) {
      // Gerçek neden kullanıcıya iletilir: "dosya bozuk" demek, dosyanın
      // neden okunamadığını söylemez ve tekrar denemeyi imkânsız kılar.
      if (error is FormatException) {
        rethrow;
      }
      throw FormatException(
        'Excel dosyası okunamadı. Dosya .xlsx biçiminde olmalı ve Excel '
            'tarafından kaydedilmiş olmalıdır.',
        '$error',
      );
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

    final columnIndexes = _resolveColumnIndexes(
      normalizedHeaders,
      _columnAliases,
    );

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
      final guardianName = _formatText(value('guardianName'));
      final guardianPhone = _formatImportedPhone(value('guardianPhone'));
      final guardian2Name = _formatText(value('guardian2Name'));
      final guardian2Phone = _formatImportedPhone(value('guardian2Phone'));
      importedRows.add(
        StudentImportRow(
          rowNumber: rowIndex + 1,
          schoolName: _formatText(value('schoolName')),
          student: Student(
            fullName: capitalizeWords(fullName),
            gender: _parseGender(value('gender')),
            nationalId: _formatImportedNationalId(value('nationalId')),
            className: _formatText(value('className')),
            sectionName: _formatText(value('sectionName')),
            schoolNumber: _nullIfEmpty(value('schoolNumber')),
            birthDate: _parseDate(value('birthDate')),
            address: _formatText(value('address')),
            phone: _formatImportedPhone(value('phone')),
            hasChronicDisease: _parseBool(value('chronicDisease')),
            chronicDiseaseDetails: _formatText(value('chronicDiseaseDetails')),
            hasAllergy: _parseBool(value('allergy')),
            allergyDetails: _formatText(value('allergyDetails')),
            regularMedication: _medicationDetail(
              rawFlag: value('hasMedication'),
              rawDetail: value('medication'),
            ),
            bloodType: _formatText(value('bloodType')),
            hasPsychologicalCondition: _parseBool(value('psychological')),
            psychologicalConditionDetails: _formatText(
              value('psychologicalDetails'),
            ),
            guardianName: guardianName,
            guardianRelation: _formatText(value('guardianRelation')),
            guardianPhone: guardianPhone,
            guardianAddress: _formatText(value('guardianAddress')),
            guardian2Name: guardian2Name,
            guardian2Relation: _formatText(value('guardian2Relation')),
            guardian2Phone: guardian2Phone,
            guardian2Address: _formatText(value('guardian2Address')),
            // Formda acil iletişim alanı yok; birincil veliden türetilir.
            // Excel şablonu da aynı düzeni izler.
            emergencyContactName: guardianName ?? guardian2Name,
            emergencyContactPhone: guardianPhone ?? guardian2Phone,
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

  /// Sütun anahtarları için tanınan başlıklar.
  ///
  /// Değerler okunabilirlik için yazılmış hâliyle tutulur; eşleştirme
  /// sırasında [_normalizeHeader] ile aynı biçime indirgenir. Böylece
  /// "T.C. Kimlik No", "T.C.KimlikNo" ve "tc kimlik no" gibi yazımların
  /// hepsi tanınır.
  static const _columnAliases = <String, List<String>>{
    'gender': ['Cinsiyet', 'Cinsiyet Bilgisi', 'Gender', 'Sex'],
    'nationalId': [
      'T.C. Kimlik No',
      'T.C. Kimlik Numarası',
      'TC Kimlik No',
      'TCKN',
      'TC Kimlik',
      'Kimlik No',
      'Kimlik Numarası',
      'National ID',
    ],
    'schoolName': ['Okul', 'Okulu', 'Okul Adı', 'School'],
    'className': ['Sınıf', 'Sinif', 'Class', 'Class Name'],
    'sectionName': ['Şube', 'Sube', 'Section'],
    'schoolNumber': [
      'Okul No',
      'Öğrenci No',
      'School Number',
      'Student Number',
    ],
    'birthDate': [
      'Doğum Tarihi',
      'Dogum Tarihi',
      'Birth Date',
      'Date Of Birth',
    ],
    'address': ['Adres', 'Address'],
    'phone': [
      'Telefon',
      'Phone',
      'Tel',
      'Cep',
      'Cep Telefon',
      'Cep No',
      'Öğrenci Telefon',
      'Öğrenci Telefonu',
    ],
    'chronicDisease': ['Sürekli Hastalık', 'Chronic Disease'],
    'chronicDiseaseDetails': [
      'Sürekli Hastalık Detayı',
      'Hastalık Detayı',
      'Chronic Disease Details',
    ],
    'allergy': ['Alerji', 'Allergy'],
    'allergyDetails': ['Alerji Detayı', 'Allergy Details'],
    // Modelde yalnızca `regularMedication` metni vardır; anahtar sütunu
    // "Hayır" yazıldığında detayı temizler.
    //
    // Kısa "İlaç Kullanımı" takma adı bilinçli olarak yok: önek eşleştirme
    // çift yönlü çalıştığı için eski dosyalardaki "İlaç" başlığı bu takma
    // adın öneği sayılıp anahtar sütunu sanılır ve ilaç bilgisi silinirdi.
    'hasMedication': [
      'Düzenli İlaç Kullanımı',
      'Düzenli İlaç',
      'Regular Medication',
    ],
    'medication': [
      'İlaç Detayı',
      'İlaç Bilgisi',
      'İlaç',
      'Ilac Detayi',
      'Medication',
    ],
    'bloodType': ['Kan Grubu', 'Blood Type', 'Kan'],
    'psychological': [
      'Psikolojik Rahatsızlık',
      'Psikolojik Rahatsizlik',
      'Psychological Condition',
    ],
    'psychologicalDetails': [
      'Psikolojik Detayı',
      'Psikolojik Detay',
      'Psychological Details',
    ],
    'guardianName': ['Veli Adı', 'Veli Adi', 'Guardian Name'],
    'guardianRelation': ['Yakınlık', 'Yakinlik', 'Relation'],
    'guardianPhone': ['Veli Telefonu', 'Veli Cep', 'Guardian Phone'],
    'guardianAddress': ['Veli Adresi', 'Guardian Address'],
    'guardian2Name': ['Diğer Veli Adı', 'Diger Veli Adi', 'Other Guardian'],
    'guardian2Relation': [
      'Diğer Veli Yakınlığı',
      'Diger Veli Yakinligi',
      'Other Guardian Relation',
    ],
    'guardian2Phone': ['Diğer Veli Telefonu', 'Other Guardian Phone'],
    'guardian2Address': ['Diğer Veli Adresi', 'Other Guardian Address'],
    'boardingRegistrationDate': [
      'Pansiyon Kayıt Tarihi',
      'Boarding Registration Date',
    ],
  };

  static const _minPrefixMatchLength = 4;

  static const _phoneDigitCount = 11;
  static const _nationalIdLength = 11;

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
    'Veli Adı',
    'Yakınlık',
    'Veli Telefonu',
    'Veli Adresi',
    'Diğer Veli Adı',
    'Diğer Veli Yakınlığı',
    'Diğer Veli Telefonu',
    'Diğer Veli Adresi',
    'Sürekli Hastalık',
    'Sürekli Hastalık Detayı',
    'Alerji',
    'Alerji Detayı',
    'Düzenli İlaç Kullanımı',
    'İlaç Detayı',
    'Kan Grubu',
    'Psikolojik Rahatsızlık',
    'Psikolojik Detayı',
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
    'guardianName': 'Veli Adı',
    'guardianRelation': 'Yakınlık',
    'guardianPhone': 'Veli Telefonu',
    'guardianAddress': 'Veli Adresi',
    'guardian2Name': 'Diğer Veli Adı',
    'guardian2Relation': 'Diğer Veli Yakınlığı',
    'guardian2Phone': 'Diğer Veli Telefonu',
    'guardian2Address': 'Diğer Veli Adresi',
    'boardingRegistrationDate': 'Pansiyon Kayıt Tarihi',
    'chronicDiseaseDetails': 'Sürekli Hastalık Detayı',
    'allergyDetails': 'Alerji Detayı',
    'medication': 'İlaç Detayı',
    'psychologicalDetails': 'Psikolojik Detayı',
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
    final preferredSheet = excel.tables[studentsSheetName];
    if (preferredSheet != null) {
      return preferredSheet;
    }
    for (final sheet in excel.tables.values) {
      // Açıklama sayfası örnek satır içerdiği için "Ad Soyad" başlığı
      // taşır; veri sayfası sanılmaması bilinçli olarak dışlanır.
      if (sheet.sheetName == instructionsSheetName) {
        continue;
      }
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

  /// Başlıkları sütun anahtarlarına eşler.
  ///
  /// Önce birebir eşleşen başlıklar atanır; ancak bundan sonra kalan
  /// anahtarlar için önek eşleşmesi denenir. Sıralama önemlidir: "Okul" ve
  /// "Okul No" başlıkları aynı anda varsa, "Okul No" önce kendi takma adıyla
  /// eşleşmeli, "Okul" başlığı ise kalan "Okul" ile eşleşmelidir.
  static Map<String, int> _resolveColumnIndexes(
    List<String> normalizedHeaders,
    Map<String, List<String>> aliasesByKey,
  ) {
    final normalizedAliases = <String, List<String>>{
      for (final entry in aliasesByKey.entries)
        entry.key: entry.value.map(_normalizeHeader).toList(growable: false),
    };

    final resolved = <String, int>{
      for (final entry in normalizedAliases.entries) entry.key: -1,
    };

    for (final entry in normalizedAliases.entries) {
      final index = _findColumn(normalizedHeaders, entry.value);
      if (index != -1) {
        resolved[entry.key] = index;
      }
    }
    for (final entry in normalizedAliases.entries) {
      if (resolved[entry.key] != -1) {
        continue;
      }
      final index = _findColumnByPrefix(normalizedHeaders, entry.value);
      if (index != -1) {
        resolved[entry.key] = index;
      }
    }
    return resolved;
  }

  static int _findColumn(List<String> headers, List<String> aliases) {
    for (var index = 0; index < headers.length; index++) {
      if (aliases.contains(headers[index])) {
        return index;
      }
    }
    return -1;
  }

  /// Başlık, takma adın bir uzantısı olduğu durumda eşleşir.
  ///
  /// Örneğin "T.C. Kimlik No" başlığı "tckimlik" takma adıyla eşleşir. Yanlış
  /// eşleşmeyi önlemek için en az [_minPrefixMatchLength] karakter uzunluğunda
  /// benzerlik aranır.
  static int _findColumnByPrefix(List<String> headers, List<String> aliases) {
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      for (final alias in aliases) {
        if (alias.length < _minPrefixMatchLength ||
            header.length < _minPrefixMatchLength) {
          continue;
        }
        if (header.startsWith(alias) || alias.startsWith(header)) {
          return index;
        }
      }
    }
    return -1;
  }

  static String? _formatText(String value) {
    final formatted = capitalizeWords(value.trim());
    return formatted.isEmpty ? null : formatted;
  }

  /// İçe aktarılan telefon numarasını 11 haneli biçime getirir.
  ///
  /// Excel'de numaralar farklı yazılmış olabilir. Eksik baş sıfır, ülke kodu
  /// ve ayraçlar telafi edilir:
  ///
  /// | Excel'deki değer | Sonuç |
  /// | --- | --- |
  /// | `0555 444 33 22` | `0555 444 33 22` |
  /// | `05554443322` | `0555 444 33 22` |
  /// | `5554443322` | `0555 444 33 22` |
  /// | `+90 555 444 33 22` | `0555 444 33 22` |
  /// | `905554443322` | `0555 444 33 22` |
  static String? _formatImportedPhone(String value) {
    var digits = normalizePhoneNumber(value);
    if (digits.isEmpty) {
      return null;
    }
    // "+90 555 ..." ve "90555..." yazımlarında ülke kodu atılır. Bu adım
    // uzunluk kırpmasından önce yapılmalıdır, aksi hâlde kodun içinden
    // kırpılır.
    if (digits.length == 12 && digits.startsWith('90')) {
      digits = digits.substring(2);
    }
    // Türkiye'de alan kodu baştaki sıfırla yazılır; Excel'de sıfır kaybolduğunda
    // geri eklenir.
    if (digits.length == _phoneDigitCount - 1) {
      digits = '0$digits';
    }
    if (digits.length > _phoneDigitCount) {
      digits = digits.substring(0, _phoneDigitCount);
    }
    return formatPhoneNumber(digits);
  }

  /// T.C. kimlik numarasını 11 haneli biçime getirir.
  ///
  /// Excel sayısal hücrede başında sıfır olan kimlik numarasının sıfırını
  /// siler; 10 haneye düşen değer 11 haneye tamamlanır. Ayraçlar temizlenir.
  static String? _formatImportedNationalId(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.length == _nationalIdLength - 1) {
      return '0$digits';
    }
    return digits.length > _nationalIdLength
        ? digits.substring(0, _nationalIdLength)
        : digits;
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
    if (const {'erkek', 'erk', 'e', 'male', 'm', 'ç”·'}.contains(normalized)) {
      return StudentGender.male;
    }
    return null;
  }

  /// İlaç sütunlarını tek metin alanına indirger.
  ///
  /// Şablonda "Düzenli İlaç Kullanımı" anahtarı ve "İlaç Detayı" metni
  /// ayrı sütunlardır; modelde ise yalnızca `regularMedication` metni
  /// tutulur. Anahtar açıkça "Hayır" derse detay yok sayılır, aksi hâlde
  /// yazılan detay korunur (eski dosyalarda anahtar sütunu olmayabilir).
  static String? _medicationDetail({
    required String rawFlag,
    required String rawDetail,
  }) {
    final detail = _formatText(rawDetail);
    if (rawFlag.trim().isNotEmpty && !_parseBool(rawFlag)) {
      return null;
    }
    return detail;
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
