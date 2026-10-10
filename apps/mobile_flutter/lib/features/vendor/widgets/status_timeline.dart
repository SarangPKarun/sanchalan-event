import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

enum TimelineState { done, current, upcoming }

class TimelineStep {
  const TimelineStep(this.title, this.subtitle, this.state);

  final String title;
  final String subtitle;
  final TimelineState state;
}

/// Vertical steps joined by a line: what has happened and what comes next.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            label:
                '${steps[i].title}. ${steps[i].subtitle}. ${switch (steps[i].state) {
              TimelineState.done => 'Done',
              TimelineState.current => 'In progress',
              TimelineState.upcoming => 'Next',
            }}.',
            excludeSemantics: true,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        _Marker(state: steps[i].state),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: steps[i].state == TimelineState.done
                                  ? AppColors.successText
                                  : AppColors.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: text.titleMedium?.copyWith(
                              color: steps[i].state == TimelineState.upcoming
                                  ? AppColors.inkMuted
                                  : AppColors.ink,
                            ),
                          ),
                          Text(steps[i].subtitle, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      TimelineState.done => const Icon(Icons.check_circle, color: AppColors.successText, size: 28),
      TimelineState.current => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warningBg,
            border: Border.all(color: AppColors.warningText, width: 2),
          ),
          child: const Icon(Icons.hourglass_top, size: 14, color: AppColors.warningText),
        ),
      TimelineState.upcoming => const Icon(Icons.radio_button_unchecked, color: AppColors.outlineStrong, size: 28),
    };
  }
}
