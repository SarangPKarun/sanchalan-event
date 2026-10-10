import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/theme/app_colors.dart';
import 'package:sanchalan/dev/dev_menu.dart';
import 'package:sanchalan/dev/gallery_screen.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/shared/widgets/app_card.dart';
import 'package:sanchalan/shared/widgets/app_text_field.dart';
import 'package:sanchalan/shared/widgets/brand_mark.dart';
import 'package:sanchalan/shared/widgets/empty_state.dart';
import 'package:sanchalan/shared/widgets/error_retry.dart';
import 'package:sanchalan/shared/widgets/primary_button.dart';
import 'package:sanchalan/shared/widgets/progress_ring.dart';
import 'package:sanchalan/shared/widgets/section_header.dart';
import 'package:sanchalan/shared/widgets/skeleton.dart';
import 'package:sanchalan/shared/widgets/status_chip.dart';

import '../helpers/pump_screen.dart';

Widget scaffold(Widget child) => Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child));

void main() {
  group('buttons', () {
    testWidgets('PrimaryButton calls onPressed and is at least 48 dp tall', (tester) async {
      var taps = 0;
      await pumpScreen(tester, scaffold(PrimaryButton(label: 'Continue', onPressed: () => taps++)));
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('PrimaryButton ignores taps and hides the label while loading', (tester) async {
      var taps = 0;
      await pumpScreen(
        tester,
        scaffold(PrimaryButton(label: 'Continue', loading: true, onPressed: () => taps++)),
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });

    testWidgets('PrimaryButton is disabled without a callback', (tester) async {
      await pumpScreen(tester, scaffold(const PrimaryButton(label: 'Continue', onPressed: null)));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('SecondaryButton calls onPressed with an icon', (tester) async {
      var taps = 0;
      await pumpScreen(
        tester,
        scaffold(SecondaryButton(label: 'Back', icon: Icons.arrow_back, onPressed: () => taps++)),
      );
      await tester.tap(find.text('Back'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('a long label wraps instead of overflowing at 1.3x text', (tester) async {
      await pumpScreen(
        tester,
        scaffold(PrimaryButton(
          label: 'Generate my wedding roadmap with the planner',
          onPressed: () {},
        )),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusChip', () {
    testWidgets('names every task and vendor status', (tester) async {
      await pumpScreen(
        tester,
        scaffold(Wrap(children: [
          for (final s in TaskStatus.values) StatusChip.task(s),
          for (final s in VendorStatus.values) StatusChip.vendor(s),
        ])),
        size: const Size(800, 600),
      );
      for (final label in [
        'Not started', 'In progress', 'Done', 'Overdue', 'Removed',
        'Draft', 'In review', 'Live', 'Needs changes', 'Suspended',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('uses the tone colors', (tester) async {
      await pumpScreen(tester, scaffold(const StatusChip(label: 'Ok', tone: StatusTone.success)));
      final box = tester.widget<Container>(find.descendant(
        of: find.byType(StatusChip),
        matching: find.byType(Container),
      ));
      expect((box.decoration! as BoxDecoration).color, AppColors.successBg);
    });
  });

  testWidgets('AppCard is tappable and exposes its label', (tester) async {
    var taps = 0;
    await pumpScreen(
      tester,
      scaffold(AppCard(onTap: () => taps++, semanticLabel: 'Open event', child: const Text('Event'))),
    );
    await tester.tap(find.text('Event'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Open event'), findsOneWidget);
  });

  testWidgets('SectionHeader shows the action only when given', (tester) async {
    var taps = 0;
    await pumpScreen(
      tester,
      scaffold(Column(children: [
        const SectionHeader('Tasks'),
        SectionHeader('Budget', actionLabel: 'Edit', onAction: () => taps++),
      ])),
    );
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    expect(taps, 1);
  });

  testWidgets('EmptyState shows title, message and a working action', (tester) async {
    var taps = 0;
    await pumpScreen(
      tester,
      EmptyState(
        icon: Icons.celebration_outlined,
        title: 'Plan your first event',
        message: 'Start here.',
        actionLabel: 'Create event',
        onAction: () => taps++,
      ),
    );
    expect(find.text('Plan your first event'), findsOneWidget);
    expect(find.text('Start here.'), findsOneWidget);
    await tester.tap(find.text('Create event'));
    expect(taps, 1);
  });

  testWidgets('ErrorRetry calls onRetry', (tester) async {
    var taps = 0;
    await pumpScreen(tester, Scaffold(body: ErrorRetry(onRetry: () => taps++)));
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });

  group('ProgressRing', () {
    testWidgets('announces its percentage and clamps out-of-range values', (tester) async {
      await pumpScreen(
        tester,
        scaffold(const Column(children: [ProgressRing(value: 0.62), ProgressRing(value: 4)])),
      );
      expect(find.bySemanticsLabel('62 percent complete'), findsOneWidget);
      expect(find.bySemanticsLabel('100 percent complete'), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('shows its label above the field, an error and passes text through', (tester) async {
      String? changed;
      await pumpScreen(
        tester,
        scaffold(AppTextField(label: 'Event name', errorText: 'Required', onChanged: (v) => changed = v)),
      );
      expect(find.text('Event name'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Priya');
      expect(changed, 'Priya');
    });
  });

  testWidgets('Skeleton renders and is announced as loading', (tester) async {
    await pumpScreen(tester, scaffold(const Skeleton(height: 20, width: 120)));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('BrandMark is announced as Sanchalan, with and without wordmark', (tester) async {
    await pumpScreen(
      tester,
      scaffold(const Column(children: [BrandMark(size: 40), BrandMark(wordmark: true)])),
    );
    expect(find.bySemanticsLabel('Sanchalan'), findsNWidgets(2));
    expect(find.text('Sanchalan'), findsOneWidget); // the wordmark text
  });

  group('debug previews fit small screens', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('gallery at 360x640, text scale $scale', (tester) async {
        await pumpScreen(tester, const GalleryScreen(), textScale: scale);
        await tester.drag(find.byType(ListView), const Offset(0, -20000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('dev menu at 360x640, text scale $scale', (tester) async {
        await pumpScreen(tester, const DevMenuScreen(), textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
