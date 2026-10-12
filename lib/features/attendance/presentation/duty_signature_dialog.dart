import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_filters.dart';

/// Nöbetçi öğretmenin imza satırında nasıl görüneceği.
enum DutySignatureMode {
  /// Seçilen nöbetçiler tek satırda, virgülle.
  tekSatir,

  /// Her kat ayrı satırda: "1. Kat: Ahmet Yılmaz".
  katBazli,

  /// Yalnızca seçilen tek öğretmen.
  tekOgreten,

  /// Hiç yazma; imza elle doldurulur.
  simsiz,
}

extension DutySignatureModeLabel on DutySignatureMode {
  String get label => switch (this) {
    DutySignatureMode.tekSatir => 'Tek satırda',
    DutySignatureMode.katBazli => 'Kat bazında',
    DutySignatureMode.tekOgreten => 'Tek öğretmen',
    DutySignatureMode.simsiz => 'İsimsiz',
  };

  String get description => switch (this) {
    DutySignatureMode.tekSatir => 'Bütün nöbetçiler tek satırda',
    DutySignatureMode.katBazli => 'Her kat için ayrı satır',
    DutySignatureMode.tekOgreten => 'Listeden bir öğretmen seçin',
    DutySignatureMode.simsiz => 'Çizgi elle doldurulacak',
  };
}

/// Kullanıcının seçimi sonucu: PDF'e yazılacak satırlar.
///
/// Satırlar pencerede hesaplanır; önizleme ile çıktı bu yüzden birebir aynı
/// olur, ayrı yerde ikinci kez hesaplanmaz.
class DutySignatureSelection {
  const DutySignatureSelection({required this.lines});

  final List<String> lines;
}

/// Çizelgeyi basmadan önce imza satırının ne olacağını seçtiren pencere.
class DutySignatureDialog extends StatefulWidget {
  const DutySignatureDialog({
    super.key,
    required this.slots,
    required this.roomSections,
    required this.sectionKeyOf,
    this.initialSectionKey,
  });

  /// Seçilebilecek günün tüm nöbetçi yuvaları (tüm bölümler).
  final List<DutyDutySlot> slots;

  /// Pansiyondaki bölümler; tek bölüm varsa bölüm filtresi gizlenir.
  final List<String> roomSections;

  /// Bir bölüm etiketinin nöbet listesi anahtarına karşılığı.
  final String? Function(String? sectionLabel) sectionKeyOf;

  /// Başlangıçta seçili bölüm.
  final String? initialSectionKey;

  @override
  State<DutySignatureDialog> createState() => _DutySignatureDialogState();
}

class _DutySignatureDialogState extends State<DutySignatureDialog> {
  late String? _sectionKey = widget.initialSectionKey;
  final Set<String> _locationKeys = {};
  late DutySignatureMode _mode = DutySignatureMode.tekSatir;
  int? _teacherId;

  /// Seçili bölüme ait nöbetçi yuvaları.
  List<DutyDutySlot> get _sectionSlots => widget.slots
      .where((slot) => slot.sectionKey == (_sectionKey ?? ''))
      .toList(growable: false);

  /// Seçili bölümdeki nöbet yerleri, sıra numarasına göre.
  List<String> get _locations {
    final seen = <String>[];
    for (final slot in _sectionSlots) {
      final location = slot.location?.trim() ?? '';
      if (location.isNotEmpty && !seen.contains(location)) {
        seen.add(location);
      }
    }
    return seen;
  }

  /// Bölüm ve kat filtresinden geçen nöbetçiler.
  List<DutyDutySlot> get _filtered {
    if (_locationKeys.isEmpty) {
      return _sectionSlots;
    }
    return _sectionSlots
        .where((slot) => _locationKeys.contains(slot.location?.trim() ?? ''))
        .toList(growable: false);
  }

  void _toggleLocation(String location) {
    setState(() {
      if (!_locationKeys.remove(location)) {
        _locationKeys.add(location);
      }
    });
  }

  void _selectAllLocations() {
    setState(_locationKeys.clear);
  }

  /// Seçime göre imza satırına yazılacak satırlar.
  List<String> get _lines =>
      dutySignatureLines(mode: _mode, slots: _filtered, teacherId: _teacherId);

