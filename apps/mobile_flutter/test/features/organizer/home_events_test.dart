import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/events_view.dart';
import 'package:sanchalan/features/organizer/home_view.dart';
import 'package:sanchalan/features/organizer/organizer_shell.dart';
import 'package:sanchalan/features/organizer/widgets/hero_card.dart';
import 'package:sanchalan/shared/widgets/skeleton.dart';

import '../../helpers/pump_screen.dart';

const _unset = Object();
final today = DateTime(2026, 10, 10);
final mock = MockData(today: today);

Widget home({
  HomeStatus status = HomeStatus.ready,
  List<dynamic>? events,
  dynamic featured = _unset,
  void Function(String)? onSelect,
  void Function(String)? onOpen,
  VoidCallback? onNew,
  VoidCallback? onRetry,
  VoidCallback? onAddTask,
  VoidCallback? onAddCategory,
  VoidCallback? onFind,
  void Function(dynamic)? onTask,
}) =>
    Scaffold(
      body: HomeView(
        status: status,
        organizerName: 'Priya Sharma',
        events: events == null ? mock.events : events.cast(),
        featured: identical(featured, _unset) ? mock.wedding : featured,
        today: today,
        onSelectEvent: onSelect,
        onOpenEvent: onOpen,
        onNewEvent: onNew,
        onRetry: onRetry,
        onAddTask: onAddTask,
        onAddCategory: onAddCategory,
        onFindVendors: onFind,
        onOpenTask: onTask == null ? null : (t) => onTask(t),
      ),
    );

