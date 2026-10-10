import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/app.dart';
import 'package:sanchalan/core/auth_storage.dart';
import 'package:sanchalan/core/router/paths.dart';
import 'package:sanchalan/core/router/router.dart';
import 'package:sanchalan/features/auth/auth_controller.dart';
import 'package:sanchalan/features/vendor/vendor_providers.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/vendor.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

Map<String, String> session(String role) =>
    {accessTokenKey: 'a', refreshTokenKey: 'r', roleKey: role};

RouteHandler refreshOk = (_) => jsonBody({'accessToken': 'new'});

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Handler handler, {
  Map<String, String> secure = const {},
}) async {
  final (container, _) = makeContainer(handler, secure: secure);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const SanchalanApp(),
  ));
  await tester.pumpAndSettle();
  return container;
}

String location(ProviderContainer c) => c.read(routerProvider).state.uri.path;

Object? vendorWithStatus(String fixtureName, String status) =>
    {...(fixture(fixtureName) as Map<String, dynamic>), 'status': status};

void main() {
  testWidgets('no stored session -> sign-in screen', (tester) async {
    final c = await pumpApp(tester, routes({}));
    expect(location(c), AppPaths.welcome);
    expect(find.text('Plan every celebration, stress-free'), findsOneWidget);
  });

  group('organizer', () {
    testWidgets('profile not filled in -> /profile-setup', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'GET /organizers/me': (_) => fixtureBody('organizer_me_fresh'),
        }),
        secure: session('organizer'),
      );
      expect(location(c), AppPaths.profileSetup);
      expect(find.text('Tell us about you'), findsOneWidget);
    });

    testWidgets('profile complete -> /events', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
          'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
        }),
        secure: session('organizer'),
      );
      expect(location(c), AppPaths.home);
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('a failed load shows Retry, and Retry recovers', (tester) async {
      var fail = true;
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'GET /organizers/me': (_) =>
              fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('organizer_profile'),
          'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
        }),
        secure: session('organizer'),
      );
      expect(location(c), AppPaths.organizerError);
      expect(find.text('Something went wrong loading your account.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.home);
    });

    testWidgets('signing out returns to /welcome', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'POST /auth/logout': (_) => jsonBody({}),
          'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
          'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
        }),
        secure: session('organizer'),
      );
      expect(location(c), AppPaths.home);

      // Not awaited: inside testWidgets, time only advances while pumping.
      unawaited(c.read(authControllerProvider.notifier).signOut());
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.welcome);
    });

    testWidgets('a screen opened with push is closed when the session ends', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'POST /auth/logout': (_) => jsonBody({}),
          'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
          'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
        }),
        secure: session('organizer'),
      );
      expect(location(c), AppPaths.home);
      c.read(routerProvider).push(AppPaths.eventSetup);
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.eventSetup);

      unawaited(c.read(authControllerProvider.notifier).signOut());
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.welcome);
    });

    testWidgets('an organizer cannot open vendor screens', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
          'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
        }),
        secure: session('organizer'),
      );
      c.read(routerProvider).go(AppPaths.vendorHome);
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.home);
    });
  });

  group('vendor', () {
    Handler vendorMe(Object? body) => routes({
          'POST /auth/refresh': refreshOk,
          'GET /vendor/me': (_) => jsonBody(body),
        });

    // Every status lands on the dashboard, which adapts to the status.
    final cases = {
      'draft': (AppPaths.vendorHome, 'Finish your profile'),
      'rejected': (AppPaths.vendorHome, 'Changes requested'),
      'pending_review': (AppPaths.vendorHome, 'Your profile is under review'),
      'published': (AppPaths.vendorHome, "You're live"),
      'suspended': (AppPaths.vendorHome, 'Your listing is paused'),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key} -> ${entry.value.$1}', (tester) async {
        final c = await pumpApp(
          tester,
          vendorMe(vendorWithStatus('vendor_me_draft', entry.key)),
          secure: session('vendor'),
        );
        expect(location(c), entry.value.$1);
        expect(find.text(entry.value.$2), findsWidgets);
      });
    }

    testWidgets('the editor closes when a status change no longer allows editing', (tester) async {
      final c = await pumpApp(tester, vendorMe(fixture('vendor_me_draft')), secure: session('vendor'));
      expect(location(c), AppPaths.vendorHome);
      c.read(routerProvider).go(AppPaths.vendorProfile);
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.vendorProfile); // a draft may edit

      final submitted = VendorMeResponse.fromJson(fixture('vendor_submit') as Map<String, dynamic>);
      c.read(vendorDataProvider.notifier).apply(submitted);
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.vendorHome); // pending: back to the dashboard
    });

    testWidgets('a failed load shows Retry', (tester) async {
      var fail = true;
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/refresh': refreshOk,
          'GET /vendor/me': (_) =>
              fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('vendor_me_draft'),
        }),
        secure: session('vendor'),
      );
      expect(location(c), AppPaths.vendorError);

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.vendorHome);
    });
  });

  group('otp route', () {
    testWidgets('without arguments goes back to /phone', (tester) async {
      final c = await pumpApp(tester, routes({}));
      c.read(routerProvider).go(AppPaths.otp);
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.phone);
    });

    testWidgets('with arguments shows the OTP screen', (tester) async {
      final c = await pumpApp(tester, routes({}));
      c.read(routerProvider).go(
            AppPaths.otp,
            extra: const OtpArgs(phoneNumber: '+919999999999', role: AuthRole.organizer),
          );
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.otp);
      expect(find.text('+919999999999'), findsOneWidget);
    });
  });

  testWidgets('an admin session shows the unsupported screen with Sign out', (tester) async {
    final c = await pumpApp(
      tester,
      routes({'POST /auth/refresh': refreshOk}),
      secure: session('admin'),
    );
    expect(location(c), AppPaths.unsupportedRole);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
