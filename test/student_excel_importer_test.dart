import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:path/path.dart' as path;

void main() {
  test('Excel satırlarını okur ve eksik alanları raporlar', () async {
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_import_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'students.xlsx');

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([
      TextCellValue('Ad Soyad'),
      TextCellValue('Okul'),
      TextCellValue('Sınıf'),
      TextCellValue('Cinsiyet'),
      TextCellValue('Telefon'),
    ]);
    sheet.appendRow([
      TextCellValue('ali yılmaz'),
      TextCellValue('Atatürk Lisesi'),
      TextCellValue('11'),
      TextCellValue('Kız'),
      TextCellValue('05321234567'),
    ]);
    sheet.appendRow([
      TextCellValue('deniz kaya'),
      TextCellValue(''),
      TextCellValue('10'),
      TextCellValue('Erkek'),
      TextCellValue(''),
    ]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final preview = await const StudentExcelImporter().readFile(filePath);

    expect(preview.rows, hasLength(2));
    expect(preview.rows.first.student.fullName, 'Ali Yılmaz');
    expect(preview.rows.first.student.gender, StudentGender.female);
    expect(preview.rows.last.student.gender, StudentGender.male);
    expect(preview.rows.first.missingFields, isNot(contains('Ad Soyad')));
    expect(preview.rows.last.missingFields, contains('Okul'));
    expect(preview.importableCount, 2);
  });

  test('metin ve telefon alanlarını içe aktarırken biçimlendirir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_formatting_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'students.xlsx');
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([
      TextCellValue('Ad Soyad'),
      TextCellValue('Okul'),
      TextCellValue('Sınıf'),
      TextCellValue('Şube'),
      TextCellValue('Adres'),
      TextCellValue('Telefon'),
      TextCellValue('Veli Telefonu'),
      TextCellValue('Diğer Veli Telefonu'),
      TextCellValue('Veli Adı'),
      TextCellValue('Yakınlık'),
      TextCellValue('İlaç Detayı'),
    ]);
    sheet.appendRow([
      TextCellValue('ALİ YILMAZ'),
      TextCellValue('ATATÜRK LİSESİ'),
      TextCellValue('11-A'),
      TextCellValue('A'),
      TextCellValue('İSTANBUL KADIKÖY'),
      TextCellValue('05321234567'),
      TextCellValue('05321111111'),
      TextCellValue('05322222222'),
      TextCellValue('AYŞE YILMAZ'),
      TextCellValue('ANNE'),
      TextCellValue('İLAÇ A'),
    ]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final row = (await const StudentExcelImporter().readFile(
      filePath,
    )).rows.single;
    final student = row.student;

    expect(student.fullName, 'Ali Yılmaz');
    expect(row.schoolName, 'Atatürk Lisesi');
    expect(student.className, '11-A');
    expect(student.sectionName, 'A');
    expect(student.address, 'İstanbul Kadıköy');
    expect(student.phone, '0532 123 45 67');
    expect(student.guardianPhone, '0532 111 11 11');
    expect(student.guardian2Phone, '0532 222 22 22');
    expect(student.guardianName, 'Ayşe Yılmaz');
    expect(student.guardianRelation, 'Anne');
    expect(student.regularMedication, 'İlaç A');
  });

  test('300 veri satırına kadar okur, fazlasını reddeder', () async {
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_limit_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'students.xlsx');
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue('Ad Soyad')]);
    for (var index = 0; index < 301; index++) {
      sheet.appendRow([TextCellValue('Öğrenci $index')]);
    }
    File(filePath).writeAsBytesSync(excel.save()!);

    await expectLater(
      const StudentExcelImporter().readFile(filePath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('en fazla 300 öğrenci satırı'),
        ),
      ),
    );
  });

  test('Excel şablonu başlıklarıyla oluşturulur', () {
    final bytes = const StudentExcelImporter().createTemplateBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables['Öğrenciler'];

    expect(sheet, isNotNull);
    expect(
      sheet!.rows.first.map((cell) => cell?.value.toString()),
      containsAll(['Ad Soyad', 'T.C. Kimlik No', 'Okul No', 'Telefon']),
    );
    expect(excel.tables.keys, contains('Açıklama'));
  });

  test('Excel şablonunda iki veli başlığı bulunur', () {
    final bytes = const StudentExcelImporter().createTemplateBytes();
    final sheet = Excel.decodeBytes(bytes).tables['Öğrenciler'];
    final headers = sheet!.rows.first
        .map((cell) => cell?.value.toString())
        .toSet();

    expect(
      headers,
      containsAll([
        'Veli Adı',
        'Yakınlık',
        'Veli Telefonu',
        'Veli Adresi',
        'Diğer Veli Adı',
        'Diğer Veli Yakınlığı',
        'Diğer Veli Telefonu',
        'Diğer Veli Adresi',
      ]),
    );
    // Kaldırılan alanlar şablon kalmamalı.
    expect(headers, isNot(contains('Kiminle Yaşıyor')));
    expect(headers, isNot(contains('Anne Baba Birlikte mi')));
    expect(headers, isNot(contains('Anne Adı')));
    expect(headers, isNot(contains('Baba Adı')));
    expect(headers, isNot(contains('Veli Başka mı')));
  });

  test('şablonda örnek satır var ve veri sayfasında değil', () {
    final excel = Excel.decodeBytes(
      const StudentExcelImporter().createTemplateBytes(),
    );
    final studentsSheet = excel.tables['Öğrenciler']!;
    final instructions = excel.tables['Açıklama']!;

    // Veri sayfasında yalnızca başlık satırı var; örnek satır orada
    // bulunursa içe aktarım onu gerçek öğrenci sanar.
    expect(studentsSheet.rows, hasLength(1));
    expect(
      studentsSheet.rows.first
          .map((cell) => cell?.value.toString())
          .contains('Ali Yılmaz'),
      isFalse,
    );

    // Açıklama sayfasında başlık satırının birebir kopyası ve dolu bir
    // örnek satır yer alır.
    final templateHeaders = studentsSheet.rows.first
        .map((cell) => cell?.value.toString() ?? '')
        .toList();
    final headerIndex = instructions.rows.indexWhere(
      (row) => row
          .map((cell) => cell?.value.toString() ?? '')
          .toList()
          .join('|')
          .startsWith(templateHeaders.take(3).join('|')),
    );
    expect(headerIndex, isNot(-1), reason: 'açıklamada başlık satırı yok');

    final exampleRow = instructions.rows[headerIndex + 1]
        .map((cell) => cell?.value.toString() ?? '')
        .toList();
    expect(exampleRow.first, 'Ali Yılmaz');
    expect(
      exampleRow,
      hasLength(templateHeaders.length),
      reason: 'örnek satır tüm sütunları kapsamalı',
    );
    // Psikolojik Rahatsızlık "Hayır" olduğu için yalnızca o detay hücresi
    // bilinçli olarak boş bırakılmıştır.
    final emptyCells = <String>[];
    for (var column = 0; column < templateHeaders.length; column++) {
      if (exampleRow[column].isEmpty) {
        emptyCells.add(templateHeaders[column]);
      }
    }
    expect(emptyCells, ['Psikolojik Detayı']);
  });

  test('Açıklama sayfası veri sayfası sanılmaz', () async {
    // Kullanıcı "Öğrenciler" sayfasını silerse içe aktarıcı diğer
    // sayfaları tarar. Açıklama sayfasındaki örnek satırın "Ali Yılmaz"
    // olarak kaydedilmesi yanlış olur.
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_sheet_guard_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'students.xlsx');
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    excel['Öğrenciler']
      ..appendRow([TextCellValue('Ad Soyad')])
      ..appendRow([TextCellValue('Ali Yılmaz')]);
    excel['Açıklama'].appendRow([TextCellValue('Sadece açıklama')]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final okPreview = await const StudentExcelImporter().readFile(filePath);
    expect(okPreview.rows, hasLength(1));

    // Veri sayfası olmayan dosyada örnek satır okunmamalı.
    final emptyPath = path.join(directory.path, 'empty.xlsx');
    final onlyInstructions = Excel.createExcel();
    onlyInstructions.delete('Sheet1');
    final example = const StudentExcelImporter().createTemplateBytes();
    final decoded = Excel.decodeBytes(example);
    decoded.delete('Öğrenciler');
    File(emptyPath).writeAsBytesSync(decoded.save()!);
    final preview = await const StudentExcelImporter().readFile(emptyPath);
    expect(preview.rows, isEmpty);
  });

  test('şablonda acil iletişim sütunu bulunmaz', () {
    final sheet = Excel.decodeBytes(
      const StudentExcelImporter().createTemplateBytes(),
    ).tables['Öğrenciler']!;
    final headers = sheet.rows.first
        .map((cell) => cell?.value.toString())
        .toSet();

    // Formda da acil iletişim alanı yok; veliden türetiliyor.
    expect(headers, isNot(contains('Acil Kişi')));
    expect(headers, isNot(contains('Acil Telefon')));
    expect(headers, isNot(contains('Acil Ulaşılacak Kişi')));
  });

  test('ilaç anahtarı olarak "yok" yazılırsa detay temizlenir', () async {
    // Kullanıcılar "yok" yazıyor; "Hayır" ile aynı ele alınmalı.
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Düzenli İlaç Kullanımı': 'yok',
      'İlaç Detayı': 'Ventolin',
    });

    expect(preview.rows.single.student.regularMedication, isNull);
  });

  test('sağlık anahtarı olarak "yok" yanlış değere yol açmıyor', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Sürekli Hastalık': 'yok',
      'Alerji': 'yok',
      'Kan Grubu': 'bilinmiyor',
    });
    final student = preview.rows.single.student;

    expect(student.hasChronicDisease, isFalse);
    expect(student.hasAllergy, isFalse);
    expect(student.bloodType, 'Bilinmiyor');
  });

  test('eski şablondaki anne/baba sütunları uyarı üretir', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Anne Adı': 'Ayşe Yılmaz',
      'Anne Telefonu': '05321112233',
      'Baba Adı': 'Mehmet Yılmaz',
      'Veli Adı': 'Nuriye Amca',
      'Veli Telefonu': '05329998877',
    });

    // Bu sütunlar artık okunmuyor; kullanıcı sessizce veri kaybetmemeli.
    expect(preview.headerWarnings, contains(contains('eski şablona ait')));
    final student = preview.rows.single.student;
    // Veli sütunları okunur, anne/baba sütunları yok sayılır.
    expect(student.guardianName, 'Nuriye Amca');
    expect(student.guardianPhone, '0532 999 88 77');
  });

  test('yeni şablonda aile uyarısı çıkmaz', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Veli Adı': 'Ayşe Yılmaz',
      'Veli Telefonu': '05321112233',
    });

    expect(preview.headerWarnings, isNot(contains(contains('eski şablona'))));
  });

  test('Excel kilit dosyası seçilirse uyarı verir', () async {
    // Excel, açık çalışma kitabı için "~$ad.xlsx" adlı geçici kilit
    // dosyası oluşturur; dosya seçme penceresinde .xlsx olarak görünür.
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_lock_file_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final lockPath = path.join(directory.path, r'~$sablon.xlsx');
    File(lockPath).writeAsBytesSync(List<int>.filled(165, 0));

    await expectLater(
      const StudentExcelImporter().readFile(lockPath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('kilit dosyası'),
        ),
      ),
    );
  });

  test('xlsx olmayan dosya için biçim ipucu verir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_not_xlsx_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final bogusPath = path.join(directory.path, 'notatablo.xlsx');
    File(bogusPath).writeAsStringSync('bu bir excel dosyasi degil');

    await expectLater(
      const StudentExcelImporter().readFile(bogusPath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('.xlsx'),
        ),
      ),
    );
  });

  test('sağlık soruları anahtar ve detay olarak simetriktir', () {
    final sheet = Excel.decodeBytes(
      const StudentExcelImporter().createTemplateBytes(),
    ).tables['Öğrenciler']!;
    final headers = sheet.rows.first
        .map((cell) => cell?.value.toString())
        .toSet();

    // Her sağlık sorusu "X" + "X Detayı" çifti içermeli.
    expect(
      headers,
      containsAll([
        'Sürekli Hastalık',
        'Sürekli Hastalık Detayı',
        'Alerji',
        'Alerji Detayı',
        'Düzenli İlaç Kullanımı',
        'İlaç Detayı',
        'Psikolojik Rahatsızlık',
        'Psikolojik Detayı',
      ]),
    );
  });

  test('şablondaki her sütun içe aktarımda karşılık bulur', () async {
    // Şablon başlıkları ile okuyucu eşlemesi ayrı ayrı tanımlıdır; ikisi
    // birbirinden kayarsa sütun sessizce boş gelir. Bu test her başlığın
    // gerçekten bir değer taşıdığını doğrular.
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_template_roundtrip_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'template.xlsx');
    final excel = Excel.decodeBytes(
      const StudentExcelImporter().createTemplateBytes(),
    );
    final sheet = excel['Öğrenciler'];
    final headers = sheet.rows.first
        .map((cell) => cell?.value.toString() ?? '')
        .toList();
    sheet.appendRow([
      for (final header in headers)
        TextCellValue(
          <String, String>{
                'Ad Soyad': 'Ali Yılmaz',
                'Cinsiyet': 'Kız',
                'T.C. Kimlik No': '12345678901',
                'Okul': 'Atatürk Lisesi',
                'Sınıf': '9',
                'Şube': 'A',
                'Okul No': '1453',
                'Doğum Tarihi': '12.05.2010',
                'Adres': 'Atatürk Mah. 1. Sok.',
                'Telefon': '05321234567',
                'Veli Adı': 'Ayşe Yılmaz',
                'Yakınlık': 'Anne',
                'Veli Telefonu': '05321112233',
                'Veli Adresi': 'Atatürk Mah. 1. Sok.',
                'Diğer Veli Adı': 'Mehmet Yılmaz',
                'Diğer Veli Yakınlığı': 'Baba',
                'Diğer Veli Telefonu': '05325556677',
                'Diğer Veli Adresi': 'Cumhuriyet Mah. 2. Cad.',
                'Sürekli Hastalık': 'Evet',
                'Sürekli Hastalık Detayı': 'Astım',
                'Alerji': 'Evet',
                'Alerji Detayı': 'Fındık',
                'Düzenli İlaç Kullanımı': 'Evet',
                'İlaç Detayı': 'Ventolin',
                'Kan Grubu': '0 Rh+',
                'Psikolojik Rahatsızlık': 'Hayır',
                'Psikolojik Detayı': '',
                'Pansiyon Kayıt Tarihi': '01.09.2026',
              }[header] ??
              '',
        ),
    ]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final preview = await const StudentExcelImporter().readFile(filePath);
    expect(preview.headerWarnings, isEmpty);
    final row = preview.rows.single;
    final student = row.student;

    expect(row.schoolName, 'Atatürk Lisesi');
    expect(student.fullName, 'Ali Yılmaz');
    expect(student.gender, StudentGender.female);
    expect(student.nationalId, '12345678901');
    expect(student.className, '9');
    expect(student.sectionName, 'A');
    expect(student.schoolNumber, '1453');
    expect(student.birthDate, DateTime(2010, 5, 12));
    expect(student.address, 'Atatürk Mah. 1. Sok.');
    expect(student.phone, '0532 123 45 67');
    expect(student.guardianName, 'Ayşe Yılmaz');
    expect(student.guardianRelation, 'Anne');
    expect(student.guardianPhone, '0532 111 22 33');
    expect(student.guardianAddress, 'Atatürk Mah. 1. Sok.');
    expect(student.guardian2Name, 'Mehmet Yılmaz');
    expect(student.guardian2Relation, 'Baba');
    expect(student.guardian2Phone, '0532 555 66 77');
    expect(student.guardian2Address, 'Cumhuriyet Mah. 2. Cad.');
    expect(student.emergencyContactName, 'Ayşe Yılmaz');
    expect(student.emergencyContactPhone, '0532 111 22 33');
    expect(student.hasChronicDisease, isTrue);
    expect(student.chronicDiseaseDetails, 'Astım');
    expect(student.hasAllergy, isTrue);
    expect(student.allergyDetails, 'Fındık');
    expect(student.regularMedication, 'Ventolin');
    expect(student.bloodType, '0 Rh+');
    expect(student.hasPsychologicalCondition, isFalse);
    expect(student.boardingRegistrationDate, DateTime(2026, 9, 1));
  });

  test('şablona yalnızca Ad Soyad eklenen dosya okunur', () async {
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_template_data_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'template.xlsx');
    final excel = Excel.decodeBytes(
      const StudentExcelImporter().createTemplateBytes(),
    );
    excel['Öğrenciler'].appendRow([TextCellValue('Ali Yılmaz')]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final preview = await const StudentExcelImporter().readFile(filePath);

    expect(preview.rows, hasLength(1));
    expect(preview.rows.single.student.fullName, 'Ali Yılmaz');
    expect(preview.importableCount, 1);
  });

  test(
    'Excel biçim stilindeki uyumsuz numFmtId değerini tolere eder',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'student_excel_style_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filePath = path.join(directory.path, 'students.xlsx');
      final excel = Excel.createExcel();
      final sheet = excel['Öğrenciler'];
      sheet.appendRow([TextCellValue('Ad Soyad')]);
      sheet.appendRow([TextCellValue('Ali Yılmaz')]);
      final archive = ZipDecoder().decodeBytes(excel.save()!);
      final stylesFile = archive.findFile('xl/styles.xml')!;
      final stylesXml = utf8.decode(stylesFile.content as List<int>);
      const invalidNumFmts =
          '<numFmts count="1"><numFmt numFmtId="26" formatCode="General"/>'
          '</numFmts>';
      final stylesWithInvalidFormat = stylesXml.contains('<numFmts')
          ? stylesXml.replaceFirst(
              RegExp(r'<numFmts\b[\s\S]*?</numFmts>'),
              invalidNumFmts,
            )
          : stylesXml.replaceFirst('<fonts', '$invalidNumFmts<fonts');
      final encodedStyles = utf8.encode(stylesWithInvalidFormat);
      archive.addFile(
        ArchiveFile('xl/styles.xml', encodedStyles.length, encodedStyles),
      );
      File(filePath).writeAsBytesSync(ZipEncoder().encode(archive)!);

      final preview = await const StudentExcelImporter().readFile(filePath);

      expect(preview.rows, hasLength(1));
      expect(preview.rows.single.student.fullName, 'Ali Yılmaz');
    },
  );

  test('ilaç anahtarı Hayır ise detay temizlenir', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Düzenli İlaç Kullanımı': 'Hayır',
      'İlaç Detayı': 'Ventolin',
    });

    expect(preview.rows.single.student.regularMedication, isNull);
  });

  test('ilaç anahtarı Evet ise detay korunur', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Düzenli İlaç Kullanımı': 'Evet',
      'İlaç Detayı': 'Ventolin',
    });

    expect(preview.rows.single.student.regularMedication, 'Ventolin');
  });

  test('ilaç anahtar sütunu yoksa eski dosyalar okunur', () async {
    // Şablon değişmeden önce kaydedilmiş dosyalarda yalnızca "İlaç"
    // sütunu vardır; içe aktarım bozulmamalı. Özellikle "İlaç" başlığı
    // ilaç anahtarı sanılmamalı: önek eşleştirme çift yönlü olduğu için
    // "İlaç Kullanımı" gibi bir takma ad bu sütunu kapabilirdi.
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'İlaç': 'Ventolin',
    });

    expect(preview.rows.single.student.regularMedication, 'Ventolin');
  });

  test('kısa ve uzun ilaç başlıkları birbirine karışmaz', () async {
    // Anahtar sütunu "Düzenli İlaç", detay sütunu "İlaç" olan dosya.
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Düzenli İlaç': 'Evet',
      'İlaç': 'Ventolin',
    });
    final student = preview.rows.single.student;

    expect(student.regularMedication, 'Ventolin');
  });

  test('acil iletişim birincil veliden türetilir', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Veli Adı': 'Ayşe Yılmaz',
      'Veli Telefonu': '05321112233',
    });
    final student = preview.rows.single.student;

    expect(student.emergencyContactName, 'Ayşe Yılmaz');
    expect(student.emergencyContactPhone, '0532 111 22 33');
  });

  test('birincil veli boşsa acil iletişim ikincil veliye düşer', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Diğer Veli Adı': 'Mehmet Yılmaz',
      'Diğer Veli Telefonu': '05325556677',
    });
    final student = preview.rows.single.student;

    expect(student.emergencyContactName, 'Mehmet Yılmaz');
    expect(student.emergencyContactPhone, '0532 555 66 77');
  });

  test('veli yoksa acil iletişim boş kalır', () async {
    final preview = await _readWorkbook({'Ad Soyad': 'Ali Yılmaz'});
    final student = preview.rows.single.student;

    expect(student.emergencyContactName, isNull);
    expect(student.emergencyContactPhone, isNull);
  });

  test('Ad Soyad bulunan Öğrenciler sayfasını seçer', () async {
    final directory = await Directory.systemTemp.createTemp(
      'student_excel_sheet_selection_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filePath = path.join(directory.path, 'students.xlsx');
    final excel = Excel.createExcel();
    excel.rename(excel.tables.keys.first, 'Açıklama');
    excel['Açıklama'].appendRow([TextCellValue('Bu sayfayı kullanmayın')]);
    final studentSheet = excel['Öğrenciler'];
    studentSheet.appendRow([TextCellValue('Ad Soyad')]);
    studentSheet.appendRow([TextCellValue('Deniz Kaya')]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final preview = await const StudentExcelImporter().readFile(filePath);

    expect(preview.rows, hasLength(1));
    expect(preview.rows.single.student.fullName, 'Deniz Kaya');
  });

  test('şablon başlığı olan T.C. Kimlik No sütununu okur', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'T.C. Kimlik No': '12345678901',
    });

    expect(preview.rows.single.student.nationalId, '12345678901');
    expect(preview.headerWarnings, isNot(contains('T.C. Kimlik No')));
  });

  test('T.C. Kimlik No başlık varyantlarını tanır', () async {
    for (final header in const [
      'T.C. Kimlik No',
      'T.C. Kimlik Numarası',
      'TC Kimlik No',
      'TCKN',
      'T.C.KimlikNo',
      'tc kimlik no',
      'National ID',
    ]) {
      final preview = await _readWorkbook({
        'Ad Soyad': 'Ali Yılmaz',
        header: '12345678901',
      });

      expect(
        preview.rows.single.student.nationalId,
        '12345678901',
        reason: '"$header" başlığı tanınmadı.',
      );
    }
  });

  test(
    'Excel sayısal hücrede kaybolan baştaki sıfırı TC kimlikte geri ekler',
    () async {
      final preview = await _readWorkbook({
        'Ad Soyad': 'Ali Yılmaz',
        'T.C. Kimlik No': 2345678901,
      });

      expect(preview.rows.single.student.nationalId, '02345678901');
    },
  );

  test('TC kimlik numarasındaki ayraçları temizler', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'T.C. Kimlik No': '123 456 789 01',
    });

    expect(preview.rows.single.student.nationalId, '12345678901');
  });

  test('yaygın Cep ve Kimlik No başlıklarını tanır', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Kimlik No': '12345678901',
      'Cep': '5554443322',
      'Diğer Veli Telefonu': '5554443322',
      'Veli Cep': '0555 111 22 33',
    });
    final student = preview.rows.single.student;

    expect(student.nationalId, '12345678901');
    expect(student.phone, '0555 444 33 22');
    expect(student.guardian2Phone, '0555 444 33 22');
    expect(student.guardianPhone, '0555 111 22 33');
  });

  test('Okul ve Okul No sütunlarını birbirine karıştırmaz', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Okul': 'Atatürk Lisesi',
      'Okul No': '1453',
    });
    final row = preview.rows.single;

    expect(row.schoolName, 'Atatürk Lisesi');
    expect(row.student.schoolNumber, '1453');
  });

  test('baştaki sıfırı olmayan birleşik telefonu düzeltir', () async {
    final preview = await _readWorkbook({
      'Ad Soyad': 'Ali Yılmaz',
      'Telefon': '5554443322',
    });

    expect(preview.rows.single.student.phone, '0555 444 33 22');
  });

  test('ülke kodu ve ayraç içeren telefonları düzeltir', () async {
    final cases = <String, String>{
      '5554443322': '0555 444 33 22',
      '+90 555 444 33 22': '0555 444 33 22',
      '905554443322': '0555 444 33 22',
      '0555 444 33 22': '0555 444 33 22',
      '05554443322': '0555 444 33 22',
      '555-444-33-22': '0555 444 33 22',
      '(0555) 444 33 22': '0555 444 33 22',
    };

    for (final entry in cases.entries) {
      final preview = await _readWorkbook({
        'Ad Soyad': 'Ali Yılmaz',
        'Telefon': entry.key,
        'Veli Telefonu': entry.key,
      });
      final student = preview.rows.single.student;

      expect(
        student.phone,
        entry.value,
        reason: '"${entry.key}" yanlış aktarıldı.',
      );
      expect(
        student.guardianPhone,
        entry.value,
        reason: '"${entry.key}" yanlış aktarıldı.',
      );
    }
  });
}

/// Anahtarı başlık, değeri hücre içeriği olan tek satırlık çalışma kitabı üretir.
Future<StudentImportPreview> _readWorkbook(Map<String, Object> row) async {
  final directory = await Directory.systemTemp.createTemp(
    'student_excel_row_test',
  );
  addTearDown(() => directory.delete(recursive: true));
  final filePath = path.join(directory.path, 'students.xlsx');
  final excel = Excel.createExcel();
  final sheet = excel['Öğrenciler'];
  sheet.appendRow([for (final header in row.keys) TextCellValue(header)]);
  sheet.appendRow([
    for (final value in row.values)
      value is int ? IntCellValue(value) : TextCellValue(value as String),
  ]);
  File(filePath).writeAsBytesSync(excel.save()!);
  return const StudentExcelImporter().readFile(filePath);
}
