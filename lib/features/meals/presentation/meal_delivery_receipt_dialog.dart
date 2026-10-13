import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_delivery_receipt_pdf.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';

/// Günlük Yemek Malzemesi Teslim Tutanağı yazdırma iletişim penceresi.
///
/// Kullanıcı takvimden dilediği günü seçer, o günün kayıtlı menüsünü
/// görüntüler ve sayfa yönü ile satır sayısını ayarlayarak tutanak çıktısı alır.
class MealDeliveryReceiptDialog extends StatefulWidget {
  const MealDeliveryReceiptDialog({
    super.key,
    required this.repository,
    required this.schoolName,
    this.initialDate,
    this.signatures = MealReceiptSignatures.empty,
  });

  final MealRepository repository;
  final String schoolName;
  final DateTime? initialDate;

  /// Alt imza bloklarında basılacak okul geneli unvan ve adı soyadı bilgileri.
  final MealReceiptSignatures signatures;

  @override
  State<MealDeliveryReceiptDialog> createState() =>
      _MealDeliveryReceiptDialogState();
}

class _MealDeliveryReceiptDialogState extends State<MealDeliveryReceiptDialog> {
  late DateTime _selectedDate;
  MealDay? _day;
  int? _receiptNumber;
  bool _isLoadingMenu = true;
  bool _isPrinting = false;
  int _rowCount = 25;
  MealDeliveryReceiptOrientation _orientation =
      MealDeliveryReceiptOrientation.portrait;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadMenuForDate(_selectedDate);
  }

  /// Tutanak numarası: eğitim öğretim yılının eylül ayındaki ilk yemek günü
  /// `1` kabul edilir ve gün sayısı o tarihe kadar olan yemek günleriyle
  /// bulunur. Eylül, eğitim öğretim yılının başlangıç ayıdır.
  ///
  /// O tarihe kadar hiç menü kaydı yoksa numara `0` yerine `1` yazılır;
  /// tutanak her zaman bir numarayla basılır.
  Future<int> _computeReceiptNumber(DateTime date) async {
    final educationYearStart = date.month >= 9 ? date.year : date.year - 1;
    final count = await widget.repository.countMealDaysBetween(
      DateTime(educationYearStart, 9, 1),
      date,
    );
    return count < 1 ? 1 : count;
  }

  Future<void> _loadMenuForDate(DateTime date) async {
    setState(() => _isLoadingMenu = true);
    try {
      final days = await widget.repository.getMonth(date.year, date.month);
      final found = findMealDay(days, date);
      final receiptNumber = await _computeReceiptNumber(date);
      if (mounted) {
        setState(() {
          _day = found;
          _receiptNumber = receiptNumber;
          _isLoadingMenu = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _day = null;
          _receiptNumber = null;
          _isLoadingMenu = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Tutanak tarihi seçin',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _loadMenuForDate(picked);
    }
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      await printMealDeliveryReceipt(
        context: context,
        data: MealDeliveryReceiptData(
          schoolName: widget.schoolName,
          date: _selectedDate,
          day: _day,
          rowCount: _rowCount,
          orientation: _orientation,
          signatures: widget.signatures,
          receiptNumber: _receiptNumber,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isPrinting = false);
        AppNotifier.instance.show(
          context,
          message: 'Tutanak yazdırılamadı.',
          tone: AppNotificationTone.error,
        );
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
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(
          children: [
            _buildDialogHeader(),
            const Divider(height: 1, color: AppColors.inputBorder),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDateSelector(dateTitle),
                    const SizedBox(height: 14),
                    _buildMenuPreview(),
                    const SizedBox(height: 16),
                    _buildSignaturesPreview(),
                    const SizedBox(height: 16),
                    _buildOptionsSection(),
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

  Widget _buildDialogHeader() {
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
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yemek Malzemesi Teslim Tutanağı',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Günün menüsü ve 25 satırlık malzeme teslim tutanağı tablosu',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(String dateTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 22,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tutanak Tarihi',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateTitle,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('receipt_pick_date_button'),
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('Tarih Seç'),
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

  Widget _buildMenuPreview() {
    if (_isLoadingMenu) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    final day = _day;
    final hasMenu = day != null && day.hasAnyMeal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.appBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Günün Yemek Menüsü',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: hasMenu
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.errorFeedback.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasMenu ? '${day.itemCount} yemek kayıtlı' : 'Menü bulunamadı',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasMenu ? AppColors.primary : AppColors.errorFeedback,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasMenu)
            const Text(
              'Bu güne ait kayıtlı yemek menüsü yok. Tutanak oluşturulabilir; '
              'menü kısmı boş kalacak ve elle doldurulabilecektir.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in MealType.values)
                  _buildMealChip(type, day.mealsOf(type)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMealChip(MealType type, List<String> meals) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 3),
          if (meals.isEmpty)
            const Text(
              '— Menü yok —',
              style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
            )
          else
            for (final meal in meals)
              Text(
                '• $meal',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.darkText,
                  height: 1.25,
                ),
              ),
        ],
      ),
    );
  }

  /// Tutanak altındaki üç imza bloğunun çıktıda görünecek hâli.
  ///
  /// Yazdırmadan önce buradan kontrol edilir: girilmiş bilgi normal, girilmemiş
  /// alan ise örnek unvan rengiyle gösterilir.
  Widget _buildSignaturesPreview() {
    final signatures = widget.signatures;
    final isMissing = signatures.isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.appBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.draw_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Tutanak İmza Bilgileri',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isMissing
                      ? AppColors.errorFeedback.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isMissing ? 'Girilmedi' : 'Kayıtlı',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMissing ? AppColors.errorFeedback : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final role in MealSignatureRole.values) ...[
                Expanded(child: _buildSignatureBlock(role)),
                if (role != MealSignatureRole.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          if (isMissing) ...[
            const SizedBox(height: 10),
            const Text(
              'Yemek sayfasındaki "Tutanak İmza Bilgileri" düğmesinden bu '
              'alanları tanımlayabilirsiniz.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.secondaryText,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureBlock(MealSignatureRole role) {
    final signatures = widget.signatures;
    final name = signatures.displayName(role);
    final hasCustomTitle = signatures.jobTitleOf(role).trim().isNotEmpty;

    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            role.title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            signatures.displayJobTitle(role),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: hasCustomTitle
                  ? AppColors.darkText
                  : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name.isEmpty ? 'Adı Soyadı: …' : 'Adı Soyadı: $name',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: name.isEmpty
                  ? AppColors.secondaryText
                  : AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Çıktı Seçenekleri',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sayfa Yönü',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<MealDeliveryReceiptOrientation>(
                    key: const Key('receipt_orientation_dropdown'),
                    initialValue: _orientation,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                    ),
                    items: [
                      for (final opt in MealDeliveryReceiptOrientation.values)
                        DropdownMenuItem(
                          value: opt,
                          child: Text(
                            opt.label,
                            style: const TextStyle(fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _orientation = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elle Doldurulacak Satır Sayısı',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    key: const Key('receipt_row_count_dropdown'),
                    initialValue: _rowCount,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 15,
                        child: Text('15 Satır', style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 20,
                        child: Text('20 Satır', style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 25,
                        child: Text(
                          '25 Satır (Standart)',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text('30 Satır', style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _rowCount = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDialogFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppSecondaryButton(
            key: const Key('receipt_cancel_button'),
            label: 'Vazgeç',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          AppPrimaryButton(
            key: const Key('receipt_print_button'),
            label: 'Yazdır / PDF',
            icon: Icons.print_outlined,
            isLoading: _isPrinting,
            onPressed: _print,
          ),
        ],
      ),
    );
  }
}
