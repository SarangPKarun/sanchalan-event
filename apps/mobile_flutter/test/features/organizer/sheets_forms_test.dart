import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/event_form_view.dart';
import 'package:sanchalan/features/organizer/profile_setup_view.dart';
import 'package:sanchalan/features/organizer/sheets/budget_category_sheet.dart';
import 'package:sanchalan/features/organizer/sheets/regenerate_sheet.dart';
import 'package:sanchalan/features/organizer/sheets/sheet_scaffold.dart';
import 'package:sanchalan/features/organizer/sheets/task_sheet.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/shared/widgets/confirm_dialog.dart';

import '../../helpers/pump_screen.dart';

final today = DateTime(2026, 10, 10);
final mock = MockData(today: today);

/// Pumps a screen with an "Open" button that shows a sheet/dialog and keeps its result.
class _Opener<T> {
  T? result;
  bool done = false;

  Future<void> open(WidgetTester tester, Future<T?> Function(BuildContext) show, {Size size = const Size(400, 900), double scale = 1.0}) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await show(context);
                done = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      size: size,
      textScale: scale,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('parseAmount and keys', () {
    test('parseAmount accepts plain, grouped and rupee-prefixed numbers', () {
      expect(parseAmount('450000'), 450000);
      expect(parseAmount('4,50,000'), 450000);
      expect(parseAmount(' ₹ 1,500 '), 1500);
      expect(parseAmount('0'), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('-5'), isNull);
    });

    test('categoryKeyFromName makes an API key', () {
      expect(categoryKeyFromName('Gift boxes'), 'gift_boxes');
      expect(categoryKeyFromName('  Return   Gifts! '), 'return_gifts');
      expect(categoryKeyFromName('***'), '');
    });
  });

