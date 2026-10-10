import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'auth_messages.dart';
import 'otp_args.dart';
import 'auth_repository.dart';
import 'phone_screen.dart';

/// The phone screen connected to the backend: asks for a code, then opens the OTP screen.
class PhonePage extends ConsumerWidget {
  const PhonePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhoneScreen(
      onBack: () => context.canPop() ? context.pop() : context.go(AppPaths.welcome),
      onSubmit: (entry) async {
        try {
          await ref.read(authRepositoryProvider).requestOtp(entry.phoneNumber, entry.role);
        } catch (e) {
          return requestOtpMessage(e, entry.country);
        }
        if (context.mounted) {
          context.push(AppPaths.otp, extra: OtpArgs(phoneNumber: entry.phoneNumber, role: entry.role));
        }
        return null;
      },
    );
  }
}
