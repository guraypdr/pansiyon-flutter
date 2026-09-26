import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';

class StudentImportDialog extends StatelessWidget {
  const StudentImportDialog({super.key, required this.preview});

  final StudentImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final missingRows = preview.rows
        .where((row) => row.missingFields.contains('Ad Soyad'))
        .length;
    return AlertDialog(
      title: const Text('Excel Öğrenci Önizleme'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${preview.rows.length} satır okundu. '
              '${preview.importableCount} öğrenci içe aktarılabilir.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'En fazla ${StudentExcelImporter.maxDataRows} veri satırı desteklenir.',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
            if (missingRows > 0)
              Text(
                '$missingRows satırda Ad Soyad eksik olduğu için atlanacak.',
                style: const TextStyle(color: AppColors.errorFeedback),
              ),
            if (preview.headerWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Başlık uyarıları: ${preview.headerWarnings.join(', ')}',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: preview.rows.isEmpty
                  ? const Center(
                      child: Text('İçe aktarılacak satır bulunamadı.'),
                    )
                  : ListView.separated(
                      itemCount: preview.rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = preview.rows[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text('${row.rowNumber}'),
                          ),
                          title: Text(
                            row.student.fullName.isEmpty
                                ? 'Adsız satır'
                                : row.student.fullName,
                          ),
                          subtitle: Text(
                            row.missingFields.isEmpty
                                ? 'Tüm temel alanlar dolu'
                                : 'Eksik: ${row.missingFields.join(', ')}',
                          ),
                          trailing: row.missingFields.contains('Ad Soyad')
                              ? const Icon(
                                  Icons.warning_amber,
                                  color: AppColors.errorFeedback,
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.successFeedback,
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: preview.importableCount == 0
              ? null
              : () => Navigator.pop(context, true),
          icon: const Icon(Icons.upload_file),
          label: const Text('İçe Aktar'),
        ),
      ],
    );
  }
}
