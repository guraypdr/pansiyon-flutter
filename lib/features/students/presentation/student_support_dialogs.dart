import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

class SchoolSettingsDialog extends StatefulWidget {
  const SchoolSettingsDialog({super.key, required this.repository});

  final StudentRepository repository;

  @override
  State<SchoolSettingsDialog> createState() => _SchoolSettingsDialogState();
}

class _SchoolSettingsDialogState extends State<SchoolSettingsDialog> {
  final _nameController = TextEditingController();
  List<School> _schools = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSchools() async {
    final schools = await widget.repository.getSchools();
    if (mounted) {
      setState(() {
        _schools = schools;
        _isLoading = false;
      });
    }
  }

  Future<void> _addSchool() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Okul adı boş olamaz.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.saveSchool(School(name: name));
      _nameController.clear();
      await _loadSchools();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Okul eklenemedi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Okul Ayarları'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Yeni okul adı',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              onSubmitted: (_) => _addSchool(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.errorFeedback),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _schools.isEmpty
                  ? const Center(child: Text('Henüz okul eklenmedi.'))
                  : ListView.separated(
                      itemCount: _schools.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final school = _schools[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.school_outlined),
                          title: Text(school.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, true),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _addSchool,
          icon: const Icon(Icons.add),
          label: const Text('Okul Ekle'),
        ),
      ],
    );
  }
}

class StudentDisciplineDialog extends StatefulWidget {
  const StudentDisciplineDialog({
    super.key,
    required this.student,
    required this.repository,
  });

  final Student student;
  final StudentRepository repository;

  @override
  State<StudentDisciplineDialog> createState() =>
      _StudentDisciplineDialogState();
}

class _StudentDisciplineDialogState extends State<StudentDisciplineDialog> {
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _date = date);
    }
  }

  Future<void> _save() async {
    if (widget.student.id == null) {
      return;
    }
    setState(() => _isSaving = true);
    await widget.repository.saveDisciplineIncident(
      StudentDisciplineIncident(
        studentId: widget.student.id!,
        date: _date,
        description: _descriptionController.text.trim().isEmpty
            ? 'Detayı henüz belirlenmedi.'
            : _descriptionController.text.trim(),
      ),
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.student.fullName} - Disiplin Kaydı'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: const Text('Olay tarihi'),
              subtitle: Text(_formatDate(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Olay açıklaması',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Kaydediliyor' : 'Kaydet'),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}.$month.$day';
  }
}
