import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';
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
      TextCellValue('Telefon'),
    ]);
    sheet.appendRow([
      TextCellValue('ali yılmaz'),
      TextCellValue('Atatürk Lisesi'),
      TextCellValue('11'),
      TextCellValue('05321234567'),
    ]);
    sheet.appendRow([
      TextCellValue('deniz kaya'),
      TextCellValue(''),
      TextCellValue('10'),
      TextCellValue(''),
    ]);
    File(filePath).writeAsBytesSync(excel.save()!);

    final preview = await const StudentExcelImporter().readFile(filePath);

    expect(preview.rows, hasLength(2));
    expect(preview.rows.first.student.fullName, 'Ali Yılmaz');
    expect(preview.rows.first.missingFields, isNot(contains('Ad Soyad')));
    expect(preview.rows.last.missingFields, contains('Okul'));
    expect(preview.importableCount, 2);
  });
}
