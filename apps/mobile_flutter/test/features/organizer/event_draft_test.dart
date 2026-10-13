import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/organizer/event_draft.dart';
import 'package:sanchalan/features/organizer/event_wizard_view.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/event_profile.dart';

final _profile = EventTypeProfile.fromJson({
  'eventType': 'birthday',
  'version': 1,
  'steps': [
    {
      'id': 'a',
      'title': 'Step A',
      'questions': [
        {'key': 'name', 'label': 'Party name', 'kind': 'text', 'mapsTo': 'name', 'required': true},
      ],
    },
    {
      'id': 'b',
      'title': 'Step B',
      'questions': [
        {'key': 'theme', 'label': 'Theme', 'kind': 'text'},
      ],
    },
  ],
});

void main() {
  group('WizardDraft', () {
    final now = DateTime(2026, 10, 13, 10);
    final draft = WizardDraft(
      type: EventType.engagementOnly,
      step: 2,
      answers: {
        'name': 'A & B',
        'guestCountEstimate': 120,
        'totalBudget': 500000.0,
        'primaryDate': DateTime(2027, 2, 14),
        'subEventsWanted': ['haldi', 'sangeet'],
      },
      savedAt: now,
    );

    test('round-trips every answer type', () {
      final back = WizardDraft.decode(draft.encode(), now: now)!;
      expect(back.type, EventType.engagementOnly);
      expect(back.step, 2);
      expect(back.answers['guestCountEstimate'], 120);
      expect(back.answers['totalBudget'], 500000.0);
      expect(back.answers['primaryDate'], DateTime(2027, 2, 14));
      expect((back.answers['subEventsWanted'] as List).cast<String>(), ['haldi', 'sangeet']);
    });

    test('drops a stale or unreadable draft', () {
      expect(WizardDraft.decode(draft.encode(), now: now.add(const Duration(days: 8))), isNull);
      expect(WizardDraft.decode('not json', now: now), isNull);
      expect(WizardDraft.decode(null), isNull);
    });
  });

  test('a profile survives the cache round trip', () {
    final back = EventTypeProfile.fromJson(_profile.toJson());
    expect(back.steps.map((s) => s.id), ['a', 'b']);
    expect(back.steps.first.questions.single.required, isTrue);
    expect(back.steps.first.questions.single.mapsTo, 'name');
  });

  testWidgets('the wizard resumes from a draft and reports changes', (t) async {
    final saved = <WizardDraft?>[];
    await t.pumpWidget(MaterialApp(
      home: EventWizardView(
        profiles: [_profile],
        draft: WizardDraft(
          type: EventType.birthday,
          step: 2,
          answers: {'name': 'Aarav'},
          savedAt: DateTime.now(),
        ),
        onDraftChanged: saved.add,
        onSubmit: (_) async => null,
      ),
    ));
    expect(find.text('Step B'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Dinosaurs');
    expect(saved.last!.answers['theme'], 'Dinosaurs');
    expect(saved.last!.answers['name'], 'Aarav');
  });
}
