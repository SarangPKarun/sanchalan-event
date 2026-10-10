import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/paths.dart';
import '../events_view.dart';
import '../home_view.dart' show HomeStatus;
import '../organizer_providers.dart';

/// Events tab.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizerDataProvider);
    final data = async.value;
    return EventsView(
      status: data is OrganizerReady
          ? HomeStatus.ready
          : async.hasError
              ? HomeStatus.error
              : HomeStatus.loading,
      events: data is OrganizerReady ? data.eventGroups : const [],
      onRetry: () => ref.read(organizerDataProvider.notifier).refetch(),
      onRefresh: () => ref.read(organizerDataProvider.notifier).reloadEvents(),
      onOpenEvent: (id) => context.push(AppPaths.eventHome(id)),
      onNewEvent: () => context.push(AppPaths.eventSetup),
    );
  }
}
