import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

/// Cinsiyeti klasik erkek/kadın figürüyle gösteren rozet.
///
/// Önce soyut yüz ikonları (`face_3` / `face_6`), sonra ♂/♀ simgeleri
/// denendi; ikisi de istenmedi. [Icons.man] / [Icons.woman] ayaklı figür
/// silüetleri kullandığı için wc tabelası geleneğini karşılar ve
/// nöbetçilik odalarındaki tabelalarla aynı okunur. Belirginlik için zemin
/// kontrastı artırılmış, ikon kutusuna daha geniş yerleştirilmiştir.
class StudentGenderFigure extends StatelessWidget {
  const StudentGenderFigure({
    super.key,
    required this.gender,
    this.size = 44,
  });

  final StudentGender? gender;
  final double size;

  static const femaleAccent = Color(0xFFA8125E);
  static const maleAccent = Color(0xFF14468C);
  static const unknownAccent = Color(0xFF8A6A7D);

  /// Cinsiyete karşılık gelen vurgu rengi; kart şeritlerinde de kullanılır.
  static Color accentFor(StudentGender? gender) {
    if (gender == StudentGender.female) return femaleAccent;
    if (gender == StudentGender.male) return maleAccent;
    return unknownAccent;
  }

  @override
  Widget build(BuildContext context) {
    final background = switch (gender) {
      StudentGender.female => const Color(0xFFFBD9EA),
      StudentGender.male => const Color(0xFFD3E3FB),
      null => const Color(0xFFECECF0),
    };
    final foreground = switch (gender) {
      StudentGender.female => femaleAccent,
      StudentGender.male => maleAccent,
      null => AppColors.secondaryText,
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: foreground.withValues(alpha: 0.5),
          width: size >= 40 ? 1.6 : 1.3,
        ),
      ),
      child: Icon(
        switch (gender) {
          StudentGender.female => Icons.woman,
          StudentGender.male => Icons.man,
          null => Icons.person_outline,
        },
        color: foreground,
        size: size * 0.62,
      ),
    );
  }
}