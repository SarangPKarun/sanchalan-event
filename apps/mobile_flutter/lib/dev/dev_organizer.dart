import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/organizer/event_detail_view.dart';
import '../features/organizer/event_form_view.dart';
import '../features/organizer/events_view.dart';
import '../features/organizer/home_view.dart';
import '../features/organizer/organizer_profile_view.dart';
import '../features/organizer/organizer_shell.dart';
import '../features/organizer/vendor_detail_view.dart';
import '../features/organizer/vendors_view.dart';
import '../features/vendor/vendor_repository.dart' show VendorFilters;
import '../features/organizer/profile_setup_view.dart';
import '../features/organizer/sheets/budget_category_sheet.dart';
import '../features/organizer/sheets/regenerate_sheet.dart';
import '../features/organizer/sheets/task_sheet.dart';
import '../models/enums.dart';
import '../models/event.dart';
import '../models/roadmap.dart';
import '../models/vendor.dart';
import '../shared/widgets/confirm_dialog.dart';
import 'dev_bar.dart';
import 'dev_scenario.dart';
import 'mock_data.dart';

final _mock = MockData();

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$message (preview)')));
}

HomeStatus _status(DevScenario s) => switch (s) {
      DevScenario.loading => HomeStatus.loading,
      DevScenario.error => HomeStatus.error,
      _ => HomeStatus.ready,
    };

/// Debug-only organizer app preview: the real shell and tab views, fed with mock data.
class DevOrganizerShell extends StatelessWidget {
  const DevOrganizerShell(this.shell, {super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DevBar<DevScenario>(
          notifier: devScenario,
          options: DevScenario.values,
          labelOf: (s) => s.label,
        ),
        Expanded(
          child: OrganizerShell(
            body: shell,
            currentIndex: shell.currentIndex,
            onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ),
      ],
    );
  }
}

class DevHomeTab extends StatefulWidget {
  const DevHomeTab({super.key});

  @override
  State<DevHomeTab> createState() => _DevHomeTabState();
}

class _DevHomeTabState extends State<DevHomeTab> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: devScenario,
      builder: (context, scenario, _) {
        final all = _mock.events;
        final featured = scenario == DevScenario.noEvents
            ? null
            : all.firstWhere((e) => e.id == _selectedId, orElse: () => all.first);
        return HomeView(
          status: _status(scenario),
          organizerName: _mock.organizer.displayName,
          events: scenario == DevScenario.noEvents ? const [] : all,
          featured: featured,
          today: _mock.today,
          onRetry: () => devScenario.value = DevScenario.normal,
          onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
          onSelectEvent: (id) => setState(() => _selectedId = id),
          onOpenEvent: (id) => context.push('/dev/o/event/$id'),
          onNewEvent: () => context.push('/dev/o/new-event'),
          onFindVendors: () => StatefulNavigationShell.of(context).goBranch(2),
          onAddTask: () => _toast(context, 'Add task'),
          onAddCategory: () => _toast(context, 'Add budget item'),
          onOpenTask: (t) => _toast(context, 'Open "${t.name}"'),
        );
      },
    );
  }
}

class DevEventsTab extends StatelessWidget {
  const DevEventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: devScenario,
      builder: (context, scenario, _) => EventsView(
        status: _status(scenario),
        events: scenario == DevScenario.noEvents ? const [] : _mock.events,
        today: _mock.today,
        onRetry: () => devScenario.value = DevScenario.normal,
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
        onOpenEvent: (id) => context.push('/dev/o/event/$id'),
        onNewEvent: () => context.push('/dev/o/new-event'),
      ),
    );
  }
}

