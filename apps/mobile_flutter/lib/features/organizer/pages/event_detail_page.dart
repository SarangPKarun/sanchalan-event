import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/paths.dart';
import '../../../core/ui_feedback.dart';
import '../../../models/converters.dart';
import '../../../models/enums.dart';
import '../../../models/event.dart';
import '../../../models/roadmap.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../event_detail_view.dart';
import '../home_view.dart' show HomeStatus;
import '../organizer_providers.dart';
import '../organizer_repository.dart';
import '../sheets/budget_category_sheet.dart';
import '../sheets/regenerate_sheet.dart';
import '../sheets/task_sheet.dart';

/// Optional instructions for the event screen when it opens, e.g. from a home
/// shortcut: which tab to show and which sheet to open straight away.
class EventHomeArgs {
  const EventHomeArgs({this.tab = 0, this.addTask = false, this.addCategory = false, this.openTaskId});

  final int tab;
  final bool addTask;
  final bool addCategory;
  final String? openTaskId;
}

/// One event with its roadmap, budget and vendor shortcuts, connected to the backend.
class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.id, this.args});

  final String id;
  final EventHomeArgs? args;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  bool _generating = false;
  String? _generateError;
  bool _handledArgs = false;

  OrganizerRepository get _repo => ref.read(organizerRepositoryProvider);
  String get _id => widget.id;

  /// Reloads everything this screen shows.
  void _refresh() {
    ref.invalidate(eventDetailProvider(_id));
    ref.invalidate(eventTasksProvider(_id));
    ref.invalidate(removedTasksProvider(_id));
  }

  /// Runs [action]; on failure shows a message instead of crashing.
  Future<T?> _run<T>(Future<T> Function() action, String fallback) async {
    try {
      return await action();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, fallback));
      return null;
    }
  }

  Future<List<String>> _taskCategoryKeys() async {
    final categories = await ref.read(taskCategoriesProvider.future);
    return [for (final c in categories) c.categoryKey];
  }

  // --- roadmap ---

  Future<void> _generate({RoadmapRegenMode? mode}) async {
    setState(() {
      _generating = true;
      _generateError = null;
    });
    try {
      await _repo.generateRoadmap(_id, mode: mode);
      _refresh();
      if (mounted) showToast(context, mode == null ? 'Your roadmap is ready' : 'Roadmap updated');
    } catch (e) {
      if (mounted) setState(() => _generateError = friendlyError(e, 'Could not generate your roadmap. Please try again.'));
      if (mode != null && mounted) showToast(context, friendlyError(e, 'Could not re-run the roadmap. Please try again.'));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _regenerate() async {
    final mode = await showRegenerateSheet(context);
    if (mode != null) await _generate(mode: mode);
  }

  Future<void> _addTask() async {
    final keys = await _run(_taskCategoryKeys, 'Could not load task categories.');
    if (keys == null || !mounted) return;
    final result = await showTaskSheet(context, categoryKeys: keys);
    if (result is! TaskSaved || !mounted) return;
    final ok = await _run(
      () => _repo.createTask(
        _id,
        CreateTaskBody(name: result.name, category: result.categoryKey, dueDate: toDateOnly(result.dueDate!)),
      ),
      'Could not add the task.',
    );
    if (ok != null) _refresh();
  }

  Future<void> _openTask(TaskWithDependencies task) async {
    final keys = await _run(_taskCategoryKeys, 'Could not load task categories.');
    if (keys == null || !mounted) return;
    final result = await showTaskSheet(context, task: task, categoryKeys: keys);
    if (result == null || !mounted) return;

    switch (result) {
      case TaskDeleted():
        final ok = await _run(() => _repo.deleteTask(task.id), 'Could not remove the task.');
        if (ok != null) _refresh();
      case TaskSaved():
        final open = task.status == TaskStatus.done || task.status == TaskStatus.inProgress;
        final before = open ? task.status : TaskStatus.notStarted;
        final body = UpdateTaskBody(
          status: result.status != null && result.status != before ? result.status : null,
          name: result.name != task.name ? result.name : null,
          dueDate: result.dueDate != null && toDateOnly(result.dueDate!) != (task.dueDate == null ? null : toDateOnly(task.dueDate!))
              ? toDateOnly(result.dueDate!)
              : null,
          category: result.categoryKey != task.categoryKey ? result.categoryKey : null,
        );
        if (body.toJson().isEmpty) return;
        final ok = await _run(() => _repo.updateTask(task.id, body), 'Could not save the task.');
        if (ok != null) _refresh();
    }
  }

  Future<void> _restoreTask(TaskWithDependencies task) async {
    final ok = await _run(
      () => _repo.updateTask(task.id, const UpdateTaskBody(status: TaskStatus.notStarted)),
      'Could not restore the task.',
    );
    if (ok != null) _refresh();
  }

  // --- budget ---

  Future<void> _openCategory(EventGroup event, [BudgetCategory? existing]) async {
    final others = event.budgetCategories.where((c) => c.id != existing?.id);
    final result = await showBudgetCategorySheet(
      context,
      existing: existing,
      usedKeys: event.budgetCategories.map((c) => c.categoryKey),
      total: event.totalBudget,
      otherAllocated: others.fold<double>(0, (s, c) => s + c.allocatedAmount),
    );
    if (result == null || !mounted) return;

    switch (result) {
      case BudgetDeleted():
        final yes = await showConfirmDialog(
          context,
          title: 'Delete this category?',
          message: 'This removes the category and its allocation. Your total budget stays the same.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!yes || !mounted) return;
        final r = await _run(() => _repo.deleteBudgetCategory(_id, existing!.id), 'Could not delete the category.');
        if (r != null) {
          _refresh();
          if (r.warning != null && mounted) showToast(context, r.warning!);
        }
      case BudgetSaved():
        final String? warning;
        if (existing == null) {
          final r = await _run(
            () => _repo.createBudgetCategory(
              _id,
              CreateBudgetCategoryBody(categoryKey: result.categoryKey, allocatedAmount: result.amount),
            ),
            'Could not add the category.',
          );
          if (r == null) return;
          warning = r.warning;
        } else {
          final body = UpdateBudgetCategoryBody(
            allocatedAmount: result.amount != existing.allocatedAmount ? result.amount : null,
            categoryKey: result.categoryKey != existing.categoryKey ? result.categoryKey : null,
          );
          if (body.toJson().isEmpty) return;
          final r = await _run(() => _repo.updateBudgetCategory(_id, existing.id, body), 'Could not save the category.');
          if (r == null) return;
          warning = r.warning;
        }
        _refresh();
        if (warning != null && mounted) showToast(context, warning);
    }
  }

  // --- the event itself ---

  Future<void> _delete(EventGroup event) async {
    final yes = await showConfirmDialog(
      context,
      title: 'Delete this event?',
      message: 'This permanently deletes "${event.name}", its roadmap and its budget. This cannot be undone.',
      confirmLabel: 'Delete event',
      destructive: true,
    );
    if (!yes || !mounted) return;
    final deleted = await _run(() => _repo.deleteEventGroup(_id), 'Could not delete the event.');
    if (deleted == null || !mounted) return;
    await ref.read(organizerDataProvider.notifier).reloadEvents();
    if (!mounted) return;
    showToast(context, 'Event deleted');
    context.go(AppPaths.events);
  }

  /// Runs what the opening instructions asked for, once the event is loaded.
  void _handleArgs(EventGroup event) {
    if (_handledArgs) return;
    _handledArgs = true;
    final a = widget.args;
    if (a == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (a.addTask) _addTask();
      if (a.addCategory) _openCategory(event);
      if (a.openTaskId != null) {
        final task = event.tasks.where((t) => t.id == a.openTaskId).firstOrNull;
        if (task != null) _openTask(task);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(eventDetailProvider(_id));
    final removed = ref.watch(removedTasksProvider(_id)).value ?? const <TaskWithDependencies>[];
    final event = detail.value;
    if (event != null) _handleArgs(event);

    return EventDetailView(
      status: event != null
          ? HomeStatus.ready
          : detail.hasError
              ? HomeStatus.error
              : HomeStatus.loading,
      event: event,
      removedTasks: removed,
      initialTab: widget.args?.tab ?? 0,
      generating: _generating,
      generateError: _generateError,
      onRetry: () => ref.invalidate(eventDetailProvider(_id)),
      onEdit: () => context.push(AppPaths.eventEdit(_id)),
      onEditTotal: () => context.push(AppPaths.eventEdit(_id)),
      onDelete: event == null ? null : () => _delete(event),
      onGenerate: () => _generate(),
      onRegenerate: _regenerate,
      onAddTask: _addTask,
      onOpenTask: _openTask,
      onRestoreTask: _restoreTask,
      onAddCategory: event == null ? null : () => _openCategory(event),
      onEditCategory: event == null ? null : (c) => _openCategory(event, c),
      onBrowseVendors: (key) => context.go(key == null ? AppPaths.vendors : '${AppPaths.vendors}?category=$key'),
    );
  }
}
