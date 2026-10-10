import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/organizer/organizer_providers.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

void main() {
  Future<OrganizerData> load(ProviderContainer c) async {
    final sub = c.listen(organizerDataProvider, (_, _) {});
    addTearDown(sub.close);
    return c.read(organizerDataProvider.future);
  }

  test('profile not filled in -> needs profile (and no event fetch)', () async {
    final (c, adapter) = makeContainer(routes({
      'GET /organizers/me': (_) => fixtureBody('organizer_me_fresh'),
    }));
    expect(await load(c), isA<OrganizerNeedsProfile>());
    expect(adapter.count('/event-groups/me'), 0);
  });

  test('profile complete -> ready with events (zero events is valid)', () async {
    final (c, _) = makeContainer(routes({
      'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
      'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
    }));
    final data = await load(c) as OrganizerReady;
    expect(data.organizer.displayName, 'Priya Sharma');
    expect(data.eventGroups, isNotEmpty);

    final (c2, _) = makeContainer(routes({
      'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
      'GET /event-groups/me': (_) => jsonBody([]),
    }));
    expect((await load(c2) as OrganizerReady).eventGroups, isEmpty);
  });

  test('failure is an error state (no automatic retry); refetch recovers', () async {
    var fail = true;
    final (c, adapter) = makeContainer(routes({
      'GET /organizers/me': (_) =>
          fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('organizer_profile'),
      'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
    }));
    final sub = c.listen(organizerDataProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(c.read(organizerDataProvider.future), throwsA(anything));
    expect(c.read(organizerDataProvider).hasError, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(adapter.count('/organizers/me'), 1, reason: 'must not auto-retry');

    fail = false;
    await c.read(organizerDataProvider.notifier).refetch();
    expect(c.read(organizerDataProvider).value, isA<OrganizerReady>());
  });

  test('reloadEvents updates the list without a loading flip', () async {
    var events = fixture('event_groups_me');
    final (c, _) = makeContainer(routes({
      'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
      'GET /event-groups/me': (_) => jsonBody(events),
    }));
    await load(c);

    final states = <AsyncValue<OrganizerData>>[];
    c.listen(organizerDataProvider, (_, next) => states.add(next));
    events = <Object>[];
    await c.read(organizerDataProvider.notifier).reloadEvents();

    expect(states.any((s) => s.isLoading), isFalse);
    expect((c.read(organizerDataProvider).value as OrganizerReady).eventGroups, isEmpty);
  });

  test('reloadEvents keeps the current list when the fetch fails', () async {
    var fail = false;
    final (c, _) = makeContainer(routes({
      'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
      'GET /event-groups/me': (_) =>
          fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('event_groups_me'),
    }));
    final before = (await load(c) as OrganizerReady).eventGroups.length;

    fail = true;
    await c.read(organizerDataProvider.notifier).reloadEvents();
    final after = c.read(organizerDataProvider).value as OrganizerReady;
    expect(after.eventGroups.length, before);
  });

  test('eventDetailProvider and eventTasksProvider load one event', () async {
    final (c, _) = makeContainer(routes({
      'GET /event-groups/e1': (_) => fixtureBody('event_group_detail'),
      'GET /event-groups/e1/tasks': (_) => fixtureBody('event_group_tasks'),
    }));
    final detail = await c.read(eventDetailProvider('e1').future);
    expect(detail.tasks, isNotEmpty);
    final tasks = await c.read(eventTasksProvider('e1').future);
    expect(tasks, isNotEmpty);
  });

  test('removedTasksProvider keeps only not-applicable tasks', () async {
    final tasks = (fixture('event_group_tasks') as Map<String, dynamic>)['tasks'] as List;
    final removed = {...(tasks.first as Map<String, dynamic>), 'status': 'not_applicable'};
    final (c, adapter) = makeContainer(routes({
      'GET /event-groups/e1/tasks': (_) => jsonBody({
            'tasks': [...tasks, removed],
          }),
    }));
    final result = await c.read(removedTasksProvider('e1').future);
    expect(result, hasLength(1));
    expect(adapter.last('/event-groups/e1/tasks').queryParameters, {'includeNotApplicable': true});
  });
}
