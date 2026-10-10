import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/enums.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/primary_button.dart';
import 'sheet_scaffold.dart';

/// Asks how to re-run the roadmap. Returns the chosen mode, or null if dismissed.
Future<RoadmapRegenMode?> showRegenerateSheet(BuildContext context) =>
    showAppSheet<RoadmapRegenMode>(context, (_) => const RegenerateSheet());

class RegenerateSheet extends StatefulWidget {
  const RegenerateSheet({super.key});

  @override
  State<RegenerateSheet> createState() => _RegenerateSheetState();
}

class _RegenerateSheetState extends State<RegenerateSheet> {
  RoadmapRegenMode _mode = RoadmapRegenMode.keepMyWork;

  static const _options = [
    (
      RoadmapRegenMode.keepMyWork,
      'Refresh, keep my work',
      'Updates the suggested tasks but keeps your edits, finished tasks and anything you added.',
      false,
    ),
    (
      RoadmapRegenMode.addMissing,
      'Only add missing tasks',
      'Leaves every task as it is and adds the ones you do not have yet.',
      false,
    ),
    (
      RoadmapRegenMode.replaceAll,
      'Start over',
      'Replaces the whole roadmap. Your edits and progress will be lost.',
      true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: 'Re-run your roadmap',
      subtitle: 'Choose what should happen to the tasks you already have.',
      footer: PrimaryButton(
        label: _mode == RoadmapRegenMode.replaceAll
            ? 'Replace my roadmap'
            : 'Re-run roadmap',
        icon: Icons.auto_awesome,
        onPressed: () => Navigator.of(context).pop(_mode),
      ),
      children: [
        RadioGroup<RoadmapRegenMode>(
          groupValue: _mode,
          onChanged: (m) => setState(() => _mode = m ?? _mode),
          child: Column(
            children: [
              for (final (mode, title, description, risky) in _options)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.m),
                  child: AppCard(
                    raised: false,
                    onTap: () => setState(() => _mode = mode),
                    color: _mode == mode
                        ? (risky
                              ? AppColors.errorBg
                              : AppColors.primaryContainer)
                        : AppColors.surface,
                    borderColor: _mode == mode
                        ? (risky ? AppColors.error : AppColors.primary)
                        : AppColors.outline,
                    semanticLabel: '$title. $description',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<RoadmapRegenMode>(value: mode),
                        const SizedBox(width: AppSpace.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: text.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
