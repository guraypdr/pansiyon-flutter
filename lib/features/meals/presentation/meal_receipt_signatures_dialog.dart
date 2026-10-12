import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_labelled_field.dart';

/// Tutanak altındaki imza bloklarının okul geneli bilgilerini düzenleyen pencere.
///
/// Teslim Eden ve Teslim Alan blokları için unvan ve adı soyadı bir kez
/// girilir; kaydedilen bilgiler her tutanak çıktısında forma basılır. Boş
/// bırakılan alanlar çıktıda örnek metin olarak görünür.
class MealReceiptSignaturesDialog extends StatefulWidget {
  const MealReceiptSignaturesDialog({
    super.key,
    required this.repository,
    this.initialSignatures,
  });

  final MealRepository repository;

  /// Pencere açılırken gösterilecek kayıt; verilmezse depodan okunur.
  final MealReceiptSignatures? initialSignatures;

  @override
  State<MealReceiptSignaturesDialog> createState() =>
      _MealReceiptSignaturesDialogState();
}

class _MealReceiptSignaturesDialogState
    extends State<MealReceiptSignaturesDialog> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final role in MealSignatureRole.values) {
      _controllers[_textKey(role, 'title')] = TextEditingController();
      _controllers[_textKey(role, 'name')] = TextEditingController();
    }
    if (widget.initialSignatures != null) {
      _applySignatures(widget.initialSignatures!);
      _isLoading = false;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final signatures = await widget.repository.loadReceiptSignatures();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySignatures(signatures);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tutanak bilgileri okunamadı.';
      });
    }
  }

  void _applySignatures(MealReceiptSignatures signatures) {
    for (final role in MealSignatureRole.values) {
      _controllers[_textKey(role, 'title')]?.text = signatures.jobTitleOf(role);
      _controllers[_textKey(role, 'name')]?.text = signatures.nameOf(role);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _textKey(MealSignatureRole role, String field) => '${role.value}_$field';

  String _read(MealSignatureRole role, String field) =>
      mealTitleCase(_controllers[_textKey(role, field)]?.text ?? '');

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final signatures = MealReceiptSignatures(
      delivererJobTitle: _read(MealSignatureRole.deliverer, 'title'),
      delivererName: _read(MealSignatureRole.deliverer, 'name'),
      receiverJobTitle: _read(MealSignatureRole.receiver, 'title'),
      receiverName: _read(MealSignatureRole.receiver, 'name'),
    );

    try {
      await widget.repository.saveReceiptSignatures(signatures);
      if (mounted) {
        Navigator.of(context).pop(signatures);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Tutanak bilgileri kaydedilemedi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.inputBorder),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTokens.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHint(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorBox(_errorMessage!),
                          ],
                          const SizedBox(height: 14),
                          for (final role in MealSignatureRole.values) ...[
                            _buildRoleCard(role),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1, color: AppColors.inputBorder),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              Icons.draw_outlined,
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
                  'Tutanak İmza Bilgileri',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Teslim Eden ve Teslim Alan bloklarının unvan ve adı soyadı '
                  'bilgileri',
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
            key: const Key('signatures_close_button'),
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.appBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Bu bilgiler okul genelinde geçerlidir; bir kez girip kaydettiğinizde '
              'her malzeme teslim tutanağında aynı kişiler için basılır. '
              'Boş bırakılan alanlar çıktıda örnek unvanla görünür.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              message,
              style: const TextStyle(
                color: AppColors.errorFeedback,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(MealSignatureRole role) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                role.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Örnek unvan: ${role.defaultJobTitle}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;
              final titleField = AppLabelledField(
                label: 'Unvan',
                child: TextField(
                  key: Key('signature_${role.value}_title_field'),
                  controller: _controllers[_textKey(role, 'title')],
                  decoration: appInputDecoration(
                    hintText: role.defaultJobTitle,
                  ),
                ),
              );
              final nameField = AppLabelledField(
                label: 'Adı Soyadı',
                child: TextField(
                  key: Key('signature_${role.value}_name_field'),
                  controller: _controllers[_textKey(role, 'name')],
                  decoration: appInputDecoration(
                    hintText: 'Adı Soyadı',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleField,
                    const SizedBox(height: 10),
                    nameField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleField),
                  const SizedBox(width: 12),
                  Expanded(child: nameField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppSecondaryButton(
            key: const Key('signatures_cancel_button'),
            label: 'Vazgeç',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          AppPrimaryButton(
            key: const Key('signatures_save_button'),
            label: 'Kaydet',
            icon: Icons.save_outlined,
            isLoading: _isSaving,
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
    );
  }
}