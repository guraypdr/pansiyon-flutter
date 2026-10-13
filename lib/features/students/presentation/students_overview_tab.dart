import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_completeness.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_list_row.dart';
import 'package:pansiyon_yonetim/shared/widgets/student_gender_figure.dart';

/// Öğrenciler sayfasının liste modülü.
///
/// İstatistik şeridi, süzgeçler ve kayıt listesini barındırır. Süzgeç
/// durumu bu modülün kendisinde tutulur; arama sorgusu sunucu tarafında
/// çalıştığı için [onSearchChanged] ile dışarıya bildirilir.
class StudentsOverviewTab extends StatefulWidget {
  const StudentsOverviewTab({
    super.key,
    required this.students,
    required this.classLevels,
    required this.schools,
    required this.roomOf,
    required this.showArchived,
    required this.onShowArchivedChanged,
    required this.onSearchChanged,
    required this.onFilterStatsChanged,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
  });

  /// Sunucudan süzülmüş olarak gelen öğrenciler.
  final List<Student> students;
  final List<String> classLevels;
  final List<School> schools;
  final BoardingRoom? Function(int studentId) roomOf;

  /// Arşivlenen öğrenciler listede görünüyor mu?
  final bool showArchived;

  /// Arşiv çipi değiştiğinde çağrılır; sayfa listeyi yeniden yükler.
  final ValueChanged<bool> onShowArchivedChanged;

  /// Arama metni değiştiğinde çağrılır; sayfa listeyi yeniden yükler.
  final ValueChanged<String> onSearchChanged;

  /// Süzgeç durumu değiştiğinde çağrılır; sayfa başlık özetini günceller.
  ///
  /// Süzgeçler bu modülün kendi durumunda tutulduğu için, görünen öğrenci
  /// sayısı ve süzgeç etkinliği dışarıya bildirilir.
  final void Function({
    required int visibleCount,
    required int totalCount,
    required bool hasActiveFilters,
  }) onFilterStatsChanged;

  final void Function(Student student) onOpenDetail;
  final void Function(Student student) onEdit;
  final void Function(Student student) onDelete;
  final void Function(Student student) onArchive;

  @override
  State<StudentsOverviewTab> createState() => _StudentsOverviewTabState();
}

class _StudentsOverviewTabState extends State<StudentsOverviewTab> {
  String? _classFilter;
  int? _schoolFilter;
  StudentGender? _genderFilter;

