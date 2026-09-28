import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';

/// Her öğretmen için sabit, açık tonlu arka plan rengi.
const dutyTeacherPalette = <Color>[
  Color(0xFFFCE4EC),
  Color(0xFFE8F1FB),
  Color(0xFFFFF3D6),
  Color(0xFFE6F4EA),
  Color(0xFFF1E8FB),
  Color(0xFFFBEDE3),
  Color(0xFFE4F6F6),
  Color(0xFFFDECEC),
];

const dutyTeacherBorderPalette = <Color>[
  Color(0xFFEFB6C9),
  Color(0xFFB4D2F0),
  Color(0xFFF0D79A),
  Color(0xFFB7E0C1),
  Color(0xFFD3BEF0),
  Color(0xFFF2C9A8),
  Color(0xFFA7DCDC),
  Color(0xFFF3BEBE),
];

Color dutyTeacherFill(int? teacherId) {
  if (teacherId == null) {
    return dutyTeacherPalette.first;
  }
  return dutyTeacherPalette[teacherId.abs() % dutyTeacherPalette.length];
}

Color dutyTeacherBorder(int? teacherId) {
  if (teacherId == null) {
    return dutyTeacherBorderPalette.first;
  }
  return dutyTeacherBorderPalette[teacherId.abs() %
      dutyTeacherBorderPalette.length];
}

/// Adın baş harflerini büyük harfe çevirir (Türkçe kurallarıyla):
/// Türkçe kurallarına göre büyük harfe çevirir (i -> I).
String _turkishUpper(String value) {
  final buffer = StringBuffer();
  for (final character in value.split('')) {
    buffer.write(switch (character) {
      'i' => 'İ',
      'ı' => 'I',
      _ => character.toUpperCase(),
    });
  }
  return buffer.toString();
}

/// Adın baş harflerini büyük harfe çevirir (Türkçe kurallarıyla):
/// "zeynep kaya" -> "ZK", "ayşe yılmaz" -> "AY", "AYŞE YILMAZ" -> "AY".
String dutyTeacherInitials(String fullName) {
  final letters = fullName.replaceAll(RegExp(r'[^a-zA-ZÇĞİÖŞÜçğıöşü ]'), ' ');
  final parts = letters
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(_turkishUpper)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  final first = parts.first.characters.first;
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first}';
}

const dutyTabLabels = <String>[
  'Nöbet Listeleri',
  'Nöbet Ayarları',
  'Öğretmenler',
  'İstatistikler',
];

class DutyTabBar extends StatelessWidget {
  const DutyTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < dutyTabLabels.length; index++)
            _DutyTabButton(
              key: Key('duty_tab_$index'),
              label: dutyTabLabels[index],
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    );
  }
}

class _DutyTabButton extends StatelessWidget {
  const _DutyTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
