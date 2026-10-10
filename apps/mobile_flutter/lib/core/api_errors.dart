import 'package:dio/dio.dart';

/// The server's `{ "error": "..." }` message when there is one, else [fallback].
/// Port of apiErrorMessage in apps/mobile/lib/vendor-context.tsx.
String apiErrorMessage(Object err, String fallback) {
  if (err is DioException) {
    final data = err.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
  }
  return fallback;
}

/// No response at all: offline, DNS failure or timeout (as opposed to a server error).
bool isNetworkError(Object err) => err is DioException && err.response == null;
