// The event-creation flow for one event type, served by GET /event-types
// (see apps/backend/src/config/event-type-profiles.ts). Hand-written, no codegen.

enum QuestionKind { singleSelect, multiSelect, chips, text, number, date, budget }

const _kindWire = {
  QuestionKind.singleSelect: 'single_select',
  QuestionKind.multiSelect: 'multi_select',
  QuestionKind.chips: 'chips',
  QuestionKind.text: 'text',
  QuestionKind.number: 'number',
  QuestionKind.date: 'date',
  QuestionKind.budget: 'budget',
};

QuestionKind _kind(String wire) => switch (wire) {
      'single_select' => QuestionKind.singleSelect,
      'multi_select' => QuestionKind.multiSelect,
      'chips' => QuestionKind.chips,
      'number' => QuestionKind.number,
      'date' => QuestionKind.date,
      'budget' => QuestionKind.budget,
      _ => QuestionKind.text,
    };

class QuestionOption {
  const QuestionOption({required this.value, required this.label});
  factory QuestionOption.fromJson(Map<String, dynamic> j) =>
      QuestionOption(value: j['value'] as String, label: j['label'] as String);
  final String value;
  final String label;
  Map<String, dynamic> toJson() => {'value': value, 'label': label};
}

class Question {
  const Question({
    required this.key,
    required this.label,
    required this.kind,
    this.options = const [],
    this.allowOther = false,
    this.required = false,
    this.showIfKey,
    this.showIfEquals,
    this.mapsTo,
  });

  factory Question.fromJson(Map<String, dynamic> j) {
    final showIf = j['showIf'] as Map<String, dynamic>?;
    return Question(
      key: j['key'] as String,
      label: j['label'] as String,
      kind: _kind(j['kind'] as String),
      options: ((j['options'] as List?) ?? const [])
          .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      allowOther: j['allowOther'] as bool? ?? false,
      required: j['required'] as bool? ?? false,
      showIfKey: showIf?['key'] as String?,
      showIfEquals: showIf?['equals'] as String?,
      mapsTo: j['mapsTo'] as String?,
    );
  }

  final String key;
  final String label;
  final QuestionKind kind;
  final List<QuestionOption> options;
  final bool allowOther;
  final bool required;
  final String? showIfKey;
  final String? showIfEquals;

  /// Top-level event field this answer fills (`name`, `region`, ...). Null means it goes in `details`.
  final String? mapsTo;

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'kind': _kindWire[kind],
        'options': options.map((o) => o.toJson()).toList(),
        'allowOther': allowOther,
        'required': required,
        if (showIfKey != null) 'showIf': {'key': showIfKey, 'equals': showIfEquals},
        'mapsTo': ?mapsTo,
      };

  bool visibleFor(Map<String, Object?> answers) => showIfKey == null || answers[showIfKey] == showIfEquals;
}

class WizardStep {
  const WizardStep({required this.id, required this.title, this.subtitle, required this.questions});
  factory WizardStep.fromJson(Map<String, dynamic> j) => WizardStep(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        questions: (j['questions'] as List).map((q) => Question.fromJson(q as Map<String, dynamic>)).toList(),
      );
  final String id;
  final String title;
  final String? subtitle;
  final List<Question> questions;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': ?subtitle,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class EventTypeProfile {
  const EventTypeProfile({required this.eventType, required this.version, required this.steps});
  factory EventTypeProfile.fromJson(Map<String, dynamic> j) => EventTypeProfile(
        eventType: j['eventType'] as String,
        version: j['version'] as int,
        steps: (j['steps'] as List).map((s) => WizardStep.fromJson(s as Map<String, dynamic>)).toList(),
      );
  final String eventType;
  final int version;
  final List<WizardStep> steps;
  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'version': version,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

/// The result of asking the server to write questions for an unknown event type.
/// [profileId] is null when the server fell back to the generic questions.
class GeneratedProfile {
  const GeneratedProfile({required this.profileId, required this.profile});
  factory GeneratedProfile.fromJson(Map<String, dynamic> j) => GeneratedProfile(
        profileId: j['profileId'] as String?,
        profile: EventTypeProfile.fromJson(j['profile'] as Map<String, dynamic>),
      );
  final String? profileId;
  final EventTypeProfile profile;
  Map<String, dynamic> toJson() => {'profileId': profileId, 'profile': profile.toJson()};
}