  group('confirm dialog', () {
    testWidgets('returns true on confirm and false on cancel', (tester) async {
      final o = _Opener<bool>();
      await o.open(tester, (c) => showConfirmDialog(c, title: 'Delete?', message: 'Sure?', confirmLabel: 'Delete', destructive: true));
      expect(find.text('Sure?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(o.result, isTrue);

      final o2 = _Opener<bool>();
      await o2.open(tester, (c) => showConfirmDialog(c, title: 'Delete?', message: 'Sure?', confirmLabel: 'Delete'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(o2.result, isFalse);
    });
  });

  group('RegenerateSheet', () {
    testWidgets('defaults to keeping my work and returns the chosen mode', (tester) async {
      final o = _Opener<RoadmapRegenMode>();
      await o.open(tester, showRegenerateSheet);
      expect(find.text('Refresh, keep my work'), findsOneWidget);
      expect(find.text('Re-run roadmap'), findsOneWidget);
      await tester.tap(find.text('Re-run roadmap'));
      await tester.pumpAndSettle();
      expect(o.result, RoadmapRegenMode.keepMyWork);
    });

    testWidgets('start over warns and relabels the button', (tester) async {
      final o = _Opener<RoadmapRegenMode>();
      await o.open(tester, showRegenerateSheet);
      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();
      expect(find.text('Replace my roadmap'), findsOneWidget);
      expect(find.textContaining('progress will be lost'), findsOneWidget);
      await tester.tap(find.text('Replace my roadmap'));
      await tester.pumpAndSettle();
      expect(o.result, RoadmapRegenMode.replaceAll);
    });

    testWidgets('only add missing', (tester) async {
      final o = _Opener<RoadmapRegenMode>();
      await o.open(tester, showRegenerateSheet);
      await tester.tap(find.text('Only add missing tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Re-run roadmap'));
      await tester.pumpAndSettle();
      expect(o.result, RoadmapRegenMode.addMissing);
    });

    testWidgets('fits a small screen at large text', (tester) async {
      await _Opener<RoadmapRegenMode>().open(tester, showRegenerateSheet, size: const Size(360, 640), scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('TaskSheet', () {
    Future<_Opener<TaskSheetResult>> openNew(WidgetTester tester) async {
      final o = _Opener<TaskSheetResult>();
      await o.open(tester, (c) => showTaskSheet(c, categoryKeys: suggestedBudgetKeys, today: today));
      return o;
    }

    testWidgets('a new task needs a name, a date and a category', (tester) async {
      final o = await openNew(tester);
      expect(find.text('New task'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(find.text('Give the task a name.'), findsOneWidget);
      expect(find.text('Choose a due date.'), findsOneWidget);
      expect(find.text('Choose a category.'), findsOneWidget);
      expect(o.done, isFalse);
    });

    testWidgets('saves a new task with name, date and category', (tester) async {
      final o = await openNew(tester);
      await tester.enterText(find.byType(TextField), 'Book the band');
      await tester.tap(find.text('Music & Entertainment'));
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      final saved = o.result as TaskSaved;
      expect(saved.name, 'Book the band');
      expect(saved.categoryKey, 'music_entertainment');
      expect(saved.dueDate, isNotNull);
      expect(saved.status, isNull);
    });

    testWidgets('editing shows the current values, status and a remove option', (tester) async {
      final task = mock.weddingTasks.firstWhere((t) => t.id == 't3'); // overdue catering task
      final o = _Opener<TaskSheetResult>();
      await o.open(tester, (c) => showTaskSheet(c, task: task, categoryKeys: suggestedBudgetKeys, today: today));
      expect(find.text('Task details'), findsOneWidget);
      expect(find.text('Overdue by 5 days'), findsOneWidget);
      expect(find.text('Taste and choose the menu'), findsOneWidget);
      expect(find.textContaining('Schedule a tasting'), findsOneWidget);
      expect(find.text('Remove this task'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final saved = o.result as TaskSaved;
      expect(saved.status, TaskStatus.done);
      expect(saved.categoryKey, 'catering');
      expect(saved.name, 'Taste and choose the menu');
    });

    testWidgets('removing a task returns TaskDeleted', (tester) async {
      final task = mock.weddingTasks.first;
      final o = _Opener<TaskSheetResult>();
      await o.open(tester, (c) => showTaskSheet(c, task: task, categoryKeys: suggestedBudgetKeys, today: today));
      await tester.ensureVisible(find.text('Remove this task'));
      await tester.tap(find.text('Remove this task'));
      await tester.pumpAndSettle();
      expect(o.result, isA<TaskDeleted>());
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('fits 360x640 at text scale $scale (new and edit)', (tester) async {
        await _Opener<TaskSheetResult>().open(
          tester,
          (c) => showTaskSheet(c, categoryKeys: suggestedBudgetKeys, today: today),
          size: const Size(360, 640),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await _Opener<TaskSheetResult>().open(
          tester,
          (c) => showTaskSheet(c, task: mock.weddingTasks[2], categoryKeys: suggestedBudgetKeys, today: today),
          size: const Size(360, 640),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BudgetCategorySheet', () {
    final wedding = mock.wedding;

    Future<_Opener<BudgetSheetResult>> openNew(WidgetTester tester) async {
      final o = _Opener<BudgetSheetResult>();
      await o.open(
        tester,
        (c) => showBudgetCategorySheet(
          c,
          usedKeys: wedding.budgetCategories.map((b) => b.categoryKey),
          total: wedding.totalBudget,
          otherAllocated: 1440000,
        ),
      );
      return o;
    }

    testWidgets('hides categories that are already used', (tester) async {
      await openNew(tester);
      expect(find.text('Add budget category'), findsOneWidget);
      expect(find.text('Venue'), findsNothing); // used
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Something else'), findsOneWidget);
    });

    testWidgets('validates, then saves a suggested category with its amount', (tester) async {
      final o = await openNew(tester);
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a category or type a name.'), findsOneWidget);
      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);

      await tester.tap(find.text('Transport'));
      await tester.enterText(find.byType(TextField), '50,000');
      await tester.pumpAndSettle();
      expect(find.textContaining('is 3% of your'), findsOneWidget);
      expect(find.textContaining('over budget'), findsNothing);
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      final saved = o.result as BudgetSaved;
      expect(saved.categoryKey, 'transport');
      expect(saved.amount, 50000);
    });

    testWidgets('warns when the amount goes over budget', (tester) async {
      await openNew(tester);
      await tester.tap(find.text('Transport'));
      await tester.enterText(find.byType(TextField), '100000');
      await tester.pumpAndSettle();
      expect(find.textContaining('This takes you ₹40,000 over budget.'), findsOneWidget);
    });

    testWidgets('a custom name becomes an API key', (tester) async {
      final o = await openNew(tester);
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '').first, 'Return gifts');
      await tester.enterText(find.widgetWithText(TextField, '').last, '20000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      expect((o.result as BudgetSaved).categoryKey, 'return_gifts');
    });

    testWidgets('editing prefills and can delete', (tester) async {
      final existing = wedding.budgetCategories.first; // venue, 450000
      final o = _Opener<BudgetSheetResult>();
      await o.open(
        tester,
        (c) => showBudgetCategorySheet(
          c,
          existing: existing,
          usedKeys: wedding.budgetCategories.map((b) => b.categoryKey),
          total: wedding.totalBudget,
          otherAllocated: 990000,
        ),
      );
      expect(find.text('Edit Venue'), findsOneWidget);
      expect(find.widgetWithText(TextField, '450000'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete this category'));
      await tester.tap(find.text('Delete this category'));
      await tester.pumpAndSettle();
      expect(o.result, isA<BudgetDeleted>());
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('fits 360x640 at text scale $scale', (tester) async {
        await _Opener<BudgetSheetResult>().open(
          tester,
          (c) => showBudgetCategorySheet(c, existing: wedding.budgetCategories.first, usedKeys: const [], total: 1500000, otherAllocated: 0),
          size: const Size(360, 640),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('EventFormView', () {
    Future<void> fillCreate(WidgetTester tester) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Meera & Karan');
      await tester.enterText(fields.at(1), 'Mumbai');
      await tester.enterText(fields.at(2), '120');
      await tester.enterText(fields.at(3), '12,00,000');
      await tester.pump();
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('creating: validates every field', (tester) async {
      await pumpScreen(tester, EventFormView(today: today, onSubmit: (_, _) async => null), size: const Size(400, 1400));
      expect(find.text('New event'), findsOneWidget);
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();
      for (final m in [
        'Give your event a name.',
        'Where is it happening?',
        'Choose the date.',
        'Enter the number of guests.',
        'Enter a budget greater than zero.',
      ]) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
    });

    testWidgets('creating: submits the values', (tester) async {
      EventFormValues? values;
      BudgetAdjustment? adjustment = BudgetAdjustment.keep;
      await pumpScreen(
        tester,
        EventFormView(
          today: today,
          onSubmit: (v, a) async {
            values = v;
            adjustment = a;
            return null;
          },
        ),
        size: const Size(400, 1400),
      );
      await tester.tap(find.text('Engagement'));
      await tester.tap(find.text('Premium'));
      await fillCreate(tester);
      expect(find.textContaining('about ₹10,000 per guest'), findsOneWidget);
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();
      expect(values!.type, EventType.engagementOnly);
      expect(values!.name, 'Meera & Karan');
      expect(values!.region, 'Mumbai');
      expect(values!.guests, 120);
      expect(values!.budget, 1200000);
      expect(values!.tier, BudgetTier.premium);
      expect(adjustment, isNull);
    });

    testWidgets('creating: shows the long-wait note and then the error', (tester) async {
      final completer = Completer<String?>();
      await pumpScreen(tester, EventFormView(today: today, onSubmit: (_, _) => completer.future), size: const Size(400, 1400));
      await fillCreate(tester);
      await tester.tap(find.text('Create event'));
      await tester.pump();
      expect(find.textContaining('This can take up to a minute'), findsOneWidget);
      completer.complete('Could not create the event. Please try again.');
      await tester.pumpAndSettle();
      expect(find.text('Could not create the event. Please try again.'), findsOneWidget);
      expect(find.textContaining('This can take up to a minute'), findsNothing);
    });

    testWidgets('editing: type and place are fixed; changing the budget asks how to adjust', (tester) async {
      EventFormValues? values;
      BudgetAdjustment? adjustment;
      await pumpScreen(
        tester,
        EventFormView(
          initial: mock.wedding,
          today: today,
          onSubmit: (v, a) async {
            values = v;
            adjustment = a;
            return null;
          },
        ),
        size: const Size(400, 1600),
      );
      expect(find.text('Edit event'), findsOneWidget);
      expect(find.text('Wedding · Pune'), findsOneWidget);
      expect(find.text('Rescale every category'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '18,00,000');
      await tester.pumpAndSettle();
      expect(find.text('Rescale every category'), findsOneWidget);
      await tester.tap(find.text('Keep categories as they are'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(values!.budget, 1800000);
      expect(adjustment, BudgetAdjustment.keep);
    });

    testWidgets('editing without a budget change passes no adjustment', (tester) async {
      BudgetAdjustment? adjustment = BudgetAdjustment.rescale;
      await pumpScreen(
        tester,
        EventFormView(initial: mock.wedding, today: today, onSubmit: (v, a) async {
          adjustment = a;
          return null;
        }),
        size: const Size(400, 1600),
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(adjustment, isNull);
    });

    for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
      testWidgets('fits $size at text scale $scale (create with errors, and edit)', (tester) async {
        await pumpScreen(tester, EventFormView(today: today, onSubmit: (_, _) async => 'Error'), size: size, textScale: scale);
        await tester.tap(find.text('Create event'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await pumpScreen(tester, EventFormView(initial: mock.wedding, today: today, onSubmit: (_, _) async => null), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ProfileSetupView', () {
    testWidgets('needs a name and a type', (tester) async {
      await pumpScreen(tester, ProfileSetupView(onSubmit: (_) async => null), size: const Size(400, 1200));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name.'), findsOneWidget);
      expect(find.text('Choose one to continue.'), findsOneWidget);
    });

    testWidgets('submits the profile', (tester) async {
      String? name;
      OrganizerType? type;
      await pumpScreen(
        tester,
        ProfileSetupView(onSubmit: (b) async {
          name = b.displayName;
          type = b.organizerType;
          return null;
        }),
        size: const Size(400, 1200),
      );
      await tester.enterText(find.byType(TextField), '  Priya Sharma ');
      await tester.tap(find.text('Family'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(name, 'Priya Sharma');
      expect(type, OrganizerType.family);
    });

    testWidgets('shows a server error', (tester) async {
      await pumpScreen(tester, ProfileSetupView(onSubmit: (_) async => 'Something went wrong.'), size: const Size(400, 1200));
      await tester.enterText(find.byType(TextField), 'Priya');
      await tester.tap(find.text('Individual'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong.'), findsOneWidget);
    });

    for (final (size, scale) in [(const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
      testWidgets('fits $size at text scale $scale', (tester) async {
        await pumpScreen(tester, ProfileSetupView(onSubmit: (_) async => 'Error'), size: size, textScale: scale);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
