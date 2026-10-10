import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/vendor/sheets/past_work_sheet.dart';
import 'package:sanchalan/features/vendor/vendor_profile_editor_view.dart';
import 'package:sanchalan/features/vendor/vendor_profile_logic.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/vendor.dart';
import 'package:sanchalan/models/vendor_labels.dart';
import 'package:sanchalan/shared/widgets/app_text_field.dart';

import '../../helpers/pump_screen.dart';

final mock = MockData(today: DateTime(2026, 10, 10));
final categoryKeys = vendorCategoryLabels.keys.toList();

class Calls {
  final saves = <VendorProfileForm>[];
  final submits = <VendorProfileForm>[];
  final pastWorkSaves = <(String, String?)>[];
  final pastWorkDeletes = <String>[];
  String? saveResult;
  Future<String?>? submitResult;
}

Widget editor(VendorMeResponse me, Calls calls, {VendorRequiredField? focus}) => VendorProfileEditorView(
      me: me,
      categoryKeys: categoryKeys,
      focusField: focus,
      onSave: (f) async {
        calls.saves.add(f);
        return calls.saveResult;
      },
      onSubmit: (f) {
        calls.submits.add(f);
        return calls.submitResult ?? Future.value(null);
      },
      onSavePastWork: (e, id) async {
        calls.pastWorkSaves.add((e.title, id));
        return null;
      },
      onDeletePastWork: (id) async {
        calls.pastWorkDeletes.add(id);
        return null;
      },
    );

/// The n-th text field inside the open past-work sheet (0 = title, 1 = details).
Finder sheetField(int i) =>
    find.descendant(of: find.byType(PastWorkSheet), matching: find.byType(TextField)).at(i);

