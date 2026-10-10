import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/event.dart';
import '../../models/roadmap.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton.dart';
import 'event_stats.dart';
import 'widgets/budget_widgets.dart';
import 'widgets/hero_card.dart';
import 'widgets/task_tile.dart';

/// What the home tab shows, so a screen never guesses.
enum HomeStatus { loading, error, ready }

/// Home tab of the organizer app. Plain widget: data in, callbacks out.
/// [featured] is the event shown in the hero card, with its tasks and budget.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.status,
    this.organizerName,
    this.events = const [],
    this.featured,
    this.today,
    this.onRetry,
    this.onRefresh,
    this.onSelectEvent,
    this.onOpenEvent,
    this.onNewEvent,
    this.onAddTask,
    this.onAddCategory,
    this.onFindVendors,
    this.onOpenTask,
  });

  final HomeStatus status;
  final String? organizerName;
  final List<EventGroup> events;
  final EventGroup? featured;
  final DateTime? today;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final ValueChanged<String>? onSelectEvent;
  final ValueChanged<String>? onOpenEvent;
  final VoidCallback? onNewEvent;
  final VoidCallback? onAddTask;
  final VoidCallback? onAddCategory;
  final VoidCallback? onFindVendors;
  final ValueChanged<TaskWithDependencies>? onOpenTask;

  String get _greeting {
    final first = organizerName?.trim().split(' ').first;
    return first == null || first.isEmpty ? 'Hello' : 'Hello, $first';
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (status) {
      HomeStatus.loading => const _HomeSkeleton(),
      HomeStatus.error => ErrorRetry(onRetry: onRetry ?? () {}),
      HomeStatus.ready => events.isEmpty || featured == null ? _empty(context) : _content(context),
    };
    final scrollable = status == HomeStatus.ready && events.isNotEmpty && featured != null;
    return SafeArea(
      bottom: false,
      child: scrollable && onRefresh != null
          ? RefreshIndicator(onRefresh: onRefresh!, child: body)
          : body,
    );
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Greeting(text: _greeting),
            Expanded(
              child: EmptyState(
                icon: Icons.celebration_outlined,
                title: 'Plan your first event',
                message: 'Tell us about the celebration and we will build your roadmap and budget.',
                actionLabel: 'Create event',
                onAction: onNewEvent,
              ),
            ),
          ],
        ),
      );

  Widget _content(BuildContext context) {
    final event = featured!;
    final progress = taskProgress(event.tasks, today: today);
    final next = nextUp(event.tasks, today: today);
    final budget = budgetSummary(event);
    final sorted = sortEvents(events, today: today);
    final text = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
      children: [
        _Greeting(text: _greeting),
        if (sorted.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in sorted) ...[
                  ChoiceChip(
                    label: Text(e.name),
                    selected: e.id == event.id,
                    onSelected: (_) => onSelectEvent?.call(e.id),
                    showCheckmark: false,
                    labelStyle: text.labelMedium?.copyWith(
                      color: e.id == event.id ? AppColors.onPrimaryContainer : AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.m),
        ],
        HeroCard(
          event: event,
          progress: progress,
          today: today,
          onTap: onOpenEvent == null ? null : () => onOpenEvent!(event.id),
        ),
        const SizedBox(height: AppSpace.l),
        // Equal heights even when one label wraps to two lines.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _QuickAction(icon: Icons.add_task, label: 'Add task', onTap: onAddTask)),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: _QuickAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Add budget item',
                  onTap: onAddCategory,
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(child: _QuickAction(icon: Icons.storefront_outlined, label: 'Find vendors', onTap: onFindVendors)),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        SectionHeader(
          'Next up',
          actionLabel: progress.isEmpty ? null : 'See all',
          onAction: onOpenEvent == null ? null : () => onOpenEvent!(event.id),
        ),
        if (progress.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generate your roadmap', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'We will pick the tasks you need and set due dates working back from the big day.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpace.l),
                PrimaryButton(
                  label: 'Open event',
                  expand: false,
                  icon: Icons.auto_awesome,
                  onPressed: onOpenEvent == null ? null : () => onOpenEvent!(event.id),
                ),
              ],
            ),
          )
        else if (next.isEmpty)
          const AppCard(
            child: Row(
              children: [
                Icon(Icons.celebration_outlined, color: AppColors.successText),
                SizedBox(width: AppSpace.m),
                Expanded(child: Text("You're all caught up. Nothing is waiting on you.")),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
            child: Column(
              children: [
                for (var i = 0; i < next.length; i++) ...[
                  if (i > 0) const Divider(),
                  TaskTile(
                    task: next[i],
                    today: today,
                    showCategory: true,
                    onTap: onOpenTask == null ? null : () => onOpenTask!(next[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpace.xl),
        SectionHeader(
          'Budget',
          actionLabel: 'See budget',
          onAction: onOpenEvent == null ? null : () => onOpenEvent!(event.id),
        ),
        AppCard(
          child: budget.shares.isEmpty
              ? Text(
                  'No budget categories yet.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(formatInr(budget.total), style: text.headlineSmall),
                        const SizedBox(width: AppSpace.s),
                        Text('total', style: text.bodySmall),
                      ],
                    ),
                    const SizedBox(height: AppSpace.m),
                    BudgetBar(summary: budget),
                    const SizedBox(height: AppSpace.m),
                    BudgetLegend(summary: budget),
                    const SizedBox(height: AppSpace.s),
                    RemainingLabel(summary: budget),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m, top: AppSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(text, style: t.headlineLarge?.copyWith(color: AppColors.maroon))),
          const SizedBox(height: 2),
          Text("Let's plan something beautiful.", style: t.bodyLarge?.copyWith(color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      raised: false,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.m, horizontal: AppSpace.s),
      semanticLabel: label,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpace.m),
          Skeleton(height: 32, width: 180),
          SizedBox(height: AppSpace.s),
          Skeleton(height: 18, width: 240),
          SizedBox(height: AppSpace.xl),
          SkeletonCard(height: 190),
          SizedBox(height: AppSpace.l),
          Row(
            children: [
              Expanded(child: SkeletonCard(height: 88)),
              SizedBox(width: AppSpace.m),
              Expanded(child: SkeletonCard(height: 88)),
              SizedBox(width: AppSpace.m),
              Expanded(child: SkeletonCard(height: 88)),
            ],
          ),
          SizedBox(height: AppSpace.xl),
          SkeletonCard(height: 150),
        ],
      ),
    );
  }
}