  /// Süzgeçler sunucu tarafında çalışmaz; gelen liste burada daraltılır.
  List<Student> get _visibleStudents {
    return widget.students.where((student) {
      if (_classFilter != null && student.className != _classFilter) {
        return false;
      }
      if (_schoolFilter != null && student.schoolId != _schoolFilter) {
        return false;
      }
      if (_genderFilter != null && student.gender != _genderFilter) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  bool get _hasActiveFilters =>
      _classFilter != null || _schoolFilter != null || _genderFilter != null;

  void _clearFilters() {
    setState(() {
      _classFilter = null;
      _schoolFilter = null;
      _genderFilter = null;
    });
    _reportStats();
  }

  /// Süzgeç sonucunu sayfaya bildirir; başlık özeti buna göre yazılır.
  void _reportStats() {
    widget.onFilterStatsChanged(
      visibleCount: _visibleStudents.length,
      totalCount: widget.students.length,
      hasActiveFilters: _hasActiveFilters,
    );
  }

  @override
  void initState() {
    super.initState();
    // İlk özet, filtre uygulanmadan önceki (tam liste) durumu yansıtır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleStudents;
    final assignedCount = widget.students
        .where((s) => s.id != null && widget.roomOf(s.id!) != null)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.pageGutter,
            0,
            AppTokens.pageGutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StudentStatStrip(
                total: widget.students.length,
                assigned: assignedCount,
                unassigned: widget.students.length - assignedCount,
              ),
              const SizedBox(height: 14),
              _buildFilterCard(),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline,
                  title: widget.students.isEmpty
                      ? 'Henüz öğrenci eklenmemiş'
                      : 'Filtrelere uyan öğrenci yok',
                  message: widget.students.isEmpty
                      ? 'İlk öğrenciyi ekleyerek pansiyon kayıtlarını oluşturun.'
                      : 'Filtreleri temizleyerek tüm öğrencileri görebilirsiniz.',
                )
              : _StudentList(
                  students: visible,
                  roomOf: widget.roomOf,
                  onOpenDetail: widget.onOpenDetail,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                  onArchive: widget.onArchive,
                ),
        ),
      ],
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3E0C28),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _buildFilters(),
    );
  }

  Widget _buildFilters() {
    final searchField = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 340),
      child: TextField(
        key: const Key('student_search_field'),
        onChanged: widget.onSearchChanged,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Öğrenci ara',
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = <Widget>[
          _FilterButton<String>(
            filterKey: const Key('class_filter_button'),
            label: 'Sınıf',
            value: _classFilter,
            hint: 'Tümü',
            options: widget.classLevels,
            onSelected: (value) { setState(() => _classFilter = value); _reportStats(); },
          ),
          _FilterButton<int>(
            filterKey: const Key('school_filter_button'),
            label: 'Okul',
            value: _schoolFilter,
            hint: 'Tümü',
            options: [
              for (final school in widget.schools)
                if (school.id != null) school.id!,
            ],
            optionLabel: (id) {
              for (final school in widget.schools) {
                if (school.id == id) return school.name;
              }
              return '$id';
            },
            onSelected: (value) { setState(() => _schoolFilter = value); _reportStats(); },
          ),
          _FilterButton<StudentGender>(
            filterKey: const Key('gender_filter_button'),
            label: 'Cinsiyet',
            value: _genderFilter,
            hint: 'Tümü',
            options: StudentGender.values,
            optionLabel: (gender) => gender.label,
            onSelected: (value) { setState(() => _genderFilter = value); _reportStats(); },
          ),
          if (_hasActiveFilters)
            ActionChip(
              key: const Key('clear_filters_button'),
              avatar: const Icon(Icons.close, size: 16),
              label: const Text('Filtreleri temizle'),
              onPressed: _clearFilters,
            ),
          FilterChip(
            key: const Key('show_archived_chip'),
            avatar: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('Arşivlenmişler'),
            selected: widget.showArchived,
            onSelected: widget.onShowArchivedChanged,
          ),
        ];

        final wide = constraints.maxWidth >= AppTokens.compactBreakpoint;
        if (wide) {
          return Row(
            children: [
              searchField,
              const SizedBox(width: 10),
              for (final filter in filters) ...[
                filter,
                const SizedBox(width: 8),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [searchField, ...filters],
        );
      },
    );
  }
}

/// Öğrenci istatistik şeridi: toplam, yerleştirilmiş ve yerleştirilmemiş.
class _StudentStatStrip extends StatelessWidget {
  const _StudentStatStrip({
    required this.total,
    required this.assigned,
    required this.unassigned,
  });

  final int total;
  final int assigned;
  final int unassigned;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Toplam',
            value: total.toString(),
            icon: Icons.people_outline,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Yerleştirilmiş',
            value: assigned.toString(),
            icon: Icons.check_circle_outline,
            color: AppColors.successFeedback,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Yerleştirilmemiş',
            value: unassigned.toString(),
            icon: Icons.pending_outlined,
            color: const Color(0xFFB26A00),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3E0C28),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
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

/// Öğrencileri kart listesi olarak gösterir.
class _StudentList extends StatelessWidget {
  const _StudentList({
    required this.students,
    required this.roomOf,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
  });

  final List<Student> students;
  final BoardingRoom? Function(int studentId) roomOf;
  final void Function(Student student) onOpenDetail;
  final void Function(Student student) onEdit;
  final void Function(Student student) onDelete;
  final void Function(Student student) onArchive;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('student_list'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final student = students[index];
        return _StudentCard(
          student: student,
          room: student.id == null ? null : roomOf(student.id!),
          onOpenDetail: () => onOpenDetail(student),
          onEdit: () => onEdit(student),
          onDelete: () => onDelete(student),
          onArchive: () => onArchive(student),
        );
      },
    );
  }
}

