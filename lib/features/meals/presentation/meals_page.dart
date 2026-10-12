import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_excel_importer.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_menu_pdf.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/features/meals/presentation/meal_delivery_receipt_dialog.dart';
import 'package:pansiyon_yonetim/features/meals/presentation/meal_receipt_signatures_dialog.dart';
import 'package:pansiyon_yonetim/features/meals/presentation/meal_edit_dialog.dart';
import 'package:pansiyon_yonetim/features/meals/presentation/meal_import_dialog.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_empty_state.dart';

/// Pansiyon yemek listesi.
///
/// Menüler Excel'den toplu olarak içe aktarılır; her gün dört öğünüyle
/// ayrık yemekler hâlinde saklanır.
class MealsPage extends StatefulWidget {
  const MealsPage({
    super.key,
    required this.repository,
    this.boardingInfoRepository,
  });

  final MealRepository repository;
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  List<MealDay> _days = const [];
  List<MealMonthRef> _months = const [];
  MealReceiptSignatures _signatures = MealReceiptSignatures.empty;
  String _schoolName = '';
  late int _selectedYear;
  late int _selectedMonth;
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.repository.getMonth(_selectedYear, _selectedMonth),
        widget.repository.getMonths(),
        widget.boardingInfoRepository?.load() ??
            Future<BoardingInfoDraft?>.value(null),
        widget.repository.loadReceiptSignatures(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _days = results[0] as List<MealDay>;
        _months = results[1] as List<MealMonthRef>;
        _schoolName = (results[2] as BoardingInfoDraft?)?.schoolName ?? '';
        _signatures = results[3] as MealReceiptSignatures;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Yemek listesi yüklenemedi.', AppNotificationTone.error);
    }
  }

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  // --- Ay seçimi ----------------------------------------------------------------

  /// Seçili ayda menü yoksa ayı gösterir ama boşsa uyarır.
  void _selectMonth(int year, int month) {
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
      _isLoading = true;
    });
    unawaited(_load());
  }

  void _shiftMonth(int delta) {
    var month = _selectedMonth + delta;
    var year = _selectedYear;
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    _selectMonth(year, month);
  }

  /// Ay seçici için seçenekler.
  ///
  /// Seçili ay her zaman listede bulunur; ardından menüsü kayıtlı aylar ve
  /// çevredeki aylar eklenir. Böylece menüsü olmayan bir ay da seçilebilir.
  List<({int year, int month, String label, int dayCount})> get _monthOptions {
    final options = <({int year, int month, String label, int dayCount})>[];
    final seen = <String>{};

    void add(int year, int month, int dayCount) {
      if (!seen.add('$year-$month')) {
        return;
      }
      final title = mealMonthTitle(year, month);
      options.add((
        year: year,
        month: month,
        dayCount: dayCount,
        label: dayCount > 0 ? '$title ($dayCount gün)' : '$title (menü yok)',
      ));
    }

    add(_selectedYear, _selectedMonth, _days.length);
    for (final ref in _months) {
      add(ref.year, ref.month, ref.dayCount);
    }
    for (final ref in _neighbourMonths(_selectedYear, _selectedMonth)) {
      add(ref.year, ref.month, 0);
    }
    options.sort((a, b) {
      final compare = b.year.compareTo(a.year);
      return compare != 0 ? compare : b.month.compareTo(a.month);
    });
    return options;
  }

  List<MealMonthRef> _neighbourMonths(int year, int month) {
    final result = <MealMonthRef>[];
    for (final delta in [-2, -1, 1, 2]) {
      var m = month + delta;
      var y = year;
      while (m < 1) {
        m += 12;
        y -= 1;
      }
      while (m > 12) {
        m -= 12;
        y += 1;
      }
      result.add(MealMonthRef(year: y, month: m, dayCount: 0));
    }
    return result;
  }

  // --- İçe aktarma --------------------------------------------------------------

  Future<void> _importFromExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    final path = result.isEmpty ? null : result.single.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() => _isImporting = true);
    try {
      final preview = await const MealExcelImporter().readFile(path);
      if (!mounted) {
        return;
      }
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => MealImportDialog(preview: preview),
      );
      if (shouldImport != true || !mounted) {
        return;
      }
      final outcome = await widget.repository.importDays(preview.days);
      if (!mounted) {
        return;
      }
      // Excel birden çok ay içerebilir; içe aktarılan ilk ay gösterilir.
      final first = preview.days.first.date;
      _selectMonth(first.year, first.month);
      _notify(outcome.summary, AppNotificationTone.success);
    } catch (_) {
      _notify('Excel yüklenemedi.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  // --- Yazdırma -----------------------------------------------------------------

  Future<void> _print() async {
    if (_days.isEmpty) {
      _notify(
        'Yazdırılacak menü yok. Önce Excel içe aktarın.',
        AppNotificationTone.error,
      );
      return;
    }
    setState(() => _isPrinting = true);
    try {
      await printMealMenu(
        context: context,
        data: MealMenuPrintData(
          schoolName: _schoolName,
          year: _selectedYear,
          month: _selectedMonth,
          days: _days,
        ),
      );
    } catch (_) {
      _notify('Menü yazdırılamadı.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _deleteDay(MealDay day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Menüyü sil'),
        content: Text(
          '${day.date.day}.${day.date.month}.${day.date.year} '
          '${mealWeekdayName(day.date)} gününün menüsü silinsin mi?',
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
    if (confirmed != true) {
      return;
    }
    try {
      await widget.repository.deleteDay(day.date);
      _notify('Menü silindi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Menü silinemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _openEditMealDialog(MealDay day) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => MealEditDialog(
        repository: widget.repository,
        day: day,
      ),
    );
    if (saved == true && mounted) {
      _notify('Menü kaydedildi.', AppNotificationTone.success);
      await _load();
    }
  }

  Future<void> _openAddMealDialog() async {
    final now = DateTime.now();
    final defaultDate =
        (_selectedYear == now.year && _selectedMonth == now.month)
            ? now
            : DateTime(_selectedYear, _selectedMonth, 1);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => MealEditDialog(
        repository: widget.repository,
        initialDate: defaultDate,
      ),
    );
    if (saved == true && mounted) {
      _notify('Menü kaydedildi.', AppNotificationTone.success);
      await _load();
    }
  }

  Future<void> _openReceiptDialog({DateTime? initialDate}) async {
    final now = DateTime.now();
    final defaultDate = initialDate ??
        ((_selectedYear == now.year && _selectedMonth == now.month)
            ? now
            : DateTime(_selectedYear, _selectedMonth, 1));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MealDeliveryReceiptDialog(
        repository: widget.repository,
        schoolName: _schoolName,
        initialDate: defaultDate,
        signatures: _signatures,
      ),
    );
  }

  /// Tutanak imza bloklarının okul geneli bilgilerini düzenleyen pencereyi açar.
  Future<void> _openSignaturesDialog() async {
    final saved = await showDialog<MealReceiptSignatures>(
      context: context,
      builder: (dialogContext) => MealReceiptSignaturesDialog(
        repository: widget.repository,
        initialSignatures: _signatures,
      ),
    );
    if (saved == null || !mounted) {
      return;
    }
    setState(() => _signatures = saved);
    _notify('Tutanak imza bilgileri kaydedildi.', AppNotificationTone.success);
  }

  // --- Görünüm ------------------------------------------------------------------

  String get _summaryLine {
    if (_days.isEmpty) {
      return '${mealMonthTitle(_selectedYear, _selectedMonth)} için menü yok';
    }
    final items = _days.fold<int>(0, (sum, day) => sum + day.itemCount);
    return '${_days.length} gün • $items yemek • '
        '${mealMonthTitle(_selectedYear, _selectedMonth)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pageGutter,
        AppTokens.gapMd,
        AppTokens.pageGutter,
        AppTokens.pageGutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildMonthBar(),
          const SizedBox(height: 10),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 840;

        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ).createShader(bounds),
              child: const Text(
                'Yemek Listesi',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ),
            if (_schoolName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _schoolName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _summaryLine,
              style: AppTypography.caption.copyWith(fontSize: 13),
            ),
          ],
        );

        final buttons = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSecondaryButton(
              key: const Key('meals_add_button'),
              label: 'Menü Ekle',
              icon: Icons.add_rounded,
              onPressed: _openAddMealDialog,
            ),
            AppSecondaryButton(
              key: const Key('meals_import_button'),
              label: 'Excel İçe Aktar',
              icon: Icons.upload_file_outlined,
              isLoading: _isImporting,
              onPressed: _importFromExcel,
            ),
            AppSecondaryButton(
              key: const Key('meals_receipt_button'),
              label: 'Malzeme Tutanağı',
              icon: Icons.receipt_long_outlined,
              onPressed: () => _openReceiptDialog(),
            ),
            AppSecondaryButton(
              key: const Key('meals_signatures_button'),
              label: 'Tutanak İmza Bilgileri',
              icon: Icons.draw_outlined,
              onPressed: _openSignaturesDialog,
            ),
            AppPrimaryButton(
              key: const Key('meals_print_button'),
              label: 'Yazdır',
              icon: Icons.print_outlined,
              isLoading: _isPrinting,
              onPressed: _days.isEmpty ? null : _print,
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 10),
              buttons,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 12),
            buttons,
          ],
        );
      },
    );
  }

  Widget _buildMonthBar() {
    final options = _monthOptions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          AppIconAction(
            key: const Key('meals_previous_month'),
            icon: Icons.chevron_left_rounded,
            tooltip: 'Önceki ay',
            onPressed: () => _shiftMonth(-1),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('meals_month_selector'),
                isExpanded: true,
                value: '$_selectedYear-$_selectedMonth',
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: '${option.year}-${option.month}',
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  final parts = value.split('-');
                  _selectMonth(int.parse(parts[0]), int.parse(parts[1]));
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          AppIconAction(
            key: const Key('meals_next_month'),
            icon: Icons.chevron_right_rounded,
            tooltip: 'Sonraki ay',
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_days.isEmpty) {
      return AppEmptyState(
        icon: Icons.restaurant_menu_outlined,
        title: 'Bu ay için menü yok',
        message:
            'Yemek listesini Excel dosyasından toplu olarak içe aktarabilir '
            'veya yeni bir gün menüsü ekleyebilirsiniz.',
        action: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            AppSecondaryButton(
              key: const Key('meals_empty_add_button'),
              label: 'Menü Ekle',
              icon: Icons.add_rounded,
              onPressed: _openAddMealDialog,
            ),
            AppPrimaryButton(
              key: const Key('meals_empty_import_button'),
              label: 'Excel İçe Aktar',
              icon: Icons.upload_file_outlined,
              onPressed: _isImporting ? null : _importFromExcel,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      key: const Key('meals_list'),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _days.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _MealDayCard(
          day: _days[index],
          onEdit: () => _openEditMealDialog(_days[index]),
          onReceipt: () => _openReceiptDialog(initialDate: _days[index].date),
          onDelete: () => _deleteDay(_days[index]),
        );
      },
    );
  }
}

/// Bir günün menü kartı: solda tarih, sağda dört öğün sütunu.
class _MealDayCard extends StatelessWidget {
  const _MealDayCard({
    required this.day,
    required this.onEdit,
    required this.onReceipt,
    required this.onDelete,
  });

  final MealDay day;
  final VoidCallback onEdit;
  final VoidCallback onReceipt;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dayLabel = '${day.date.day}.${day.date.month}.${day.date.year}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3E0C28),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mealWeekdayName(day.date),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: IconButton(
                              key: Key('meal_day_edit_${mealDateKey(day.date)}'),
                              onPressed: onEdit,
                              tooltip: 'Bu günü düzenle',
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              color: AppColors.primary,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                          const SizedBox(width: 2),
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: IconButton(
                              key: Key('meal_day_receipt_${mealDateKey(day.date)}'),
                              onPressed: onReceipt,
                              tooltip: 'Malzeme teslim tutanağı',
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              color: AppColors.secondaryText,
                              icon: const Icon(Icons.receipt_long_outlined),
                            ),
                          ),
                          const SizedBox(width: 2),
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: IconButton(
                              key: Key('meal_day_delete_${mealDateKey(day.date)}'),
                              onPressed: onDelete,
                              tooltip: 'Bu günü sil',
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              color: AppColors.secondaryText,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Dar ekranda dört öğün yan yana sığmaz; iki sütuna sarılır.
                      final columns = constraints.maxWidth < 520 ? 2 : 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          for (final type in MealType.values)
                            SizedBox(
                              width: columns == 4
                                  ? (constraints.maxWidth - 36) / 4
                                  : (constraints.maxWidth - 12) / 2,
                              child: _MealColumn(type: type, day: day),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealColumn extends StatelessWidget {
  const _MealColumn({required this.type, required this.day});

  final MealType type;
  final MealDay day;

  @override
  Widget build(BuildContext context) {
    final meals = day.mealsOf(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: meals.isEmpty
                    ? AppColors.inputBorder
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                type.shortLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: meals.isEmpty
                      ? AppColors.secondaryText
                      : AppColors.darkText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (meals.isEmpty)
          const Text(
            '—',
            style: TextStyle(fontSize: 12, color: AppColors.inputBorder),
          )
        else
          for (final meal in meals)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                meal,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.secondaryText,
                  height: 1.35,
                ),
              ),
            ),
      ],
    );
  }
}
