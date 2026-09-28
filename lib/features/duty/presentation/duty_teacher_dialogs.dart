import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_teacher_excel_importer.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

class DutyTeacherDialog extends StatefulWidget {
  const DutyTeacherDialog({super.key, this.teacher});

  final DutyTeacher? teacher;

  @override
  State<DutyTeacherDialog> createState() => _DutyTeacherDialogState();
}

class _DutyTeacherDialogState extends State<DutyTeacherDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.teacher?.fullName ?? '',
  );
  late final TextEditingController _nationalIdController =
      TextEditingController(text: widget.teacher?.nationalId ?? '');
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.teacher?.phone ?? '',
  );
  late final TextEditingController _schoolController = TextEditingController(
    text: widget.teacher?.school ?? '',
  );
  late final TextEditingController _branchController = TextEditingController(
    text: widget.teacher?.branch ?? '',
  );
  late bool _hasTraining = widget.teacher?.hasDutyTraining ?? false;
  late DutyPreference _preference =
      widget.teacher?.dutyPreference ?? DutyPreference.balanced;
  late final Set<int> _availableWeekdays = {
    ...(widget.teacher?.availableWeekdays ?? const [1, 2, 3, 4, 5]),
  };

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_availableWeekdays.contains(day)) {
        _availableWeekdays.remove(day);
      } else {
        _availableWeekdays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.teacher == null ? 'Öğretmen Ekle' : 'Öğretmeni Düzenle',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_nameController, 'Ad Soyad', 'duty_teacher_name'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _nationalIdController,
                      'T.C. Kimlik No',
                      'duty_teacher_national_id',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _phoneController,
                      'Telefon',
                      'duty_teacher_phone',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _schoolController,
                      'Okul',
                      'duty_teacher_school',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _branchController,
                      'Branş',
                      'duty_teacher_branch',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('duty_teacher_training_switch'),
                value: _hasTraining,
                onChanged: (value) => setState(() => _hasTraining = value),
                title: const Text('Beletmenlik eğitimi aldı'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 6),
              Text(
                'Nöbet isteği',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              SegmentedButton<DutyPreference>(
                key: const Key('duty_teacher_preference'),
                segments: [
                  for (final item in DutyPreference.values)
                    ButtonSegment(value: item, label: Text(item.label)),
                ],
                selected: {_preference},
                onSelectionChanged: (value) =>
                    setState(() => _preference = value.first),
              ),
              const SizedBox(height: 14),
              Text(
                'Nöbet için müsait olduğu günler',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      key: Key('duty_weekday_$day'),
                      label: Text(dutyWeekdayLabel(day).substring(0, 3)),
                      selected: _availableWeekdays.contains(day),
                      onSelected: (_) => _toggleWeekday(day),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('duty_teacher_save_button'),
          onPressed: _save,
          child: Text(widget.teacher == null ? 'Öğretmeni Ekle' : 'Kaydet'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      key: Key(key),
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotifier.instance.show(
        context,
        message: 'Ad soyad giriniz.',
        tone: AppNotificationTone.error,
      );
      return;
    }
    if (_availableWeekdays.isEmpty) {
      AppNotifier.instance.show(
        context,
        message: 'En az bir müsait gün seçiniz.',
        tone: AppNotificationTone.error,
      );
      return;
    }
    Navigator.of(context).pop(
      DutyTeacher(
        id: widget.teacher?.id,
        fullName: name,
        nationalId: _nationalIdController.text.trim().isEmpty
            ? null
            : _nationalIdController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        school: _schoolController.text.trim().isEmpty
            ? null
            : _schoolController.text.trim(),
        branch: _branchController.text.trim().isEmpty
            ? null
            : _branchController.text.trim(),
        hasDutyTraining: _hasTraining,
        dutyPreference: _preference,
        availableWeekdays: _availableWeekdays.toList()..sort(),
        isActive: widget.teacher?.isActive ?? true,
      ),
    );
  }
}

class DutyImportDialog extends StatelessWidget {
  const DutyImportDialog({super.key, required this.preview});

  final dynamic preview;

  @override
  Widget build(BuildContext context) {
    final rows = preview.rows as List<DutyTeacherImportRow>;
    final warnings = preview.headerWarnings as List<String>;
    return AlertDialog(
      title: const Text('Excel Öğretmen Önizlemesi'),
      content: SizedBox(
        width: 620,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${rows.length} satır okundu • ${preview.validCount} satır eklenecek',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
              ),
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                warnings.join(' • '),
                style: const TextStyle(
                  color: AppColors.errorFeedback,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      row.teacher.fullName.isEmpty
                          ? '(Adsız)'
                          : row.teacher.fullName,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                    subtitle: Text(
                      [
                        row.teacher.school,
                        row.teacher.branch,
                        row.teacher.dutyPreference.label,
                        row.teacher.availableWeekdayLabel,
                      ].whereType<String>().join(' • '),
                    ),
                    trailing: row.missingFields.isEmpty
                        ? const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.successFeedback,
                          )
                        : Text(
                            'Eksik: ${row.missingFields.join(', ')}',
                            style: const TextStyle(
                              color: AppColors.errorFeedback,
                              fontSize: 11.5,
                            ),
                          ),
                  );
                },
              ),
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
          key: const Key('duty_import_confirm_button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('${preview.validCount} Öğretmeni Ekle'),
        ),
      ],
    );
  }
}
