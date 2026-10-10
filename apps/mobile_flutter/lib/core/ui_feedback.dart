import 'package:flutter/material.dart';

import 'api_errors.dart';

/// A short message at the bottom of the screen.
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A message fit to show a person: the server's own text when it sent one,
/// "no internet" when there was no response at all, else [fallback].
String friendlyError(Object error, String fallback) {
  if (isNetworkError(error)) return 'No internet connection. Check it and try again.';
  return apiErrorMessage(error, fallback);
}
