import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'auth.g.dart';

@JsonSerializable(includeIfNull: false)
class OtpRequestBody {
  const OtpRequestBody({required this.phoneNumber, required this.role});
  factory OtpRequestBody.fromJson(Map<String, dynamic> json) => _$OtpRequestBodyFromJson(json);
  final String phoneNumber;
  final AuthRole role;
  Map<String, dynamic> toJson() => _$OtpRequestBodyToJson(this);
}

@JsonSerializable()
class OtpRequestResponse {
  const OtpRequestResponse({required this.expiresInSeconds});
  factory OtpRequestResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpRequestResponseFromJson(json);
  final int expiresInSeconds;
  Map<String, dynamic> toJson() => _$OtpRequestResponseToJson(this);
}

@JsonSerializable()
class OtpVerifyBody {
  const OtpVerifyBody({required this.phoneNumber, required this.otp, required this.role});
  factory OtpVerifyBody.fromJson(Map<String, dynamic> json) => _$OtpVerifyBodyFromJson(json);
  final String phoneNumber;
  final String otp;
  final AuthRole role;
  Map<String, dynamic> toJson() => _$OtpVerifyBodyToJson(this);
}

/// Response of POST /auth/otp/verify (and /admin/auth/login).
@JsonSerializable(includeIfNull: false)
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.userId,
    this.adminRole,
  });
  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);
  final String accessToken;
  final String refreshToken;
  final AuthRole role;
  final String userId;
  final AdminRole? adminRole;
  Map<String, dynamic> toJson() => _$AuthTokensToJson(this);
}

@JsonSerializable()
class RefreshRequestBody {
  const RefreshRequestBody({required this.refreshToken});
  factory RefreshRequestBody.fromJson(Map<String, dynamic> json) =>
      _$RefreshRequestBodyFromJson(json);
  final String refreshToken;
  Map<String, dynamic> toJson() => _$RefreshRequestBodyToJson(this);
}

@JsonSerializable()
class RefreshResponse {
  const RefreshResponse({required this.accessToken});
  factory RefreshResponse.fromJson(Map<String, dynamic> json) => _$RefreshResponseFromJson(json);
  final String accessToken;
  Map<String, dynamic> toJson() => _$RefreshResponseToJson(this);
}
