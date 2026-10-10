import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/event.dart';
import '../../../shared/widgets/app_card.dart';

/// One event in the list: date badge, name, type, when, guests and budget.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.today, this.onTap});

  final EventGroup event;
  final DateTime? today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final past = daysUntil(event.primaryDate, today: today) < 0;
    final when = whenLabel(event.primaryDate, today: today);
    final date = event.primaryDate;

    final card = AppCard(
      onTap: onTap,
      raised: !past,
      semanticLabel:
          '${event.name}, ${eventTypeLabel(event.eventType)}, ${formatDate(date)}, $when, ${plural(event.guestCountEstimate, 'guest')}, budget ${formatInr(event.totalBudget)}',
      child: Row(
        children: [
          // Date badge
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
            decoration: BoxDecoration(
              color: past ? AppColors.surfaceMuted : AppColors.maroonContainer,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: text.headlineSmall?.copyWith(color: past ? AppColors.inkMuted : AppColors.maroon, height: 1.1),
                ),
                Text(
                  formatDayMonth(date).split(' ').last.toUpperCase(),
                  style: text.labelSmall?.copyWith(color: past ? AppColors.inkMuted : AppColors.maroon),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${eventTypeLabel(event.eventType)} · $when',
                  style: text.bodySmall?.copyWith(
                    color: when == 'Today' || when == 'Tomorrow' ? AppColors.primary : AppColors.inkMuted,
                    fontWeight: when == 'Today' || when == 'Tomorrow' ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                Row(
                  children: [
                    const Icon(Icons.groups_outlined, size: 16, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Text('${event.guestCountEstimate}', style: text.bodySmall),
                    const SizedBox(width: AppSpace.m),
                    const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(formatInrCompact(event.totalBudget), style: text.bodySmall, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        ],
      ),
    );
    return past ? Opacity(opacity: 0.8, child: card) : card;
  }
}