List<RouteBase> devOrganizerRoutes() => [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => DevOrganizerShell(shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dev/o/home', builder: (_, _) => const DevHomeTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/dev/o/events', builder: (_, _) => const DevEventsTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dev/o/vendors',
              builder: (_, state) => DevVendorsTab(initialCategory: state.uri.queryParameters['category']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/dev/o/profile', builder: (_, _) => const DevProfileTab()),
          ]),
        ],
      ),
      GoRoute(
        path: '/dev/o/event/:id',
        builder: (context, state) => DevEventDetail(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dev/o/vendor/:id',
        builder: (context, state) => DevVendorDetail(vendorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dev/o/new-event',
        builder: (context, state) => EventFormView(
          today: _mock.today,
          onBack: () => context.pop(),
          onSubmit: (values, _) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            // Preview rule: a name containing "fail" shows the error state.
            if (values.name.toLowerCase().contains('fail')) return 'Could not create the event. Please try again.';
            if (context.mounted) {
              _toast(context, 'Event "${values.name}" created');
              context.pop();
            }
            return null;
          },
        ),
      ),
      GoRoute(
        path: '/dev/o/edit-event/:id',
        builder: (context, state) {
          final event = _mock.events.firstWhere((e) => e.id == state.pathParameters['id']);
          return EventFormView(
            initial: event,
            today: _mock.today,
            onBack: () => context.pop(),
            onSubmit: (values, adjustment) async {
              await Future<void>.delayed(const Duration(milliseconds: 800));
              if (context.mounted) {
                _toast(context, 'Saved${adjustment == null ? '' : ' (${adjustment.name} categories)'}');
                context.pop();
              }
              return null;
            },
          );
        },
      ),
      GoRoute(
        path: '/dev/o/profile-setup',
        builder: (context, state) => ProfileSetupView(
          onSubmit: (body) async {
            await Future<void>.delayed(const Duration(milliseconds: 800));
            if (context.mounted) {
              _toast(context, 'Welcome, ${body.displayName}');
              context.go('/dev');
            }
            return null;
          },
        ),
      ),
    ];

class DevVendorsTab extends StatefulWidget {
  const DevVendorsTab({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<DevVendorsTab> createState() => _DevVendorsTabState();
}

class _DevVendorsTabState extends State<DevVendorsTab> {
  late VendorFilters _filters = VendorFilters(category: widget.initialCategory);

  @override
  void didUpdateWidget(DevVendorsTab old) {
    super.didUpdateWidget(old);
    if (old.initialCategory != widget.initialCategory) {
      _filters = VendorFilters(category: widget.initialCategory, priceTier: _filters.priceTier);
    }
  }

  List<Vendor> get _matching => [
        for (final v in _mock.vendors)
          if ((_filters.category == null || v.categoryKeys.contains(_filters.category)) &&
              (_filters.priceTier == null || v.priceTier == _filters.priceTier))
            v,
      ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: devScenario,
      builder: (context, scenario, _) => VendorsView(
        status: _status(scenario),
        vendors: scenario == DevScenario.noEvents ? const [] : _matching,
        filters: _filters,
        categoryKeys: suggestedBudgetKeys.where((k) => _mock.vendors.any((v) => v.categoryKeys.contains(k))).toList(),
        forEventName: _mock.wedding.name,
        onFiltersChanged: (f) => setState(() => _filters = f),
        onOpenVendor: (v) => context.push('/dev/o/vendor/${v.id}'),
        onRetry: () => devScenario.value = DevScenario.normal,
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
      ),
    );
  }
}

class DevVendorDetail extends StatelessWidget {
  const DevVendorDetail({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: devScenario,
      builder: (context, scenario, _) => VendorDetailView(
        status: _status(scenario),
        vendor: _mock.vendors.firstWhere((v) => v.id == vendorId),
        onCall: () => _toast(context, 'Call'),
        onWhatsApp: () => _toast(context, 'Open WhatsApp'),
        onOpenLink: (url) => _toast(context, 'Open $url'),
        onRetry: () => devScenario.value = DevScenario.normal,
      ),
    );
  }
}

class DevProfileTab extends StatelessWidget {
  const DevProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return OrganizerProfileView(
      organizer: _mock.organizer,
      onEdit: () => context.push('/dev/o/profile-setup'),
      onSignOut: () async {
        final yes = await showConfirmDialog(
          context,
          title: 'Sign out?',
          message: 'You will need your phone number and a new code to sign back in.',
          confirmLabel: 'Sign out',
          destructive: true,
        );
        if (yes && context.mounted) _toast(context, 'Signed out');
      },
    );
  }
}

/// Event detail with working mock interactions: edit tasks and budget, remove
/// and restore tasks, generate the roadmap.
class DevEventDetail extends StatefulWidget {
  const DevEventDetail({super.key, required this.eventId});

  final String eventId;

  @override
  State<DevEventDetail> createState() => _DevEventDetailState();
}

class _DevEventDetailState extends State<DevEventDetail> {
  late EventGroup _event = _mock.events.firstWhere((e) => e.id == widget.eventId);
  late List<TaskWithDependencies> _removed = widget.eventId == 'ev-wedding' ? _mock.removedTasks : [];
  bool _generating = false;
  int _nextId = 1000;

  EventGroup _with({List<TaskWithDependencies>? tasks, List<BudgetCategory>? categories}) {
    final json = _event.toJson()
      ..['tasks'] = [for (final t in tasks ?? _event.tasks) t.toJson()]
      ..['budgetCategories'] = [for (final c in categories ?? _event.budgetCategories) c.toJson()];
    return EventGroup.fromJson(json);
  }

