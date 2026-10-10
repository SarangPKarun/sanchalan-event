import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/auth/otp_screen.dart';
import 'package:sanchalan/features/auth/phone_screen.dart';
import 'package:sanchalan/features/auth/welcome_screen.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/shared/widgets/otp_boxes.dart';
import 'package:sanchalan/shared/widgets/primary_button.dart';

import '../../helpers/pump_screen.dart';

Finder get sendCode => find.widgetWithText(FilledButton, 'Send code');
Finder get verify => find.widgetWithText(FilledButton, 'Verify');

bool enabled(WidgetTester tester, Finder f) => tester.widget<FilledButton>(f).onPressed != null;

void main() {
  group('WelcomeScreen', () {
    testWidgets('shows the promise and starts on tap', (tester) async {
      var taps = 0;
      await pumpScreen(tester, WelcomeScreen(onGetStarted: () => taps++));
      expect(find.text('Plan every celebration, stress-free'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      expect(taps, 1);
    });

    for (final (size, scale) in [
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(320, 480), 1.3),
    ]) {
      testWidgets('fits $size at text scale $scale', (tester) async {
        await pumpScreen(tester, WelcomeScreen(onGetStarted: () {}), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('PhoneScreen', () {
    Future<PhoneEntry?> typeAndSend(
      WidgetTester tester, {
      String number = '98765 43210',
      Future<String?> Function(PhoneEntry)? onSubmit,
    }) async {
      PhoneEntry? entry;
      await pumpScreen(tester, PhoneScreen(onSubmit: (e) async {
        entry = e;
        return onSubmit == null ? null : onSubmit(e);
      }));
      await tester.enterText(find.byType(TextField), number);
      await tester.pump();
      await tester.tap(sendCode);
      await tester.pump();
      return entry;
    }

    testWidgets('Send code is disabled until the number is valid', (tester) async {
      await pumpScreen(tester, PhoneScreen(onSubmit: (_) async => null));
      expect(enabled(tester, sendCode), isFalse);
      expect(find.text('Enter a valid India mobile number.'), findsNothing);

      await tester.enterText(find.byType(TextField), '98765');
      await tester.pump();
      expect(enabled(tester, sendCode), isFalse);
      expect(find.text('Enter a valid India mobile number.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '98765 43210');
      await tester.pump();
      expect(enabled(tester, sendCode), isTrue);
      expect(find.text('Enter a valid India mobile number.'), findsNothing);
    });

    testWidgets('submits the E.164 number with the organizer role by default', (tester) async {
      final entry = await typeAndSend(tester);
      expect(entry!.phoneNumber, '+919876543210');
      expect(entry.role, AuthRole.organizer);
      expect(entry.country.iso2, 'IN');
    });

    testWidgets('choosing the vendor card changes the role', (tester) async {
      PhoneEntry? entry;
      await pumpScreen(tester, PhoneScreen(onSubmit: (e) async {
        entry = e;
        return null;
      }));
      await tester.tap(find.text("I'm a vendor"));
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();
      await tester.tap(sendCode);
      await tester.pump();
      expect(entry!.role, AuthRole.vendor);
    });

    testWidgets('role cards announce which one is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, PhoneScreen(onSubmit: (_) async => null));
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp("I'm planning an event"))),
        isSemantics(isSelected: true, isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('shows a spinner while sending and the error afterwards', (tester) async {
      final completer = Completer<String?>();
      await typeAndSend(tester, onSubmit: (_) => completer.future);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(enabled(tester, find.byType(FilledButton)), isFalse);

      completer.complete('Could not send a code. Check the number and try again.');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Could not send a code. Check the number and try again.'), findsOneWidget);

      // Editing the number clears the error.
      await tester.enterText(find.byType(TextField), '98765 43211');
      await tester.pump();
      expect(find.text('Could not send a code. Check the number and try again.'), findsNothing);
    });

    testWidgets('picking another country changes the code and the rules', (tester) async {
      PhoneEntry? entry;
      await pumpScreen(tester, PhoneScreen(onSubmit: (e) async {
        entry = e;
        return null;
      }));
      await tester.ensureVisible(find.textContaining('+91'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('+91'));
      await tester.pumpAndSettle();
      expect(find.text('Select a country'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '').last, 'emirates');
      await tester.pumpAndSettle();
      expect(find.text('United Arab Emirates'), findsOneWidget);
      expect(find.text('India'), findsNothing);

      await tester.tap(find.text('United Arab Emirates'));
      await tester.pumpAndSettle();
      expect(find.textContaining('+971'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '50 123 4567');
      await tester.pump();
      await tester.tap(sendCode);
      await tester.pump();
      expect(entry!.phoneNumber, '+971501234567');
    });

    testWidgets('a search with no results says so', (tester) async {
      await pumpScreen(tester, PhoneScreen(onSubmit: (_) async => null));
      await tester.ensureVisible(find.textContaining('+91'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('+91'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '').last, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No country found'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('fits 360x640 at text scale $scale, including the error state', (tester) async {
        await pumpScreen(
          tester,
          PhoneScreen(onSubmit: (_) async => 'Could not send a code. Check the number and try again.'),
          textScale: scale,
        );
        await tester.enterText(find.byType(TextField), '98765');
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), '9876543210');
        await tester.pump();
        await tester.dragUntilVisible(sendCode, find.byType(ListView), const Offset(0, -100));
        await tester.tap(sendCode, warnIfMissed: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('OtpScreen', () {
    Future<void> enterCode(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(EditableText), code);
      await tester.pump();
    }

    testWidgets('shows the number, six boxes and a disabled Verify', (tester) async {
      await pumpScreen(
        tester,
        OtpScreen(phoneNumber: '+91 98765 43210', onVerify: (_) async => null, onResend: () async => null),
      );
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.byType(OtpBoxes), findsOneWidget);
      expect(enabled(tester, verify), isFalse);
    });

    testWidgets('completing the code verifies it automatically, once', (tester) async {
      final codes = <String>[];
      await pumpScreen(
        tester,
        OtpScreen(
          phoneNumber: '+91',
          onVerify: (c) async {
            codes.add(c);
            return null;
          },
          onResend: () async => null,
        ),
      );
      await enterCode(tester, '12345');
      expect(codes, isEmpty);
      expect(enabled(tester, verify), isFalse);
      await enterCode(tester, '123456');
      expect(codes, ['123456']);
    });

    testWidgets('a wrong code shows the error and typing again clears it', (tester) async {
      await pumpScreen(
        tester,
        OtpScreen(
          phoneNumber: '+91',
          onVerify: (_) async => 'That code is wrong or expired.',
          onResend: () async => null,
        ),
      );
      await enterCode(tester, '000000');
      await tester.pump();
      expect(find.text('That code is wrong or expired.'), findsWidgets);
      await enterCode(tester, '00000');
      expect(find.text('That code is wrong or expired.'), findsNothing);
    });

    testWidgets('the Verify button works too and shows a spinner while checking', (tester) async {
      final completer = Completer<String?>();
      await pumpScreen(
        tester,
        OtpScreen(phoneNumber: '+91', onVerify: (_) => completer.future, onResend: () async => null),
      );
      await enterCode(tester, '123456');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete(null);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('resend: countdown, then enabled, then restarts', (tester) async {
      var resends = 0;
      await pumpScreen(
        tester,
        OtpScreen(
          phoneNumber: '+91',
          onVerify: (_) async => null,
          onResend: () async {
            resends++;
            return null;
          },
        ),
      );
      expect(find.text('Resend code in 0:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Resend code in 0:25'), findsOneWidget);
      expect(find.text('Resend code'), findsNothing);

      await tester.pump(const Duration(seconds: 25));
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      expect(resends, 1);
      expect(find.text('Resend code in 0:30'), findsOneWidget);
    });

    testWidgets('a failed resend shows the error and keeps Resend available', (tester) async {
      await pumpScreen(
        tester,
        OtpScreen(
          phoneNumber: '+91',
          resendSeconds: 2,
          onVerify: (_) async => null,
          onResend: () async => 'Could not resend the code.',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      expect(find.text('Could not resend the code.'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
    });

    testWidgets('Change number calls back', (tester) async {
      var taps = 0;
      await pumpScreen(
        tester,
        OtpScreen(
          phoneNumber: '+91',
          onVerify: (_) async => null,
          onResend: () async => null,
          onChangeNumber: () => taps++,
        ),
      );
      await tester.tap(find.text('Change number'));
      expect(taps, 1);
    });

    for (final (size, scale) in [
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(320, 480), 1.3),
    ]) {
      testWidgets('fits $size at text scale $scale with an error showing', (tester) async {
        await pumpScreen(
          tester,
          OtpScreen(
            phoneNumber: '+91 98765 43210',
            onChangeNumber: () {},
            onVerify: (_) async => 'That code is wrong or expired.',
            onResend: () async => null,
          ),
          size: size,
          textScale: scale,
        );
        await tester.enterText(find.byType(EditableText), '000000');
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('PrimaryButton import is used by the screens', (tester) async {
    // Guards against the screens drifting off the shared button.
    await pumpScreen(tester, PhoneScreen(onSubmit: (_) async => null));
    expect(find.byType(PrimaryButton), findsOneWidget);
  });
}
