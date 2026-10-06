import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_labelled_field.dart';

/// Proje temasıyla uyumlu açılır liste alanı.
///
/// Tüm sayfalardaki açılır listeler bu bileşeni kullanır; böylece etiket
/// stili, içerik dolgusu, kenarlık yarıçapı, açılır menü rengi ve seçili
/// değer metni her yerde aynı görünür.
///
/// [placeholder] verilirse listenin başına `null` değerli bir "seçilmedi"
/// satırı eklenir; alanın boş bırakılması bu satırla ifade edilir.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.validator,
    this.enabled = true,
    this.isExpanded = true,
  });

  /// Seçili değer. `null` olabilir.
  final T? value;

  /// Seçenekler. `null` değerli bir öğe kullanmayın; [placeholder] kullanın.
  final List<DropdownMenuItem<T>> items;

  final ValueChanged<T?>? onChanged;

  /// Alan üstünde gösterilen etiket.
  final String? label;

  /// Başa eklenecek "seçilmedi" metni.
  final String? placeholder;

  final String? helperText;

  /// Form dışından verilen hata metni.
  ///
  /// Sihirbaz gibi doğrulamayı kendi yöneten ekranlar `validator` yerine
  /// bunu kullanır.
  final String? errorText;

  final FormFieldValidator<T?>? validator;
  final bool enabled;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final allItems = <DropdownMenuItem<T>>[
      if (placeholder != null)
        DropdownMenuItem<T>(
          value: null,
          child: Text(
            placeholder!,
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        ),
      ...items,
    ];

    final field = DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: isExpanded,
      decoration: appInputDecoration(
        helperText: helperText,
        errorText: errorText,
      ),
      items: allItems,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      style: AppTheme.inputTextStyle,
      dropdownColor: AppColors.surface,
      iconEnabledColor: AppColors.secondaryText,
      iconDisabledColor: AppColors.inputBorder,
      icon: const Icon(Icons.expand_more_rounded, size: 22),
    );

    if (label == null || label!.trim().isEmpty) {
      return field;
    }
    return AppLabelledField(label: label!, child: field);
  }
}

/// Çerçevesiz, satır içi açılır liste.
///
/// Filtre çubukları ve çizelge hücreleri gibi dar alanlarda etiketli form
/// alanı yerine kullanılır; kenar çizgisi olmadığı için hücreye sığar.
class AppInlineDropdown<T> extends StatelessWidget {
  const AppInlineDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.textStyle,
    this.fontSize = 13,
    this.isExpanded = true,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// Değer seçilmediğinde gösterilen metin.
  final String? hint;

  /// Seçili değerin yazı tipi. Verilmezse tema metin rengi kullanılır.
  final TextStyle? textStyle;

  final double fontSize;

  /// Seçilen değerin satırı doldurup doldurmayacağı.
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: isExpanded,
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        dropdownColor: AppColors.surface,
        iconEnabledColor: AppColors.secondaryText,
        style:
            textStyle ??
            TextStyle(color: AppColors.darkText, fontSize: fontSize),
        hint: hint == null
            ? null
            : Text(
                hint!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: fontSize,
                ),
              ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
