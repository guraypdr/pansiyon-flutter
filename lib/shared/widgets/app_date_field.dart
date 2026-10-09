import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

/// Tarih seçme alanlarının ortak kullanılan biçimi.
///
/// Alanın kendisi yazılabilir değildir; dokununca [onTap] çağrılır ve
/// temaya uygun Türkçe takvim açılır.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Tarih seçin',
    this.errorText,
    this.enabled = true,
    this.fieldKey,
  });

  final String label;
  final DateTime? value;
  final String placeholder;
  final String? errorText;
  final bool enabled;
  final Key? fieldKey;
  final VoidCallback onTap;

  static String formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    final month = date.month.toString().padLeft(2, '0');
    return '${date.day} $month ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: '$label: ${hasValue ? formatDate(value) : placeholder}',
          child: InkWell(
            key: fieldKey,
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: errorText,
                prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
                suffixIcon: hasValue && enabled
                    ? IconButton(
                        tooltip: 'Tarihi temizle',
                        onPressed: onTap,
                        icon: const Icon(Icons.close, size: AppTokens.iconSm),
                      )
                    : null,
              ),
              child: Text(
                hasValue ? formatDate(value) : placeholder,
                style: TextStyle(
                  color: hasValue
                      ? AppColors.darkText
                      : AppColors.secondaryText.withValues(alpha: 0.68),
                  fontSize: 15,
                  fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tema uyumlu Türkçe tarih seçiciyi açar.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    cancelText: 'Vazgeç',
    confirmText: 'Tamam',
    errorFormatText: 'Geçersiz tarih',
    errorInvalidText: 'Bu tarih seçilemez',
    fieldHintText: 'Gün/Ay/Yıl',
    fieldLabelText: 'Tarih',
  );
}
