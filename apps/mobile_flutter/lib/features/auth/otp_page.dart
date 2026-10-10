import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'auth_repository.dart';
import 'otp_args.dart';
import 'otp_screen.dart';

/// The OTP screen connected to the backend. A correct code signs the user in;
/// the router then moves them to the right place for their role.
class OtpPage extends ConsumerWidget {
  const OtpPage({super.key, required this.args});

  final OtpArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OtpScreen(
      phoneNumber: args.phoneNumber,
      onChangeNumber: () => context.canPop() ? context.pop() : context.go(AppPaths.phone),
      onVerify: (otp) async {
        try {
          final tokens = await ref
              .read(authRepositoryProvider)
              .verifyOtp(phoneNumber: args.phoneNumber, otp: otp, role: args.role);
          await ref.read(authControllerProvider.notifier).signIn(tokens);
          return null;
        } catch (e) {
          return verifyOtpMessage(e);
        }
      },
      onResend: () async {
        try {
          await ref.read(authRepositoryProvider).requestOtp(args.phoneNumber, args.role);
          return null;
        } catch (e) {
          return resendOtpMessage(e);
        }
      },
    );
  }
}
