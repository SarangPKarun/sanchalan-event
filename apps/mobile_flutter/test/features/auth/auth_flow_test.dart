import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/app.dart';
import 'package:sanchalan/core/providers.dart';
import 'package:sanchalan/core/router/paths.dart';
import 'package:sanchalan/core/router/router.dart';
import 'package:sanchalan/features/auth/auth_messages.dart';
import 'package:sanchalan/features/auth/country_codes.dart';
import 'package:sanchalan/models/enums.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

String location(ProviderContainer c) => c.read(routerProvider).state.uri.path;

Future<ProviderContainer> pumpApp(WidgetTester tester, Handler handler) async {
  final (container, _) = makeContainer(handler);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SanchalanApp()));
  await tester.pumpAndSettle();
  return container;
}

Future<void> signInThroughScreens(WidgetTester tester, {String role = "I'm planning an event"}) async {
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(role));
  await tester.enterText(find.byType(TextField), '98765 43210');
  await tester.pump();
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();
}

void main() {
  group('messages', () {
    DioException err(int code, [String message = '']) {
      final o = RequestOptions(path: '/x');
      return DioException(
        requestOptions: o,
        response: Response(requestOptions: o, statusCode: code, data: {'error': message}),
      );
    }

    final offline = DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'offline');

    test('request code', () {
      expect(requestOtpMessage(err(400), defaultCountry), 'Enter a valid India phone number.');
      expect(requestOtpMessage(err(429), defaultCountry), contains('Too many codes'));
      expect(requestOtpMessage(err(500), defaultCountry), contains('Could not send a code'));
      expect(requestOtpMessage(offline, defaultCountry), contains('No internet'));
    });

    test('verify code reads the server reason', () {
      expect(verifyOtpMessage(err(400, 'Invalid OTP')), 'That code is not right. Check it and try again.');
      expect(verifyOtpMessage(err(400, 'OTP expired. Please request a new one.')), contains('expired'));
      expect(verifyOtpMessage(err(400, 'Too many incorrect attempts. Please request a new OTP.')), contains('no longer be used'));
      expect(verifyOtpMessage(err(400, 'OTP already used. Please request a new one.')), contains('no longer be used'));
      expect(verifyOtpMessage(err(500)), contains('Could not check'));
      expect(verifyOtpMessage(offline), contains('No internet'));
    });

    test('resend', () {
      expect(resendOtpMessage(err(429)), contains('Too many codes'));
      expect(resendOtpMessage(err(500)), contains('Could not resend'));
      expect(resendOtpMessage(offline), contains('No internet'));
    });
  });

  group('sign-in flow', () {
    testWidgets('welcome, phone, OTP, then the profile setup for a new organizer', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/otp/request': (_) => jsonBody({'expiresInSeconds': 300}),
          'POST /auth/otp/verify': (_) => fixtureBody('auth_verify_organizer'),
          'GET /organizers/me': (_) => fixtureBody('organizer_me_fresh'),
        }),
      );
      expect(location(c), AppPaths.welcome);
      await signInThroughScreens(tester);
      expect(location(c), AppPaths.otp);
      expect(find.text('+919876543210'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.profileSetup);

      final storage = c.read(authStorageProvider);
      expect(await storage.getRole(), AuthRole.organizer);
      expect(await storage.getRefreshToken(), isNotNull);
    });

    testWidgets('the request carries the number and the chosen role', (tester) async {
      final (container, adapter) = makeContainer(routes({
        'POST /auth/otp/request': (_) => jsonBody({'expiresInSeconds': 300}),
      }));
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SanchalanApp()));
      await tester.pumpAndSettle();
      await signInThroughScreens(tester, role: "I'm a vendor");
      expect(adapter.last('/auth/otp/request').data, {'phoneNumber': '+919876543210', 'role': 'vendor'});
    });

    testWidgets('a vendor lands on the vendor dashboard', (tester) async {
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/otp/request': (_) => jsonBody({'expiresInSeconds': 300}),
          'POST /auth/otp/verify': (_) => jsonBody({
                'accessToken': 'a',
                'refreshToken': 'r',
                'role': 'vendor',
                'userId': 'v1',
              }),
          'GET /vendor/me': (_) => fixtureBody('vendor_me_draft'),
        }),
      );
      await signInThroughScreens(tester, role: "I'm a vendor");
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.vendorHome);
    });

    testWidgets('a failed send shows the server-derived message and stays on the phone screen', (tester) async {
      final c = await pumpApp(tester, routes({'POST /auth/otp/request': (o) => jsonBody({'error': 'bad'}, 400)}));
      await signInThroughScreens(tester);
      expect(location(c), AppPaths.phone);
      expect(find.text('Enter a valid India phone number.'), findsOneWidget);
    });

    testWidgets('rate limiting is explained', (tester) async {
      await pumpApp(tester, routes({'POST /auth/otp/request': (o) => jsonBody({'error': 'slow down'}, 429)}));
      await signInThroughScreens(tester);
      expect(find.textContaining('Too many codes requested'), findsOneWidget);
    });

    testWidgets('a wrong code shows a message and the user can try again', (tester) async {
      var attempt = 0;
      final c = await pumpApp(
        tester,
        routes({
          'POST /auth/otp/request': (_) => jsonBody({'expiresInSeconds': 300}),
          'POST /auth/otp/verify': (_) {
            attempt++;
            return attempt == 1 ? jsonBody({'error': 'Invalid OTP'}, 400) : fixtureBody('auth_verify_organizer');
          },
          'GET /organizers/me': (_) => fixtureBody('organizer_profile'),
          'GET /event-groups/me': (_) => fixtureBody('event_groups_me'),
        }),
      );
      await signInThroughScreens(tester);
      await tester.enterText(find.byType(EditableText), '000000');
      await tester.pumpAndSettle();
      expect(find.text('That code is not right. Check it and try again.'), findsWidgets);
      expect(location(c), AppPaths.otp);

      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.home);
    });

    testWidgets('resend asks for a new code once the countdown ends', (tester) async {
      var sent = 0;
      await pumpApp(
        tester,
        routes({
          'POST /auth/otp/request': (_) {
            sent++;
            return jsonBody({'expiresInSeconds': 300});
          },
        }),
      );
      await signInThroughScreens(tester);
      expect(sent, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(sent, 2);
    });

    testWidgets('Change number goes back to the phone screen', (tester) async {
      final c = await pumpApp(tester, routes({'POST /auth/otp/request': (_) => jsonBody({'expiresInSeconds': 300})}));
      await signInThroughScreens(tester);
      await tester.tap(find.text('Change number'));
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.phone);
    });

    testWidgets('the back arrow on the phone screen returns to welcome', (tester) async {
      final c = await pumpApp(tester, routes({}));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(location(c), AppPaths.welcome);
    });
  });
}
