import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';
import '../../models/event.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/primary_button.dart';
import 'sheets/sheet_scaffold.dart' show parseAmount;

class EventFormValues {
  const EventFormValues({
    required this.type,
    required this.name,
    required this.region,
    required this.date,
    required this.guests,
    required this.budget,
    required this.tier,
  });

  final EventType type;
  final String name;
  final String region;
  final DateTime date;
  final int guests;
  final double budget;
  final BudgetTier tier;
}

const _typeIcons = {
  EventType.wedding: Icons.favorite_border,
  EventType.birthday: Icons.cake_outlined,
  EventType.corporate: Icons.business_center_outlined,
  EventType.religious: Icons.temple_hindu_outlined,
  EventType.engagementOnly: Icons.diamond_outlined,
  EventType.custom: Icons.tune,
};

const _tierHints = {
  BudgetTier.essential: 'Simple and thrifty',
  BudgetTier.standard: 'Balanced and comfortable',
  BudgetTier.premium: 'Elevated touches',
  BudgetTier.luxury: 'No compromises',
};

/// Create ([initial] null) or edit an event. [onSubmit] does the work and
/// returns an error message to show, or null on success. On edit, the type and
/// region are fixed (the API does not change them).
class EventFormView extends StatefulWidget {
  const EventFormView({super.key, this.initial, required this.onSubmit, this.today, this.onBack});

  final EventGroup? initial;
  final Future<String?> Function(EventFormValues values, BudgetAdjustment? adjustment) onSubmit;
  final DateTime? today;
  final VoidCallback? onBack;

  @override
  State<EventFormView> createState() => _EventFormViewState();
}