/// Tek öğrenci kartı.
class _StudentCard extends StatefulWidget {
  const _StudentCard({
    required this.student,
    required this.room,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
  });

  final Student student;
  final BoardingRoom? room;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final missing = studentMissingFields(student);
    final classLabel = formatClassSectionLabel(
      student.className,
      student.sectionName,
    );
    final roomLabel = widget.room?.roomNumber.toString();

    final trailingInfo = [
      if (student.schoolName != null) student.schoolName!,
      if (student.guardianPhone != null) 'Veli: ${student.guardianPhone}',
    ].join(' • ');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onOpenDetail,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          key: Key('student_card_${student.id}'),
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surface
                : AppColors.cardSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.inputBorder,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              StudentGenderFigure(gender: student.gender, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (missing.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _MetaChip(
                            label: '${missing.length} eksik',
                            icon: Icons.warning_amber_rounded,
                            color: missing.any((f) => f.isCritical)
                                ? AppColors.errorFeedback
                                : const Color(0xFFB26A00),
                            tooltip: studentMissingSummary(missing),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (classLabel.isNotEmpty) ...[
                          _MetaChip(
                            label: classLabel,
                            icon: Icons.class_outlined,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (roomLabel != null) ...[
                          RoomNumberBadge(label: roomLabel),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            trailingInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StudentCardActions(
                studentId: student.id,
                visible: _isHovered,
                onOpenDetail: widget.onOpenDetail,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                onArchive: widget.onArchive,
                isArchived: student.isArchived,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartın sağındaki detay / düzenleme / sil düğmeleri.
class _StudentCardActions extends StatelessWidget {
  const _StudentCardActions({
    required this.studentId,
    required this.visible,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.isArchived,
  });

  final int? studentId;
  final bool visible;
  final bool isArchived;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StudentCardAction(
            actionKey: Key('student_detail_$studentId'),
            tooltip: 'Detay',
            icon: Icons.visibility_outlined,
            onPressed: onOpenDetail,
          ),
          _StudentCardAction(
            actionKey: Key('student_edit_$studentId'),
            tooltip: 'Düzenle',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          _StudentCardAction(
            actionKey: Key(
              isArchived
                  ? 'student_restore_$studentId'
                  : 'student_archive_$studentId',
            ),
            tooltip: isArchived ? 'Arşivden çıkar' : 'Arşivle',
            icon: isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            onPressed: onArchive,
          ),
          _StudentCardAction(
            actionKey: Key('student_delete_$studentId'),
            tooltip: 'Sil',
            icon: Icons.delete_outline,
            color: AppColors.errorFeedback,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _StudentCardAction extends StatelessWidget {
  const _StudentCardAction({
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
      icon: Icon(icon, size: 20, color: color ?? AppColors.secondaryText),
    );
  }
}

/// Küçük bilgi rozeti (ikon + metin, yuvarlak köşeli).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon, this.color, this.tooltip});

  final String label;
  final IconData? icon;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.secondary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    final message = tooltip;
    return message == null ? chip : Tooltip(message: message, child: chip);
  }
}

class _FilterButton<T> extends StatelessWidget {
  const _FilterButton({
    required this.filterKey,
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onSelected,
    this.optionLabel,
  });

  final Key filterKey;
  final String label;
  final T? value;
  final String hint;
  final List<T> options;
  final ValueChanged<T?> onSelected;
  final String Function(T value)? optionLabel;

  String _text(T option) => optionLabel?.call(option) ?? option.toString();

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return PopupMenuButton<int>(
      key: filterKey,
      tooltip: '$label filtresi',
      onSelected: (index) => onSelected(index == 0 ? null : options[index - 1]),
      offset: const Offset(0, 44),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.inputBorder),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<int>(value: 0, child: Text('$label: $hint')),
        for (var index = 0; index < options.length; index++)
          PopupMenuItem<int>(
            value: index + 1,
            child: Text(_text(options[index])),
          ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == null ? label : '$label: ${_text(value as T)}',
              style: TextStyle(
                color: isActive ? AppColors.primaryDark : AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}