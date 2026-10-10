import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../event_stats.dart';

const _segmentColors = [
  AppColors.primary,
  AppColors.maroon,
  AppColors.gold,
  AppColors.infoText,
  AppColors.successText,
];

/// Colors used for the biggest categories; everything else is grouped as "Other".
Color shareColor(int index) =>
    index < _segmentColors.length ? _segmentColors[index] : AppColors.outlineStrong;

/// A bar split into the biggest budget categories (and "Other"), over a track
/// that stands for the total budget.
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.summary, this.maxSegments = 4, this.height = 14});

  final BudgetSummary summary;
  final int maxSegments;
  final double height;

  List<(Color, double)> get _segments {
    final shown = summary.shares.take(maxSegments).toList();
    final rest = summary.shares.skip(maxSegments).fold<double>(0, (s, e) => s + e.fractionOfTotal);
    return [
      for (var i = 0; i < shown.length; i++) (shareColor(i), shown[i].fractionOfTotal),
      if (rest > 0) (AppColors.outlineStrong, rest),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Budget used: ${(summary.allocatedFraction * 100).round()} percent allocated',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.surfaceMuted),
              child: LayoutBuilder(
                builder: (context, c) {
                  final segs = _segments;
                  final totalFraction = segs.fold<double>(0, (s, e) => s + e.$2);
                  // When over-allocated, scale down so the bar still fits.
                  final scale = totalFraction > 1 ? 1 / totalFraction : 1.0;
                  return Row(
                    // Stretch so each segment fills the bar's height (a childless box would be 0 high).
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (color, fraction) in segs)
                        SizedBox(
                          width: c.maxWidth * fraction * scale,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              border: const Border(right: BorderSide(color: AppColors.surface, width: 1.5)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dot, category name and amount for the biggest categories.
class BudgetLegend extends StatelessWidget {
  const BudgetLegend({super.key, required this.summary, this.maxItems = 4});

  final BudgetSummary summary;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = summary.shares.take(maxItems).toList();
    final rest = summary.shares.skip(maxItems).fold<double>(0, (s, e) => s + e.amount);
    Widget row(Color color, String label, double amount) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(label, style: text.bodyMedium, overflow: TextOverflow.ellipsis)),
              Text(formatInrCompact(amount), style: text.titleSmall),
            ],
          ),
        );
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) row(shareColor(i), categoryLabel(shown[i].categoryKey), shown[i].amount),
        if (rest > 0) row(AppColors.outlineStrong, 'Other', rest),
      ],
    );
  }
}

/// "₹60K left" in green, or "₹10K over budget" in red.
class RemainingLabel extends StatelessWidget {
  const RemainingLabel({super.key, required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final over = summary.isOver;
    final amount = formatInrCompact(summary.remaining.abs());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 18,
          color: over ? AppColors.errorText : AppColors.successText,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            over ? '$amount over budget' : '$amount left to allocate',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: over ? AppColors.errorText : AppColors.successText,
                ),
          ),
        ),
      ],
    );
  }
}
