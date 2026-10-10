import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/app.dart';
import 'package:sanchalan/core/auth_storage.dart';
import 'package:sanchalan/core/link_launcher.dart';
import 'package:sanchalan/core/router/paths.dart';
import 'package:sanchalan/core/router/router.dart';
import 'package:sanchalan/features/vendor/vendor_errors.dart';
import 'package:sanchalan/models/vendor.dart';
import 'package:sanchalan/shared/widgets/app_text_field.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

class FakeLauncher implements LinkLauncher {
  final calls = <String>[];

  @override
  Future<bool> call(String phoneNumber) async {
    calls.add('call $phoneNumber');
    return true;
  }

  @override
  Future<bool> whatsApp(String phoneNumber) async => true;
  @override
  Future<bool> openUrl(String url) async => true;
  @override
  Future<bool> email(String address) async {
    calls.add('email $address');
    return true;
  }
}

Map<String, dynamic> me(String fixtureName, {String? status}) {
  final json = Map<String, dynamic>.of(fixture(fixtureName) as Map<String, dynamic>);
  if (status != null) json['status'] = status;
  return json;
}

/// The vendor's own profile in the given status, with the completeness the server would send.
Map<String, dynamic> meAs(String status, {bool complete = true}) {
  final base = me(complete ? 'vendor_me_published' : 'vendor_me_draft', status: status);
  return base;
}

class Harness {
  Harness(this.container, this.adapter, this.launcher);
  final ProviderContainer container;
  final FakeAdapter adapter;
  final FakeLauncher launcher;

  String get location => container.read(routerProvider).state.uri.path;
  void go(String path, {Object? extra}) => container.read(routerProvider).go(path, extra: extra);
  int count(String method, String path) => adapter.requests.where((r) => r.method == method && r.path == path).length;
  RequestOptions last(String method, String path) => adapter.requests.lastWhere((r) => r.method == method && r.path == path);
}

