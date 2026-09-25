import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

void main() {
  test('pansiyon kademesine göre sınıf seviyeleri üretir', () {
    expect(classLevelsForEducationLevel(EducationLevel.middleSchool), [
      '5',
      '6',
      '7',
      '8',
    ]);
    expect(classLevelsForEducationLevel(EducationLevel.highSchool), [
      'Hazırlık',
      '9',
      '10',
      '11',
      '12',
    ]);
    expect(classLevelsForEducationLevel(null), isEmpty);
  });
}
