import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_cache.dart';
import 'event_draft.dart';

import '../../models/event.dart';
import '../../models/event_profile.dart';
import '../../models/organizer.dart';
import '../../models/roadmap.dart';
import 'organizer_repository.dart';

/// Failures surface as AsyncError with a Retry button; no automatic retries
/// (Riverpod 3 retries failed providers by default).
Duration? _noRetry(int retryCount, Object error) => null;

sealed class OrganizerData {
  const OrganizerData();
}

/// Logged in but the profile (name and type) isn't filled in yet.
class OrganizerNeedsProfile extends OrganizerData {
  const OrganizerNeedsProfile();
}

class OrganizerReady extends OrganizerData {
  const OrganizerReady(this.organizer, this.eventGroups);
  final Organizer organizer;

  /// Zero events is a valid state (the Events screen shows an empty state).
  final List<EventGroup> eventGroups;
}

/// Organizer profile plus event list. Port of apps/mobile/lib/organizer-context.tsx.
/// AsyncLoading = loading, AsyncError = retryable error.
class OrganizerDataNotifier extends AsyncNotifier<OrganizerData> {
  @override
  Future<OrganizerData> build() => _load();

  Future<OrganizerData> _load() async {
    final repo = ref.read(organizerRepositoryProvider);
    final organizer = await repo.getMe();
    final name = organizer.displayName;
    if (name == null || name.isEmpty || organizer.organizerType == null) {
      return const OrganizerNeedsProfile();
    }
    return OrganizerReady(organizer, await repo.listEventGroups());
  }

  /// Full reload; flips to loading.
  Future<void> refetch() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_load);
    if (ref.mounted) state = result;
  }

  /// Replaces the organizer (after the profile was edited) without a loading flip.
  void setOrganizer(Organizer organizer) {
    final current = state.value;
    if (current is OrganizerReady) state = AsyncData(OrganizerReady(organizer, current.eventGroups));
  }

  /// Reloads only the event list, silently (no loading flip). Use after
  /// creating, editing or deleting an event. Keeps the current list on failure.
  Future<void> reloadEvents() async {
    final current = state.value;
    if (current is! OrganizerReady) return;
    try {
      final events = await ref.read(organizerRepositoryProvider).listEventGroups();
      if (ref.mounted) state = AsyncData(OrganizerReady(current.organizer, events));
    } catch (_) {
      // Keep the list we already have; the next reload will retry.
    }
  }
}

final organizerDataProvider = AsyncNotifierProvider<OrganizerDataNotifier, OrganizerData>(
  OrganizerDataNotifier.new,
  retry: _noRetry,
);

/// The creation questions for every event type. Fetched once and kept for the session.
///
/// Stale-while-revalidate: a copy saved on the device is returned at once (so the wizard
/// opens with no wait, even offline) and refreshed in the background for next time.
final eventProfilesProvider = FutureProvider<List<EventTypeProfile>>(
  (ref) async {
    const key = 'event_type_profiles_v1';
    final cache = ref.watch(localCacheProvider);
    final repo = ref.watch(organizerRepositoryProvider);

    Future<List<EventTypeProfile>> fetch() async {
      final profiles = await repo.listEventTypeProfiles();
      await cache.write(key, jsonEncode(profiles.map((p) => p.toJson()).toList()));
      return profiles;
    }

    final saved = await cache.read(key);
    if (saved != null) {
      try {
        final cached = (jsonDecode(saved) as List)
            .map((p) => EventTypeProfile.fromJson(p as Map<String, dynamic>))
            .toList();
        unawaited(fetch().then<void>((_) {}, onError: (_) {}));
        return cached;
      } catch (_) {
        await cache.remove(key);
      }
    }
    return fetch();
  },
  retry: _noRetry,
);

/// The saved half-finished event, if any (and not stale).
final eventDraftProvider = FutureProvider.autoDispose<WizardDraft?>(
  (ref) async => WizardDraft.decode(await ref.watch(localCacheProvider).read(WizardDraft.storageKey)),
  retry: _noRetry,
);

/// One event with sub-events, budget categories and tasks.
final eventDetailProvider = FutureProvider.autoDispose.family<EventGroup, String>(
  (ref, id) => ref.watch(organizerRepositoryProvider).getEventGroup(id),
  retry: _noRetry,
);

/// Active tasks of an event. Invalidate after task or roadmap changes.
final eventTasksProvider = FutureProvider.autoDispose.family<List<TaskWithDependencies>, String>(
  (ref, id) => ref.watch(organizerRepositoryProvider).listTasks(id),
  retry: _noRetry,
);

/// Tasks removed from an event (`not_applicable`), for the restore list.
final removedTasksProvider = FutureProvider.autoDispose.family<List<TaskWithDependencies>, String>(
  (ref, id) async {
    final all = await ref.watch(organizerRepositoryProvider).listTasks(id, includeNotApplicable: true);
    return all.where((t) => t.status.name == 'notApplicable').toList();
  },
  retry: _noRetry,
);

final taskCategoriesProvider = FutureProvider.autoDispose<List<TaskCategory>>(
  (ref) => ref.watch(organizerRepositoryProvider).listTaskCategories(),
  retry: _noRetry,
);

/// The event the home screen features, chosen with the chips. Null means "the soonest one".
class SelectedEventNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedEventIdProvider = NotifierProvider<SelectedEventNotifier, String?>(SelectedEventNotifier.new);