Future<Harness> pumpVendor(
  WidgetTester tester,
  Map<String, dynamic> Function() vendorMe, {
  Map<String, RouteHandler> overrides = const {},
}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final launcher = FakeLauncher();
  final (container, adapter) = makeContainer(
    routes({
      'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
      'POST /auth/logout': (_) => jsonBody({}),
      'GET /vendor/me': (_) => jsonBody(vendorMe()),
      'GET /vendor-categories': (_) => fixtureBody('vendor_categories'),
      ...overrides,
    }),
    secure: {accessTokenKey: 'a', refreshTokenKey: 'r', roleKey: 'vendor'},
    overrides: [linkLauncherProvider.overrideWithValue(launcher)],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SanchalanApp()));
  await tester.pumpAndSettle();
  return Harness(container, adapter, launcher);
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('missingFromError reads the server list', () {
    DioException err(Object? data) {
      final o = RequestOptions(path: '/x');
      return DioException(requestOptions: o, response: Response(requestOptions: o, statusCode: 400, data: data));
    }

    expect(
      missingFromError(err({'error': 'x', 'details': {'missing': ['pastWork', 'bogus', 'priceTier']}})),
      [VendorRequiredField.pastWork, VendorRequiredField.priceTier], // the server's order
    );
    expect(missingFromError(err({'error': 'x'})), isEmpty);
    expect(missingFromError(err('plain text')), isEmpty);
    expect(missingFromError(StateError('not dio')), isEmpty);
  });

  group('dashboard', () {
    testWidgets('a new draft sees the checklist and opens the editor from it', (tester) async {
      final h = await pumpVendor(tester, () => me('vendor_me_draft'));
      expect(h.location, AppPaths.vendorHome);
      expect(find.text('Finish your profile'), findsOneWidget);
      await tap(tester, find.text('Service area'));
      expect(h.location, AppPaths.vendorProfile);
      expect(find.text('Your business profile'), findsOneWidget);
    });

    testWidgets('a live vendor sees the live banner', (tester) async {
      await pumpVendor(tester, () => me('vendor_me_published'));
      expect(find.text("You're live"), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('withdrawing an application returns the vendor to a draft', (tester) async {
      final h = await pumpVendor(
        tester,
        () => me('vendor_submit'),
        overrides: {'POST /vendor/me/withdraw': (_) => fixtureBody('vendor_me_draft')},
      );
      expect(find.text('Your profile is under review'), findsOneWidget);
      await tap(tester, find.text('Withdraw to edit'));
      expect(h.count('POST', '/vendor/me/withdraw'), 1);
      expect(find.text('Finish your profile'), findsOneWidget);
    });

    testWidgets('a failed withdraw says why', (tester) async {
      await pumpVendor(
        tester,
        () => me('vendor_submit'),
        overrides: {'POST /vendor/me/withdraw': (_) => jsonBody({'error': 'Cannot withdraw now.'}, 409)},
      );
      await tap(tester, find.text('Withdraw to edit'));
      expect(find.text('Cannot withdraw now.'), findsOneWidget);
      expect(find.text('Your profile is under review'), findsOneWidget);
    });

    testWidgets('a suspended vendor can contact support by mail', (tester) async {
      final h = await pumpVendor(tester, () => me('vendor_me_published', status: 'suspended'));
      expect(find.text('Your listing is paused'), findsOneWidget);
      await tap(tester, find.text('Contact support'));
      expect(h.launcher.calls, ['email support@sanchalan.app']);
    });

    testWidgets('a failed load shows Retry', (tester) async {
      var fail = true;
      final h = await pumpVendor(tester, () => throw StateError('unused'), overrides: {
        'GET /vendor/me': (_) => fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('vendor_me_draft'),
      });
      expect(find.text('Retry'), findsOneWidget);
      fail = false;
      await tap(tester, find.text('Retry'));
      expect(find.text('Finish your profile'), findsOneWidget);
      expect(h.count('GET', '/vendor/me'), 2);
    });

    testWidgets('signing out asks first', (tester) async {
      final h = await pumpVendor(tester, () => me('vendor_me_published'));
      await tap(tester, find.byTooltip('Account'));
      await tap(tester, find.text('Sign out'));
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')));
      await tester.pumpAndSettle();
      expect(h.count('POST', '/auth/logout'), 1);
      expect(h.location, AppPaths.welcome);
    });
  });

  Finder input(String label) =>
      find.descendant(of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

  Map<String, dynamic> updateResponse(Map<String, dynamic> vendorMe, {bool reverify = false}) =>
      {'vendor': vendorMe, 'reverificationTriggered': reverify};

  group('editor: draft', () {
    testWidgets('saving a draft sends only what changed and confirms', (tester) async {
      final h = await pumpVendor(
        tester,
        () => me('vendor_me_draft'),
        overrides: {'PATCH /vendor/me': (_) => fixtureBody('vendor_update_profile')},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tester.enterText(input('Business name'), 'Shubh Photos');
      await tester.pump();
      await tap(tester, find.text('Save draft'));
      expect(h.last('PATCH', '/vendor/me').data, {'businessName': 'Shubh Photos'});
      expect(h.count('PUT', '/vendor/me/categories'), 0);
      expect(find.text('Draft saved.'), findsOneWidget);
      expect(h.location, AppPaths.vendorProfile);
    });

    testWidgets('choosing categories saves them through their own call', (tester) async {
      final h = await pumpVendor(
        tester,
        () => me('vendor_me_draft'),
        overrides: {'PUT /vendor/me/categories': (_) => fixtureBody('vendor_set_categories')},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(FilterChip, 'Photography'));
      await tap(tester, find.text('Save draft'));
      expect(h.last('PUT', '/vendor/me/categories').data, {'categoryKeys': ['photography']});
      expect(h.count('PATCH', '/vendor/me'), 0);
    });

    testWidgets('a server error is shown and the form stays', (tester) async {
      final h = await pumpVendor(
        tester,
        () => me('vendor_me_draft'),
        overrides: {'PATCH /vendor/me': (_) => jsonBody({'error': 'That name is taken.'}, 409)},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tester.enterText(input('Business name'), 'Taken Name');
      await tester.pump();
      await tap(tester, find.text('Save draft'));
      expect(find.text('That name is taken.'), findsOneWidget);
      expect(h.location, AppPaths.vendorProfile);
    });

    testWidgets('past work: add, then delete without any warning on a draft', (tester) async {
      final draftWithWork = me('vendor_me_published', status: 'draft');
      final workId = (draftWithWork['portfolioItems'] as List).first['id'] as String;
      final h = await pumpVendor(
        tester,
        () => draftWithWork,
        overrides: {
          'POST /vendor/me/past-work': (_) => fixtureBody('vendor_past_work_add', 201),
          'DELETE /vendor/me/past-work/$workId': (_) => fixtureBody('vendor_past_work_add'),
        },
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();

      await tap(tester, find.text('Add past work'));
      await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).first, 'Kulkarni wedding');
      await tester.pump();
      await tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add')));
      expect(h.last('POST', '/vendor/me/past-work').data, {'title': 'Kulkarni wedding', 'caption': null});
      expect(find.text('Send for review again?'), findsNothing);

      await tap(tester, find.text((draftWithWork['portfolioItems'] as List).first['title'] as String));
      await tap(tester, find.text('Delete this entry'));
      expect(h.count('DELETE', '/vendor/me/past-work/$workId'), 1);
    });

    testWidgets('the categories failing to load shows Retry', (tester) async {
      final h = await pumpVendor(
        tester,
        () => me('vendor_me_draft'),
        overrides: {'GET /vendor-categories': (_) => jsonBody({'error': 'boom'}, 500)},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      expect(find.text('Could not load the categories.'), findsOneWidget);
    });
  });

  group('editor: submitting', () {
    Map<String, dynamic> completeDraft() => me('vendor_me_published', status: 'draft');

    testWidgets('a complete profile is submitted and the vendor lands on the under-review dashboard', (tester) async {
      final h = await pumpVendor(
        tester,
        completeDraft,
        overrides: {'POST /vendor/me/submit': (_) => fixtureBody('vendor_submit')},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Submit for review'));
      expect(h.count('POST', '/vendor/me/submit'), 1);
      expect(h.location, AppPaths.vendorHome);
      expect(find.text('Your profile is under review'), findsOneWidget);
    });

    testWidgets('unsaved edits are saved before submitting', (tester) async {
      final h = await pumpVendor(
        tester,
        completeDraft,
        overrides: {
          // The server answers with the saved profile, consistent with what was loaded.
          'PATCH /vendor/me': (_) => jsonBody(updateResponse(completeDraft())),
          'POST /vendor/me/submit': (_) => fixtureBody('vendor_submit'),
        },
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tester.enterText(input('Years of experience (optional)'), '12');
      await tester.pump();
      await tap(tester, find.text('Submit for review'));
      final order = [for (final r in h.adapter.requests) '${r.method} ${r.path}'];
      expect(order, contains('PATCH /vendor/me'), reason: order.join(' | '));
      expect(order.indexOf('PATCH /vendor/me'), lessThan(order.indexOf('POST /vendor/me/submit')));
    });

    testWidgets("the server's missing list becomes a Still needed message", (tester) async {
      final h = await pumpVendor(
        tester,
        completeDraft,
        overrides: {
          'POST /vendor/me/submit': (_) => jsonBody({
                'error': 'Profile is incomplete',
                'details': {'missing': ['pastWork', 'description']},
              }, 400),
        },
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Submit for review'));
      expect(find.text('Still needed: Past work, About your business.'), findsOneWidget);
      expect(h.location, AppPaths.vendorProfile);
    });

    testWidgets('an incomplete draft is stopped on the phone before any request', (tester) async {
      final h = await pumpVendor(tester, () => me('vendor_me_draft'));
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Submit for review'));
      expect(find.text('Please fix the highlighted fields.'), findsOneWidget);
      expect(h.count('POST', '/vendor/me/submit'), 0);
    });
  });

  group('editor: live profile', () {
    testWidgets('changing the business name asks first, then sends the profile back to review', (tester) async {
      final pending = me('vendor_submit');
      final h = await pumpVendor(
        tester,
        () => me('vendor_me_published'),
        overrides: {'PATCH /vendor/me': (_) => jsonBody(updateResponse(pending, reverify: true))},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tester.enterText(input('Business name'), 'Shubh Studios');
      await tester.pump();
      await tap(tester, find.text('Save changes'));
      expect(find.text('Send for review again?'), findsOneWidget);
      expect(h.count('PATCH', '/vendor/me'), 0);
      await tap(tester, find.text('Save and send'));
      expect(h.last('PATCH', '/vendor/me').data, {'businessName': 'Shubh Studios'});
      // The status flipped to pending, so the router closed the editor.
      expect(h.location, AppPaths.vendorHome);
      expect(find.text('Your profile is under review'), findsOneWidget);
    });

    testWidgets('a harmless change saves silently and goes back to the dashboard', (tester) async {
      final live = me('vendor_me_published');
      final h = await pumpVendor(
        tester,
        () => live,
        overrides: {'PATCH /vendor/me': (_) => jsonBody(updateResponse(live))},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tester.enterText(input('Years of experience (optional)'), '9');
      await tester.pump();
      await tap(tester, find.text('Save changes'));
      expect(find.text('Send for review again?'), findsNothing);
      expect(h.last('PATCH', '/vendor/me').data, {'yearsOfExperience': 9});
      expect(h.location, AppPaths.vendorHome);
    });

    testWidgets('clearing an optional field sends an explicit null', (tester) async {
      final live = me('vendor_me_published');
      final h = await pumpVendor(
        tester,
        () => {...live, 'instagramUrl': 'https://instagram.com/shubh'},
        overrides: {'PATCH /vendor/me': (_) => jsonBody(updateResponse(live))},
      );
      h.go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      await tester.enterText(input('Instagram'), '');
      await tester.pump();
      await tap(tester, find.text('Save changes'));
      expect(h.last('PATCH', '/vendor/me').data, {'instagramUrl': null});
    });
  });
}
