import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/otp_screen.dart';
import '../features/auth/phone_screen.dart';
import '../features/auth/welcome_screen.dart';
import 'dev_menu.dart';
import 'dev_organizer.dart';
import 'gallery_screen.dart';

const _previewPhone = '+91 98765 43210';

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Debug-only preview routes (mock data, no network). Added to the router only
/// in debug builds.
List<RouteBase> devRoutes() => [
      ...devOrganizerRoutes(),
      GoRoute(path: '/dev', builder: (context, state) => const DevMenuScreen()),
      GoRoute(path: '/dev/gallery', builder: (context, state) => const GalleryScreen()),
      GoRoute(
        path: '/dev/welcome',
        builder: (context, state) =>
            WelcomeScreen(onGetStarted: () => context.push('/dev/phone')),
      ),
      GoRoute(
        path: '/dev/phone',
        builder: (context, state) => PhoneScreen(
          onBack: () => context.canPop() ? context.pop() : context.go('/dev'),
          onSubmit: (entry) async {
            await Future<void>.delayed(const Duration(milliseconds: 800));
            // Preview rule: numbers ending 0000 fail, to show the error state.
            if (entry.phoneNumber.endsWith('0000')) {
              return 'Could not send a code. Check the number and try again.';
            }
            if (context.mounted) context.push('/dev/otp', extra: entry.phoneNumber);
            return null;
          },
        ),
      ),
      GoRoute(
        path: '/dev/otp',
        builder: (context, state) => OtpScreen(
          phoneNumber: state.extra as String? ?? _previewPhone,
          onChangeNumber: () => context.canPop() ? context.pop() : context.go('/dev'),
          onResend: () async {
            await Future<void>.delayed(const Duration(milliseconds: 600));
            if (context.mounted) _toast(context, 'New code sent (preview)');
            return null;
          },
          onVerify: (otp) async {
            await Future<void>.delayed(const Duration(milliseconds: 700));
            // Preview rule: 123456 succeeds, anything else is rejected.
            if (otp != '123456') return 'That code is wrong or expired.';
            if (context.mounted) {
              _toast(context, 'Signed in (preview)');
              context.go('/dev');
            }
            return null;
          },
        ),
      ),
    ];
