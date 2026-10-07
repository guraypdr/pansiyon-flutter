import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/student_gender_figure.dart';

/// Öğrenciyi tek satırda gösteren kompakt liste satırı.
///
/// Hem Öğrenciler listesinde hem de Odalar sayfasındaki oda kartlarında
/// kullanılır. **Taşma olmaması için** ad ve alt satır birlikte esnek
/// alana konur: sabit genişlikli ikinci bir metin eklemek adı ezip
/// `RenderFlex` taşması üretiyordu.
class StudentListRow extends StatefulWidget {
  const StudentListRow({
    super.key,
    required this.student,
    this.subtitle,
    this.trailing,
    this.onOpenDetail,
    this.onEdit,
    this.onDelete,
    this.figureSize = 30,
    this.showActions = true,
    this.dense = false,
    this.height,
  });

  final Student student;

  /// Adın altında gösterilen ikincil metin (sınıf/şube gibi).
  final String? subtitle;

  /// Sağda sabit duran içerik (oda rozeti gibi).
  final Widget? trailing;

  final VoidCallback? onOpenDetail;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final double figureSize;

  /// `false` ise düzenleme/sil düğmeleri hiç gösterilmez.
  final bool showActions;

  /// Oda kartı gibi dar yükseklikli satırlar için.
  final bool dense;

  /// Verilirse satır bu yüksekliğe sabitlenir. Oda kartlarında tüm satırların
  /// eşit olması için gereklidir; `null` ise yükseklik içeriğe göre belirlenir.
  final double? height;

  @override
  State<StudentListRow> createState() => _StudentListRowState();
}

class _StudentListRowState extends State<StudentListRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final subtitle = widget.subtitle?.trim() ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onOpenDetail,
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: widget.key ?? Key('student_row_${student.id}'),
          height: widget.height,
          alignment: widget.height == null
              ? null
              : Alignment.centerLeft,
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 6 : 10,
            vertical: widget.dense ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.cardSurfaceAccent.withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              StudentGenderFigure(
                gender: student.gender,
                size: widget.figureSize,
              ),
              const SizedBox(width: 10),
              // Ad ve alt satır aynı esnek alanı paylaşır; ikisi de
              // `ellipsis` ile kırpılır, hiçbir koşulda taşma olmaz.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: widget.dense ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: widget.dense ? 11 : 11.5,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
              if (widget.showActions) _Actions(hovered: _isHovered, widget: widget),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satırın sağındaki düzenleme / sil düğmeleri.
///
/// Üzerine gelmede görünür olur; `AnimatedOpacity` yer alanı korur, bu
/// yüzden adın genişliği değişmez ve satır zıplamaz.
class _Actions extends StatelessWidget {
  const _Actions({required this.hovered, required this.widget});

  final bool hovered;
  final StudentListRow widget;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    return AnimatedOpacity(
      opacity: hovered ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onEdit != null)
            _RowIconAction(
              actionKey: Key('student_edit_${student.id}'),
              tooltip: 'Düzenle',
              icon: Icons.edit_outlined,
              onPressed: widget.onEdit!,
            ),
          if (widget.onDelete != null)
            _RowIconAction(
              actionKey: Key('student_delete_${student.id}'),
              tooltip: 'Sil',
              icon: Icons.delete_outline,
              color: AppColors.errorFeedback,
              onPressed: widget.onDelete!,
            ),
        ],
      ),
    );
  }
}

class _RowIconAction extends StatelessWidget {
  const _RowIconAction({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      icon: Icon(icon, size: 17, color: color ?? AppColors.secondaryText),
    );
  }
}

/// Oda numarası rozeti. Atamasız öğrenci rozet göstermez.
class RoomNumberBadge extends StatelessWidget {
  const RoomNumberBadge({super.key, required this.label, this.tone});

  final String label;

