import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/vendor_labels.dart';

// --- money and dates ---

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Rupees with Indian digit grouping, e.g. `₹12,50,000`.
String formatInr(num amount) => _inr.format(amount);

/// Short form for tight spaces: `₹15 L`, `₹1.5 Cr`, `₹50K`, `₹800`.
String formatInrCompact(num amount) {
  final sign = amount < 0 ? '-' : '';
  final v = amount.abs();
  String trim(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
  if (v >= 10000000) return '$sign₹${trim(v / 10000000)} Cr';
  if (v >= 100000) return '$sign₹${trim(v / 100000)} L';
  if (v >= 1000) return '$sign₹${trim(v / 1000)}K';
  return '$sign₹${v.round()}';
}

/// `14 Feb 2027`.
String formatDate(DateTime d) => DateFormat('d MMM y').format(d);

/// `14 Feb`.
String formatDayMonth(DateTime d) => DateFormat('d MMM').format(d);

/// `Sun, 14 Feb 2027`.
String formatLongDate(DateTime d) => DateFormat('EEE, d MMM y').format(d);

DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Whole calendar days from [today] to [date]; negative when [date] is past.
int daysUntil(DateTime date, {DateTime? today}) =>
    dateOnly(date).difference(dateOnly(today ?? DateTime.now())).inDays;

/// For event cards: `Today`, `Tomorrow`, `In 12 days`, `Past event`.
String whenLabel(DateTime date, {DateTime? today}) {
  final days = daysUntil(date, today: today);
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 1) return 'In $days days';
  return 'Past event';
}

/// For the home hero: `48 days to go`, `Tomorrow`, `Today`, `Completed`.
String daysToGoLabel(DateTime date, {DateTime? today}) {
  final days = daysUntil(date, today: today);
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 1) return '$days days to go';
  return 'Completed';
}

/// Due-date label for a task: `Due 14 Feb`, `Due today`, `Overdue by 3 days`.
String dueLabel(DateTime? due, {DateTime? today}) {
  if (due == null) return 'No due date';
  final days = daysUntil(due, today: today);
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days > 1) return 'Due ${formatDayMonth(due)}';
  final late = -days;
  return 'Overdue by $late ${late == 1 ? 'day' : 'days'}';
}

// --- labels ---

String eventTypeLabel(EventType t) => switch (t) {
      EventType.wedding => 'Wedding',
      EventType.birthday => 'Birthday',
      EventType.corporate => 'Corporate',
      EventType.religious => 'Religious',
      EventType.engagementOnly => 'Engagement',
      EventType.custom => 'Custom',
    };

String budgetTierLabel(BudgetTier t) => switch (t) {
      BudgetTier.essential => 'Essential',
      BudgetTier.standard => 'Standard',
      BudgetTier.premium => 'Premium',
      BudgetTier.luxury => 'Luxury',
    };

String organizerTypeLabel(OrganizerType t) => switch (t) {
      OrganizerType.individual => 'Individual',
      OrganizerType.family => 'Family',
      OrganizerType.company => 'Company',
      OrganizerType.committee => 'Committee',
    };

const _categoryLabelOverrides = <String, String>{
  'guest_logistics': 'Guest logistics',
  'legal_documentation': 'Legal & documents',
};

/// Display name of a task or budget category key. Vendor categories and task
/// categories share most keys, so the vendor labels are reused.
String categoryLabel(String key) {
  final known = _categoryLabelOverrides[key] ?? vendorCategoryLabels[key];
  if (known != null) return known;
  return vendorCategoryLabel(key);
}

String taskStatusLabel(TaskStatus s) => switch (s) {
      TaskStatus.notStarted => 'Not started',
      TaskStatus.inProgress => 'In progress',
      TaskStatus.done => 'Done',
      TaskStatus.overdue => 'Overdue',
      TaskStatus.notApplicable => 'Removed',
    };

/// `1 task` / `3 tasks`.
String plural(int n, String singular, [String? pluralForm]) =>
    '$n ${n == 1 ? singular : (pluralForm ?? '${singular}s')}';
