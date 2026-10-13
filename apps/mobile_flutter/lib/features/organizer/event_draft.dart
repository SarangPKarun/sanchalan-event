import 'dart:convert';

import '../../models/enums.dart';

/// A half-finished event, so closing the app mid-wizard does not lose the answers.
class WizardDraft {
  const WizardDraft({
    required this.type,
    required this.step,
    required this.answers,
    required this.savedAt,
    this.description,
    this.generated,
  });

  static const storageKey = 'event_wizard_draft_v1';
  static const maxAge = Duration(days: 7);

  final EventType? type;
  final int step;
  final Map<String, Object?> answers;
  final DateTime savedAt;

  /// Custom events: what the user typed, and the questions the server wrote for it
  /// (a [GeneratedProfile] as JSON), so resuming does not repeat the LLM call.
  final String? description;
  final Map<String, dynamic>? generated;

  String encode() => jsonEncode({
        'type': type == null ? null : enumWireValue(type!),
        'step': step,
        'savedAt': savedAt.toIso8601String(),
        'description': description,
        'generated': generated,
        'answers': {
          for (final e in answers.entries)
            e.key: e.value is DateTime ? {'date': (e.value as DateTime).toIso8601String()} : e.value,
        },
      });

  /// Null when the text is not a usable draft or is older than [maxAge].
  static WizardDraft? decode(String? source, {DateTime? now}) {
    if (source == null) return null;
    try {
      final j = jsonDecode(source) as Map<String, dynamic>;
      final savedAt = DateTime.parse(j['savedAt'] as String);
      if ((now ?? DateTime.now()).difference(savedAt) > maxAge) return null;
      final wire = j['type'] as String?;
      final answers = <String, Object?>{};
      for (final e in (j['answers'] as Map<String, dynamic>).entries) {
        final v = e.value;
        answers[e.key] = v is Map ? DateTime.parse(v['date'] as String) : v;
      }
      return WizardDraft(
        type: wire == null ? null : EventType.values.firstWhere((t) => enumWireValue(t) == wire),
        step: j['step'] as int,
        answers: answers,
        savedAt: savedAt,
        description: j['description'] as String?,
        generated: j['generated'] as Map<String, dynamic>?,
      );
    } catch (_) {
      return null;
    }
  }
}
