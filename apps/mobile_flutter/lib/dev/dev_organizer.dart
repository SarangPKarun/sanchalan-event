import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/organizer/events_view.dart';
import '../features/organizer/home_view.dart';
import '../features/organizer/organizer_shell.dart';
import '../shared/widgets/placeholder_screen.dart';
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
        const _DevBar(),
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

/// Thin strip that says this is a preview and switches the data scenario.
class _DevBar extends StatelessWidget {
  const _DevBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to previews',
                icon: const Icon(Icons.close, color: AppColors.surface, size: 20),
                onPressed: () => context.go('/dev'),
              ),
              Text('PREVIEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.goldContainer)),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: devScenario,
                builder: (context, current, _) => PopupMenuButton<DevScenario>(
                  tooltip: 'Data scenario',
                  initialValue: current,
                  onSelected: (s) => devScenario.value = s,
                  itemBuilder: (_) => [
                    for (final s in DevScenario.values) PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
                    child: Row(
                      children: [
                        Text(
                          'Scenario: ${current.label}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.surface),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.surface),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            GoRoute(path: '/dev/o/vendors', builder: (_, _) => const PlaceholderScreen('Vendors')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/dev/o/profile', builder: (_, _) => const PlaceholderScreen('Profile')),
          ]),
        ],
      ),
      GoRoute(
        path: '/dev/o/event/:id',
        builder: (context, state) => PlaceholderScreen('Event', detail: state.pathParameters['id']),
      ),
      GoRoute(path: '/dev/o/new-event', builder: (_, _) => const PlaceholderScreen('New event')),
    ];
