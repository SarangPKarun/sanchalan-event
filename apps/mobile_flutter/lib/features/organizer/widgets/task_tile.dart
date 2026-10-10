import 'package:flutter/material.dart';

import '../../../core/category_icons.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/enums.dart';
import '../../../models/roadmap.dart';
import '../event_stats.dart';

/// One roadmap task: status icon, name, due date. Tap opens the task.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.today,
    this.onTap,
    this.showCategory = false,
    this.trailing,
  });

  final TaskWithDependencies task;
  final DateTime? today;
  final VoidCallback? onTap;

  /// Show the category icon and name under the title (used where tasks are not grouped).
  final bool showCategory;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = effectiveStatus(task, today: today);
    final (icon, color) = switch (status) {
      TaskStatus.done => (Icons.check_circle, AppColors.successText),
      TaskStatus.inProgress => (Icons.timelapse, AppColors.infoText),
      TaskStatus.overdue => (Icons.error, AppColors.errorText),
      TaskStatus.notApplicable => (Icons.remove_circle_outline, AppColors.inkMuted),
      TaskStatus.notStarted => (Icons.radio_button_unchecked, AppColors.inkMuted),
    };
    final done = status == TaskStatus.done;
    final due = dueLabel(task.dueDate, today: today);
    final overdue = status == TaskStatus.overdue;

    return Semantics(
      button: onTap != null,
      label: '${task.name}. ${taskStatusLabel(status)}. $due.',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
            child: Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: done ? AppColors.inkMuted : AppColors.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        due,
                        style: text.bodySmall?.copyWith(
                          color: overdue ? AppColors.errorText : AppColors.inkMuted,
                          fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      if (showCategory)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon(task.categoryKey), size: 14, color: AppColors.inkMuted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(categoryLabel(task.categoryKey), style: text.bodySmall),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.inkMuted) : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