class _EventFormViewState extends State<EventFormView> {
  late EventType _type = widget.initial?.eventType ?? EventType.wedding;
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _region = TextEditingController(text: widget.initial?.region ?? '');
  late DateTime? _date = widget.initial?.primaryDate;
  late final _guests = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.guestCountEstimate.toString(),
  );
  late final _budget = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.totalBudget.round().toString(),
  );
  late BudgetTier _tier = widget.initial?.budgetTier ?? BudgetTier.standard;
  BudgetAdjustment _adjustment = BudgetAdjustment.rescale;
  bool _showErrors = false;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    _guests.dispose();
    _budget.dispose();
    super.dispose();
  }

  int? get _guestCount {
    final v = int.tryParse(_guests.text.trim());
    return v != null && v > 0 ? v : null;
  }

  double? get _budgetValue => parseAmount(_budget.text);

  bool get _budgetChanged =>
      _isEdit && _budgetValue != null && _budgetValue != widget.initial!.totalBudget;

  String? get _nameError => _showErrors && _name.text.trim().isEmpty ? 'Give your event a name.' : null;
  String? get _regionError => _showErrors && _region.text.trim().isEmpty ? 'Where is it happening?' : null;
  String? get _dateError => _showErrors && _date == null ? 'Choose the date.' : null;
  String? get _guestError => _showErrors && _guestCount == null ? 'Enter the number of guests.' : null;
  String? get _budgetError =>
      _showErrors && _budgetValue == null ? 'Enter a budget greater than zero.' : null;

  Future<void> _pickDate() async {
    final today = dateOnly(widget.today ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 30)),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _showErrors = true;
      _error = null;
    });
    if (_name.text.trim().isEmpty ||
        (!_isEdit && _region.text.trim().isEmpty) ||
        _date == null ||
        _guestCount == null ||
        _budgetValue == null) {
      return;
    }
    setState(() => _submitting = true);
    final error = await widget.onSubmit(
      EventFormValues(
        type: _type,
        name: _name.text.trim(),
        region: _region.text.trim(),
        date: _date!,
        guests: _guestCount!,
        budget: _budgetValue!,
        tier: _tier,
      ),
      _budgetChanged ? _adjustment : null,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final budget = _budgetValue;
    final guests = _guestCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit event' : 'New event'),
        leading: widget.onBack == null
            ? null
            : IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.s, AppSpace.xl, AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEdit) ...[
                      Text('What are you celebrating?', style: text.titleSmall),
                      const SizedBox(height: AppSpace.s),
                      Wrap(
                        spacing: AppSpace.s,
                        runSpacing: AppSpace.s,
                        children: [
                          for (final t in EventType.values)
                            ChoiceChip(
                              avatar: Icon(_typeIcons[t], size: 18),
                              label: Text(eventTypeLabel(t)),
                              selected: _type == t,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _type = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.l),
                    ],
                    AppTextField(
                      label: 'Event name',
                      controller: _name,
                      hint: 'e.g. Priya & Rohan',
                      errorText: _nameError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpace.l),
                    if (_isEdit)
                      _ReadOnlyRow(
                        label: 'Type and place',
                        value: '${eventTypeLabel(_type)} · ${widget.initial!.region}',
                      )
                    else
                      AppTextField(
                        label: 'City or region',
                        controller: _region,
                        hint: 'e.g. Pune',
                        errorText: _regionError,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                    const SizedBox(height: AppSpace.l),
                    Text('Date', style: text.titleSmall),
                    const SizedBox(height: AppSpace.s),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_date == null ? 'Choose a date' : formatLongDate(_date!)),
                      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                    ),
                    if (_dateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Text(_dateError!, style: text.bodySmall?.copyWith(color: AppColors.errorText)),
                      ),
                    const SizedBox(height: AppSpace.l),
                    AppTextField(
                      label: 'Expected guests',
                      controller: _guests,
                      hint: '250',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      errorText: _guestError,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpace.l),
                    AppTextField(
                      label: 'Total budget',
                      controller: _budget,
                      hint: '15,00,000',
                      keyboardType: TextInputType.number,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: AppSpace.l, right: AppSpace.s),
                        child: Text('₹'),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                      errorText: _budgetError,
                      helperText: budget != null && guests != null
                          ? '${formatInr(budget)} · about ${formatInr(budget / guests)} per guest'
                          : budget != null
                              ? formatInr(budget)
                              : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_budgetChanged) ...[
                      const SizedBox(height: AppSpace.l),
                      Text('What should happen to your budget categories?', style: text.titleSmall),
                      const SizedBox(height: AppSpace.s),
                      RadioGroup<BudgetAdjustment>(
                        groupValue: _adjustment,
                        onChanged: (v) => setState(() => _adjustment = v ?? _adjustment),
                        child: Column(
                          children: [
                            for (final (value, title, hint) in const [
                              (
                                BudgetAdjustment.rescale,
                                'Rescale every category',
                                'Each category grows or shrinks in proportion.',
                              ),
                              (
                                BudgetAdjustment.keep,
                                'Keep categories as they are',
                                'Only the total changes. You may need to adjust categories yourself.',
                              ),
                            ])
                              RadioListTile<BudgetAdjustment>(
                                value: value,
                                title: Text(title),
                                subtitle: Text(hint),
                                contentPadding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.l),
                    Text('Budget style', style: text.titleSmall),
                    const SizedBox(height: AppSpace.s),
                    Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.s,
                      children: [
                        for (final t in BudgetTier.values)
                          ChoiceChip(
                            label: Text(budgetTierLabel(t)),
                            selected: _tier == t,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _tier = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(_tierHints[_tier]!, style: text.bodySmall),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.l),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpace.m),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          child: Text(
                            _error!,
                            style: text.bodyMedium?.copyWith(color: AppColors.errorText),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                if (_submitting && !_isEdit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s),
                    child: Text(
                      'Building your budget. This can take up to a minute.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ),
                PrimaryButton(
                  label: _isEdit ? 'Save changes' : 'Create event',
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.titleSmall),
        const SizedBox(height: AppSpace.s),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: Text(value, style: text.bodyLarge),
        ),
      ],
    );
  }
}
