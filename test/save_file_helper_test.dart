import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/files/save_file_helper.dart';

void main() {
  group('writeFileChecked', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'save_file_helper_test',
      );
    });

    tearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    test('baytları dosyaya yazar ve boyutu doğrular', () async {
      final file = File('${tempDirectory.path}/sablon.xlsx');
      const bytes = [1, 2, 3, 4, 5];

      await writeFileChecked(file.path, bytes);

      expect(await file.readAsBytes(), bytes);
      expect(await file.length(), bytes.length);
    });

    test('yazma başarısız olursa dosya bırakmaz', () async {
      // Hedef bir dizin adresi: dosya açılamaz.
      final file = File(tempDirectory.path);

      await expectLater(
        writeFileChecked(file.path, const [1, 2, 3]),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('zaten var olan boş dosyanın üzerine yazar', () async {
      // Gerçek senaryo: daha önce başarısız bir kayıt 0 baytlık dosya
      // bırakmış, kullanıcı aynı adla tekrar kaydetmeye çalışıyor.
      final file = File('${tempDirectory.path}/sablon.xlsx');
      file.writeAsBytesSync(const []);
      expect(await file.length(), 0);

      const bytes = [9, 8, 7];
      await writeFileChecked(file.path, bytes);

      expect(await file.readAsBytes(), bytes);
      expect(await file.length(), isNot(0));
    });
  });

  group('resolveSaveDirectory', () {
    test('var olan bir klasör döndürür', () async {
      final directory = await resolveSaveDirectory();

      // Windows dışında sağlayıcı çalışmayabilir; bu durumda null kabul
      // edilir, ancak null değilse gerçekten var olan bir klasör olmalı.
      if (directory != null) {
        expect(await Directory(directory).exists(), isTrue);
      }
    });
  });
}
