import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';

/// Nöbet istatistikleri: eklenen öğretmenler ve aylık nöbet dağılımı.
class DutyStatsTab extends StatelessWidget {
  const DutyStatsTab({
    super.key,
    required this.teachers,
    required this.lists,
    required this.assignments,
    required this.year,
    required this.perTeacherMonth,
  });

  final List<DutyTeacher> teachers;
  final List<DutyMonthList> lists;
  final List<DutyAssignment> assignments;
  final int year;

  /// Öğretmen id -> ay -> nöbet sayısı
  final Map<int, Map<int, int>> perTeacherMonth;

  @override
  Widget build(BuildContext context) {
    final yearLists = lists.where((item) => item.year == year).toList();
    final yearTotal = yearLists.fold<int>(
      0,
      (sum, item) => sum + item.assignmentCount,
    );
    final activeTeachers = teachers.where((teacher) => teacher.isActive).length;
    final monthlyAverage = yearLists.isEmpty
        ? 0
        : yearTotal ~/ yearLists.length;

    // Nöbet almamış öğretmenler istatistiği boğuyor; listeye yalnızca o
    // yılda en az bir nöbet alanlar girer.
    final ranked = teachers.where((t) => _totalOf(t) > 0).toList()
      ..sort((a, b) {
        final byTotal = _totalOf(b).compareTo(_totalOf(a));
        if (byTotal != 0) return byTotal;
        return a.fullName.compareTo(b.fullName);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        // Özet kartları dar pencerede alt alta geçsin diye Wrap kullanılır;
        // Row kullanılırsa dört kart sığmaz ve taşma çıkar.
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 680
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final cards = <_StatCardData>[
              _StatCardData(
                label: 'Eklenen öğretmen',
                value: '${teachers.length}',
                detail: '$activeTeachers aktif',
                color: AppColors.primary,
                icon: Icons.groups_outlined,
              ),
              _StatCardData(
                label: '$year yılı nöbet',
                value: '$yearTotal',
                detail: '${yearLists.length} liste',
                color: AppColors.secondary,
                icon: Icons.event_note_outlined,
              ),
              _StatCardData(
                label: 'Liste başına ortalama',
                value: '$monthlyAverage',
                detail: 'nöbet',
                color: AppColors.lavender,
                icon: Icons.stacked_line_chart,
              ),
              _StatCardData(
                label: 'Bu aydaki nöbet',
                value: '${assignments.length}',
                detail: 'seçili liste',
                color: AppColors.successFeedback,
                icon: Icons.today_outlined,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards)
                  SizedBox(width: width, child: _StatCard(data: card)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _StatsSection(
          title: 'Aylık nöbet dağılımı',
          subtitle: '$year yılında oluşturulan listeler',
          child: _MonthlyChart(lists: yearLists),
        ),
        const SizedBox(height: 12),
        _StatsSection(
          title: 'Öğretmen bazında aylık nöbetler',
          subtitle: ranked.isEmpty
             ? 'Bu yılda nöbet alan öğretmen yok'
              : 'Toplam nöbete göre sıralı, ${ranked.length} öğretmen',
          child: _TeacherChart(
            teachers: ranked,
            perTeacherMonth: perTeacherMonth,
          ),
        ),
      ],
    );
  }

  int _totalOf(DutyTeacher teacher) {
    return (perTeacherMonth[teacher.id] ?? const {}).values.fold<int>(
      0,
      (a, b) => a + b,
    );
  }
}

class _StatCardData {
  const _StatCardData({
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Değer bloğu sabit genişlikte; ayrıntı metni kalan alanda
          // kırpılır. Böylece dört kart yan yana da hizalı kalır.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: data.color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                data.label,
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
                Icon(data.icon, size: 19, color: data.color.withValues(alpha: 0.8)),
                const SizedBox(height: 6),
                Text(
                  data.detail,
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

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Aylık dağılım: her ay için yatay çubuk ve sayı.
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.lists});

  final List<DutyMonthList> lists;

  /// Çubukların ortak yüksekliği; başlık ve değer satırıyla hizalıdır.
  static const double _barHeight = 22;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return const _StatsEmpty();
    }
    final counts = <int, int>{};
    for (final list in lists) {
      counts[list.month] = (counts[list.month] ?? 0) + list.assignmentCount;
    }
    final maxValue = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final months = counts.keys.toList()..sort();

    return Column(
      children: [
        // Ölçek çubuğu: çubukların neye göre uzun olduğu belli olsun.
        Row(
          children: [
            const SizedBox(width: 78),
            Expanded(
              child: Text(
                'en yüksek ay: $maxValue nöbet',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(width: 52),
          ],
        ),
        const SizedBox(height: 8),
        for (final month in months)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    dutyMonthName(month),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ratio = maxValue == 0
                          ? 0.0
                          : counts[month]! / maxValue;
                      return Stack(
                        children: [
                          // Boş kalan kısım, çubuk kısa olduğunda hizayı
                          // koruyabilmek için hep görünür.
                          Container(
                            height: _barHeight,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio == 0 ? 0.0001 : ratio,
                            child: Container(
                              height: _barHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withValues(alpha: 0.72),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${counts[month]}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Öğretmen x ay nöbet tablosu.
///
/// Tüm hücreler **tek bir satır yüksekliği** kullanır; başlık satırı da
/// aynı yükseklikte olduğu için sütunlar kaymaz. Daha önce ay başlıkları
/// yükseklik sınırlaması olmayan bir `Center` içinde yer aldığı için tabloya
/// göre aşağı kayıyordu.
class _TeacherChart extends StatelessWidget {
  const _TeacherChart({required this.teachers, required this.perTeacherMonth});

  final List<DutyTeacher> teachers;

  /// Öğretmen id -> ay -> nöbet sayısı
  final Map<int, Map<int, int>> perTeacherMonth;

  static const double _headerHeight = 34;
  static const double _rowHeight = 44;
  static const double _nameWidth = 210;
  static const double _monthWidth = 58;
  static const double _totalWidth = 74;

  @override
  Widget build(BuildContext context) {
    if (teachers.isEmpty) {
      return const _StatsEmpty();
    }
    final months = <int>{
      for (final counts in perTeacherMonth.values) ...counts.keys,
    }.toList()..sort();

    var maxValue = 1;
    for (final counts in perTeacherMonth.values) {
      for (final value in counts.values) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // `stretch` verilirse yatay kaydırma içinde sonsuz genişlik
            // oluşur. Sütun genişlikleri zaten başlıkta tanımlı ve her
            // satırda aynı, bu yüzden sarma yok.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(months),
              for (var index = 0; index < teachers.length; index++)
                _buildRow(teachers[index], months, index, maxValue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<int> months) {
    Widget cell(String label, {double width = _monthWidth, Color? color}) {
      return SizedBox(
        width: width,
        height: _headerHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
            border: const Border(
              right: BorderSide(color: AppColors.inputBorder),
              bottom: BorderSide(color: AppColors.inputBorder),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.secondaryText,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          cell('Öğretmen', width: _nameWidth),
          for (final month in months)
            cell(dutyMonthName(month).substring(0, 3)),
          cell('Toplam', width: _totalWidth, color: AppColors.primaryDark),
        ],
      ),
    );
  }

  Widget _buildRow(
    DutyTeacher teacher,
    List<int> months,
    int index,
    int maxValue,
  ) {
    final perMonth = perTeacherMonth[teacher.id] ?? const {};
    final total = perMonth.values.fold<int>(0, (a, b) => a + b);
    // Zebra şerit, gözün satırı sütunlar boyunca takip etmesini sağlar.
    final background = index.isOdd
        ? AppColors.cardSurface.withValues(alpha: 0.45)
        : Colors.transparent;

    Widget cell(Widget child, {double width = _monthWidth, bool isTotal = false}) {
      return SizedBox(
        width: width,
        height: _rowHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isTotal
                ? AppColors.primary.withValues(alpha: 0.06)
                : background,
            border: const Border(
              right: BorderSide(color: AppColors.inputBorder),
              bottom: BorderSide(color: AppColors.inputBorder),
            ),
          ),
          child: Center(child: child),
        ),
      );
    }

    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _nameWidth,
            height: _rowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: const Border(
                  right: BorderSide(color: AppColors.inputBorder),
                  bottom: BorderSide(color: AppColors.inputBorder),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: dutyTeacherFill(teacher.id),
                      child: Text(
                        dutyTeacherInitials(teacher.fullName),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    // Tercih rengi: nöbet isteğini satır başında belirtir.
                    Container(
                      width: 3,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _preferenceColor(teacher.dutyPreference),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          Text(
                            teacher.dutyPreference.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.15,
                              color: _preferenceColor(
                                teacher.dutyPreference,
                              ).withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final month in months)
            cell(_countCell(perMonth[month] ?? 0, maxValue)),
          cell(
            Text(
              '$total',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            width: _totalWidth,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _countCell(int value, int maxValue) {
    if (value == 0) {
      // Nöbet alınmayan hücre sessiz kalmasın diye soluk gösterilir.
      return const Text(
        '·',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryText,
        ),
      );
    }
    return Text(
      '$value',
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: value >= maxValue ? FontWeight.w800 : FontWeight.w600,
        color: value >= maxValue ? AppColors.primaryDark : AppColors.darkText,
      ),
    );
  }

  static Color _preferenceColor(DutyPreference preference) {
    return switch (preference) {
      DutyPreference.minimum => AppColors.secondaryText,
      DutyPreference.balanced => AppColors.primary,
      DutyPreference.maximum => AppColors.lavender,
    };
  }
}

class _StatsEmpty extends StatelessWidget {
  const _StatsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          'Gösterilecek veri yok',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
      ),
    );
  }
}