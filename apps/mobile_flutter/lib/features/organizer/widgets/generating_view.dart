import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/brand_mark.dart';

/// Shown while the roadmap is generated (the server asks an LLM, which can take
/// up to a minute and a half). Walks through the steps so the wait feels alive.
class GeneratingView extends StatefulWidget {
  const GeneratingView({super.key, this.stepDuration = const Duration(seconds: 3)});

  final Duration stepDuration;

  static const steps = [
    'Reading your event details',
    'Choosing the tasks you need',
    'Setting due dates for the big day',
    'Putting your roadmap together',
  ];

  @override
  State<GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<GeneratingView> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.stepDuration, (t) {
      if (!mounted) return t.cancel();
      if (_step < GeneratingView.steps.length - 1) {
        setState(() => _step++);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpace.l),
          const BrandMark(size: 72),
          const SizedBox(height: AppSpace.xl),
          Semantics(
            header: true,
            child: Text('Building your roadmap', style: text.headlineSmall, textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            'This can take up to a minute. You can keep this screen open.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xl),
          const LinearProgressIndicator(minHeight: 6, borderRadius: BorderRadius.all(Radius.circular(6))),
          const SizedBox(height: AppSpace.xl),
          for (var i = 0; i < GeneratingView.steps.length; i++)
            Semantics(
              liveRegion: i == _step,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: i < _step
                          ? const Icon(Icons.check_circle, color: AppColors.successText, size: 22)
                          : i == _step
                              ? const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : const Icon(Icons.radio_button_unchecked, color: AppColors.outlineStrong, size: 22),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: Text(
                        GeneratingView.steps[i],
                        style: text.bodyLarge?.copyWith(
                          color: i <= _step ? AppColors.ink : AppColors.inkMuted,
                          fontWeight: i == _step ? FontWeight.w800 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
