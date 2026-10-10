import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/vendor.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../vendor_profile_logic.dart';

/// "Finish your profile": progress ring and the seven things a profile needs.
/// Missing items are tappable and open the editor at that section.
class CompletenessCard extends StatelessWidget {
  const CompletenessCard({super.key, required this.completeness, this.onTapItem});

  final VendorCompleteness completeness;
  final ValueChanged<VendorRequiredField>? onTapItem;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = completenessItems(completeness);
    final done = items.where((i) => i.done).length;
    final percent = completenessPercent(completeness);

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: percent / 100,
                size: 72,
                strokeWidth: 8,
                color: completeness.complete ? AppColors.successText : AppColors.primary,
                child: Text('$percent%', style: text.titleMedium),
              ),
              const SizedBox(width: AppSpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completeness.complete ? 'Your profile is complete' : 'Finish your profile',
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completeness.complete
                          ? 'Ready to send for review.'
                          : '$done of ${items.length} done',
                      style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          const Divider(),
          for (final item in items)
            Semantics(
              button: !item.done && onTapItem != null,
              label: '${item.label}. ${item.done ? 'Done' : item.hint}.',
              excludeSemantics: true,
              onTap: item.done ? null : () => onTapItem?.call(item.field),
              child: InkWell(
                onTap: item.done || onTapItem == null ? null : () => onTapItem!(item.field),
                borderRadius: BorderRadius.circular(AppRadius.m),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      Icon(
                        item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: item.done ? AppColors.successText : AppColors.outlineStrong,
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: text.titleMedium?.copyWith(
                                  color: item.done ? AppColors.inkMuted : AppColors.ink,
                                ),
                              ),
                              if (!item.done) Text(item.hint, style: text.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      if (!item.done) const Icon(Icons.chevron_right, color: AppColors.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
