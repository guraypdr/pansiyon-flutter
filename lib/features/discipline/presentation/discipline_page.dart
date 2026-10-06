import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';

class DisciplinePage extends StatefulWidget {
  const DisciplinePage({super.key, required this.repository});

  final StudentRepository repository;

  @override
  State<DisciplinePage> createState() => _DisciplinePageState();
}

class _DisciplinePageState extends State<DisciplinePage> {
  List<Student> _students = const [];
  List<StudentDisciplineIncident> _incidents = const [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.repository.getStudents(),
        widget.repository.getAllDisciplineIncidents(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _students = results[0] as List<Student>;
        _incidents = results[1] as List<StudentDisciplineIncident>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Disiplin kayıtları yüklenemedi.', AppNotificationTone.error);
    }
  }

  List<StudentDisciplineIncident> get _visibleIncidents {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _incidents;
    }
    return _incidents
        .where(
          (incident) =>
              (incident.studentName ?? '').toLowerCase().contains(query) ||
              incident.description.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  String get _summaryLine {
    final total = _incidents.length;
    final students = _incidents
        .map((incident) => incident.studentId)
        .toSet()
        .length;
    return '$total kayıt • $students öğrenci';
  }

  Future<void> _openForm([StudentDisciplineIncident? incident]) async {
    if (_students.isEmpty) {
      _notify('Önce öğrenci eklemelisiniz.', AppNotificationTone.error);
      return;
    }
    final result = await showDialog<_DisciplineInput>(
      context: context,
      builder: (dialogContext) =>
          _DisciplineDialog(students: _students, incident: incident),
    );
    if (result == null) {
      return;
    }
    try {
      await widget.repository.saveDisciplineIncident(
        StudentDisciplineIncident(
          studentId: result.studentId,
          date: result.date,
          description: result.description,
        ),
      );
      _notify('Kayıt eklendi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Kayıt eklenemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _delete(StudentDisciplineIncident incident) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text('Bu disiplin kaydı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || incident.id == null || !mounted) {
      return;
    }
    try {
      await widget.repository.deleteDisciplineIncident(incident.id!);
      _notify('Kayıt silindi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Kayıt silinemedi.', AppNotificationTone.error);
    }
  }

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final visible = _visibleIncidents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disiplin Kayıtları',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summaryLine,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 260,
                height: 40,
                child: TextField(
                  key: const Key('discipline_search_field'),
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Öğrenci veya açıklama ara',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('add_discipline_button'),
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Kayıt ekle'),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gavel_outlined,
                        size: 46,
                        color: AppColors.lavender,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Disiplin kaydı yok',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Öğrenci ekleyerek ilk kaydı oluşturabilirsiniz.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final incident = visible[index];
                    return _DisciplineCard(
                      incident: incident,
                      onEdit: () => _openForm(incident),
                      onDelete: () => _delete(incident),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({
    required this.incident,
    required this.onEdit,
    required this.onDelete,
  });

  final StudentDisciplineIncident incident;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('discipline_card_${incident.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.errorFeedback.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.gavel_outlined,
              size: 20,
              color: AppColors.errorFeedback,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        incident.studentName ?? 'Bilinmeyen öğrenci',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppDateField.formatDate(incident.date),
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  incident.description,
                  style: const TextStyle(fontSize: 13.5, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('discipline_edit_${incident.id}'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Düzenle',
          ),
          IconButton(
            key: Key('discipline_delete_${incident.id}'),
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.errorFeedback,
            ),
            tooltip: 'Sil',
          ),
        ],
      ),
    );
  }
}

class _DisciplineInput {
  const _DisciplineInput({
    required this.studentId,
    required this.date,
    required this.description,
  });

  final int studentId;
  final DateTime date;
  final String description;
}

class _DisciplineDialog extends StatefulWidget {
  const _DisciplineDialog({required this.students, this.incident});

  final List<Student> students;
  final StudentDisciplineIncident? incident;

  @override
  State<_DisciplineDialog> createState() => _DisciplineDialogState();
}

class _DisciplineDialogState extends State<_DisciplineDialog> {
  late int _studentId = widget.students.first.id!;
  late DateTime _date = widget.incident?.date ?? DateTime.now();
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.incident?.description ?? '');

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showAppDatePicker(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Olay tarihi',
    );
    if (date != null) {
      setState(() => _date = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.incident == null ? 'Disiplin kaydı ekle' : 'Kaydı düzenle',
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineDropdown<int>(
              key: const Key('discipline_student_field'),
              value: _studentId,
              isExpanded: true,
              items: [
                for (final student in widget.students)
                  DropdownMenuItem(
                    value: student.id!,
                    child: Text(student.fullName),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _studentId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('discipline_date_button'),
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text('Tarih: ${AppDateField.formatDate(_date)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('discipline_description_field'),
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Olay açıklaması'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final description = _descriptionController.text.trim();
            if (description.isEmpty) {
              AppNotifier.instance.show(
                context,
                message: 'Açıklama giriniz.',
                tone: AppNotificationTone.error,
              );
              return;
            }
            Navigator.of(context).pop(
              _DisciplineInput(
                studentId: _studentId,
                date: _date,
                description: description,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
