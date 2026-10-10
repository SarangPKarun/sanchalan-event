import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/event.dart';
import '../../models/roadmap.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/skeleton.dart';
import 'budget_tab.dart';
import 'event_vendors_tab.dart';
import 'home_view.dart' show HomeStatus;
import 'roadmap_tab.dart';

enum EventMenuAction { edit, delete }

/// One event with Roadmap, Budget and Vendors tabs. Plain widget: data in, callbacks out.
class EventDetailView extends StatelessWidget {
  const EventDetailView({
    super.key,
    required this.status,
    this.event,
    this.removedTasks = const [],
    this.today,
    this.initialTab = 0,
    this.generating = false,
    this.generateError,
    this.onRetry,
    this.onEdit,
    this.onDelete,
    this.onGenerate,
    this.onRegenerate,
    this.onAddTask,
    this.onOpenTask,
    this.onRestoreTask,
    this.onEditTotal,
    this.onAddCategory,
    this.onEditCategory,
    this.onBrowseVendors,
  });

  final HomeStatus status;
  final EventGroup? event;
  final List<TaskWithDependencies> removedTasks;
  final DateTime? today;
  final int initialTab;
  final bool generating;
  final String? generateError;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onAddTask;
  final ValueChanged<TaskWithDependencies>? onOpenTask;
  final ValueChanged<TaskWithDependencies>? onRestoreTask;
  final VoidCallback? onEditTotal;
  final VoidCallback? onAddCategory;
  final ValueChanged<BudgetCategory>? onEditCategory;
  final ValueChanged<String?>? onBrowseVendors;

  @override
  Widget build(BuildContext context) {
    final e = event;
    if (status == HomeStatus.loading || (status == HomeStatus.ready && e == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(AppSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 28, width: 220),
              SizedBox(height: AppSpace.m),
              Skeleton(height: 18, width: 160),
              SizedBox(height: AppSpace.xl),
              SkeletonCard(height: 72),
              SizedBox(height: AppSpace.m),
              SkeletonCard(height: 160),
            ],
          ),
        ),
      );
    }
    if (status == HomeStatus.error) {
      return Scaffold(appBar: AppBar(), body: ErrorRetry(onRetry: onRetry ?? () {}));
    }

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(e!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<EventMenuAction>(
              tooltip: 'More',
              onSelected: (a) => switch (a) {
                EventMenuAction.edit => onEdit?.call(),
                EventMenuAction.delete => onDelete?.call(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: EventMenuAction.edit,
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit event details')),
                ),
                PopupMenuItem(
                  value: EventMenuAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.errorText),
                    title: Text('Delete event', style: TextStyle(color: AppColors.errorText)),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _Header(event: e, today: today)),
            const SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate()),
          ],
          body: TabBarView(
            children: [
              RoadmapTab(
                tasks: e.tasks,
                removedTasks: removedTasks,
                today: today,
                generating: generating,
                generateError: generateError,
                onGenerate: onGenerate,
                onRegenerate: onRegenerate,
                onAddTask: onAddTask,
                onOpenTask: onOpenTask,
                onRestoreTask: onRestoreTask,
              ),
              BudgetTab(
                event: e,
                onEditTotal: onEditTotal,
                onAddCategory: onAddCategory,
                onEditCategory: onEditCategory,
              ),
              EventVendorsTab(event: e, onBrowse: onBrowseVendors),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event, this.today});

  final EventGroup event;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget info(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.inkMuted),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: text.bodyMedium)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatLongDate(event.primaryDate)} · ${whenLabel(event.primaryDate, today: today)}',
            style: text.titleMedium?.copyWith(color: AppColors.maroon),
          ),
          const SizedBox(height: AppSpace.s),
          Wrap(
            spacing: AppSpace.l,
            runSpacing: AppSpace.xs,
            children: [
              info(Icons.celebration_outlined, eventTypeLabel(event.eventType)),
              info(Icons.location_on_outlined, event.region),
              info(Icons.groups_outlined, plural(event.guestCountEstimate, 'guest')),
              info(Icons.workspace_premium_outlined, '${budgetTierLabel(event.budgetTier)} budget'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate();

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: const TabBar(
        tabs: [Tab(text: 'Roadmap'), Tab(text: 'Budget'), Tab(text: 'Vendors')],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
