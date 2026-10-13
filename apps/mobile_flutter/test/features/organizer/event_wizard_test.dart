import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/organizer/event_wizard_view.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/features/organizer/event_draft.dart';
import 'package:sanchalan/models/event_profile.dart';

Map<String, dynamic> _q(String key, String label, String kind,
        {String? mapsTo, bool required = false, List<List<String>>? options, Map<String, String>? showIf}) =>
    {
      'key': key,
      'label': label,
      'kind': kind,
      'required': required,
      'mapsTo': ?mapsTo,
      'showIf': ?showIf,
      if (options != null) 'options': [for (final o in options) {'value': o[0], 'label': o[1]}],
    };

final _profiles = [
  EventTypeProfile.fromJson({
    'eventType': 'birthday',
    'version': 1,
    'steps': [
      {
        'id': 'basics',
        'title': 'Let us start',
        'questions': [_q('name', 'Party name', 'text', mapsTo: 'name', required: true)],
      },
      {
        'id': 'style',
        'title': 'The fun part',
        'questions': [
          _q('region', 'City', 'text', mapsTo: 'region', required: true),
          _q('theme', 'Theme', 'text'),
          _q('food', 'Food', 'single_select', options: [
            ['veg', 'Vegetarian'],
            ['both', 'Both'],
          ]),
          _q('guestNote', 'Veg guests', 'text', showIf: {'key': 'food', 'equals': 'veg'}),
        ],
      },
      {
        'id': 'budget',
        'title': 'Numbers',
        'questions': [
          _q('guestCountEstimate', 'Guests', 'number', mapsTo: 'guestCountEstimate', required: true),
          _q('totalBudget', 'Budget', 'budget', mapsTo: 'totalBudget', required: true),
          _q('budgetTier', 'Style', 'single_select',
              mapsTo: 'budgetTier', required: true, options: [
                ['standard', 'Standard'],
              ]),
          _q('primaryDate', 'Date', 'date', mapsTo: 'primaryDate', required: true),
        ],
      },
    ],
  }),
];

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  customTests();
  testWidgets('walks the steps, asks only the type questions, and submits the split result', (t) async {
    WizardResult? got;
    await t.pumpWidget(MaterialApp(
      home: EventWizardView(
        profiles: _profiles,
        today: DateTime(2026, 10, 13),
        onSubmit: (r) async {
          got = r;
          return null;
        },
      ),
    ));

    // Next is disabled until a type is chosen; wedding has no profile here, so it uses none.
    await _tap(t, find.text('Birthday'));
    await _tap(t, find.text('Next'));

    // Required name blocks the step.
    await _tap(t, find.text('Next'));
    expect(find.text('This one is needed.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Aarav turns 5');
    await _tap(t, find.text('Next'));

    // showIf: the follow-up appears only after choosing Vegetarian.
    expect(find.text('Veg guests'), findsNothing);
    await _tap(t, find.text('Vegetarian'));
    expect(find.text('Veg guests'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'Pune');
    await t.enterText(find.byType(TextField).at(1), 'Dinosaurs');
    await _tap(t, find.text('Next'));

    await t.enterText(find.byType(TextField).at(0), '40');
    await t.enterText(find.byType(TextField).at(1), '50,000');
    await _tap(t, find.text('Standard'));
    await _tap(t, find.text('Choose a date'));
    await _tap(t, find.text('OK'));
    await _tap(t, find.text('Create event'));

    expect(got, isNotNull);
    expect(got!.type, EventType.birthday);
    expect(got!.name, 'Aarav turns 5');
    expect(got!.region, 'Pune');
    expect(got!.guests, 40);
    expect(got!.budget, 50000);
    expect(got!.tier, BudgetTier.standard);
    // Only type-specific answers go into details, not the core fields.
    expect(got!.details, {'theme': 'Dinosaurs', 'food': 'veg'});
  });
}

// --- custom events: the server writes the questions ---

EventTypeProfile _custom(List<Map<String, dynamic>> middle) => EventTypeProfile.fromJson({
      'eventType': 'custom',
      'version': 1,
      'steps': [
        {
          'id': 'basics',
          'title': 'Basics',
          'questions': [_q('name', 'Event name', 'text', mapsTo: 'name', required: true)],
        },
        ...middle,
      ],
    });

void customTests() {
  final generic = _custom([]);
  final written = _custom([
    {
      'id': 'gen1',
      'title': 'About the crowd',
      'questions': [_q('chiefGuest', 'Who is the chief guest?', 'text')],
    },
  ]);

  Widget app({
    required Future<GeneratedProfile> Function(String) onGenerate,
    List<String>? calls,
    WizardDraft? draft,
  }) =>
      MaterialApp(
        home: EventWizardView(
          profiles: [generic],
          draft: draft,
          onGenerate: (d) {
            calls?.add(d);
            return onGenerate(d);
          },
          onSubmit: (_) async => null,
        ),
      );

  testWidgets('custom: describe, then the written questions replace the basic ones', (t) async {
    final calls = <String>[];
    await t.pumpWidget(app(
      calls: calls,
      onGenerate: (_) async => GeneratedProfile(profileId: 'p1', profile: written),
    ));
    await _tap(t, find.text('Custom'));
    await _tap(t, find.text('Next'));

    // The describe step needs a few words before it moves on.
    expect(find.text('Tell us about your event'), findsOneWidget);
    await _tap(t, find.text('Next'));
    expect(calls, isEmpty);
    await t.enterText(find.byType(TextField), 'A college tech fest');
    await _tap(t, find.text('Next'));
    expect(calls, ['A college tech fest']);

    // Basics step, then the written step.
    await t.enterText(find.byType(TextField), 'TechFest');
    await _tap(t, find.text('Next'));
    expect(find.text('Who is the chief guest?'), findsOneWidget);

    // Going back and continuing without edits does not call the server again.
    await _tap(t, find.byTooltip('Back'));
    await _tap(t, find.byTooltip('Back'));
    await _tap(t, find.text('Next'));
    expect(calls, hasLength(1));
  });

  testWidgets('custom: a failure keeps the user on the describe step; skip uses the basic questions', (t) async {
    await t.pumpWidget(app(onGenerate: (_) async => throw Exception('offline')));
    await _tap(t, find.text('Custom'));
    await _tap(t, find.text('Next'));
    await t.enterText(find.byType(TextField), 'A college tech fest');
    await _tap(t, find.text('Next'));
    expect(find.textContaining('Could not prepare your questions'), findsOneWidget);
    expect(find.text('Tell us about your event'), findsOneWidget);

    await _tap(t, find.text('Skip, use basic questions'));
    expect(find.text('Basics'), findsOneWidget);
  });
}
