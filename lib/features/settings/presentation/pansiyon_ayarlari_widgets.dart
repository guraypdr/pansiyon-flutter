part of 'pansiyon_ayarlari_page.dart';

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.compact,
    required this.onStepSelected,
  });

  final List<String> steps;
  final int currentStep;
  final bool compact;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            _StepProgressItem(
              index: index,
              label: steps[index],
              currentStep: currentStep,
              onSelected: () => onStepSelected(index),
            ),
            if (index != steps.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: _StepProgressItem(
              index: index,
              label: steps[index],
              currentStep: currentStep,
              onSelected: () => onStepSelected(index),
            ),
          ),
          if (index != steps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                width: 32,
                height: 2,
                color: index < currentStep
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.55),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepProgressItem extends StatelessWidget {
  const _StepProgressItem({
    required this.index,
    required this.label,
    required this.currentStep,
    required this.onSelected,
  });

  final int index;
  final String label;
  final int currentStep;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final completed = index < currentStep;
    final current = index == currentStep;
    final borderColor = current
        ? AppColors.transparent
        : completed
        ? AppColors.primary.withValues(alpha: 0.28)
        : AppColors.border.withValues(alpha: 0.55);
    final labelColor = current
        ? AppColors.surface
        : completed
        ? AppColors.darkText
        : AppColors.secondaryText;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: index <= currentStep ? onSelected : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: current
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  )
                : null,
            color: current
                ? null
                : completed
                ? AppColors.softMagenta
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current
                      ? AppColors.surface
                      : completed
                      ? AppColors.primary
                      : AppColors.softMagenta,
                  shape: BoxShape.circle,
                ),
                child: completed
                    ? const Icon(
                        Icons.check,
                        color: AppColors.surface,
                        size: 15,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: current
                              ? AppColors.primary
                              : AppColors.darkText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12.5,
                    fontWeight: current || completed
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.currentStep,
    required this.isSaving,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (currentStep > 0)
          TextButton(
            onPressed: isSaving ? null : onBack,
            child: const Text('Geri'),
          ),
        const Spacer(),
        if (currentStep < 3)
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Devam'),
          )
        else
          FilledButton.icon(
            onPressed: isSaving ? null : onNext,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'Kaydediliyor' : 'Kaydet'),
          ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.cardSurfaceAccent],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeWords(title),
                      style: const TextStyle(
                        color: AppColors.sidebar,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capitalizeWords(label),
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _standardInputDecoration({String? errorText}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    errorText: errorText,
    filled: true,
    fillColor: AppColors.inputSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: border(AppColors.inputBorder),
    enabledBorder: border(AppColors.inputBorder),
    focusedBorder: border(AppColors.primary, 2),
    errorBorder: border(AppColors.errorFeedback),
    focusedErrorBorder: border(AppColors.errorFeedback, 2),
  );
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final BoardingType? value;
  final ValueChanged<BoardingType?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return _LabelledField(
      label: 'Pansiyon türü',
      child: InputDecorator(
        decoration: _standardInputDecoration(errorText: errorText),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<BoardingType>(
            value: value,
            isExpanded: true,
            style: AppTheme.inputTextStyle,
            items: [
              for (final type in BoardingType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _BuildingSectionEditor extends StatelessWidget {
  const _BuildingSectionEditor({
    required this.section,
    required this.blocks,
    required this.onAddBlock,
    required this.onRemoveBlock,
    required this.onAddFloor,
    required this.onRemoveFloor,
    required this.onBasementChanged,
    required this.onStudentRoomsChanged,
    required this.onStudyRoomChanged,
  });

  final BoardingSection section;
  final List<_BlockForm> blocks;
  final VoidCallback onAddBlock;
  final ValueChanged<int> onRemoveBlock;
  final ValueChanged<_BlockForm> onAddFloor;
  final void Function(_BlockForm, int) onRemoveFloor;
  final void Function(_BlockForm, bool) onBasementChanged;
  final void Function(_BlockForm, int, bool) onStudentRoomsChanged;
  final void Function(_BlockForm, int, bool) onStudyRoomChanged;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      title: section.label,
      subtitle: 'Blok sayısı: ${blocks.length}',
      child: Column(
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            _BlockEditor(
              block: blocks[index],
              index: index,
              onRemove: () => onRemoveBlock(index),
              onAddFloor: () => onAddFloor(blocks[index]),
              onRemoveFloor: (floorIndex) =>
                  onRemoveFloor(blocks[index], floorIndex),
              onBasementChanged: (value) =>
                  onBasementChanged(blocks[index], value),
              onStudentRoomsChanged: (floorIndex, value) =>
                  onStudentRoomsChanged(blocks[index], floorIndex, value),
              onStudyRoomChanged: (floorIndex, value) =>
                  onStudyRoomChanged(blocks[index], floorIndex, value),
            ),
            if (index != blocks.length - 1) const SizedBox(height: 14),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddBlock,
              icon: const Icon(Icons.add),
              label: const Text('Blok ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockEditor extends StatelessWidget {
  const _BlockEditor({
    required this.block,
    required this.index,
    required this.onRemove,
    required this.onAddFloor,
    required this.onRemoveFloor,
    required this.onBasementChanged,
    required this.onStudentRoomsChanged,
    required this.onStudyRoomChanged,
  });

  final _BlockForm block;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onAddFloor;
  final ValueChanged<int> onRemoveFloor;
  final ValueChanged<bool> onBasementChanged;
  final void Function(int, bool) onStudentRoomsChanged;
  final void Function(int, bool) onStudyRoomChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(block.id),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.cardSurfaceAccent],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Blok ${index + 1}',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bloğu sil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LabelledField(
            label: 'Blok adı',
            child: TextFormField(
              controller: block.nameController,
              style: AppTheme.inputTextStyle,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [capitalizeWordsFormatter],
              decoration: const InputDecoration(),
              validator: (value) => requiredField(value, 'Blok adı'),
            ),
          ),
          const SizedBox(height: 12),
          _LabelledField(
            label: 'Standart oda kapasitesi',
            child: TextFormField(
              controller: block.capacityController,
              style: AppTheme.inputTextStyle,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(),
              validator: (value) =>
                  positiveNumberValidator(value, 'Standart oda kapasitesi'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bodrum kat var mı?'),
              subtitle: Text(
                block.hasBasement
                    ? 'Katlar Bodrum Kat, Zemin Kat, 1. Kat ve devamı şeklinde adlandırılır.'
                    : 'Katlar Zemin Kat, 1. Kat ve devamı şeklinde adlandırılır.',
              ),
              value: block.hasBasement,
              onChanged: onBasementChanged,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Katlar ve oda/etüt salonları',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Kat sayısı: ${block.floors.length}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onAddFloor,
                icon: const Icon(Icons.add),
                label: const Text('Kat ekle'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (
            var floorIndex = 0;
            floorIndex < block.floors.length;
            floorIndex++
          ) ...[
            Builder(
              builder: (context) {
                final floor = block.floors[floorIndex];
                final floorLabel = _floorLabel(
                  hasBasement: block.hasBasement,
                  index: floorIndex,
                );

                return Container(
                  key: ValueKey('${block.id}_floor_$floorIndex'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              floorLabel,
                              style: const TextStyle(
                                color: AppColors.darkText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Katı sil',
                            onPressed: block.floors.length <= 1
                                ? null
                                : () => onRemoveFloor(floorIndex),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ResponsiveFields(
                        children: [
                          _FloorFeatureToggle(
                            title: 'Bu katta etüt salonu var mı?',
                            value: floor.hasStudyRoom,
                            onChanged: (value) =>
                                onStudyRoomChanged(floorIndex, value),
                          ),
                          _FloorFeatureToggle(
                            title: 'Bu katta öğrenci odası var mı?',
                            value: floor.hasStudentRooms,
                            onChanged: (value) =>
                                onStudentRoomsChanged(floorIndex, value),
                          ),
                        ],
                      ),
                      if (floor.hasStudyRoom) ...[
                        const SizedBox(height: 12),
                        _LabelledField(
                          label: 'Etüt salonu sayısı',
                          child: TextFormField(
                            controller: floor.studyRoomCountController,
                            style: AppTheme.inputTextStyle,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(),
                            validator: (value) => positiveNumberValidator(
                              value,
                              'Etüt salonu sayısı',
                            ),
                          ),
                        ),
                      ],
                      if (floor.hasStudentRooms) ...[
                        const SizedBox(height: 12),
                        _ResponsiveFields(
                          children: [
                            _LabelledField(
                              label: 'Oda başlangıç numarası',
                              child: TextFormField(
                                controller: floor.roomStartNumberController,
                                style: AppTheme.inputTextStyle,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(),
                                validator: (value) => positiveNumberValidator(
                                  value,
                                  'Oda başlangıç numarası',
                                ),
                              ),
                            ),
                            _LabelledField(
                              label: 'Öğrenci odası sayısı',
                              child: TextFormField(
                                controller: floor.roomCountController,
                                style: AppTheme.inputTextStyle,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(),
                                validator: (value) => positiveNumberValidator(
                                  value,
                                  'Öğrenci odası sayısı',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (floorIndex != block.floors.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FloorFeatureToggle extends StatelessWidget {
  const _FloorFeatureToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupRestoreCard extends StatefulWidget {
  const _BackupRestoreCard({required this.backupService, this.onChanged});

  final DatabaseBackupService backupService;
  final VoidCallback? onChanged;

  @override
  State<_BackupRestoreCard> createState() => _BackupRestoreCardState();
}

class _BackupRestoreCardState extends State<_BackupRestoreCard> {
  DatabaseBackup? _latestBackup;
  bool _isWorking = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final backups = await widget.backupService.listBackups();
      if (mounted) {
        setState(() {
          _latestBackup = backups.isEmpty ? null : backups.first;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createBackup() async {
    if (_isWorking) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      await widget.backupService.createBackup();
      await _load();
      widget.onChanged?.call();
      if (mounted) {
        _notify(
          context,
          'Veri yedeği oluşturuldu.',
          AppNotificationTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        _notify(context, 'Yedek oluşturulamadı.');
      }
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isWorking) {
      return;
    }
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Geri yüklenecek yedek dosyası',
      type: FileType.custom,
      allowedExtensions: const ['pansiyon', 'db', 'sqlite', 'sqlite3'],
    );
    final filePath = files.isEmpty ? null : files.single.path;
    if (filePath == null || !mounted) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      await widget.backupService.restoreBackup(filePath);
      await _load();
      widget.onChanged?.call();
      if (mounted) {
        _notify(context, 'Yedek geri yüklendi.', AppNotificationTone.success);
      }
    } on DatabaseRestoreException catch (error) {
      if (mounted) {
        _notify(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _notify(context, 'Yedek geri yüklenemedi.');
      }
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _FormSection(
      title: 'Yedekleme ve Geri Yükleme',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isWorking)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          Text(
            _isLoading
                ? 'Yedekler okunuyor...'
                : _latestBackup == null
                ? 'Henüz yedek oluşturulmadı.'
                : 'Son yedek: ${_formatBackupDate(_latestBackup!.createdAt)} • '
                      '${_formatBackupSize(_latestBackup!.sizeBytes)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const Key('create_backup_button'),
                onPressed: _isWorking ? null : _createBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Yedekle'),
              ),
              OutlinedButton.icon(
                key: const Key('restore_backup_button'),
                onPressed: _isWorking ? null : _restoreBackup,
                icon: const Icon(Icons.restore),
                label: const Text('Geri Yükle'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Yedekler, pansiyon dosyanızın yanındaki "backups" klasöründe '
            '.pansiyon dosyası olarak tutulur. Geri yüklemeden önce mevcut '
            'verilerinizin yedeği otomatik alınır.',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

void _notify(
  BuildContext context,
  String message, [
  AppNotificationTone tone = AppNotificationTone.error,
]) {
  if (!context.mounted) {
    return;
  }
  AppNotifier.instance.show(context, message: message, tone: tone);
}

String _formatBackupDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

String _formatBackupSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _floorLabel({required bool hasBasement, required int index}) {
  if (hasBasement && index == 0) {
    return 'Bodrum Kat';
  }
  final upperFloorNumber = index - (hasBasement ? 1 : 0);
  if (upperFloorNumber == 0) {
    return 'Zemin Kat';
  }
  return '$upperFloorNumber. Kat';
}
