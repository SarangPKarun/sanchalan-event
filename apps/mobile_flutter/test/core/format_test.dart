import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/format.dart';
import 'package:sanchalan/models/enums.dart';

void main() {
  final today = DateTime(2026, 10, 10, 18, 30); // time of day must not matter

  group('money', () {
    test('formatInr uses Indian grouping', () {
      expect(formatInr(1250000), '₹12,50,000');
      expect(formatInr(100000), '₹1,00,000');
      expect(formatInr(999), '₹999');
      expect(formatInr(0), '₹0');
      expect(formatInr(1500000.4), '₹15,00,000');
    });

    test('formatInrCompact', () {
      expect(formatInrCompact(800), '₹800');
      expect(formatInrCompact(50000), '₹50K');
      expect(formatInrCompact(1500), '₹1.5K');
      expect(formatInrCompact(100000), '₹1 L');
      expect(formatInrCompact(1500000), '₹15 L');
      expect(formatInrCompact(10000000), '₹1 Cr');
      expect(formatInrCompact(15000000), '₹1.5 Cr');
      expect(formatInrCompact(-60000), '-₹60K');
    });
  });

  group('dates', () {
    test('formatting', () {
      expect(formatDate(DateTime(2027, 2, 14)), '14 Feb 2027');
      expect(formatDayMonth(DateTime(2027, 2, 4)), '4 Feb');
      expect(formatLongDate(DateTime(2027, 2, 14)), 'Sun, 14 Feb 2027');
    });

    test('daysUntil counts calendar days and ignores the time of day', () {
      expect(daysUntil(DateTime(2026, 10, 10), today: today), 0);
      expect(daysUntil(DateTime(2026, 10, 11), today: today), 1);
      expect(daysUntil(DateTime(2026, 12, 1), today: today), 52);
      expect(daysUntil(DateTime(2026, 10, 7), today: today), -3);
      expect(daysUntil(DateTime(2026, 10, 10, 23, 59), today: DateTime(2026, 10, 10, 0, 1)), 0);
    });

    test('whenLabel for event cards', () {
      expect(whenLabel(DateTime(2026, 10, 10), today: today), 'Today');
      expect(whenLabel(DateTime(2026, 10, 11), today: today), 'Tomorrow');
      expect(whenLabel(DateTime(2026, 10, 25), today: today), 'In 15 days');
      expect(whenLabel(DateTime(2026, 10, 9), today: today), 'Past event');
    });

    test('daysToGoLabel for the hero card', () {
      expect(daysToGoLabel(DateTime(2026, 12, 1), today: today), '52 days to go');
      expect(daysToGoLabel(DateTime(2026, 10, 11), today: today), 'Tomorrow');
      expect(daysToGoLabel(DateTime(2026, 10, 10), today: today), 'Today');
      expect(daysToGoLabel(DateTime(2026, 9, 1), today: today), 'Completed');
    });

    test('dueLabel', () {
      expect(dueLabel(null, today: today), 'No due date');
      expect(dueLabel(DateTime(2026, 10, 10), today: today), 'Due today');
      expect(dueLabel(DateTime(2026, 10, 11), today: today), 'Due tomorrow');
      expect(dueLabel(DateTime(2026, 10, 20), today: today), 'Due 20 Oct');
      expect(dueLabel(DateTime(2026, 10, 9), today: today), 'Overdue by 1 day');
      expect(dueLabel(DateTime(2026, 10, 5), today: today), 'Overdue by 5 days');
    });
  });

  group('labels', () {
    test('every enum value has a label', () {
      for (final t in EventType.values) {
        expect(eventTypeLabel(t), isNotEmpty);
      }
      for (final t in BudgetTier.values) {
        expect(budgetTierLabel(t), isNotEmpty);
      }
      for (final t in OrganizerType.values) {
        expect(organizerTypeLabel(t), isNotEmpty);
      }
      for (final t in TaskStatus.values) {
        expect(taskStatusLabel(t), isNotEmpty);
      }
      expect(eventTypeLabel(EventType.engagementOnly), 'Engagement');
    });

    test('categoryLabel covers every seeded task category with a readable name', () {
      const seeded = [
        'venue', 'guest_logistics', 'catering', 'photography', 'decor', 'invitations',
        'priest_officiant', 'transport', 'attire', 'music_entertainment',
        'legal_documentation', 'misc',
      ];
      for (final k in seeded) {
        final label = categoryLabel(k);
        expect(label, isNot(contains('_')), reason: k);
        expect(label[0], label[0].toUpperCase(), reason: k);
      }
      expect(categoryLabel('legal_documentation'), 'Legal & documents');
      expect(categoryLabel('music_entertainment'), 'Music & Entertainment');
      expect(categoryLabel('something_new'), 'Something new');
    });

    test('plural', () {
      expect(plural(1, 'task'), '1 task');
      expect(plural(3, 'task'), '3 tasks');
      expect(plural(0, 'guest'), '0 guests');
      expect(plural(2, 'category', 'categories'), '2 categories');
    });
  });
}
