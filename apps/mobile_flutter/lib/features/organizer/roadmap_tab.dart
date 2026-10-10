import 'package:flutter/material.dart';

import '../../core/category_icons.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/roadmap.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/progress_ring.dart';
import 'event_stats.dart';
import 'widgets/generating_view.dart';
import 'widgets/task_tile.dart';

/// Roadmap tab of an event: progress, filters, tasks by category, removed tasks.
class RoadmapTab extends StatefulWidget {
  const RoadmapTab({
    super.key,
    required this.tasks,
    this.removedTasks = const [],
    this.today,
    this.generating = false,
    this.generateError,
    this.onGenerate,
    this.onRegenerate,
    this.onAddTask,
    this.onOpenTask,
    this.onRestoreTask,
  });

  final List<TaskWithDependencies> tasks;
  final List<TaskWithDependencies> removedTasks;
  final DateTime? today;
  final bool generating;
  final String? generateError;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onAddTask;
  final ValueChanged<TaskWithDependencies>? onOpenTask;
  final ValueChanged<TaskWithDependencies>? onRestoreTask;

  @override
  State<RoadmapTab> createState() => _RoadmapTabState();
}

class _RoadmapTabState extends State<RoadmapTab> {
  TaskFilter _filter = TaskFilter.all;
  bool _showRemoved = false;

  static const _labels = {
    TaskFilter.all: 'All',
    TaskFilter.todo: 'To do',
    TaskFilter.overdue: 'Overdue',
    TaskFilter.done: 'Done',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (widget.generating) {
      return ListView(children: const [GeneratingView()]);
    }

    final active = activeTasks(widget.tasks);
    if (active.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
                const SizedBox(height: AppSpace.m),
                Text('Get your roadmap', style: text.headlineSmall),
                const SizedBox(height: AppSpace.s),
                Text(
                  'We will pick the tasks you need for this event and set due dates working back from the big day. You can change anything afterwards.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
                if (widget.generateError != null) ...[
                  const SizedBox(height: AppSpace.m),
                  _ErrorNote(widget.generateError!),
                ],
                const SizedBox(height: AppSpace.l),
                PrimaryButton(
                  label: widget.generateError == null ? 'Generate my roadmap' : 'Try again',
                  icon: Icons.auto_awesome,
                  onPressed: widget.onGenerate,
                ),
              ],
            ),
          ),
          if (widget.onAddTask != null) ...[
            const SizedBox(height: AppSpace.m),
            SecondaryButton(label: 'Add a task myself', icon: Icons.add, onPressed: widget.onAddTask),
          ],
        ],
      );
    }

    final progress = taskProgress(active, today: widget.today);
    final shown = filterTasks(active, _filter, today: widget.today);
    final groups = groupTasksByCategory(shown);
    int count(TaskFilter f) => filterTasks(active, f, today: widget.today).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.m, AppSpace.gutter, AppSpace.xxl),
      children: [
        AppCard(
          raised: false,
          child: Row(
            children: [
              ProgressRing(
                value: progress.fraction,
                size: 64,
                strokeWidth: 7,
                child: Text('${progress.percent}%', style: text.labelMedium),
              ),
              const SizedBox(width: AppSpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${progress.done} of ${progress.total} tasks done', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      progress.overdue > 0
                          ? '${plural(progress.overdue, 'task')} overdue'
                          : 'Nothing is overdue',
                      style: text.bodyMedium?.copyWith(
                        color: progress.overdue > 0 ? AppColors.errorText : AppColors.successText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.m),
        // A wrapping row (not a sideways scroll), so every filter stays visible.
        Wrap(
          spacing: AppSpace.s,
          children: [
            for (final f in TaskFilter.values)
              ChoiceChip(
                label: Text('${_labels[f]} (${count(f)})'),
                selected: _filter == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(label: 'Add task', icon: Icons.add, onPressed: widget.onAddTask),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: SecondaryButton(label: 'Re-run', icon: Icons.refresh, onPressed: widget.onRegenerate),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
            child: Text(
              switch (_filter) {
                TaskFilter.overdue => 'Nothing is overdue. Well done!',
                TaskFilter.done => 'No finished tasks yet.',
                _ => 'No tasks here.',
              },
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s, top: AppSpace.s),
            child: Row(
              children: [
                Icon(categoryIcon(g.categoryKey), size: 20, color: AppColors.maroon),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(categoryLabel(g.categoryKey), style: text.titleMedium?.copyWith(color: AppColors.maroon)),
                  ),
                ),
                Text('${g.tasks.length}', style: text.bodySmall),
              ],
            ),
          ),
          AppCard(
            raised: false,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
            child: Column(
              children: [
                for (var i = 0; i < g.tasks.length; i++) ...[
                  if (i > 0) const Divider(),
                  TaskTile(
                    task: g.tasks[i],
                    today: widget.today,
                    onTap: widget.onOpenTask == null ? null : () => widget.onOpenTask!(g.tasks[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpace.l),
        TextButton.icon(
          onPressed: () => setState(() => _showRemoved = !_showRemoved),
          icon: Icon(_showRemoved ? Icons.expand_less : Icons.expand_more),
          label: Text(
            _showRemoved ? 'Hide removed tasks' : 'Removed tasks (${widget.removedTasks.length})',
          ),
        ),
        if (_showRemoved)
          widget.removedTasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.s),
                  child: Text('No removed tasks.', style: text.bodyMedium),
                )
              : AppCard(
                  raised: false,
                  color: AppColors.surfaceMuted,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
                  child: Column(
                    children: [
                      for (final t in widget.removedTasks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: text.bodyLarge?.copyWith(
                                    color: AppColors.inkMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: widget.onRestoreTask == null ? null : () => widget.onRestoreTask!(t),
                                child: const Text('Restore'),
                              ),
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

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(AppRadius.m)),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.errorText, size: 20),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.errorText)),
            ),
          ],
        ),
      );
}
