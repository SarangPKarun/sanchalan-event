import 'package:dio/dio.dart';

import '../../models/vendor.dart';

/// The fields the server says are still missing when a submit is refused:
/// `{ "error": "...", "details": { "missing": ["pastWork", ...] } }`. Empty if it sent none.
List<VendorRequiredField> missingFromError(Object error) {
  if (error is! DioException) return const [];
  final data = error.response?.data;
  final details = data is Map ? data['details'] : null;
  final missing = details is Map ? details['missing'] : null;
  if (missing is! List) return const [];
  return [
    for (final name in missing)
      for (final f in VendorRequiredField.values)
        if (f.name == name) f,
  ];
}
