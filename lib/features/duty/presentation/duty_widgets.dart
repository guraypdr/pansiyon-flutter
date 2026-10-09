import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

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

const dutyTabLabels = <String>[
  'Nöbet Listeleri',
  'Nöbet Ayarları',
  'Öğretmenler',
  'İstatistikler',
];

/// Bölüm menüsündeki ikonlar; `dutyTabLabels` ile aynı sırada.
const dutyTabIcons = <IconData>[
  Icons.event_note_outlined,
  Icons.tune_outlined,
  Icons.groups_outlined,
  Icons.insights_outlined,
];

/// Nöbet sayfasının bölümlerini gösteren dikey menü.
///
/// Sekme çubuğu yerine kullanılır: bölümler yatayda gizlenmez, dikey bir
/// listede hep görünür. Etkin bölüm renkli zemin ve sol kenar çizgisiyle
/// belirtilir.
class DutySectionMenu extends StatelessWidget {
  const DutySectionMenu({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double width = 208;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: AppTokens.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < dutyTabLabels.length; index++)
            _DutySectionItem(
              key: Key('duty_section_$index'),
              icon: dutyTabIcons[index],
              label: dutyTabLabels[index],
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
              isLast: index == dutyTabLabels.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Dikey menüdeki tek bölüm.
class _DutySectionItem extends StatelessWidget {
  const _DutySectionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isLast,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 13, 12, 13),
          decoration: BoxDecoration(
            // Etkin bölümün solunda kalın renkli çizgi. Köşe yuvarlatma
            // dışarıdaki kapsayıcının kırpmasıyla sağlanır; kenarlık
            // renkleri farklı olduğu için burada radius verilemez.
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
              bottom: isLast
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.inputBorder),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppTokens.iconMd,
                color: selected ? AppColors.primary : AppColors.secondaryText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.darkText,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.chevron_right,
                  size: AppTokens.iconMd,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DutyStatTile extends StatelessWidget {
  const DutyStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: color.withValues(alpha: 0.8)),
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Özet kutularını dar pencereye uygun sütun sayısına göre dizer.
class DutyStatTileWrap extends StatelessWidget {
  const DutyStatTileWrap({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// Hafta kartının boydan boya koyu başlık çubuğu.
///
/// Numaralandırma ayın 1. gününden itibaren 1'den başlar. Çubuk kartın tam
/// genişliğini kaplar ve yalnızca "N. HAFTA" yazısını taşır.
class DutyWeekHeader extends StatelessWidget {
  const DutyWeekHeader({super.key, required this.weekNumber});

  final int weekNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        '$weekNumber. HAFTA',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Nöbet yeri etiketi: "N. Kat:" biçiminde, öğretmen adının önünde.
///
/// Uzun yer adları kırpılır; tam metin ipucunda görünür.
class DutyLocationLabel extends StatelessWidget {
  const DutyLocationLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final label = trimmed.isEmpty ? 'Nöbet yeri yok:' : '$trimmed:';

    return Tooltip(
      message: trimmed.isEmpty ? 'Nöbet yeri seçilmedi' : trimmed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