  Future<void> _generate({int seconds = 5}) async {
    setState(() => _generating = true);
    await Future<void>.delayed(Duration(seconds: seconds));
    if (!mounted) return;
    setState(() {
      _generating = false;
      if (_event.tasks.isEmpty) {
        _event = _with(
          tasks: [
            for (final t in _mock.weddingTasks)
              TaskWithDependencies.fromJson({...t.toJson(), 'eventGroupId': _event.id}),
          ],
        );
      }
    });
    if (mounted) _toast(context, 'Roadmap ready');
  }

  Future<void> _openTask(TaskWithDependencies? task) async {
    final result = await showTaskSheet(
      context,
      task: task,
      categoryKeys: suggestedBudgetKeys,
      today: _mock.today,
    );
    if (result == null || !mounted) return;
    setState(() {
      switch (result) {
        case TaskDeleted():
          _removed = [..._removed, task!];
          _event = _with(tasks: [for (final t in _event.tasks) if (t.id != task.id) t]);
        case TaskSaved():
          final json = (task?.toJson() ?? {
                'id': 'new-${_nextId++}',
                'eventGroupId': _event.id,
                'taskCategoryId': 'cat',
                'source': 'user_added',
                'ownerType': 'organizer',
                'createdAt': _mock.today.toIso8601String(),
                'updatedAt': _mock.today.toIso8601String(),
                'status': 'not_started',
                'dependsOnTaskIds': <String>[],
              })
            ..['name'] = result.name
            ..['categoryKey'] = result.categoryKey
            ..['dueDate'] = result.dueDate?.toIso8601String().substring(0, 10)
            ..addAll(result.status == null ? {} : {'status': enumWireValue(result.status!)});
          final updated = TaskWithDependencies.fromJson(json);
          _event = _with(
            tasks: task == null
                ? [..._event.tasks, updated]
                : [for (final t in _event.tasks) t.id == task.id ? updated : t],
          );
      }
    });
  }

  Future<void> _openCategory(BudgetCategory? existing) async {
    final others = _event.budgetCategories.where((c) => c.id != existing?.id);
    final result = await showBudgetCategorySheet(
      context,
      existing: existing,
      usedKeys: _event.budgetCategories.map((c) => c.categoryKey),
      total: _event.totalBudget,
      otherAllocated: others.fold<double>(0, (s, c) => s + c.allocatedAmount),
    );
    if (result == null || !mounted) return;
    setState(() {
      switch (result) {
        case BudgetDeleted():
          _event = _with(categories: others.toList());
        case BudgetSaved():
          final json = {
            ...?existing?.toJson(),
            'id': existing?.id ?? 'bn-${_nextId++}',
            'eventGroupId': _event.id,
            'categoryKey': result.categoryKey,
            'allocatedAmount': result.amount,
            'budgetTierOverride': null,
          };
          final updated = BudgetCategory.fromJson(json);
          _event = _with(
            categories: existing == null
                ? [..._event.budgetCategories, updated]
                : [for (final c in _event.budgetCategories) c.id == existing.id ? updated : c],
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: devScenario,
      builder: (context, scenario, _) => EventDetailView(
        status: _status(scenario),
        event: _event,
        removedTasks: _removed,
        today: _mock.today,
        generating: _generating,
        onRetry: () => devScenario.value = DevScenario.normal,
        onEdit: () => context.push('/dev/o/edit-event/${_event.id}'),
        onEditTotal: () => context.push('/dev/o/edit-event/${_event.id}'),
        onDelete: () async {
          final yes = await showConfirmDialog(
            context,
            title: 'Delete this event?',
            message: 'This permanently deletes "${_event.name}", its roadmap and its budget. This cannot be undone.',
            confirmLabel: 'Delete event',
            destructive: true,
          );
          if (yes && context.mounted) {
            _toast(context, 'Event deleted');
            context.pop();
          }
        },
        onGenerate: () => _generate(),
        onRegenerate: () async {
          final mode = await showRegenerateSheet(context);
          if (mode != null) await _generate(seconds: 4);
        },
        onAddTask: () => _openTask(null),
        onOpenTask: _openTask,
        onRestoreTask: (t) => setState(() {
          _removed = [for (final r in _removed) if (r.id != t.id) r];
          _event = _with(tasks: [
            ..._event.tasks,
            TaskWithDependencies.fromJson({...t.toJson(), 'status': 'not_started'}),
          ]);
        }),
        onAddCategory: () => _openCategory(null),
        onEditCategory: _openCategory,
        onBrowseVendors: (key) =>
            context.go(key == null ? '/dev/o/vendors' : '/dev/o/vendors?category=$key'),
      ),
    );
  }
}
