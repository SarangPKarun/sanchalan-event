import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/paths.dart';
import '../../../models/event.dart';
import '../event_stats.dart';
import '../home_view.dart';
import '../organizer_providers.dart';
import 'event_detail_page.dart';

/// The event the home screen features: the chosen one if it still exists, else the soonest.
EventGroup? pickFeatured(List<EventGroup> events, String? selectedId) {
  if (events.isEmpty) return null;
  for (final e in events) {
    if (e.id == selectedId) return e;
  }
  return featuredEvent(events);
}

/// Home tab: the featured event with its progress, next tasks and budget.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizerDataProvider);
    final data = async.value;
    if (data is! OrganizerReady) {
      return HomeView(
        status: async.hasError ? HomeStatus.error : HomeStatus.loading,
        onRetry: () => ref.read(organizerDataProvider.notifier).refetch(),
      );
    }

    final events = data.eventGroups;
    final summary = pickFeatured(events, ref.watch(selectedEventIdProvider));
    final detail = summary == null ? null : ref.watch(eventDetailProvider(summary.id));
    final status = detail == null
        ? HomeStatus.ready
        : detail.hasError && !detail.hasValue
            ? HomeStatus.error
            : detail.hasValue
                ? HomeStatus.ready
                : HomeStatus.loading;

    Future<void> refresh() async {
      await ref.read(organizerDataProvider.notifier).reloadEvents();
      if (summary != null) {
        ref.invalidate(eventDetailProvider(summary.id));
        try {
          await ref.read(eventDetailProvider(summary.id).future);
        } catch (_) {
          // The error state of the provider is shown by the view.
        }
      }
    }

    void openEvent(String id, {EventHomeArgs? args}) => context.push(AppPaths.eventHome(id), extra: args);

    return HomeView(
      status: status,
      organizerName: data.organizer.displayName,
      events: events,
      featured: detail?.value,
      onRetry: summary == null ? null : () => ref.invalidate(eventDetailProvider(summary.id)),
      onRefresh: refresh,
      onSelectEvent: (id) => ref.read(selectedEventIdProvider.notifier).select(id),
      onOpenEvent: openEvent,
      onNewEvent: () => context.push(AppPaths.eventSetup),
      onFindVendors: () => context.go(AppPaths.vendors),
      onAddTask: summary == null ? null : () => openEvent(summary.id, args: const EventHomeArgs(addTask: true)),
      onAddCategory: summary == null
          ? null
          : () => openEvent(summary.id, args: const EventHomeArgs(tab: 1, addCategory: true)),
      onOpenTask: summary == null
          ? null
          : (task) => openEvent(summary.id, args: EventHomeArgs(openTaskId: task.id)),
    );
  }
}
