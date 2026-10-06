import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/validation/user_error_message.dart';

void main() {
  group('userErrorMessage', () {
    test('StateError mesajını prefix olmadan döndürür', () {
      final message = userErrorMessage(
        StateError('Bu odaya yalnızca kız öğrenci yerleştirilebilir.'),
        fallback: 'Öğrenci yerleştirilemedi.',
      );

      expect(message, 'Bu odaya yalnızca kız öğrenci yerleştirilebilir.');
      expect(message, isNot(contains('Bad state')));
    });

    test('ArgumentError için mesajı döndürür, geçersiz değeri değil', () {
      final message = userErrorMessage(
        ArgumentError.value(
          'Zemin Salonu',
          'name',
          'Etüt salonu adı boş olamaz.',
        ),
        fallback: 'Etüt salonu kaydedilemedi.',
      );

      expect(message, 'Etüt salonu adı boş olamaz.');
      // Geçmişte metin ayrıştırılınca geçersiz değer ("Zemin Salonu")
      // kullanıcıya gösteriliyordu.
      expect(message, isNot(contains('Zemin Salonu')));
      expect(message, isNot(contains('Invalid argument')));
    });

    test('tanınmayan hata türünde iç mesajı sızdırmaz', () {
      final message = userErrorMessage(
        const FileSystemException(
          'Veritabanı açılamadı',
          r'C:\Users\admin\pansiyon.ozel\veri.db',
        ),
        fallback: 'Öğrenci yerleştirilemedi.',
      );

      expect(message, 'Öğrenci yerleştirilemedi.');
      expect(message, isNot(contains('pansiyon.ozel')));
      expect(message, isNot(contains('veri.db')));
    });

    test('boş StateError mesajında fallback kullanılır', () {
      final message = userErrorMessage(
        StateError('   '),
        fallback: 'Etüt salonu kaydedilemedi.',
      );

      expect(message, 'Etüt salonu kaydedilemedi.');
    });

    test('mesajsız ArgumentError için fallback kullanılır', () {
      final message = userErrorMessage(
        ArgumentError(),
        fallback: 'Etüt salonu kaydedilemedi.',
      );

      expect(message, 'Etüt salonu kaydedilemedi.');
    });

    test('mesajdaki başlı ve son boşluklar temizlenir', () {
      final message = userErrorMessage(
        StateError('  Oda bulunamadı.\n'),
        fallback: 'Öğrenci yerleştirilemedi.',
      );

      expect(message, 'Oda bulunamadı.');
    });
  });
}
