import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/event_stats.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/roadmap.dart';

void main() {
  final today = DateTime(2026, 10, 10);
  final mock = MockData(today: today);
  final tasks = mock.weddingTasks;

  group('tasks', () {
    test('effectiveStatus marks open tasks past their due date as overdue', () {
      TaskStatus of(String id) =>
          effectiveStatus(tasks.firstWhere((t) => t.id == id), today: today);
      expect(of('t3'), TaskStatus.overdue); // not started, due 5 days ago
      expect(of('t9'), TaskStatus.overdue); // in progress, due 2 days ago
      expect(of('t1'), TaskStatus.done); // done stays done even though past due
      expect(of('t5'), TaskStatus.inProgress); // due in the future
      expect(of('t2'), TaskStatus.notStarted);
    });

    test('progress counts active tasks only', () {
      final p = taskProgress([...tasks, ...mock.removedTasks], today: today);
      expect(p.total, 17);
      expect(p.done, 4);
      expect(p.overdue, 2);
      expect(p.percent, 24);
      expect(p.fraction, closeTo(4 / 17, 1e-9));
      expect(taskProgress([], today: today).isEmpty, isTrue);
      expect(taskProgress([], today: today).fraction, 0);
    });

    test('nextUp puts overdue first, then by due date, and skips done and removed', () {
      final next = nextUp([...tasks, ...mock.removedTasks], limit: 5, today: today);
      expect(next.map((t) => t.id), ['t3', 't9', 't12', 't10', 't5']);
      expect(nextUp(tasks, today: today), hasLength(3));
    });

    test('nextUp puts undated tasks last', () {
      final undated = TaskWithDependencies.fromJson(
        mock.removedTasks.first.toJson()..['status'] = 'not_started',
      );
      final all = nextUp([...tasks, undated], limit: 100, today: today);
      expect(all.last.id, undated.id);
      expect(all.last.dueDate, isNull);
    });

    test('filters', () {
      expect(filterTasks(tasks, TaskFilter.all, today: today), hasLength(17));
      expect(filterTasks(tasks, TaskFilter.done, today: today), hasLength(4));
      expect(filterTasks(tasks, TaskFilter.todo, today: today), hasLength(13));
      expect(filterTasks(tasks, TaskFilter.overdue, today: today).map((t) => t.id),
          unorderedEquals(['t3', 't9']));
      expect(filterTasks(mock.removedTasks, TaskFilter.all, today: today), isEmpty);
    });

    test('grouping: categories alphabetical, tasks by due date', () {
      final groups = groupTasksByCategory(tasks);
      expect(groups.map((g) => g.categoryKey), [
        'attire', 'catering', 'decor', 'guest_logistics', 'invitations',
        'legal_documentation', 'music_entertainment', 'photography',
        'priest_officiant', 'transport', 'venue',
      ]);
      final catering = groups.firstWhere((g) => g.categoryKey == 'catering');
      expect(catering.tasks.map((t) => t.id), ['t3', 't4']);
      expect(groups.expand((g) => g.tasks), hasLength(tasks.length));
    });
  });

  group('budget', () {
    test('wedding: allocated, remaining and shares', () {
      final b = budgetSummary(mock.wedding);
      expect(b.total, 1500000);
      expect(b.allocated, 1440000);
      expect(b.remaining, 60000);
      expect(b.isOver, isFalse);
      expect(b.allocatedFraction, closeTo(0.96, 1e-9));
      expect(b.shares.first.categoryKey, 'venue'); // biggest first
      expect(b.shares.first.fractionOfTotal, closeTo(0.3, 1e-9));
      expect(b.shares.map((s) => s.amount).toList(), [...b.shares.map((s) => s.amount)]..sort((a, c) => c.compareTo(a)));
    });

    test('birthday: over-allocated', () {
      final b = budgetSummary(mock.birthday);
      expect(b.isOver, isTrue);
      expect(b.remaining, -10000);
      expect(b.allocatedFraction, 1); // capped for the bar
    });

    test('no categories and a zero budget do not divide by zero', () {
      final b = budgetSummary(mock.newEvent);
      expect(b.allocated, 450000);
      final empty = BudgetSummary(total: 0, allocated: 0, shares: const []);
      expect(empty.allocatedFraction, 0);
      expect(empty.isOver, isFalse);
    });
  });

  group('events', () {
    test('upcoming soonest first, then past most recent first', () {
      final sorted = sortEvents(mock.events, today: today);
      expect(sorted.map((e) => e.id), ['ev-wedding', 'ev-new', 'ev-birthday']);
    });

    test('featured event is the soonest upcoming, else the latest past', () {
      expect(featuredEvent(mock.events, today: today)!.id, 'ev-wedding');
      expect(featuredEvent([mock.birthday], today: today)!.id, 'ev-birthday');
      expect(featuredEvent([], today: today), isNull);
    });
  });

  group('mock data', () {
    test('is relative to the given day', () {
      expect(mock.wedding.primaryDate, DateTime(2026, 11, 27));
      expect(mock.birthday.primaryDate, DateTime(2026, 9, 10));
    });

    test('vendors parse with categories and past work', () {
      expect(mock.vendors, hasLength(5));
      expect(mock.vendors.first.categoryKeys, ['photography']);
      expect(mock.vendors.first.portfolioItems, isNotEmpty);
      expect(mock.vendors.map((v) => v.id).toSet(), hasLength(5));
    });
  });
}
