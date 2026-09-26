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
      TextCellValue('Anne Telefonu'),
      TextCellValue('Baba Telefonu'),
      TextCellValue('Veli Adı'),
      TextCellValue('Yakınlık'),
      TextCellValue('İlaç'),
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
    expect(student.motherPhone, '0532 111 11 11');
    expect(student.fatherPhone, '0532 222 22 22');
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
}
