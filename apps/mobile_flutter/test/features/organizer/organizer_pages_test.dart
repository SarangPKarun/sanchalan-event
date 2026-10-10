import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/app.dart';
import 'package:sanchalan/core/auth_storage.dart';
import 'package:sanchalan/core/link_launcher.dart';
import 'package:sanchalan/core/router/paths.dart';
import 'package:sanchalan/core/router/router.dart';
import 'package:sanchalan/features/organizer/event_stats.dart';
import 'package:sanchalan/features/organizer/pages/event_detail_page.dart' show EventHomeArgs;
import 'package:sanchalan/features/organizer/sheets/budget_category_sheet.dart';
import 'package:sanchalan/features/organizer/sheets/task_sheet.dart';
import 'package:sanchalan/features/organizer/widgets/hero_card.dart';
import 'package:sanchalan/models/roadmap.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

class FakeLauncher implements LinkLauncher {
  final calls = <String>[];
  bool result = true;

  @override
  Future<bool> call(String phoneNumber) async {
    calls.add('call $phoneNumber');
    return result;
  }
  @override
  Future<bool> whatsApp(String phoneNumber) async {
    calls.add('whatsapp $phoneNumber');
    return result;
  }
  @override
  Future<bool> openUrl(String url) async {
    calls.add('url $url');
    return result;
  }
  @override
  Future<bool> email(String address) async {
    calls.add('email $address');
    return result;
  }
}

final detailJson = fixture('event_group_detail') as Map<String, dynamic>;
final eventId = detailJson['id'] as String;
final eventName = detailJson['name'] as String;
final vendorId = ((fixture('vendors_list') as Map)['vendors'] as List).first['id'] as String;

/// A task the screen shows near the top (first category alphabetically, earliest date).
TaskWithDependencies firstShownTask() {
  final tasks = [for (final t in (fixture('event_group_tasks') as Map)['tasks'] as List) TaskWithDependencies.fromJson(t as Map<String, dynamic>)];
  return groupTasksByCategory(activeTasks(tasks)).first.tasks.first;
}

Map<String, RouteHandler> baseRoutes() => {
      'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
      'POST /auth/logout': (_) => jsonBody({}),
      'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
      'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
      'GET /event-groups/$eventId': (_) => fixtureBody('event_group_detail'),
      'GET /event-groups/$eventId/tasks': (_) => fixtureBody('event_group_tasks'),
      'GET /task-categories': (_) => fixtureBody('task_categories'),
      'GET /vendors': (_) => fixtureBody('vendors_list'),
      'GET /vendor-categories': (_) => fixtureBody('vendor_categories'),
      'GET /vendors/$vendorId': (_) => fixtureBody('vendor_detail'),
    };

class Harness {
  Harness(this.container, this.adapter, this.launcher);
  final ProviderContainer container;
  final FakeAdapter adapter;
  final FakeLauncher launcher;

  String get location => container.read(routerProvider).state.uri.path;
  void go(String path, {Object? extra}) => container.read(routerProvider).go(path, extra: extra);
  int count(String method, String path) => adapter.requests.where((r) => r.method == method && r.path == path).length;
  RequestOptions last(String method, String path) =>
      adapter.requests.lastWhere((r) => r.method == method && r.path == path);
}

Future<Harness> pumpOrganizer(
  WidgetTester tester, {
  Map<String, RouteHandler> overrides = const {},
}) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final launcher = FakeLauncher();
  final (container, adapter) = makeContainer(
    routes({...baseRoutes(), ...overrides}),
    secure: {accessTokenKey: 'a', refreshTokenKey: 'r', roleKey: 'organizer'},
    overrides: [linkLauncherProvider.overrideWithValue(launcher)],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SanchalanApp()));
  await tester.pumpAndSettle();
  return Harness(container, adapter, launcher);
}

/// Taps and lets everything settle. No ensureVisible: on the event screen it would scroll
/// the tab pager sideways and switch tabs.
Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder inSheet(Type sheet, String text) => find.descendant(of: find.byType(sheet), matching: find.text(text));

