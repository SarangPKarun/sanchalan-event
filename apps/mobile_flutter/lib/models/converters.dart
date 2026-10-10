import 'package:json_annotation/json_annotation.dart';

/// Money fields. The backend sends numbers (Decimals are converted with
/// toNumber), but accept numeric strings too so a serializer change can't crash the app.
class MoneyConverter implements JsonConverter<double, Object?> {
  const MoneyConverter();

  @override
  double fromJson(Object? json) => json is String ? double.parse(json) : (json as num).toDouble();

  @override
  Object toJson(double object) => object;
}

class NullableMoneyConverter implements JsonConverter<double?, Object?> {
  const NullableMoneyConverter();

  @override
  double? fromJson(Object? json) =>
      json == null ? null : (json is String ? double.parse(json) : (json as num).toDouble());

  @override
  Object? toJson(double? object) => object;
}

/// "YYYY-MM-DD" for request bodies (the API's date-only fields).
String toDateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
