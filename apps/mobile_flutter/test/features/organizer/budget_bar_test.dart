import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/theme/app_colors.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/event_stats.dart';
import 'package:sanchalan/features/organizer/widgets/budget_widgets.dart';

import '../../helpers/pump_screen.dart';

final mock = MockData(today: DateTime(2026, 10, 10));

/// The colored segments of a BudgetBar (not the track behind them).
List<Size> segmentSizes(WidgetTester tester) => [
      for (final box in find
          .descendant(of: find.byType(BudgetBar), matching: find.byType(DecoratedBox))
          .evaluate())
        if (((box.widget as DecoratedBox).decoration as BoxDecoration).border != null) tester.getSize(find.byWidget(box.widget)),
    ];

void main() {
  testWidgets('segments are drawn with a real height and add up to the allocated share', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: BudgetBar(summary: budgetSummary(mock.wedding)))),
      size: const Size(400, 200),
    );
    final sizes = segmentSizes(tester);
    expect(sizes, hasLength(5)); // four biggest categories plus "Other"
    for (final s in sizes) {
      expect(s.height, 14, reason: 'a segment collapsed to zero height');
      expect(s.width, greaterThan(0));
    }
    // 96% of a 360 dp track is allocated.
    expect(sizes.fold<double>(0, (t, s) => t + s.width), closeTo(360 * 0.96, 1.5));
  });

  testWidgets('an over-allocated budget is scaled to fit the track', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: BudgetBar(summary: budgetSummary(mock.birthday)))),
      size: const Size(400, 200),
    );
    final total = segmentSizes(tester).fold<double>(0, (t, s) => t + s.width);
    expect(total, lessThanOrEqualTo(360.5));
    expect(total, greaterThan(350));
  });

  test('the first segment color is the primary color', () {
    expect(shareColor(0), AppColors.primary);
    expect(shareColor(99), AppColors.outlineStrong);
  });
}
