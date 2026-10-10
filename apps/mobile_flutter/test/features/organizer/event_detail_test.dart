import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/event_detail_view.dart';
import 'package:sanchalan/features/organizer/home_view.dart' show HomeStatus;
import 'package:sanchalan/features/organizer/widgets/generating_view.dart';
import 'package:sanchalan/models/event.dart';
import 'package:sanchalan/shared/widgets/skeleton.dart';

import '../../helpers/pump_screen.dart';

final today = DateTime(2026, 10, 10);
final mock = MockData(today: today);

const _tall = Size(400, 1600);

Widget detail({
  HomeStatus status = HomeStatus.ready,
  EventGroup? event,
  bool useEvent = true,
  int tab = 0,
  bool generating = false,
  String? generateError,
  VoidCallback? onRetry,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onGenerate,
  VoidCallback? onRegenerate,
  VoidCallback? onAddTask,
  ValueChanged<dynamic>? onOpenTask,
  ValueChanged<dynamic>? onRestore,
  VoidCallback? onEditTotal,
  VoidCallback? onAddCategory,
  ValueChanged<dynamic>? onEditCategory,
  ValueChanged<String?>? onBrowse,
}) =>
    EventDetailView(
      status: status,
      event: useEvent ? (event ?? mock.wedding) : null,
      removedTasks: mock.removedTasks,
      today: today,
      initialTab: tab,
      generating: generating,
      generateError: generateError,
      onRetry: onRetry,
      onEdit: onEdit,
      onDelete: onDelete,
      onGenerate: onGenerate,
      onRegenerate: onRegenerate,
      onAddTask: onAddTask,
      onOpenTask: onOpenTask == null ? null : (t) => onOpenTask(t),
      onRestoreTask: onRestore == null ? null : (t) => onRestore(t),
      onEditTotal: onEditTotal,
      onAddCategory: onAddCategory,
      onEditCategory: onEditCategory == null ? null : (c) => onEditCategory(c),
      onBrowseVendors: onBrowse,
    );

/// Scrolls the current tab's list until [target] is built and on screen.
Future<void> scrollTo(WidgetTester tester, Finder target) => tester.scrollUntilVisible(
      target,
      300,
      // The vertical list of the current tab (the tab pager scrolls sideways).
      scrollable: find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical),
          )
          .first,
    );

