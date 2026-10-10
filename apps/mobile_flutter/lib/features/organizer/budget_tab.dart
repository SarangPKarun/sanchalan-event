import 'package:flutter/material.dart';

import '../../core/category_icons.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/event.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'event_stats.dart';
import 'widgets/budget_widgets.dart';

/// Budget tab of an event: totals, a split bar and every category.
class BudgetTab extends StatelessWidget {
  const BudgetTab({
    super.key,
    required this.event,
    this.onEditTotal,
    this.onAddCategory,
    this.onEditCategory,
  });

  final EventGroup event;
  final VoidCallback? onEditTotal;
  final VoidCallback? onAddCategory;
  final ValueChanged<BudgetCategory>? onEditCategory;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summary = budgetSummary(event);
    final byKey = {for (final c in event.budgetCategories) c.categoryKey: c};

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.m, AppSpace.gutter, AppSpace.xxl),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total budget', style: text.bodySmall),
                        Text(formatInr(summary.total), style: text.headlineMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit total budget',
                    onPressed: onEditTotal,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              BudgetBar(summary: summary, maxSegments: 5),
              const SizedBox(height: AppSpace.m),
              Row(
                children: [
                  Expanded(child: _Figure(label: 'Allocated', value: formatInr(summary.allocated))),
                  Expanded(
                    child: _Figure(
                      label: summary.isOver ? 'Over by' : 'Left to allocate',
                      value: formatInr(summary.remaining.abs()),
                      color: summary.isOver ? AppColors.errorText : AppColors.successText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (summary.isOver) ...[
          const SizedBox(height: AppSpace.m),
          Container(
            padding: const EdgeInsets.all(AppSpace.m),
            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: Text(
                    'Your categories add up to ${formatInr(summary.allocated)}, which is ${formatInr(summary.remaining.abs())} more than your total budget. Lower a category or raise the total.',
                    style: text.bodyMedium?.copyWith(color: AppColors.warningText),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            Expanded(child: Text('Categories', style: text.titleLarge)),
            Text(plural(event.budgetCategories.length, 'category', 'categories'), style: text.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpace.s),
        if (summary.shares.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
            child: Text(
              'No categories yet. Add the first one to start planning your spend.',
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        for (var i = 0; i < summary.shares.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: AppCard(
              raised: false,
              onTap: onEditCategory == null ? null : () => onEditCategory!(byKey[summary.shares[i].categoryKey]!),
              semanticLabel:
                  '${categoryLabel(summary.shares[i].categoryKey)}, ${formatInr(summary.shares[i].amount)}, ${(summary.shares[i].fractionOfTotal * 100).round()} percent of budget. Tap to edit.',
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: shareColor(i).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon(summary.shares[i].categoryKey), color: shareColor(i), size: 22),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(categoryLabel(summary.shares[i].categoryKey), style: text.titleMedium),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: summary.shares[i].fractionOfTotal.clamp(0.0, 1.0),
                            minHeight: 6,
                            color: shareColor(i),
                            backgroundColor: AppColors.surfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatInrCompact(summary.shares[i].amount), style: text.titleMedium),
                      Text('${(summary.shares[i].fractionOfTotal * 100).round()}%', style: text.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Add category', icon: Icons.add, onPressed: onAddCategory),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        Text(value, style: text.titleMedium?.copyWith(color: color)),
      ],
    );
  }
}
