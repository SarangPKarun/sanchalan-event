import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/category_icons.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/event.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import 'sheet_scaffold.dart';

sealed class BudgetSheetResult {
  const BudgetSheetResult();
}

class BudgetSaved extends BudgetSheetResult {
  const BudgetSaved({required this.categoryKey, required this.amount});

  final String categoryKey;
  final double amount;
}

class BudgetDeleted extends BudgetSheetResult {
  const BudgetDeleted();
}

/// Categories people commonly budget for, offered as one-tap choices.
const suggestedBudgetKeys = [
  'venue',
  'catering',
  'decor',
  'photography',
  'attire',
  'invitations',
  'music_entertainment',
  'priest_officiant',
  'transport',
  'guest_logistics',
  'legal_documentation',
  'misc',
];

/// "Gift boxes" -> "gift_boxes", the key the API stores.
String categoryKeyFromName(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// Add ([existing] null) or edit a budget category.
/// [otherAllocated] is what the other categories already use, to show what is left.
Future<BudgetSheetResult?> showBudgetCategorySheet(
  BuildContext context, {
  BudgetCategory? existing,
  required Iterable<String> usedKeys,
  required double total,
  required double otherAllocated,
}) => showAppSheet<BudgetSheetResult>(
  context,
  (_) => BudgetCategorySheet(
    existing: existing,
    usedKeys: usedKeys.toSet(),
    total: total,
    otherAllocated: otherAllocated,
  ),
);

class BudgetCategorySheet extends StatefulWidget {
  const BudgetCategorySheet({
    super.key,
    this.existing,
    required this.usedKeys,
    required this.total,
    required this.otherAllocated,
  });

  final BudgetCategory? existing;
  final Set<String> usedKeys;
  final double total;
  final double otherAllocated;

  @override
  State<BudgetCategorySheet> createState() => _BudgetCategorySheetState();
}

class _BudgetCategorySheetState extends State<BudgetCategorySheet> {
  static const _other = '__other__';

  late String? _choice = _initialChoice;
  late final _custom = TextEditingController(text: _initialCustom);
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.allocatedAmount.round().toString(),
  );
  bool _showErrors = false;

  bool get _isNew => widget.existing == null;

  String? get _initialChoice {
    final key = widget.existing?.categoryKey;
    if (key == null) return null;
    return suggestedBudgetKeys.contains(key) ? key : _other;
  }

  String get _initialCustom {
    final key = widget.existing?.categoryKey;
    if (key == null || suggestedBudgetKeys.contains(key)) return '';
    return categoryLabel(key);
  }

  @override
  void dispose() {
    _custom.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? get _key {
    if (_choice == null) return null;
    if (_choice == _other) {
      final k = categoryKeyFromName(_custom.text);
      return k.isEmpty ? null : k;
    }
    return _choice;
  }

  double? get _value => parseAmount(_amount.text);

  String? get _categoryError => !_showErrors
      ? null
      : _key == null
      ? 'Choose a category or type a name.'
      : (_isNew && widget.usedKeys.contains(_key)
            ? 'You already have this category.'
            : null);

  String? get _amountError => _showErrors && _value == null
      ? 'Enter an amount greater than zero.'
      : null;

  void _save() {
    setState(() => _showErrors = true);
    final key = _key;
    final value = _value;
    if (key == null || value == null) return;
    if (_isNew && widget.usedKeys.contains(key)) return;
    Navigator.of(context).pop(BudgetSaved(categoryKey: key, amount: value));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = _value;
    final left = value == null
        ? null
        : widget.total - widget.otherAllocated - value;
    final share = value == null || widget.total <= 0
        ? null
        : (value / widget.total * 100).round();
    final available = [
      for (final k in suggestedBudgetKeys)
        if (!widget.usedKeys.contains(k) || k == widget.existing?.categoryKey)
          k,
    ];

    return SheetFrame(
      title: _isNew
          ? 'Add budget category'
          : 'Edit ${categoryLabel(widget.existing!.categoryKey)}',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: _isNew ? 'Add category' : 'Save changes',
            onPressed: _save,
          ),
          if (!_isNew)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(const BudgetDeleted()),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete this category'),
              style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            ),
        ],
      ),
      children: [
        Text('Category', style: text.titleSmall),
        const SizedBox(height: AppSpace.s),
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final k in available)
              ChoiceChip(
                avatar: Icon(categoryIcon(k), size: 18),
                label: Text(categoryLabel(k)),
                selected: _choice == k,
                showCheckmark: false,
                onSelected: (_) => setState(() => _choice = k),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Something else'),
              selected: _choice == _other,
              showCheckmark: false,
              onSelected: (_) => setState(() => _choice = _other),
            ),
          ],
        ),
        if (_choice == _other) ...[
          const SizedBox(height: AppSpace.m),
          AppTextField(
            label: 'Category name',
            controller: _custom,
            hint: 'e.g. Return gifts',
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_categoryError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text(
              _categoryError!,
              style: text.bodySmall?.copyWith(color: AppColors.errorText),
            ),
          ),
        const SizedBox(height: AppSpace.l),
        AppTextField(
          label: 'Amount',
          controller: _amount,
          hint: '4,50,000',
          keyboardType: TextInputType.number,
          prefix: const Padding(
            padding: EdgeInsets.only(left: AppSpace.l, right: AppSpace.s),
            child: Text('₹'),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
          ],
          errorText: _amountError,
          onChanged: (_) => setState(() {}),
        ),
        if (value != null) ...[
          const SizedBox(height: AppSpace.s),
          Text(
            '${formatInr(value)} is $share% of your ${formatInr(widget.total)} budget.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            left! >= 0
                ? '${formatInr(left)} left to allocate after this.'
                : 'This takes you ${formatInr(-left)} over budget.',
            style: text.bodyMedium?.copyWith(
              color: left >= 0 ? AppColors.successText : AppColors.errorText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
