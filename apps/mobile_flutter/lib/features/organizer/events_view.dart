import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/event.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton.dart';
import 'event_stats.dart';
import 'home_view.dart' show HomeStatus;
import 'widgets/event_card.dart';

/// Events tab: upcoming events first, then past ones. Plain widget.
class EventsView extends StatelessWidget {
  const EventsView({
    super.key,
    required this.status,
    this.events = const [],
    this.today,
    this.onRetry,
    this.onRefresh,
    this.onOpenEvent,
    this.onNewEvent,
  });

  final HomeStatus status;
  final List<EventGroup> events;
  final DateTime? today;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final ValueChanged<String>? onOpenEvent;
  final VoidCallback? onNewEvent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My events'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: status == HomeStatus.ready && events.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: onNewEvent,
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            )
          : null,
      body: switch (status) {
        HomeStatus.loading => ListView(
            padding: const EdgeInsets.all(AppSpace.gutter),
            children: const [
              SkeletonCard(height: 104),
              SizedBox(height: AppSpace.m),
              SkeletonCard(height: 104),
              SizedBox(height: AppSpace.m),
              SkeletonCard(height: 104),
            ],
          ),
        HomeStatus.error => ErrorRetry(onRetry: onRetry ?? () {}),
        HomeStatus.ready when events.isEmpty => EmptyState(
            icon: Icons.celebration_outlined,
            title: 'No events yet',
            message: 'Create your first event to get a budget and a roadmap.',
            actionLabel: 'Create event',
            onAction: onNewEvent,
          ),
        HomeStatus.ready => _list(context, text),
      },
    );
  }

  Widget _list(BuildContext context, TextTheme text) {
    final sorted = sortEvents(events, today: today);
    final upcoming = [for (final e in sorted) if (daysUntil(e.primaryDate, today: today) >= 0) e];
    final past = [for (final e in sorted) if (daysUntil(e.primaryDate, today: today) < 0) e];

    Widget cards(List<EventGroup> list) => Column(
          children: [
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: EventCard(
                  event: e,
                  today: today,
                  onTap: onOpenEvent == null ? null : () => onOpenEvent!(e.id),
                ),
              ),
          ],
        );

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, 96),
      children: [
        Text(
          plural(events.length, 'event'),
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpace.m),
        if (upcoming.isNotEmpty) ...[const SectionHeader('Upcoming'), cards(upcoming)],
        if (past.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          const SectionHeader('Past'),
          cards(past),
        ],
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
