// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpRequestBody _$OtpRequestBodyFromJson(Map<String, dynamic> json) =>
    OtpRequestBody(
      phoneNumber: json['phoneNumber'] as String,
      role: $enumDecode(_$AuthRoleEnumMap, json['role']),
    );

Map<String, dynamic> _$OtpRequestBodyToJson(OtpRequestBody instance) =>
    <String, dynamic>{
      'phoneNumber': instance.phoneNumber,
      'role': _$AuthRoleEnumMap[instance.role]!,
    };

const _$AuthRoleEnumMap = {
  AuthRole.organizer: 'organizer',
  AuthRole.vendor: 'vendor',
  AuthRole.admin: 'admin',
};

OtpRequestResponse _$OtpRequestResponseFromJson(Map<String, dynamic> json) =>
    OtpRequestResponse(
      expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
    );

Map<String, dynamic> _$OtpRequestResponseToJson(OtpRequestResponse instance) =>
    <String, dynamic>{'expiresInSeconds': instance.expiresInSeconds};

OtpVerifyBody _$OtpVerifyBodyFromJson(Map<String, dynamic> json) =>
    OtpVerifyBody(
      phoneNumber: json['phoneNumber'] as String,
      otp: json['otp'] as String,
      role: $enumDecode(_$AuthRoleEnumMap, json['role']),
    );

Map<String, dynamic> _$OtpVerifyBodyToJson(OtpVerifyBody instance) =>
    <String, dynamic>{
      'phoneNumber': instance.phoneNumber,
      'otp': instance.otp,
      'role': _$AuthRoleEnumMap[instance.role]!,
    };

AuthTokens _$AuthTokensFromJson(Map<String, dynamic> json) => AuthTokens(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  role: $enumDecode(_$AuthRoleEnumMap, json['role']),
  userId: json['userId'] as String,
  adminRole: $enumDecodeNullable(_$AdminRoleEnumMap, json['adminRole']),
);

Map<String, dynamic> _$AuthTokensToJson(AuthTokens instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'role': _$AuthRoleEnumMap[instance.role]!,
      'userId': instance.userId,
      'adminRole': ?_$AdminRoleEnumMap[instance.adminRole],
    };

const _$AdminRoleEnumMap = {
  AdminRole.superAdmin: 'super_admin',
  AdminRole.vendorReviewer: 'vendor_reviewer',
  AdminRole.support: 'support',
};

RefreshRequestBody _$RefreshRequestBodyFromJson(Map<String, dynamic> json) =>
    RefreshRequestBody(refreshToken: json['refreshToken'] as String);

Map<String, dynamic> _$RefreshRequestBodyToJson(RefreshRequestBody instance) =>
    <String, dynamic>{'refreshToken': instance.refreshToken};

RefreshResponse _$RefreshResponseFromJson(Map<String, dynamic> json) =>
    RefreshResponse(accessToken: json['accessToken'] as String);

Map<String, dynamic> _$RefreshResponseToJson(RefreshResponse instance) =>
    <String, dynamic>{'accessToken': instance.accessToken};
