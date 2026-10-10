import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/event.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../event_stats.dart';

/// The featured event on the home screen: name, countdown and task progress.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.event, required this.progress, this.today, this.onTap});

  final EventGroup event;
  final TaskProgress progress;
  final DateTime? today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = daysUntil(event.primaryDate, today: today);
    final upcoming = days > 1;
    const onMaroon = AppColors.onMaroon;
    const soft = AppColors.goldContainer;

    // Scales down instead of overflowing next to the ring on narrow screens or large text.
    final countdown = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: upcoming
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$days', style: text.displayMedium?.copyWith(color: onMaroon, height: 1)),
                const SizedBox(width: 6),
                Text('days to go', style: text.titleMedium?.copyWith(color: soft)),
              ],
            )
          : Text(daysToGoLabel(event.primaryDate, today: today),
              style: text.headlineMedium?.copyWith(color: onMaroon)),
    );

    return Semantics(
      button: onTap != null,
      label:
          '${event.name}, ${formatDate(event.primaryDate)}. ${daysToGoLabel(event.primaryDate, today: today)}. ${progress.done} of ${progress.total} tasks done.',
      excludeSemantics: true,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.maroon, Color(0xFF5A1620)],
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(eventTypeLabel(event.eventType),
                            style: text.labelMedium?.copyWith(color: onMaroon)),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward, color: soft, size: 20),
                    ],
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(event.name, style: text.headlineMedium?.copyWith(color: onMaroon)),
                  const SizedBox(height: 4),
                  Text(
                    '${formatLongDate(event.primaryDate)} · ${event.region}',
                    style: text.bodyMedium?.copyWith(color: soft),
                  ),
                  const SizedBox(height: AppSpace.l),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: countdown),
                      if (!progress.isEmpty)
                        ProgressRing(
                          value: progress.fraction,
                          size: 76,
                          strokeWidth: 8,
                          color: AppColors.gold,
                          trackColor: Colors.white.withValues(alpha: 0.2),
                          semanticLabel: '${progress.percent} percent of tasks done',
                          child: Text('${progress.percent}%',
                              style: text.titleMedium?.copyWith(color: onMaroon)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    progress.isEmpty
                        ? 'Your roadmap is not generated yet'
                        : '${progress.done} of ${progress.total} tasks done'
                            '${progress.overdue > 0 ? ' · ${progress.overdue} overdue' : ''}',
                    style: text.bodyMedium?.copyWith(color: soft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