/// Scrolls the current tab's vertical list until [target] is built.
Future<void> scrollTo(WidgetTester tester, Finder target) => tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical),
          )
          .first,
    );

Map<String, dynamic> eventWithoutTasks() => {...detailJson, 'tasks': <Object>[]};

void main() {
  group('home', () {
    testWidgets('greets the organizer and features the event', (tester) async {
      final h = await pumpOrganizer(tester);
      expect(h.location, AppPaths.home);
      expect(find.text('Hello, Priya'), findsOneWidget);
      expect(find.text(eventName), findsWidgets);
      expect(find.byType(HeroCard), findsOneWidget);
    });

    testWidgets('no events: an invitation to create one', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {'GET /event-groups/me': (_) => jsonBody([])});
      expect(find.text('Plan your first event'), findsOneWidget);
      await tap(tester, find.text('Create event'));
      expect(h.location, AppPaths.eventSetup);
    });

    testWidgets('a failure loading the featured event shows Retry, which reloads it', (tester) async {
      var fail = true;
      final h = await pumpOrganizer(tester, overrides: {
        'GET /event-groups/$eventId': (_) => fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('event_group_detail'),
      });
      expect(find.text('Retry'), findsOneWidget);
      fail = false;
      await tap(tester, find.text('Retry'));
      expect(find.byType(HeroCard), findsOneWidget);
      expect(h.count('GET', '/event-groups/$eventId'), 2);
    });

    testWidgets('tapping the hero card opens the event', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.byType(HeroCard));
      expect(h.location, AppPaths.eventHome(eventId));
      expect(find.widgetWithText(Tab, 'Roadmap'), findsOneWidget);
    });

    testWidgets('the Add task shortcut opens the event with the task sheet', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.text('Add task'));
      expect(h.location, AppPaths.eventHome(eventId));
      expect(find.text('New task'), findsOneWidget);
    });

    testWidgets('the Add budget item shortcut opens the Budget tab with the category sheet', (tester) async {
      await pumpOrganizer(tester);
      await tap(tester, find.text('Add budget item'));
      expect(find.text('Add budget category'), findsOneWidget);
    });

    testWidgets('Find vendors switches to the Vendors tab', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.text('Find vendors'));
      expect(h.location, AppPaths.vendors);
    });
  });

  group('events tab', () {
    testWidgets('lists events and opens one', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.text('Events'));
      expect(h.location, AppPaths.events);
      expect(find.text('My events'), findsOneWidget);
      await tap(tester, find.text(eventName).first);
      expect(h.location, AppPaths.eventHome(eventId));
    });

    testWidgets('New event opens the form', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.text('Events'));
      await tap(tester, find.text('New event'));
      expect(h.location, AppPaths.eventSetup);
    });
  });

  group('create event', () {
    Future<void> fill(WidgetTester tester) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Meera & Karan');
      await tester.enterText(fields.at(1), 'Mumbai');
      await tester.enterText(fields.at(2), '120');
      await tester.enterText(fields.at(3), '12,00,000');
      await tester.pump();
      await tap(tester, find.text('Choose a date'));
      await tap(tester, find.text('OK'));
    }

    testWidgets('sends the form and opens the new event', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {'POST /event-groups': (_) => fixtureBody('event_group_create', 201)});
      h.go(AppPaths.eventSetup);
      await tester.pumpAndSettle();
      await fill(tester);
      await tap(tester, find.text('Premium'));
      await tap(tester, find.text('Create event'));

      final body = h.last('POST', '/event-groups').data as Map;
      expect(body['name'], 'Meera & Karan');
      expect(body['region'], 'Mumbai');
      expect(body['guestCountEstimate'], 120);
      expect(body['totalBudget'], 1200000.0);
      expect(body['budgetTier'], 'premium');
      expect(body['eventType'], 'wedding');
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(body['primaryDate'] as String), isTrue);
      expect(h.last('POST', '/event-groups').receiveTimeout, const Duration(seconds: 90));
      expect(h.location, AppPaths.eventHome((fixture('event_group_create') as Map)['id'] as String));
      expect(h.count('GET', '/event-groups/me'), greaterThanOrEqualTo(2)); // list reloaded
    });

    testWidgets('a server failure stays on the form with the message', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {'POST /event-groups': (_) => jsonBody({'error': 'The planner is busy.'}, 500)});
      h.go(AppPaths.eventSetup);
      await tester.pumpAndSettle();
      await fill(tester);
      await tap(tester, find.text('Create event'));
      expect(find.text('The planner is busy.'), findsOneWidget);
      expect(h.location, AppPaths.eventSetup);
    });
  });

  group('event detail: roadmap', () {
    testWidgets('shows the event and its tasks', (tester) async {
      final h = await pumpOrganizer(tester);
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      expect(find.text(firstShownTask().name), findsOneWidget);
      expect(find.textContaining('tasks done'), findsOneWidget);
    });

    testWidgets('adds a task', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {
        'POST /event-groups/$eventId/tasks': (_) => fixtureBody('task_create', 201),
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Add task').first);
      await tester.enterText(find.descendant(of: find.byType(TaskSheet), matching: find.byType(TextField)), 'Buy gifts');
      await tap(tester, find.descendant(of: find.byType(TaskSheet), matching: find.text('Catering')));
      await tap(tester, inSheet(TaskSheet, 'Choose a date'));
      await tap(tester, find.text('OK'));
      await tap(tester, inSheet(TaskSheet, 'Add task'));

      final body = h.last('POST', '/event-groups/$eventId/tasks').data as Map;
      expect(body['name'], 'Buy gifts');
      expect(body['category'], 'catering');
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(body['dueDate'] as String), isTrue);
      expect(h.count('GET', '/event-groups/$eventId'), greaterThanOrEqualTo(2)); // reloaded
    });

    testWidgets('changing only the status sends only the status', (tester) async {
      final task = firstShownTask();
      final h = await pumpOrganizer(tester, overrides: {'PATCH /tasks/${task.id}': (_) => fixtureBody('task_update')});
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text(task.name));
      await tap(tester, inSheet(TaskSheet, 'Done'));
      await tap(tester, inSheet(TaskSheet, 'Save changes'));
      expect(h.last('PATCH', '/tasks/${task.id}').data, {'status': 'done'});
    });

    testWidgets('saving without changes sends nothing', (tester) async {
      final task = firstShownTask();
      final h = await pumpOrganizer(tester);
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text(task.name));
      await tap(tester, inSheet(TaskSheet, 'Save changes'));
      expect(h.count('PATCH', '/tasks/${task.id}'), 0);
    });

    testWidgets('removes a task', (tester) async {
      final task = firstShownTask();
      final h = await pumpOrganizer(tester, overrides: {'DELETE /tasks/${task.id}': (_) => fixtureBody('task_delete')});
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text(task.name));
      await tap(tester, inSheet(TaskSheet, 'Remove this task'));
      expect(h.count('DELETE', '/tasks/${task.id}'), 1);
    });

    testWidgets('a failed save shows the server message and keeps the screen', (tester) async {
      final task = firstShownTask();
      final h = await pumpOrganizer(tester, overrides: {'PATCH /tasks/${task.id}': (_) => jsonBody({'error': 'Task is locked.'}, 409)});
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text(task.name));
      await tap(tester, inSheet(TaskSheet, 'Done'));
      await tap(tester, inSheet(TaskSheet, 'Save changes'));
      expect(find.text('Task is locked.'), findsOneWidget);
    });

    testWidgets('generates a roadmap for an event without one, showing the waiting view', (tester) async {
      var tasksGenerated = false;
      final gate = Completer<void>();
      final h = await pumpOrganizer(tester, overrides: {
        'GET /event-groups/$eventId': (_) => tasksGenerated ? fixtureBody('event_group_detail') : jsonBody(eventWithoutTasks()),
        'POST /event-groups/$eventId/generate-roadmap': (_) async {
          await gate.future;
          tasksGenerated = true;
          return fixtureBody('roadmap_generate', 201);
        },
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      expect(find.text('Get your roadmap'), findsOneWidget);

      await tester.tap(find.text('Generate my roadmap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Building your roadmap'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Building your roadmap'), findsNothing);
      expect(find.textContaining('tasks done'), findsOneWidget);
      expect(h.last('POST', '/event-groups/$eventId/generate-roadmap').receiveTimeout, const Duration(seconds: 90));
    });

    testWidgets('a failed generation offers Try again', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {
        'GET /event-groups/$eventId': (_) => jsonBody(eventWithoutTasks()),
        'POST /event-groups/$eventId/generate-roadmap': (_) => jsonBody({'error': 'Planner unavailable.'}, 502),
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Generate my roadmap'));
      expect(find.text('Planner unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('re-running sends the chosen mode', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {
        'POST /event-groups/$eventId/generate-roadmap': (_) => fixtureBody('roadmap_generate', 201),
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Re-run'));
      await tap(tester, find.text('Only add missing tasks'));
      await tap(tester, find.text('Re-run roadmap'));
      expect(h.last('POST', '/event-groups/$eventId/generate-roadmap').data, {'mode': 'add_missing'});
    });
  });

  group('event detail: budget', () {
    final first = (detailJson['budgetCategories'] as List).first as Map<String, dynamic>;
    final firstKey = first['categoryKey'] as String;
    final firstId = first['id'] as String;

    Future<Harness> openBudget(WidgetTester tester, [Map<String, RouteHandler> overrides = const {}]) async {
      final h = await pumpOrganizer(tester, overrides: overrides);
      h.go(AppPaths.eventHome(eventId), extra: const EventHomeArgs(tab: 1));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('edits a category amount, sending only the amount', (tester) async {
      final h = await openBudget(tester, {
        'PATCH /event-groups/$eventId/budget-categories/$firstId': (_) => fixtureBody('budget_category_update'),
      });
      await tap(tester, find.text(categoryLabelFor(firstKey)).first);
      expect(find.textContaining('Edit '), findsWidgets);
      final amount = find.descendant(of: find.byType(BudgetCategorySheet), matching: find.byType(TextField)).last;
      await tester.enterText(amount, '123456');
      await tester.pumpAndSettle();
      await tap(tester, inSheet(BudgetCategorySheet, 'Save changes'));
      expect(h.last('PATCH', '/event-groups/$eventId/budget-categories/$firstId').data, {'allocatedAmount': 123456.0});
    });

    testWidgets('deleting asks to confirm first', (tester) async {
      final h = await openBudget(tester, {
        'DELETE /event-groups/$eventId/budget-categories/$firstId': (_) => fixtureBody('budget_category_delete'),
      });
      await tap(tester, find.text(categoryLabelFor(firstKey)).first);
      await tap(tester, inSheet(BudgetCategorySheet, 'Delete this category'));
      expect(find.text('Delete this category?'), findsOneWidget);
      expect(h.count('DELETE', '/event-groups/$eventId/budget-categories/$firstId'), 0);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(h.count('DELETE', '/event-groups/$eventId/budget-categories/$firstId'), 1);
    });

    testWidgets('adds a custom category', (tester) async {
      final h = await openBudget(tester, {
        'POST /event-groups/$eventId/budget-categories': (_) => fixtureBody('budget_category_create', 201),
      });
      await tap(tester, find.text('Add category').first);
      await tap(tester, inSheet(BudgetCategorySheet, 'Something else'));
      final fields = find.descendant(of: find.byType(BudgetCategorySheet), matching: find.byType(TextField));
      await tester.enterText(fields.first, 'Return gifts');
      await tester.enterText(fields.last, '20000');
      await tester.pumpAndSettle();
      await tap(tester, inSheet(BudgetCategorySheet, 'Add category'));
      expect(h.last('POST', '/event-groups/$eventId/budget-categories').data, {
        'categoryKey': 'return_gifts',
        'allocatedAmount': 20000.0,
      });
    });

    testWidgets('a budget warning from the server is shown', (tester) async {
      await openBudget(tester, {
        'PATCH /event-groups/$eventId/budget-categories/$firstId': (_) => jsonBody({
              'budgetCategory': {...first, 'allocatedAmount': 99999999},
              'warning': 'Allocated budget exceeds total budget.',
            }),
      });
      await tap(tester, find.text(categoryLabelFor(firstKey)).first);
      final amount = find.descendant(of: find.byType(BudgetCategorySheet), matching: find.byType(TextField)).last;
      await tester.enterText(amount, '99999999');
      await tester.pumpAndSettle();
      await tap(tester, inSheet(BudgetCategorySheet, 'Save changes'));
      expect(find.text('Allocated budget exceeds total budget.'), findsOneWidget);
    });
  });

  group('event detail: the event', () {
    testWidgets('editing the name sends only the name, then returns', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {
        'PATCH /event-groups/$eventId': (_) => fixtureBody('event_group_update'),
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('More'));
      await tap(tester, find.text('Edit event details'));
      expect(h.location, AppPaths.eventEdit(eventId));
      await tester.enterText(find.byType(TextField).first, 'Priya & Rohan (new)');
      await tester.pump();
      await tap(tester, find.text('Save changes'));
      expect(h.last('PATCH', '/event-groups/$eventId').data, {'name': 'Priya & Rohan (new)'});
      expect(h.location, AppPaths.eventHome(eventId));
    });

    testWidgets('saving an edit form without changes sends nothing', (tester) async {
      final h = await pumpOrganizer(tester);
      h.go(AppPaths.eventEdit(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save changes'));
      expect(h.count('PATCH', '/event-groups/$eventId'), 0);
    });

    testWidgets('deleting asks first, then removes the event and returns to the list', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {
        'DELETE /event-groups/$eventId': (_) => jsonBody({'deleted': true, 'id': eventId}),
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('More'));
      await tap(tester, find.text('Delete event'));
      expect(find.text('Delete this event?'), findsOneWidget);
      expect(h.count('DELETE', '/event-groups/$eventId'), 0);
      await tester.tap(find.widgetWithText(TextButton, 'Delete event'));
      await tester.pumpAndSettle();
      expect(h.count('DELETE', '/event-groups/$eventId'), 1);
      expect(h.location, AppPaths.events);
    });

    testWidgets('a failed delete keeps the event and says why', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {
        'DELETE /event-groups/$eventId': (_) => jsonBody({'error': 'This event has recorded payments.'}, 409),
      });
      h.go(AppPaths.eventHome(eventId));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('More'));
      await tap(tester, find.text('Delete event'));
      await tester.tap(find.widgetWithText(TextButton, 'Delete event'));
      await tester.pumpAndSettle();
      expect(find.text('This event has recorded payments.'), findsOneWidget);
      expect(h.location, AppPaths.eventHome(eventId));
    });
  });

  group('vendors', () {
    testWidgets('lists vendors, filters on the server, and opens one', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.text('Vendors'));
      expect(find.text('Shubh Photos'), findsOneWidget);
      expect(find.text('For $eventName'), findsOneWidget);

      final premium = find.widgetWithText(ChoiceChip, 'Premium');
      await tester.ensureVisible(premium); // the chip row scrolls sideways
      await tester.pumpAndSettle();
      await tap(tester, premium);
      expect(h.last('GET', '/vendors').queryParameters, {'priceTier': 'premium'});

      await tap(tester, find.text('Shubh Photos'));
      expect(h.location, AppPaths.vendorDetail(vendorId));
    });

    testWidgets('Browse by category from an event opens the directory filtered', (tester) async {
      final h = await pumpOrganizer(tester);
      h.go(AppPaths.eventHome(eventId), extra: const EventHomeArgs());
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(Tab, 'Vendors'));
      await tap(tester, find.text('Catering').first);
      expect(h.location, AppPaths.vendors);
      expect(h.last('GET', '/vendors').queryParameters['category'], 'catering');
    });

    testWidgets('a failure shows Retry', (tester) async {
      var fail = true;
      final h = await pumpOrganizer(tester, overrides: {
        'GET /vendors': (_) => fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('vendors_list'),
      });
      await tap(tester, find.text('Vendors'));
      expect(find.text('Could not load vendors.'), findsOneWidget);
      fail = false;
      await tap(tester, find.text('Retry'));
      expect(find.text('Shubh Photos'), findsOneWidget);
      expect(h.count('GET', '/vendors'), 2);
    });

    testWidgets('Call, WhatsApp and links go through the launcher', (tester) async {
      final json = {...(fixture('vendor_detail') as Map<String, dynamic>), 'whatsappNumber': '+919811122233', 'instagramUrl': 'https://instagram.com/shubh'};
      final h = await pumpOrganizer(tester, overrides: {'GET /vendors/$vendorId': (_) => jsonBody(json)});
      h.go(AppPaths.vendorDetail(vendorId));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Call'));
      await tap(tester, find.text('WhatsApp'));
      await tap(tester, find.text('Instagram'));
      expect(h.launcher.calls, ['call ${json['phoneNumber']}', 'whatsapp +919811122233', 'url https://instagram.com/shubh']);
    });

    testWidgets('a launcher failure is explained', (tester) async {
      final h = await pumpOrganizer(tester);
      h.launcher.result = false;
      h.go(AppPaths.vendorDetail(vendorId));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Call'));
      expect(find.text('Could not open the phone app.'), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('shows the organizer; editing sends the new profile', (tester) async {
      final h = await pumpOrganizer(tester, overrides: {'POST /organizers/me/profile': (_) => fixtureBody('organizer_profile')});
      await tap(tester, find.text('Profile'));
      expect(find.text('Priya Sharma'), findsOneWidget);
      await tap(tester, find.text('Edit profile'));
      expect(h.location, AppPaths.profileEdit);
      await tester.enterText(find.byType(TextField), 'Priya S.');
      await tester.pump();
      await tap(tester, find.text('Save'));
      expect(h.last('POST', '/organizers/me/profile').data, {'displayName': 'Priya S.', 'organizerType': 'family'});
      expect(h.location, AppPaths.profile);
    });

    testWidgets('signing out asks first, then returns to welcome', (tester) async {
      final h = await pumpOrganizer(tester);
      await tap(tester, find.text('Profile'));
      await tap(tester, find.text('Sign out'));
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')));
      await tester.pumpAndSettle();
      expect(h.count('POST', '/auth/logout'), 1);
      expect(h.location, AppPaths.welcome);
    });

    testWidgets('first-time setup saves the profile and lands on home', (tester) async {
      var saved = false;
      final h = await pumpOrganizer(tester, overrides: {
        'GET /organizers/me': (_) => saved ? fixtureBody('organizer_profile') : fixtureBody('organizer_me_fresh'),
        'POST /organizers/me/profile': (_) {
          saved = true;
          return fixtureBody('organizer_profile');
        },
      });
      expect(h.location, AppPaths.profileSetup);
      await tester.enterText(find.byType(TextField), 'Priya Sharma');
      await tap(tester, find.text('Family'));
      await tap(tester, find.text('Continue'));
      expect(h.last('POST', '/organizers/me/profile').data, {'displayName': 'Priya Sharma', 'organizerType': 'family'});
      expect(h.location, AppPaths.home);
    });
  });
}

String categoryLabelFor(String key) {
  const labels = {
    'venue': 'Venue',
    'catering': 'Catering',
    'decor': 'Décor',
    'photography': 'Photography',
    'attire': 'Attire',
    'invitations': 'Invitations',
    'music_entertainment': 'Music & Entertainment',
    'priest_officiant': 'Priest / Officiant',
    'transport': 'Transport',
    'guest_logistics': 'Guest logistics',
    'legal_documentation': 'Legal & documents',
    'misc': 'Other',
  };
  return labels[key] ?? key;
}
