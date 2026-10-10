import 'package:flutter/material.dart';

import '../../core/category_icons.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/event.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';

/// Vendors tab of an event: shortcuts into the vendor directory by budget category.
class EventVendorsTab extends StatelessWidget {
  const EventVendorsTab({super.key, required this.event, this.onBrowse});

  final EventGroup event;

  /// Called with a category key to filter by, or null for all vendors.
  final ValueChanged<String?>? onBrowse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cats = [...event.budgetCategories]..sort((a, b) => b.allocatedAmount.compareTo(a.allocatedAmount));
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.m, AppSpace.gutter, AppSpace.xxl),
      children: [
        Text('Find vendors for ${event.name}', style: text.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Browse trusted vendors by what you plan to spend on.',
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpace.l),
        PrimaryButton(
          label: 'Browse all vendors',
          icon: Icons.storefront_outlined,
          onPressed: onBrowse == null ? null : () => onBrowse!(null),
        ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          Text('By category', style: text.titleMedium),
          const SizedBox(height: AppSpace.s),
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s),
              child: AppCard(
                raised: false,
                onTap: onBrowse == null ? null : () => onBrowse!(c.categoryKey),
                semanticLabel: '${categoryLabel(c.categoryKey)} vendors, budget ${formatInr(c.allocatedAmount)}',
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                      child: Icon(categoryIcon(c.categoryKey), color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(categoryLabel(c.categoryKey), style: text.titleMedium),
                          Text('Budget ${formatInrCompact(c.allocatedAmount)}', style: text.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.inkMuted),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpace.xl),
        Container(
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.inkMuted),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Guest list and RSVPs', style: text.titleMedium),
                    Text('Coming soon', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