  @override
  Widget build(BuildContext context) {
    final slots = _sectionSlots;
    final canChooseMode = slots.isNotEmpty;

    return AlertDialog(
      title: const Text('Nöbetçi Öğretmen'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Çizelgenin altındaki imza satırında kimin yazacağını seçin.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),

              // --- Bölüm ---
              if (widget.roomSections.length > 1) ...[
                _groupLabel('Bölüm'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final section in widget.roomSections)
                      AppFilterChip(
                        label: section,
                        isSelected: _sectionKey == widget.sectionKeyOf(section),
                        onTap: () => setState(() {
                          _sectionKey = widget.sectionKeyOf(section);
                          _locationKeys.clear();
                          _teacherId = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // --- Kat ---
              if (_locations.isNotEmpty) ...[
                _groupLabel('Nöbet yeri'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppFilterChip(
                      label: 'Tümü',
                      isSelected: _locationKeys.isEmpty,
                      onTap: _selectAllLocations,
                    ),
                    for (final location in _locations)
                      AppFilterChip(
                        label: location,
                        isSelected: _locationKeys.contains(location),
                        onTap: () => _toggleLocation(location),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // --- Gösterim biçimi ---
              _groupLabel('Gösterim'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in DutySignatureMode.values)
                    if (canChooseMode || mode == DutySignatureMode.simsiz)
                      AppFilterChip(
                        label: mode.label,
                        isSelected: _mode == mode,
                        onTap: () => setState(() => _mode = mode),
                      ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _mode.description,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),

              // --- Tek öğretmen seçimi ---
              if (_mode == DutySignatureMode.tekOgreten &&
                  _filtered.isNotEmpty) ...[
                const SizedBox(height: 14),
                _groupLabel('Öğretmen'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in _filtered)
                      AppFilterChip(
                        label: _slotLabel(slot),
                        isSelected: _teacherId == slot.teacher.id,
                        onTap: () =>
                            setState(() => _teacherId = slot.teacher.id),
                      ),
                  ],
                ),
              ],

              // --- Önizleme ---
              const SizedBox(height: 16),
              _Preview(lines: _lines, isEmpty: slots.isEmpty),
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
          key: const Key('duty_signature_print_button'),
          onPressed: () =>
              Navigator.of(context).pop(DutySignatureSelection(lines: _lines)),
          child: const Text('Yazdır'),
        ),
      ],
    );
  }

  static String _slotLabel(DutyDutySlot slot) {
    final location = slot.location?.trim() ?? '';
    return location.isEmpty ? slot.teacher.fullName : location;
  }

  static Widget _groupLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.lines, required this.isEmpty});

  final List<String> lines;

  /// O gün hiç nöbetçi tanımlı değilse uyarı gösterilir.
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Çıktıda görünecek',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          if (isEmpty)
            const Text(
              'Bu tarihte nöbetçi tanımlı değil; çizgi elle doldurulacak.',
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            )
          else if (lines.isEmpty)
            const Text(
              'İsimsiz basılacak; çizgi elle doldurulacak.',
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            )
          else
            for (final line in lines)
              Text(
                line,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
        ],
      ),
    );
  }
}

/// Seçime göre PDF'e yazılacak imza satırlarını üretir.
///
/// Saf fonksiyon; hem pencere önizlemesinde hem de çizelge oluşturulurken aynı
/// sonucu verir, böylece önizleme ile çıktı birbirinden ayrı düşmez.
List<String> dutySignatureLines({
  required DutySignatureMode mode,
  required List<DutyDutySlot> slots,
  int? teacherId,
}) {
  switch (mode) {
    case DutySignatureMode.simsiz:
      return const [];
    case DutySignatureMode.tekOgreten:
      final slot = slots.where((item) => item.teacher.id == teacherId);
      return slot.isEmpty ? const [] : [slot.first.teacher.fullName];
    case DutySignatureMode.katBazli:
      return [
        for (final slot in slots)
          (slot.location?.trim().isNotEmpty ?? false)
              ? '${slot.location!.trim()}: ${slot.teacher.fullName}'
              : slot.teacher.fullName,
      ];
    case DutySignatureMode.tekSatir:
      return [
        if (slots.isNotEmpty)
          slots.map((slot) => slot.teacher.fullName).join(', '),
      ];
  }
}