void main() {
  group('header and tabs', () {
    testWidgets('shows the event facts and the three tabs', (tester) async {
      await pumpScreen(tester, detail(), size: _tall);
      expect(find.text('Priya & Rohan'), findsOneWidget); // app bar title
      expect(find.textContaining('48 days').evaluate().isNotEmpty || find.textContaining('In 48 days').evaluate().isNotEmpty, isTrue);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('250 guests'), findsOneWidget);
      expect(find.text('Standard budget'), findsOneWidget);
      for (final t in ['Roadmap', 'Budget', 'Vendors']) {
        expect(find.widgetWithText(Tab, t), findsOneWidget);
      }
    });

    testWidgets('switching tabs shows the budget and vendors content', (tester) async {
      await pumpScreen(tester, detail(), size: _tall);
      await tester.tap(find.widgetWithText(Tab, 'Budget'));
      await tester.pumpAndSettle();
      expect(find.text('Total budget'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      expect(find.text('Browse all vendors'), findsOneWidget);
    });

    testWidgets('the menu offers Edit and Delete', (tester) async {
      final calls = <String>[];
      await pumpScreen(tester, detail(onEdit: () => calls.add('edit'), onDelete: () => calls.add('delete')), size: _tall);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit event details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();
      expect(calls, ['edit', 'delete']);
    });

    testWidgets('loading shows skeletons, error shows Retry, missing event is loading', (tester) async {
      var retries = 0;
      await pumpScreen(tester, detail(status: HomeStatus.loading));
      expect(find.byType(Skeleton), findsWidgets);
      await pumpScreen(tester, detail(status: HomeStatus.ready, useEvent: false));
      expect(find.byType(Skeleton), findsWidgets);
      await pumpScreen(tester, detail(status: HomeStatus.error, onRetry: () => retries++));
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('roadmap tab', () {
    testWidgets('progress, filters with counts and tasks grouped by category', (tester) async {
      await pumpScreen(tester, detail(), size: _tall);
      expect(find.text('4 of 17 tasks done'), findsOneWidget);
      expect(find.text('2 tasks overdue'), findsOneWidget);
      expect(find.text('All (17)'), findsOneWidget);
      expect(find.text('To do (13)'), findsOneWidget);
      expect(find.text('Overdue (2)'), findsOneWidget);
      expect(find.text('Done (4)'), findsOneWidget);
      expect(find.text('Attire'), findsOneWidget);
      await scrollTo(tester, find.text('Book the wedding venue'));
      expect(find.text('Book the wedding venue'), findsOneWidget);
    });

    testWidgets('the Overdue filter narrows the list', (tester) async {
      await pumpScreen(tester, detail(), size: _tall);
      await tester.tap(find.text('Overdue (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Taste and choose the menu'), findsOneWidget);
      expect(find.text('Buy bride and groom outfits'), findsOneWidget);
      expect(find.text('Book the wedding venue'), findsNothing);
    });

    testWidgets('an empty filter explains itself', (tester) async {
      await pumpScreen(tester, detail(event: mock.birthday), size: _tall);
      await tester.tap(find.textContaining('Overdue ('));
      await tester.pumpAndSettle();
      expect(find.text('Nothing is overdue. Well done!'), findsOneWidget);
    });

    testWidgets('callbacks: add, re-run, open task', (tester) async {
      final calls = <String>[];
      await pumpScreen(
        tester,
        detail(
          onAddTask: () => calls.add('add'),
          onRegenerate: () => calls.add('regen'),
          onOpenTask: (t) => calls.add('open ${t.id}'),
        ),
        size: _tall,
      );
      await tester.tap(find.text('Add task'));
      await tester.tap(find.text('Re-run'));
      await tester.tap(find.text('Buy bride and groom outfits'));
      expect(calls, ['add', 'regen', 'open t9']);
    });

    testWidgets('removed tasks can be shown and restored', (tester) async {
      String? restored;
      await pumpScreen(tester, detail(onRestore: (t) => restored = t.id), size: _tall);
      expect(find.text('Hire a live cooking counter'), findsNothing);
      await scrollTo(tester, find.text('Removed tasks (1)'));
      await tester.tap(find.text('Removed tasks (1)'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Restore'));
      await tester.ensureVisible(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Hire a live cooking counter'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      expect(restored, 't18');
      await scrollTo(tester, find.text('Hide removed tasks'));
      await tester.tap(find.text('Hide removed tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Hire a live cooking counter'), findsNothing);
    });

    testWidgets('no roadmap yet: invites to generate, and can offer Try again after a failure', (tester) async {
      var generated = 0;
      await pumpScreen(tester, detail(event: mock.newEvent, onGenerate: () => generated++), size: _tall);
      expect(find.text('Get your roadmap'), findsOneWidget);
      await tester.tap(find.text('Generate my roadmap'));
      expect(generated, 1);

      await pumpScreen(
        tester,
        detail(event: mock.newEvent, generateError: 'Could not generate your roadmap. Please try again.', onGenerate: () => generated++),
        size: _tall,
      );
      expect(find.text('Could not generate your roadmap. Please try again.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(generated, 2);
    });

    testWidgets('while generating, the waiting view replaces the list', (tester) async {
      await pumpScreen(tester, detail(event: mock.newEvent, generating: true), size: _tall);
      expect(find.text('Building your roadmap'), findsOneWidget);
      expect(find.text('Generate my roadmap'), findsNothing);
    });
  });

  group('GeneratingView', () {
    testWidgets('walks through the steps over time', (tester) async {
      await pumpScreen(tester, const Scaffold(body: GeneratingView(stepDuration: Duration(seconds: 2))), size: _tall);
      for (final s in GeneratingView.steps) {
        expect(find.text(s), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_circle), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byIcon(Icons.check_circle), findsNWidgets(GeneratingView.steps.length - 1));
    });

    testWidgets('fits a small screen at large text', (tester) async {
      await pumpScreen(tester, const Scaffold(body: SingleChildScrollView(child: GeneratingView())), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('budget tab', () {
    testWidgets('totals and categories', (tester) async {
      await pumpScreen(tester, detail(tab: 1), size: _tall);
      expect(find.text('₹15,00,000'), findsOneWidget);
      expect(find.text('₹14,40,000'), findsOneWidget);
      expect(find.text('₹60,000'), findsOneWidget);
      expect(find.text('Left to allocate'), findsOneWidget);
      expect(find.text('7 categories'), findsOneWidget);
      expect(find.text('Venue'), findsWidgets);
      expect(find.textContaining('more than your total budget'), findsNothing);
    });

    testWidgets('an over-allocated budget shows a warning', (tester) async {
      await pumpScreen(tester, detail(event: mock.birthday, tab: 1), size: _tall);
      expect(find.text('Over by'), findsOneWidget);
      expect(find.textContaining('₹10,000 more than your total budget'), findsOneWidget);
    });

    testWidgets('callbacks: edit total, edit category, add category', (tester) async {
      final calls = <String>[];
      await pumpScreen(
        tester,
        detail(
          tab: 1,
          onEditTotal: () => calls.add('total'),
          onEditCategory: (c) => calls.add('edit ${c.categoryKey}'),
          onAddCategory: () => calls.add('add'),
        ),
        size: const Size(400, 2000),
      );
      await tester.tap(find.byTooltip('Edit total budget'));
      await tester.tap(find.text('Catering').first);
      await tester.ensureVisible(find.text('Add category'));
      await tester.tap(find.text('Add category'));
      expect(calls, ['total', 'edit catering', 'add']);
    });

    testWidgets('no categories yet', (tester) async {
      final empty = EventGroup.fromJson({...mock.newEvent.toJson(), 'budgetCategories': <Object>[]});
      await pumpScreen(tester, detail(event: empty, tab: 1), size: _tall);
      expect(find.textContaining('No categories yet'), findsOneWidget);
    });
  });

  group('vendors tab', () {
    testWidgets('browse all, by category, and the coming-soon note', (tester) async {
      final calls = <String?>[];
      await pumpScreen(tester, detail(tab: 2, onBrowse: calls.add), size: _tall);
      await tester.tap(find.text('Browse all vendors'));
      await tester.tap(find.text('Catering'));
      expect(calls, [null, 'catering']);
      expect(find.text('Coming soon'), findsOneWidget);
    });
  });

  for (final tab in [0, 1, 2]) {
    for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
      testWidgets('tab $tab fits $size at text scale $scale', (tester) async {
        await pumpScreen(tester, detail(tab: tab), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        await pumpScreen(tester, detail(tab: tab, event: mock.newEvent), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