void main() {
  group('HomeView', () {
    testWidgets('greets by first name and shows the hero card', (tester) async {
      await pumpScreen(tester, home());
      expect(find.text('Hello, Priya'), findsOneWidget);
      expect(find.text('Priya & Rohan'), findsWidgets);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('days to go'), findsOneWidget);
      expect(find.text('4 of 17 tasks done · 2 overdue'), findsOneWidget);
      expect(find.text('24%'), findsOneWidget);
    });

    testWidgets('Next up lists the most urgent tasks, overdue first', (tester) async {
      await pumpScreen(tester, home(), size: const Size(400, 1400));
      expect(find.text('Next up'), findsOneWidget);
      expect(find.text('Taste and choose the menu'), findsOneWidget);
      expect(find.text('Buy bride and groom outfits'), findsOneWidget);
      expect(find.text('Overdue by 5 days'), findsOneWidget);
      // Third entry is the next dated one; later tasks are not shown.
      expect(find.text('Send invitations to guests'), findsOneWidget);
      expect(find.text('Arrange baraat transport'), findsNothing);
    });

    testWidgets('budget snapshot shows total, split and what is left', (tester) async {
      await pumpScreen(tester, home(), size: const Size(400, 1600));
      expect(find.text('₹15,00,000'), findsOneWidget);
      expect(find.text('Venue'), findsOneWidget);
      expect(find.text('₹4.5 L'), findsOneWidget);
      expect(find.text('₹60K left to allocate'), findsOneWidget);
    });

    testWidgets('an over-allocated budget says so', (tester) async {
      await pumpScreen(tester, home(featured: mock.birthday), size: const Size(400, 1600));
      expect(find.text('₹10K over budget'), findsOneWidget);
    });

    testWidgets('an event without a roadmap offers to generate one', (tester) async {
      var opened = '';
      await pumpScreen(
        tester,
        home(featured: mock.newEvent, onOpen: (id) => opened = id),
        size: const Size(400, 1400),
      );
      expect(find.text('Your roadmap is not generated yet'), findsOneWidget);
      expect(find.text('Generate your roadmap'), findsOneWidget);
      await tester.tap(find.text('Open event'));
      expect(opened, 'ev-new');
    });

    testWidgets('when every task is done it says you are caught up', (tester) async {
      await pumpScreen(tester, home(featured: mock.birthday), size: const Size(400, 1400));
      expect(find.textContaining("You're all caught up"), findsOneWidget);
    });

    testWidgets('event chips switch the featured event', (tester) async {
      String? selected;
      await pumpScreen(tester, home(onSelect: (id) => selected = id));
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      final chip = find.widgetWithText(ChoiceChip, "Aarav's 5th birthday");
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      expect(selected, 'ev-birthday');
    });

    testWidgets('a single event shows no switcher', (tester) async {
      await pumpScreen(tester, home(events: [mock.wedding]));
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('callbacks: hero, task, quick actions', (tester) async {
      final calls = <String>[];
      await pumpScreen(
        tester,
        home(
          onOpen: (id) => calls.add('open $id'),
          onTask: (t) => calls.add('task ${t.id}'),
          onAddTask: () => calls.add('add task'),
          onAddCategory: () => calls.add('add category'),
          onFind: () => calls.add('vendors'),
        ),
        size: const Size(400, 1400),
      );
      await tester.tap(find.byType(HeroCard));
      await tester.tap(find.text('Taste and choose the menu'));
      await tester.tap(find.text('Add task'));
      await tester.tap(find.text('Add budget item'));
      await tester.tap(find.text('Find vendors'));
      expect(calls, ['open ev-wedding', 'task t3', 'add task', 'add category', 'vendors']);
    });

    testWidgets('no events: empty state with a Create event action', (tester) async {
      var taps = 0;
      await pumpScreen(
        tester,
        home(events: [], featured: null, onNew: () => taps++),
      );
      expect(find.text('Plan your first event'), findsOneWidget);
      await tester.tap(find.text('Create event'));
      expect(taps, 1);
      expect(find.text('Hello, Priya'), findsOneWidget);
    });

    testWidgets('loading shows skeletons, error shows Retry', (tester) async {
      var retries = 0;
      await pumpScreen(tester, home(status: HomeStatus.loading));
      expect(find.byType(Skeleton), findsWidgets);

      await pumpScreen(tester, home(status: HomeStatus.error, onRetry: () => retries++));
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    for (final status in HomeStatus.values) {
      for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
        testWidgets('${status.name} fits $size at text scale $scale', (tester) async {
          await pumpScreen(tester, home(status: status), size: size, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('EventsView', () {
    Widget events({
      HomeStatus status = HomeStatus.ready,
      List<dynamic>? list,
      void Function(String)? onOpen,
      VoidCallback? onNew,
      VoidCallback? onRetry,
    }) =>
        EventsView(
          status: status,
          events: list == null ? mock.events : list.cast(),
          today: today,
          onOpenEvent: onOpen,
          onNewEvent: onNew,
          onRetry: onRetry,
        );

    testWidgets('lists upcoming events first, then past', (tester) async {
      await pumpScreen(tester, events(), size: const Size(400, 1200));
      expect(find.text('3 events'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      final wedding = tester.getTopLeft(find.text('Priya & Rohan')).dy;
      final engagement = tester.getTopLeft(find.text('Meera & Karan engagement')).dy;
      final birthday = tester.getTopLeft(find.text("Aarav's 5th birthday")).dy;
      expect(wedding, lessThan(engagement));
      expect(engagement, lessThan(birthday));
    });

    testWidgets('cards show type, when, guests and budget', (tester) async {
      await pumpScreen(tester, events(), size: const Size(400, 1200));
      expect(find.text('Wedding · In 48 days'), findsOneWidget);
      expect(find.text('Birthday · Past event'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('₹15 L'), findsOneWidget);
    });

    testWidgets('tapping a card opens it; the button creates a new event', (tester) async {
      String? opened;
      var created = 0;
      await pumpScreen(tester, events(onOpen: (id) => opened = id, onNew: () => created++), size: const Size(400, 1200));
      await tester.tap(find.text('Priya & Rohan'));
      expect(opened, 'ev-wedding');
      await tester.tap(find.text('New event'));
      expect(created, 1);
    });

    testWidgets('empty state', (tester) async {
      var created = 0;
      await pumpScreen(tester, events(list: [], onNew: () => created++));
      expect(find.text('No events yet'), findsOneWidget);
      expect(find.text('New event'), findsNothing); // no FAB when empty
      await tester.tap(find.text('Create event'));
      expect(created, 1);
    });

    testWidgets('loading and error', (tester) async {
      var retries = 0;
      await pumpScreen(tester, events(status: HomeStatus.loading));
      expect(find.byType(Skeleton), findsNWidgets(3));
      await pumpScreen(tester, events(status: HomeStatus.error, onRetry: () => retries++));
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
      testWidgets('fits $size at text scale $scale', (tester) async {
        await pumpScreen(tester, events(), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('OrganizerShell', () {
    testWidgets('shows four tabs and reports the selected one', (tester) async {
      final taps = <int>[];
      await pumpScreen(
        tester,
        OrganizerShell(body: const Text('content'), currentIndex: 0, onSelect: taps.add),
      );
      for (final label in ['Home', 'Events', 'Vendors', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Vendors'));
      await tester.tap(find.text('Profile'));
      expect(taps, [2, 3]);
      expect(find.text('content'), findsOneWidget);
    });
  });
}