Finder field(String label) =>
    find.descendant(of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

Future<void> type(WidgetTester tester, String label, String value) async {
  await tester.enterText(field(label), value);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

const _tall = Size(400, 3000);

VendorMeResponse withPastWork(VendorMeResponse base, int n) {
  final json = base.vendor.toJson()
    ..['portfolioItems'] = [
      for (var i = 0; i < n; i++)
        {
          'id': 'w$i',
          'vendorId': 'me',
          'title': 'Work $i',
          'mediaUrl': null,
          'caption': null,
          'displayOrder': i,
          'createdAt': mock.today.toIso8601String(),
        },
    ];
  final vendor = Vendor.fromJson(json);
  return VendorMeResponse(vendor: vendor, completeness: computeCompleteness(vendor));
}

void main() {
  group('layout by status', () {
    testWidgets('draft: sections, progress and both actions', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      expect(find.text('Your business profile'), findsOneWidget);
      expect(find.text('2 of 7 steps done'), findsOneWidget);
      for (final s in ['Business', 'What you offer', 'Where you work', 'About your business', 'Past work']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('Submit for review'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
      expect(find.text('Heads up'), findsNothing);
    });

    testWidgets('prefills what is saved', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      expect(tester.widget<TextField>(field('Business name')).controller!.text, 'Shubh Photos');
      expect(tester.widget<TextField>(field('Contact person')).controller!.text, 'Asha Kulkarni');
    });

    testWidgets('rejected: shows the reason above the form', (tester) async {
      await pumpScreen(tester, editor(mock.vendorRejected, Calls()), size: _tall);
      expect(find.text('Changes requested'), findsOneWidget);
      expect(find.textContaining('clearer description'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget);
    });

    testWidgets('published: heads-up note and a single Save changes button', (tester) async {
      await pumpScreen(tester, editor(mock.vendorPublished, Calls()), size: _tall);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Heads up'), findsOneWidget);
      expect(find.text('Submit for review'), findsNothing);
      expect(find.text('Save draft'), findsNothing);
      expect(find.text('No changes yet'), findsOneWidget);
    });
  });

  group('submitting', () {
    testWidgets('an empty profile shows every missing piece and does not submit', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorDraft, calls), size: _tall);
      await tapText(tester, 'Submit for review');
      expect(calls.submits, isEmpty);
      expect(find.text('Choose a price range.'), findsOneWidget);
      expect(find.text('Enter the area you serve.'), findsOneWidget);
      expect(find.textContaining('Write at least 30 characters'), findsOneWidget);
      expect(find.text('Choose at least one category.'), findsOneWidget);
      expect(find.text('Please fix the highlighted fields.'), findsOneWidget);
    });

    testWidgets('a filled form without past work is stopped with a clear message', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorDraft, calls), size: _tall);
      await tapText(tester, 'Premium');
      await tapText(tester, 'Photography');
      await type(tester, 'Service area', 'Pune');
      await type(tester, 'Description', 'Candid wedding photography across Pune and Mumbai.');
      await tapText(tester, 'Submit for review');
      expect(calls.submits, isEmpty);
      expect(find.text('Still needed: Past work.'), findsOneWidget);
    });

    testWidgets('a complete profile is submitted with what was typed', (tester) async {
      final calls = Calls();
      final me = withPastWork(mock.vendorDraft, 1);
      await pumpScreen(tester, editor(me, calls), size: _tall);
      await tapText(tester, 'Luxury');
      await tapText(tester, 'Décor');
      await type(tester, 'Service area', 'Mumbai');
      await type(tester, 'Description', 'Floral mandaps and complete venue styling for weddings.');
      await tapText(tester, 'Submit for review');
      final form = calls.submits.single;
      expect(form.priceTier, VendorPriceTier.luxury);
      expect(form.categoryKeys, ['decor']);
      expect(form.serviceArea, 'Mumbai');
      expect(form.businessName, 'Shubh Photos');
    });

    testWidgets('shows a spinner while submitting, then the server error', (tester) async {
      final completer = Completer<String?>();
      final calls = Calls()..submitResult = completer.future;
      await pumpScreen(tester, editor(withPastWork(mock.vendorRejected, 1), calls), size: _tall);
      final submit = find.text('Submit for review');
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete('Still needed: Price range.');
      await tester.pumpAndSettle();
      expect(find.text('Still needed: Price range.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('saving a draft', () {
    testWidgets('saves without requiring a complete profile and confirms', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorDraft, calls), size: _tall);
      await type(tester, 'Business name', 'Shubh Studios');
      await tapText(tester, 'Save draft');
      expect(calls.saves.single.businessName, 'Shubh Studios');
      expect(find.text('Draft saved.'), findsOneWidget);
      expect(calls.submits, isEmpty);
    });

    testWidgets('a format problem blocks saving; clearing it re-enables it', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorDraft, calls), size: _tall);
      await type(tester, 'Email', 'nope');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tapText(tester, 'Save draft');
      expect(calls.saves, isEmpty);
      expect(find.text('Please fix the highlighted fields.'), findsOneWidget);
      await type(tester, 'Email', 'asha@shubh.in');
      await tapText(tester, 'Save draft');
      expect(calls.saves, hasLength(1));
    });

    testWidgets('a server error is shown instead of the confirmation', (tester) async {
      final calls = Calls()..saveResult = 'Could not save your changes.';
      await pumpScreen(tester, editor(mock.vendorDraft, calls), size: _tall);
      await tapText(tester, 'Save draft');
      expect(find.text('Could not save your changes.'), findsOneWidget);
      expect(find.text('Draft saved.'), findsNothing);
    });
  });

  group('fields', () {
    testWidgets('optional formats are checked as you type', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      await type(tester, 'WhatsApp number', '98765');
      expect(find.textContaining('international format'), findsOneWidget);
      await type(tester, 'WhatsApp number', '+919876543210');
      expect(find.textContaining('international format'), findsNothing);
      await type(tester, 'Instagram', 'insta.com/x');
      expect(find.textContaining('http://'), findsOneWidget);
      await type(tester, 'Years of experience (optional)', '99');
      expect(find.text('Enter years between 0 and 80.'), findsOneWidget);
    });

    testWidgets('description counts down, then shows its length', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      await type(tester, 'Description', 'x' * 12);
      expect(find.text('18 more characters needed'), findsOneWidget);
      await type(tester, 'Description', 'x' * 45);
      expect(find.text('45/1000'), findsOneWidget);
      await type(tester, 'Description', 'x' * 1002);
      expect(find.textContaining('2 too many'), findsOneWidget);
    });

    testWidgets('at most five categories can be chosen', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      expect(find.text('0 of 5'), findsOneWidget);
      for (final c in ['Venue', 'Catering', 'Décor', 'Photography', 'Attire']) {
        await tapText(tester, c);
      }
      expect(find.text('5 of 5'), findsOneWidget);
      final sixth = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Transport'));
      expect(sixth.onSelected, isNull);
      // A chosen one can still be removed.
      await tapText(tester, 'Venue');
      expect(find.text('4 of 5'), findsOneWidget);
    });

    testWidgets('live progress follows what is typed', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      expect(find.text('2 of 7 steps done'), findsOneWidget);
      await tapText(tester, 'Premium');
      expect(find.text('3 of 7 steps done'), findsOneWidget);
      await type(tester, 'Service area', 'Pune');
      expect(find.text('4 of 7 steps done'), findsOneWidget);
    });
  });

  group('live profile', () {
    testWidgets('changing an unwatched field saves without a warning', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorPublished, calls), size: _tall);
      await type(tester, 'Years of experience (optional)', '9');
      expect(find.text('Save changes'), findsOneWidget);
      await tapText(tester, 'Save changes');
      expect(find.text('Send for review again?'), findsNothing);
      expect(calls.saves.single.years, '9');
    });

    testWidgets('changing a watched field asks first; cancel keeps everything', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorPublished, calls), size: _tall);
      await type(tester, 'Business name', 'Shubh Studios');
      await tapText(tester, 'Save changes');
      expect(find.text('Send for review again?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.saves, isEmpty);

      await tapText(tester, 'Save changes');
      await tester.tap(find.text('Save and send'));
      await tester.pumpAndSettle();
      expect(calls.saves.single.businessName, 'Shubh Studios');
    });

    testWidgets('changing categories also asks first', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorPublished, calls), size: _tall);
      await tapText(tester, 'Décor');
      await tapText(tester, 'Save changes');
      expect(find.text('Send for review again?'), findsOneWidget);
    });
  });

  group('past work', () {
    testWidgets('lists entries with a counter and an add button', (tester) async {
      await pumpScreen(tester, editor(withPastWork(mock.vendorDraft, 2), Calls()), size: _tall);
      expect(find.text('Work 0'), findsOneWidget);
      expect(find.text('Work 1'), findsOneWidget);
      expect(find.text('2 of 10'), findsOneWidget);
      expect(find.text('Add past work'), findsOneWidget);
    });

    testWidgets('empty list explains what to do', (tester) async {
      await pumpScreen(tester, editor(mock.vendorDraft, Calls()), size: _tall);
      expect(find.textContaining('Add at least one example'), findsOneWidget);
      expect(find.text('0 of 10'), findsOneWidget);
    });

    testWidgets('at ten entries adding is disabled', (tester) async {
      await pumpScreen(tester, editor(withPastWork(mock.vendorDraft, 10), Calls()), size: _tall);
      expect(find.text('Limit reached'), findsOneWidget);
      expect(find.text('Add past work'), findsNothing);
    });

    testWidgets('adding on a draft needs no confirmation', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorDraft, calls), size: _tall);
      await tapText(tester, 'Add past work');
      await tester.enterText(sheetField(0), 'Kulkarni wedding');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Send for review again?'), findsNothing);
      expect(calls.pastWorkSaves, [('Kulkarni wedding', null)]);
    });

    testWidgets('on a live profile adding asks first', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(mock.vendorPublished, calls), size: _tall);
      await tapText(tester, 'Add past work');
      await tester.enterText(sheetField(0), 'New work');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Send for review again?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.pastWorkSaves, isEmpty);
    });

    testWidgets('editing and deleting pass the entry id', (tester) async {
      final calls = Calls();
      await pumpScreen(tester, editor(withPastWork(mock.vendorDraft, 2), calls), size: _tall);
      await tapText(tester, 'Work 1');
      await tester.enterText(sheetField(0), 'Renamed');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(calls.pastWorkSaves.single, ('Renamed', 'w1'));

      await tapText(tester, 'Work 0');
      await tester.tap(find.text('Delete this entry'));
      await tester.pumpAndSettle();
      expect(calls.pastWorkDeletes, ['w0']);
    });
  });

  group('PastWorkSheet', () {
    testWidgets('needs a title and returns trimmed values', (tester) async {
      PastWorkResult? result;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (c) => ElevatedButton(onPressed: () async => result = await showPastWorkSheet(c), child: const Text('Open')),
          ),
        ),
        size: const Size(400, 900),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Give this work a title.'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(find.byType(TextField).first, '  Sharma wedding ');
      await tester.enterText(find.byType(TextField).last, '  Pune, 2025 ');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final saved = result as PastWorkSaved;
      expect(saved.title, 'Sharma wedding');
      expect(saved.caption, 'Pune, 2025');
    });

    testWidgets('an empty caption becomes null', (tester) async {
      PastWorkResult? result;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (c) => ElevatedButton(onPressed: () async => result = await showPastWorkSheet(c), child: const Text('Open')),
          ),
        ),
        size: const Size(400, 900),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Title');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect((result as PastWorkSaved).caption, isNull);
    });
  });

  group('focus and small screens', () {
    testWidgets('opening with a missing item scrolls to its section', (tester) async {
      await pumpScreen(
        tester,
        editor(mock.vendorDraft, Calls(), focus: VendorRequiredField.pastWork),
        size: const Size(360, 640),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, greaterThan(0));
    });

    final cases = {'draft': mock.vendorDraft, 'rejected': mock.vendorRejected, 'published': mock.vendorPublished};
    for (final entry in cases.entries) {
      for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
        testWidgets('${entry.key} fits $size at text scale $scale, with errors showing', (tester) async {
          await pumpScreen(tester, editor(entry.value, Calls()), size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          if (entry.key != 'published') {
            await tester.tap(find.text('Submit for review'));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  });
}
