import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';

/// Pencere doldurulduğunda döner; `null` vazgeçildiği anlamına gelir.
class StudentArchiveRequest {
  const StudentArchiveRequest({
    required this.exitDate,
    required this.reason,
    required this.otherReason,
  });

  final DateTime exitDate;

  /// Seçilen hazır sebep.
  final String reason;

  /// "Diğer" seçildiyse kullanıcının yazdığı açıklama.
  final String otherReason;

  /// Veritabanına yazılacak sebep metni.
  String get resolvedReason =>
      otherReason.trim().isEmpty ? reason : '$reason: ${otherReason.trim()}';
}

/// Sık kullanılan ayrılış sebepleri.
const List<String> kStudentArchiveReasons = [
  'Mezun oldu',
  'Okul değişikliği',
  'Nakil / transfer',
  'Veli isteğiyle ayrıldı',
  'Devamsızlık',
  'Sağlık nedeniyle ayrıldı',
  'Diğer',
];

const String _otherReasonValue = 'Diğer';

/// Öğrenciyi silmeden pansiyondan ayrılmak için açılan pencere.
///
/// Ayrılış tarihi ve sebebi sorulur; okul kaydı ve geçmiş veriler korunur.
class ArchiveStudentDialog extends StatefulWidget {
  const ArchiveStudentDialog({
    super.key,
    required this.studentName,
    required this.registrationDate,
  });

  final String studentName;

  /// Pansiyona kayıt tarihi; ayrılış bundan önce olamaz.
  final DateTime? registrationDate;

  @override
  State<ArchiveStudentDialog> createState() => _ArchiveStudentDialogState();
}

class _ArchiveStudentDialogState extends State<ArchiveStudentDialog> {
  DateTime? _exitDate;
  String? _reason;
  final TextEditingController _otherController = TextEditingController();
  String? _errorText;

  bool get _isOther => _reason == _otherReasonValue;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = widget.registrationDate ?? DateTime(now.year - 10);
    final picked = await showAppDatePicker(
      context,
      initialDate: now,
      firstDate: first,
      lastDate: now,
      helpText: 'Pansiyondan ayrılış tarihi',
    );
    if (picked != null) {
      setState(() {
        _exitDate = picked;
        _errorText = null;
      });
    }
  }

  void _submit() {
    if (_exitDate == null) {
      setState(() => _errorText = 'Ayrılış tarihi seçin.');
      return;
    }
    if (_reason == null) {
      setState(() => _errorText = 'Ayrılış sebebini seçin.');
      return;
    }
    if (_isOther && _otherController.text.trim().isEmpty) {
      setState(() => _errorText = 'Sebebi yazın.');
      return;
    }
    Navigator.of(context).pop(
      StudentArchiveRequest(
        exitDate: _exitDate!,
        reason: _reason!,
        otherReason: _isOther ? _otherController.text : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Öğrenciyi arşivle'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.studentName} pansiyondan ayrılıyor. Kayıt silinmez, '
                'arşive alınır; geçmişi istendiğinde geri getirilebilir.',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              AppDateField(
                fieldKey: const Key('archive_exit_date_field'),
                label: 'Pansiyondan Ayrılış Tarihi',
                value: _exitDate,
                placeholder: 'Tarih seçin',
                errorText: _exitDate == null ? _errorText : null,
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              AppDropdown<String>(
                key: const Key('archive_reason_dropdown'),
                value: _reason,
                helperText: 'Ayrılış sebebini seçin',
                errorText: _exitDate != null ? _errorText : null,
                items: [
                  for (final reason in kStudentArchiveReasons)
                    DropdownMenuItem(value: reason, child: Text(reason)),
                ],
                onChanged: (value) => setState(() {
                  _reason = value;
                  _errorText = null;
                }),
              ),
              if (_isOther) ...[
                const SizedBox(height: 14),
                TextField(
                  key: const Key('archive_other_reason_field'),
                  controller: _otherController,
                  maxLines: 2,
                  onChanged: (_) => setState(() => _errorText = null),
                  decoration: const InputDecoration(
                    labelText: 'Sebebi yazın',
                    hintText: 'örn. Aile taşınması',
                    isDense: true,
                  ),
                ),
              ],
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
          key: const Key('archive_confirm_button'),
          onPressed: _submit,
          child: const Text('Arşivle'),
        ),
      ],
    );
  }
}
