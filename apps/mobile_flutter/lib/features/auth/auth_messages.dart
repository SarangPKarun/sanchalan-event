import 'package:dio/dio.dart';

import '../../core/api_errors.dart';
import 'country_codes.dart';

const _noInternet = 'No internet connection. Check it and try again.';

int? _status(Object e) => e is DioException ? e.response?.statusCode : null;

String _serverMessage(Object e) => apiErrorMessage(e, '').toLowerCase();

/// What to tell the user when sending the code failed.
String requestOtpMessage(Object error, Country country) {
  if (isNetworkError(error)) return _noInternet;
  return switch (_status(error)) {
    400 => 'Enter a valid ${country.name} phone number.',
    429 => 'Too many codes requested. Please wait a few minutes and try again.',
    _ => 'Could not send a code. Check the number and try again.',
  };
}

/// What to tell the user when checking the code failed.
String verifyOtpMessage(Object error) {
  if (isNetworkError(error)) return _noInternet;
  if (_status(error) == 400) {
    final m = _serverMessage(error);
    if (m.contains('expired')) return 'That code has expired. Tap Resend code to get a new one.';
    if (m.contains('too many') || m.contains('already used')) {
      return 'This code can no longer be used. Tap Resend code to get a new one.';
    }
    return 'That code is not right. Check it and try again.';
  }
  return 'Could not check the code. Please try again.';
}

/// What to tell the user when asking for a new code failed.
String resendOtpMessage(Object error) {
  if (isNetworkError(error)) return _noInternet;
  if (_status(error) == 429) return 'Too many codes requested. Please wait a few minutes and try again.';
  return 'Could not resend the code. Please try again.';
}