  /// Boş / dolu / normal göstergesi için renk tonu.
  final RoomBadgeTone? tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      RoomBadgeTone.empty => (
        AppColors.successFeedback.withValues(alpha: 0.14),
        AppColors.successFeedback,
      ),
      RoomBadgeTone.full => (
        AppColors.errorFeedback.withValues(alpha: 0.14),
        AppColors.errorFeedback,
      ),
      RoomBadgeTone.neutral => (AppColors.cardSurfaceAccent, AppColors.darkText),
      null => (AppColors.cardSurfaceAccent, AppColors.darkText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum RoomBadgeTone { empty, full, neutral }

/// Oda kartının geometrisi.
///
/// Kartlar `Wrap` içinde yan yana dizildiği için hepsi aynı yükseklikte
/// olmalıdır; aksi halde alt kenarları basamaklanır. Yükseklik, kartta
/// görünebilecek en fazla öğrenci satırından hesaplanır ve tüm kartlara aynı
/// değer verilir. Böylece boş odalar da dolu odalarla hizalı kalır.
class RoomCardMetrics {
  const RoomCardMetrics._({
    required this.cardHeight,
    required this.listHeight,
    required this.rowHeight,
    required this.rows,
  });

  /// Kartın dış yüksekliği.
  final double cardHeight;

  /// Öğrenci listesine ayrılan, tüm kartlarda eşit alan.
  final double listHeight;

  /// Tek öğrenci satırının yüksekliği.
  final double rowHeight;

  /// Kaç satır sığdığı.
  final int rows;

  /// Dikey boşluklar: kart dolgusu, başlık satırı ve ayırıcı.
  static const double _paddingTop = 11;
  static const double _paddingBottom = 12;
  static const double _headerRow = 40;

  /// Ayırıcının çevresindeki boşluk: 6 + 1 (çizgi) + 4.
  static const double _dividerGap = 11;

  /// Liste alanına eklenen pay.
  ///
  /// Satır yükseklikleri tam sayı olsa da liste alanı `Expanded` ile kartın
  /// kalanından hesaplanır ve piksel yuvarlaması birkaç piksel fark
  /// yaratabilir. Pay olmadan liste, o fark kadar taşıyordu.
  static const double _slack = 6;

  /// En küçük satır sayısı: oda numarası ve boş etiketi için yer bırakılır.
  static const int minRows = 2;

  /// Verilen satır sayısına göre sabit geometri üretir.
  ///
  /// Üst sınır **yoktur**: satır sayısı her zaman o panodaki en kalabalık
  /// odayı da kapsar, bu yüzden hiçbir öğrenci kırpılmaz ve kartta
  /// kaydırma çubuğuna gerek kalmaz.
  factory RoomCardMetrics.forRows(int rows) {
    final clamped = rows < minRows ? minRows : rows;
    const rowHeight = 40.0;
    final listHeight = rowHeight * clamped;
    return RoomCardMetrics._(
      cardHeight:
          _paddingTop +
          _headerRow +
          _dividerGap +
          listHeight +
          _slack +
          _paddingBottom,
      listHeight: listHeight,
      rowHeight: rowHeight,
      rows: clamped,
    );
  }

  /// Görüntülenen odaların en büyük kapasitesinden (ve en kalabalık odadan)
  /// hareketle ortak geometri hesaplar.
  ///
  /// [rooms] ve [occupancy] aynı sırada olmalıdır. Kapasiteden büyük bir
  /// atama varsa taşma olmaması için o değer de hesaba katılır.
  factory RoomCardMetrics.forRooms(
    List<int> capacities,
    List<int> occupancy,
  ) {
    var rows = 2;
    for (var index = 0; index < capacities.length; index++) {
      final byCapacity = capacities[index];
      final byStudents = index < occupancy.length ? occupancy[index] : 0;
      rows = rows > byCapacity ? rows : byCapacity;
      rows = rows > byStudents ? rows : byStudents;
    }
    return RoomCardMetrics.forRows(rows);
  }
}

/// İçinde oda kartı sıralanan başlık şeridi.
class RoomGroupHeader extends StatelessWidget {
  const RoomGroupHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Oda kartlarını, genişliği bir alt sınırın altına düşürmeden dizer.
///
/// Kartlar `Wrap` içinde sabit genişlikte durur; pencere darsa tek sütuna
/// iner, hiçbir zaman okunamayacak kadar daralmaz.
class ResponsiveCardWrap extends StatelessWidget {
  const ResponsiveCardWrap({
    super.key,
    required this.children,
    this.minCardWidth = 296,
    this.maxCardWidth = 420,
    this.spacing = 12,
  });

  final List<Widget> children;

  /// Kartın alabileceği en küçük genişlik. Uzun adlar buraya göre seçildi.
  final double minCardWidth;

  /// Geniş pencerede kartın büyüyebileceği sınır.
  final double maxCardWidth;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (available <= 0) {
          return const SizedBox.shrink();
        }
        // Kaç kart sığar? En az bir kart `minCardWidth` almalı.
        var columns = ((available + spacing) / (minCardWidth + spacing)).floor();
        if (columns < 1) columns = 1;
        final desired = ((available - spacing * (columns - 1)) / columns).clamp(
          minCardWidth,
          maxCardWidth,
        );
        // Panel alt sınırın daralırsa (örneğin öğrenci havuzu açıkken) kart
        // taşmasın diye mevcut alana kırpılır.
        final width = desired > available ? available : desired;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}