import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';

/// Bir günün menüsünü oluşturmak veya düzenlemek için kullanılan pencere.
///
/// Dört öğünün yemekleri satır satır yazılır veya düzenlenir; kaydedildiğinde
/// menü güncellenir veya yeni gün olarak veritabanına eklenir.
class MealEditDialog extends StatefulWidget {
  const MealEditDialog({
    super.key,
    required this.repository,
    this.day,
    this.initialDate,
  });

  final MealRepository repository;

  /// Düzenlenecek gün; verilmezse yeni gün ekleme modunda çalışır.
  final MealDay? day;

  /// Yeni gün ekleme modunda başlangıç tarihi (varsayılan: bugün).
  final DateTime? initialDate;

  @override
  State<MealEditDialog> createState() => _MealEditDialogState();
}

class _MealEditDialogState extends State<MealEditDialog> {
  late DateTime _selectedDate;
  late final Map<MealType, TextEditingController> _controllers;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  bool get _isEditing => widget.day != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.day?.date ?? widget.initialDate ?? DateTime.now();
    _controllers = {
      for (final type in MealType.values)
        type: TextEditingController(
          text: widget.day != null ? widget.day!.mealsOf(type).join('\n') : '',
        ),
    };

    // Dinleyici ekleyerek satır sayısı değiştikçe rozetleri tazeleriz.
    for (final controller in _controllers.values) {
      controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_onTextChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: _isEditing ? 'Menü tarihini değiştir' : 'Menü tarihi seçin',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  int _countLines(MealType type) {
    return _parseItems(type).length;
  }

  List<String> _parseItems(MealType type) {
    final text = _controllers[type]?.text ?? '';
    return splitMealItems(text);
  }

  void _clearMeal(MealType type) {
    _controllers[type]?.clear();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Menüyü sil'),
        content: Text(
          '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year} '
          '${mealWeekdayName(_selectedDate)} gününün menüsü silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await widget.repository.deleteDay(_selectedDate);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = 'Menü silinirken bir hata oluştu.';
        });
      }
    }
  }

  Future<void> _save() async {
    final items = <MealType, MealItems>{};
    for (final type in MealType.values) {
      final parsed = _parseItems(type);
      if (parsed.isNotEmpty) {
        items[type] = parsed;
      }
    }

    final updatedDay = MealDay(
      id: widget.day?.id,
      date: _selectedDate,
      items: items,
    );

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.saveDay(updatedDay);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Menü kaydedilemedi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateTitle =
        '${_selectedDate.day} ${mealMonthName(_selectedDate.month)} ${_selectedDate.year}, '
        '${mealWeekdayName(_selectedDate)}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Column(
          children: [
            _buildDialogHeader(dateTitle),
            const Divider(height: 1, color: AppColors.inputBorder),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDateBanner(dateTitle),
                    const SizedBox(height: 14),
                    _buildHelpHint(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorFeedback.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.errorFeedback.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.errorFeedback,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.errorFeedback,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildMealInputsGrid(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.inputBorder),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(String dateTitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Günü Düzenle' : 'Yeni Menü Ekle',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateTitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('meal_edit_close_button'),
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBanner(String dateTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tarih',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                Text(
                  dateTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('meal_edit_pick_date_button'),
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('Değiştir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Her öğün için yemekleri alt alta satırlar hâlinde yazın. '
              'Boş bırakılan öğünler menüye dâhil edilmez.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealInputsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;

        final breakfastBox = _buildMealBox(
          type: MealType.breakfast,
          icon: Icons.wb_sunny_outlined,
          color: const Color(0xFFD97706),
          hint: 'Örn:\nHaşlanmış Yumurta\nBeyaz Peynir\nSiyah Zeytin\nDomates, Salatalık',
        );
        final lunchBox = _buildMealBox(
          type: MealType.lunch,
          icon: Icons.lunch_dining_outlined,
          color: const Color(0xFF0D9488),
          hint: 'Örn:\nMercimek Çorbası\nOrman Kebabı\nPirinç Pilavı\nAyran',
        );
        final dinnerBox = _buildMealBox(
          type: MealType.dinner,
          icon: Icons.nights_stay_outlined,
          color: const Color(0xFF4F46E5),
          hint: 'Örn:\nTarhana Çorbası\nKuru Fasulye\nBulgur Pilavı\nCacık',
        );
        final snackBox = _buildMealBox(
          type: MealType.snack,
          icon: Icons.local_cafe_outlined,
          color: const Color(0xFFDB2777),
          hint: 'Örn:\nElma\nSüt',
        );

        if (!isWide) {
          return Column(
            children: [
              breakfastBox,
              const SizedBox(height: 12),
              lunchBox,
              const SizedBox(height: 12),
              dinnerBox,
              const SizedBox(height: 12),
              snackBox,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: breakfastBox),
                const SizedBox(width: 14),
                Expanded(child: lunchBox),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: dinnerBox),
                const SizedBox(width: 14),
                Expanded(child: snackBox),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMealBox({
    required MealType type,
    required IconData icon,
    required Color color,
    required String hint,
  }) {
    final count = _countLines(type);
    final controller = _controllers[type]!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: count > 0
                      ? color.withValues(alpha: 0.12)
                      : AppColors.inputBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count > 0 ? '$count yemek' : 'Boş',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: count > 0 ? color : AppColors.secondaryText,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: Key('meal_edit_clear_${type.value}'),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  tooltip: 'Öğünü temizle',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  color: AppColors.secondaryText,
                  onPressed: () => _clearMeal(type),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: Key('meal_edit_input_${type.value}'),
            controller: controller,
            maxLines: 5,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkText,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText.withValues(alpha: 0.55),
                height: 1.35,
              ),
              filled: true,
              fillColor: AppColors.appBackground.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (_isEditing)
            TextButton.icon(
              key: const Key('meal_edit_delete_day_button'),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Günü Sil'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorFeedback,
              ),
              onPressed: _isSaving || _isDeleting ? null : _delete,
            ),
          const Spacer(),
          AppSecondaryButton(
            key: const Key('meal_edit_cancel_button'),
            label: 'Vazgeç',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: 10),
          AppPrimaryButton(
            key: const Key('meal_edit_save_button'),
            label: 'Kaydet',
            icon: Icons.check_rounded,
            isLoading: _isSaving,
            onPressed: _isSaving || _isDeleting ? null : _save,
          ),
        ],
      ),
    );
  }
}
