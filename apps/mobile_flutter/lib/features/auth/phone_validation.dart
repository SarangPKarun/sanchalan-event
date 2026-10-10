import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'country_codes.dart';

/// Result of checking what the user typed against the selected country.
class PhoneCheck {
  const PhoneCheck({
    required this.e164,
    required this.digits,
    required this.isValid,
  });

  /// Dial code plus digits, e.g. `+919876543210`.
  final String e164;

  /// What was typed, digits only.
  final String digits;

  /// A real mobile number for that country (same rule as the backend:
  /// India needs exactly 10 digits and a valid mobile prefix).
  final bool isValid;

  /// Show the "enter a valid number" hint only once the user has typed something.
  bool get showInvalidHint => digits.isNotEmpty && !isValid;
}

PhoneCheck checkPhone(Country country, String typed) {
  final digits = typed.replaceAll(RegExp(r'\D'), '');
  final e164 = '${country.dialCode}$digits';
  var valid = false;
  if (digits.isNotEmpty) {
    try {
      final parsed = PhoneNumber.parse(e164);
      valid = parsed.isValid(type: PhoneNumberType.mobile);
    } catch (_) {
      valid = false;
    }
  }
  return PhoneCheck(e164: e164, digits: digits, isValid: valid);
}
