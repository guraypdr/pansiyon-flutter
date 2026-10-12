import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/attendance/presentation/duty_signature_dialog.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

void main() {
  // Çizelgeyi basmadan önce imza satırının ne olacağı seçilir. Bu saf
  // fonksiyon hem penceredeki önizlemede hem de çizelge oluşturulurken
  // çağrılır; önizleme ile çıktı bu yüzden ayrışamaz.

  DutyDutySlot slot(int id, String name, String location) => DutyDutySlot(
    teacher: DutyTeacher(id: id, fullName: name),
    location: location,
    sectionKey: '',
  );

  final first = slot(1, 'Halil Oğuzhan Bal', '1. Kat');
  final second = slot(2, 'Sercan Sümbül', '2. Kat');
  final both = [first, second];

  group('dutySignatureLines', () {
    test('simsiz secim hicbir isim yazmaz', () {
      expect(
        dutySignatureLines(mode: DutySignatureMode.simsiz, slots: both),
        isEmpty,
      );
    });

    test('tek satirda tum noketciler virgulle yazilir', () {
      expect(
        dutySignatureLines(mode: DutySignatureMode.tekSatir, slots: both),
        ['Halil Oğuzhan Bal, Sercan Sümbül'],
      );
    });

    test('kat bazinda her kat ayri satirda', () {
      expect(
        dutySignatureLines(mode: DutySignatureMode.katBazli, slots: both),
        ['1. Kat: Halil Oğuzhan Bal', '2. Kat: Sercan Sümbül'],
      );
    });

    test('kat bazinda noket yeri yoksa yalniz ad yazilir', () {
      final noLocation = slot(3, 'Ahmet Yılmaz', '');
      expect(
        dutySignatureLines(
          mode: DutySignatureMode.katBazli,
          slots: [noLocation],
        ),
        ['Ahmet Yılmaz'],
      );
    });

    test('tek ogretmen secilince yalniz o yazilir', () {
      expect(
        dutySignatureLines(
          mode: DutySignatureMode.tekOgreten,
          slots: both,
          teacherId: 2,
        ),
        ['Sercan Sümbül'],
      );
    });

    test('ogretmen secilmediyse tek ogretmen modu bos kalir', () {
      expect(
        dutySignatureLines(mode: DutySignatureMode.tekOgreten, slots: both),
        isEmpty,
      );
    });

    test('noketci yoksa hicbir mod satir uretmez', () {
      for (final mode in DutySignatureMode.values) {
        expect(
          dutySignatureLines(mode: mode, slots: const []),
          isEmpty,
          reason: '$mode',
        );
      }
    });

    test('kat filtresi secilen yuvalari daraltir', () {
      // Yalnızca 2. yuva seçildiğinde yalnızca o kat yazılır.
      final onlySecond = [second];
      expect(
        dutySignatureLines(mode: DutySignatureMode.katBazli, slots: onlySecond),
        ['2. Kat: Sercan Sümbül'],
      );
    });
  });

  group('DutySignatureMode etiketleri', () {
    test('her modun etiketi ve aciklamasi var', () {
      for (final mode in DutySignatureMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });

    test('dort secenek sunulur', () {
      expect(DutySignatureMode.values, hasLength(4));
    });
  });
}
