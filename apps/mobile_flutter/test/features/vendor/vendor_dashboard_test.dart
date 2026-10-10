import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/home_view.dart' show HomeStatus;
import 'package:sanchalan/features/vendor/vendor_dashboard_view.dart';
import 'package:sanchalan/features/vendor/widgets/status_timeline.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/vendor.dart';
import 'package:sanchalan/shared/widgets/skeleton.dart';

import '../../helpers/pump_screen.dart';

final mock = MockData(today: DateTime(2026, 10, 10));

Widget dashboard(
  VendorMeResponse? me, {
  HomeStatus status = HomeStatus.ready,
  bool busy = false,
  String? error,
  void Function([VendorRequiredField? f])? onEdit,
  VoidCallback? onWithdraw,
  VoidCallback? onSupport,
  VoidCallback? onSignOut,
  VoidCallback? onRetry,
}) =>
    VendorDashboardView(
      status: status,
      me: me,
      busy: busy,
      error: error,
      onEdit: onEdit,
      onWithdraw: onWithdraw,
      onContactSupport: onSupport,
      onSignOut: onSignOut,
      onRetry: onRetry,
    );

const _tall = Size(400, 1800);

void main() {
  group('draft', () {
    testWidgets('greets the contact person and shows the checklist', (tester) async {
      await pumpScreen(tester, dashboard(mock.vendorDraft), size: _tall);
      expect(find.text('Hello, Asha'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Finish your profile'), findsOneWidget);
      expect(find.text('2 of 7 done'), findsOneWidget);
      expect(find.text('29%'), findsOneWidget);
      for (final label in ['Price range', 'Service area', 'About your business', 'What you offer', 'Past work']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('At least 30 characters'), findsOneWidget);
      expect(find.text('Continue setting up'), findsOneWidget);
    });

    testWidgets('tapping a missing item opens the editor at that field; done items do not', (tester) async {
      final opened = <VendorRequiredField?>[];
      await pumpScreen(tester, dashboard(mock.vendorDraft, onEdit: ([f]) => opened.add(f)), size: _tall);
      await tester.tap(find.text('Service area'));
      await tester.tap(find.text('Business name'));
      await tester.tap(find.text('Continue setting up'));
      expect(opened, [VendorRequiredField.serviceArea, null]);
    });

    testWidgets('a complete draft offers Review and submit', (tester) async {
      await pumpScreen(tester, dashboard(mock.vendorMe(VendorStatus.draft)), size: _tall);
      expect(find.text('Your profile is complete'), findsOneWidget);
      expect(find.text('Review and submit'), findsOneWidget);
    });
  });

  group('rejected', () {
    testWidgets('shows the reason, the checklist and Fix and resubmit', (tester) async {
      var edits = 0;
      await pumpScreen(tester, dashboard(mock.vendorRejected, onEdit: ([_]) => edits++), size: _tall);
      expect(find.text('Changes requested'), findsOneWidget);
      expect(find.textContaining('clearer description'), findsOneWidget);
      expect(find.text('Needs changes'), findsOneWidget);
      await tester.tap(find.text('Fix and resubmit'));
      expect(edits, 1);
    });

    testWidgets('has a fallback message when no reason was given', (tester) async {
      final me = mock.vendorMe(VendorStatus.rejected, rejectionReason: '');
      final noReason = VendorMeResponse(
        vendor: Vendor.fromJson({...me.vendor.toJson(), 'rejectionReason': null}),
        completeness: me.completeness,
      );
      await pumpScreen(tester, dashboard(noReason), size: _tall);
      expect(find.textContaining('review your profile'), findsOneWidget);
    });
  });

  group('under review', () {
    testWidgets('timeline with the submission date, and withdraw', (tester) async {
      var withdrawn = 0;
      await pumpScreen(tester, dashboard(mock.vendorPending, onWithdraw: () => withdrawn++), size: _tall);
      expect(find.text('Your profile is under review'), findsOneWidget);
      expect(find.textContaining('submitted on 8 Oct 2026'), findsOneWidget);
      expect(find.byType(StatusTimeline), findsOneWidget);
      for (final t in ['Submitted', 'In review', 'Live']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      await tester.tap(find.text('Withdraw to edit'));
      expect(withdrawn, 1);
    });

    testWidgets('while withdrawing the button is disabled; errors are shown', (tester) async {
      var withdrawn = 0;
      await pumpScreen(
        tester,
        dashboard(mock.vendorPending, busy: true, error: 'Could not withdraw your profile.', onWithdraw: () => withdrawn++),
        size: _tall,
      );
      expect(find.text('Withdrawing...'), findsOneWidget);
      expect(find.text('Could not withdraw your profile.'), findsOneWidget);
      await tester.tap(find.text('Withdrawing...'), warnIfMissed: false);
      expect(withdrawn, 0);
    });
  });

  group('published', () {
    testWidgets('live banner, public preview, Edit and the re-review note', (tester) async {
      var edits = 0;
      await pumpScreen(tester, dashboard(mock.vendorPublished, onEdit: ([_]) => edits++), size: _tall);
      expect(find.text("You're live"), findsOneWidget);
      expect(find.text('Live'), findsWidgets);
      expect(find.text('How families see you'), findsOneWidget);
      expect(find.text('Shubh Photos'), findsOneWidget);
      expect(find.text('Sharma wedding'), findsOneWidget);
      expect(find.textContaining('sends your profile back for review'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      expect(edits, 1);
    });
  });

  group('suspended', () {
    testWidgets('explains and offers support, nothing else', (tester) async {
      var support = 0;
      await pumpScreen(tester, dashboard(mock.vendorSuspended, onSupport: () => support++), size: _tall);
      expect(find.text('Your listing is paused'), findsOneWidget);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Withdraw to edit'), findsNothing);
      await tester.tap(find.text('Contact support'));
      expect(support, 1);
    });
  });

  group('shared', () {
    testWidgets('the account menu signs out', (tester) async {
      var out = 0;
      await pumpScreen(tester, dashboard(mock.vendorPublished, onSignOut: () => out++), size: _tall);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(out, 1);
    });

    testWidgets('loading, missing data and error', (tester) async {
      var retries = 0;
      await pumpScreen(tester, dashboard(null, status: HomeStatus.loading));
      expect(find.byType(Skeleton), findsWidgets);
      await pumpScreen(tester, dashboard(null));
      expect(find.byType(Skeleton), findsWidgets);
      await pumpScreen(tester, dashboard(null, status: HomeStatus.error, onRetry: () => retries++));
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('falls back to the business name, then to a plain hello', (tester) async {
      final noContact = Vendor.fromJson({...mock.vendorPublished.vendor.toJson(), 'contactPersonName': null});
      await pumpScreen(tester, dashboard(VendorMeResponse(vendor: noContact, completeness: mock.vendorPublished.completeness)), size: _tall);
      expect(find.text('Hello, Shubh'), findsOneWidget);
      final nothing = Vendor.fromJson({...mock.vendorPublished.vendor.toJson(), 'contactPersonName': null, 'businessName': null});
      await pumpScreen(tester, dashboard(VendorMeResponse(vendor: nothing, completeness: mock.vendorPublished.completeness)), size: _tall);
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('small screens', () {
    final cases = {
      'draft': mock.vendorDraft,
      'rejected': mock.vendorRejected,
      'pending': mock.vendorPending,
      'published': mock.vendorPublished,
      'suspended': mock.vendorSuspended,
    };
    for (final entry in cases.entries) {
      for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
        testWidgets('${entry.key} fits $size at text scale $scale', (tester) async {
          await pumpScreen(tester, dashboard(entry.value, onEdit: ([_]) {}), size: size, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
