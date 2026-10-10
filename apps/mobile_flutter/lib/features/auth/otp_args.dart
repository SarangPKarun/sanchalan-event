import '../../models/enums.dart';

/// Passed as `extra` when going from the phone screen to the OTP screen.
class OtpArgs {
  const OtpArgs({required this.phoneNumber, required this.role});

  final String phoneNumber;
  final AuthRole role;
}
