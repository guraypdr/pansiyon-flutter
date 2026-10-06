import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';

/// Alan etiketini giriş alanının üstüne yerleştiren ortak sarmalayıcı.
///
/// Projedeki masaüstü formlarında etiket, alanın içinde yüzen `labelText`
/// olarak değil üstte ayrı bir başlık olarak gösterilir. Bu bileşen o düzeni
/// tek yerde tanımlar; her sayfada kendi kopyası yapılmaz.
class AppLabelledField extends StatelessWidget {
  const AppLabelledField({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.trailing,
  });

  final String label;
  final Widget child;

  /// Etiketin altında küçük punto ile gösterilen açıklama.
  final String? helperText;

  /// Etiket satırının sağında gösterilecek ek bileşen.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.trim(),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 7),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

/// Proje genelinde kullanılan giriş alanı kenarlığı.
InputDecoration appInputDecoration({
  String? helperText,
  String? errorText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    helperText: helperText,
    errorText: errorText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.inputSurface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: border(AppColors.inputBorder),
    enabledBorder: border(AppColors.inputBorder),
    focusedBorder: border(AppColors.primary, 2),
    errorBorder: border(AppColors.errorFeedback),
    focusedErrorBorder: border(AppColors.errorFeedback, 2),
    disabledBorder: border(AppColors.inputBorder),
  );
}
