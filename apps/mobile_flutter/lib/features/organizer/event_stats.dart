import '../../core/format.dart';
import '../../models/enums.dart';
import '../../models/event.dart';
import '../../models/roadmap.dart';

/// Pure calculations the organizer screens show. No Flutter, no network.

/// A task's status as the user should see it: not started or in progress, but
/// past its due date, counts as overdue.
TaskStatus effectiveStatus(TaskWithDependencies t, {DateTime? today}) {
  final open = t.status == TaskStatus.notStarted || t.status == TaskStatus.inProgress;
  final due = t.dueDate;
  if (open && due != null && daysUntil(due, today: today) < 0) return TaskStatus.overdue;
  return t.status;
}

/// Tasks that are part of the plan (removed ones are not).
List<TaskWithDependencies> activeTasks(Iterable<TaskWithDependencies> tasks) =>
    [for (final t in tasks) if (t.status != TaskStatus.notApplicable) t];

class TaskProgress {
  const TaskProgress({required this.done, required this.total, required this.overdue});

  final int done;
  final int total;
  final int overdue;

  double get fraction => total == 0 ? 0 : done / total;
  int get percent => (fraction * 100).round();
  bool get isEmpty => total == 0;
}

TaskProgress taskProgress(Iterable<TaskWithDependencies> tasks, {DateTime? today}) {
  final active = activeTasks(tasks);
  return TaskProgress(
    done: active.where((t) => t.status == TaskStatus.done).length,
    total: active.length,
    overdue: active.where((t) => effectiveStatus(t, today: today) == TaskStatus.overdue).length,
  );
}

int _byDueDate(TaskWithDependencies a, TaskWithDependencies b) {
  final ad = a.dueDate, bd = b.dueDate;
  if (ad == null && bd == null) return a.name.compareTo(b.name);
  if (ad == null) return 1; // undated tasks go last
  if (bd == null) return -1;
  final c = ad.compareTo(bd);
  return c != 0 ? c : a.name.compareTo(b.name);
}

/// The most urgent open tasks: overdue first, then by due date, undated last.
List<TaskWithDependencies> nextUp(
  Iterable<TaskWithDependencies> tasks, {
  int limit = 3,
  DateTime? today,
}) {
  final open = [
    for (final t in activeTasks(tasks))
      if (t.status != TaskStatus.done) t,
  ];
  open.sort((a, b) {
    final ao = effectiveStatus(a, today: today) == TaskStatus.overdue;
    final bo = effectiveStatus(b, today: today) == TaskStatus.overdue;
    if (ao != bo) return ao ? -1 : 1;
    return _byDueDate(a, b);
  });
  return open.take(limit).toList();
}

enum TaskFilter { all, todo, overdue, done }

List<TaskWithDependencies> filterTasks(
  Iterable<TaskWithDependencies> tasks,
  TaskFilter filter, {
  DateTime? today,
}) {
  final active = activeTasks(tasks);
  return switch (filter) {
    TaskFilter.all => active,
    TaskFilter.done => [for (final t in active) if (t.status == TaskStatus.done) t],
    TaskFilter.todo => [for (final t in active) if (t.status != TaskStatus.done) t],
    TaskFilter.overdue => [
        for (final t in active)
          if (effectiveStatus(t, today: today) == TaskStatus.overdue) t,
      ],
  };
}

class TaskGroup {
  const TaskGroup(this.categoryKey, this.tasks);
  final String categoryKey;
  final List<TaskWithDependencies> tasks;
}

/// Tasks grouped by category (categories in alphabetical order, as the server
/// sends them), each group sorted by due date.
List<TaskGroup> groupTasksByCategory(Iterable<TaskWithDependencies> tasks) {
  final byKey = <String, List<TaskWithDependencies>>{};
  for (final t in tasks) {
    byKey.putIfAbsent(t.categoryKey, () => []).add(t);
  }
  final keys = byKey.keys.toList()..sort();
  return [
    for (final k in keys) TaskGroup(k, byKey[k]!..sort(_byDueDate)),
  ];
}

class BudgetShare {
  const BudgetShare(this.categoryKey, this.amount, this.fractionOfTotal);
  final String categoryKey;
  final double amount;
  final double fractionOfTotal;
}

class BudgetSummary {
  const BudgetSummary({required this.total, required this.allocated, required this.shares});

  final double total;
  final double allocated;

  /// Biggest first.
  final List<BudgetShare> shares;

  double get remaining => total - allocated;
  bool get isOver => allocated > total;

  /// How much of the total is allocated, capped at 1 for bars.
  double get allocatedFraction => total <= 0 ? 0 : (allocated / total).clamp(0.0, 1.0);
}

BudgetSummary budgetSummary(EventGroup event) {
  final allocated = event.budgetCategories.fold<double>(0, (s, c) => s + c.allocatedAmount);
  final shares = [
    for (final c in event.budgetCategories)
      BudgetShare(
        c.categoryKey,
        c.allocatedAmount,
        event.totalBudget <= 0 ? 0 : c.allocatedAmount / event.totalBudget,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return BudgetSummary(total: event.totalBudget, allocated: allocated, shares: shares);
}

/// Upcoming events first (soonest first), then past events (most recent first).
List<EventGroup> sortEvents(Iterable<EventGroup> events, {DateTime? today}) {
  final upcoming = [for (final e in events) if (daysUntil(e.primaryDate, today: today) >= 0) e]
    ..sort((a, b) => a.primaryDate.compareTo(b.primaryDate));
  final past = [for (final e in events) if (daysUntil(e.primaryDate, today: today) < 0) e]
    ..sort((a, b) => b.primaryDate.compareTo(a.primaryDate));
  return [...upcoming, ...past];
}

/// The event the home screen features: the soonest upcoming one, else the most recent past one.
EventGroup? featuredEvent(Iterable<EventGroup> events, {DateTime? today}) {
  final sorted = sortEvents(events, today: today);
  return sorted.isEmpty ? null : sorted.first;
}
