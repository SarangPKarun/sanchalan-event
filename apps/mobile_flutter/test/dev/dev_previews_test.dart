import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sanchalan/core/theme/app_theme.dart';
import 'package:sanchalan/dev/dev_routes.dart';
import 'package:sanchalan/dev/dev_scenario.dart';
import 'package:sanchalan/dev/dev_vendor.dart';
import 'package:sanchalan/dev/mock_data.dart';

/// Opens the debug previews at [location] in a real router, like the app does.
Future<GoRouter> openPreview(WidgetTester tester, String location, {Size size = const Size(400, 1800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: location, routes: devRoutes());
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: buildAppTheme(), routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

/// Picks a scenario from the debug bar. Uses fixed pumps because the Loading
/// scenario animates forever, so pumpAndSettle would never return.
Future<void> pickScenario(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Data scenario'));
  await tester.pump(); // builds the menu route
  await tester.pump(const Duration(milliseconds: 500)); // finishes its opening animation
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    devScenario.value = DevScenario.normal;
    devVendorScenario.value = DevVendorScenario.draft;
    devVendorMe.value = MockData().vendorDraft;
  });

  group('vendor app preview', () {
    testWidgets('each scenario shows its dashboard', (tester) async {
      await openPreview(tester, '/dev/v/home');
      expect(find.text('Finish your profile'), findsOneWidget);

      await pickScenario(tester, 'Rejected');
      expect(find.text('Changes requested'), findsOneWidget);
      await pickScenario(tester, 'Under review');
      expect(find.text('Your profile is under review'), findsOneWidget);
      await pickScenario(tester, 'Live');
      expect(find.text("You're live"), findsOneWidget);
      await pickScenario(tester, 'Suspended');
      expect(find.text('Your listing is paused'), findsOneWidget);
      await pickScenario(tester, 'Error');
      expect(find.text('Retry'), findsOneWidget);
      await pickScenario(tester, 'Loading');
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('withdrawing an application returns the vendor to a draft', (tester) async {
      await openPreview(tester, '/dev/v/home');
      await pickScenario(tester, 'Under review');
      await tester.tap(find.text('Withdraw to edit'));
      await tester.pump();
      expect(find.text('Withdrawing...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Finish your profile'), findsNothing); // complete profile, so "complete" card
      expect(find.text('Your profile is complete'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('an incomplete profile is refused, a complete one goes to review', (tester) async {
      await openPreview(tester, '/dev/v/home');
      await pickScenario(tester, 'Rejected'); // complete profile with a reason
      await tester.tap(find.text('Fix and resubmit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for review'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Your profile is under review'), findsOneWidget);
    });

    testWidgets('a draft with missing items is refused with the list', (tester) async {
      await openPreview(tester, '/dev/v/editor');
      // The draft is missing several items; typed fields alone cannot fix past work.
      final submit = find.text('Submit for review');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Please fix the highlighted fields.'), findsOneWidget);
    });

    testWidgets('a live profile edited in a watched field goes back to review', (tester) async {
      await openPreview(tester, '/dev/v/home');
      await pickScenario(tester, 'Live');
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.text('Heads up'), findsOneWidget);

      final name = find.descendant(
        of: find.widgetWithText(Column, 'Business name'),
        matching: find.byType(TextField),
      );
      await tester.enterText(name.first, 'Shubh Studios');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and send'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      // Back on the dashboard, now under review.
      expect(find.text('Your profile is under review'), findsOneWidget);
    });
  });

  group('organizer app preview', () {
    testWidgets('home shows the hero card and switches tabs', (tester) async {
      await openPreview(tester, '/dev/o/home');
      expect(find.text('Hello, Priya'), findsOneWidget);
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.text('My events'), findsOneWidget);
      await tester.tap(find.text('Vendors'));
      await tester.pumpAndSettle();
      expect(find.text('Shubh Photos'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('scenarios: no events, loading, error', (tester) async {
      await openPreview(tester, '/dev/o/home');
      await pickScenario(tester, 'No events yet');
      expect(find.text('Plan your first event'), findsOneWidget);
      await pickScenario(tester, 'Error');
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Priya'), findsOneWidget);
    });

    testWidgets('the roadmap generate flow shows the waiting view and then the tasks', (tester) async {
      await openPreview(tester, '/dev/o/event/ev-new');
      expect(find.text('Get your roadmap'), findsOneWidget);
      await tester.tap(find.text('Generate my roadmap'));
      await tester.pump();
      expect(find.text('Building your roadmap'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Building your roadmap'), findsNothing);
      expect(find.textContaining('tasks done'), findsOneWidget);
    });

    testWidgets('a task can be removed and restored', (tester) async {
      await openPreview(tester, '/dev/o/event/ev-wedding');
      await tester.tap(find.text('Buy bride and groom outfits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove this task'));
      await tester.pumpAndSettle();
      expect(find.text('Buy bride and groom outfits'), findsNothing);
      expect(find.text('4 of 16 tasks done'), findsOneWidget);
    });

    testWidgets('new event form: a name containing fail shows the error, then it can be created', (tester) async {
      final router = await openPreview(tester, '/dev/o/new-event');
      expect(router.state.uri.path, '/dev/o/new-event');
      expect(find.text('New event'), findsOneWidget);
    });
  });

  group('previews menu', () {
    testWidgets('every entry opens without errors', (tester) async {
      final router = await openPreview(tester, '/dev');
      for (final path in [
        '/dev/welcome', '/dev/phone', '/dev/otp', '/dev/gallery', '/dev/o/home',
        '/dev/o/event/ev-wedding', '/dev/o/event/ev-new', '/dev/o/new-event',
        '/dev/o/edit-event/ev-wedding', '/dev/o/profile-setup', '/dev/o/vendor/v1',
        '/dev/v/home', '/dev/v/editor',
      ]) {
        router.go(path);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: path);
        expect(router.state.uri.path, path);
      }
    });
  });
}
