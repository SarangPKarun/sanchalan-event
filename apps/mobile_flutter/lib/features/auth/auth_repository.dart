import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/auth.dart';
import '../../models/enums.dart';

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// Sends an OTP. Returns how long it stays valid.
  Future<OtpRequestResponse> requestOtp(String phoneNumber, AuthRole role) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/otp/request',
      data: OtpRequestBody(phoneNumber: phoneNumber, role: role).toJson(),
    );
    return OtpRequestResponse.fromJson(res.data!);
  }

  Future<AuthTokens> verifyOtp({
    required String phoneNumber,
    required String otp,
    required AuthRole role,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      data: OtpVerifyBody(phoneNumber: phoneNumber, otp: otp, role: role).toJson(),
    );
    return AuthTokens.fromJson(res.data!);
  }

  /// New access token for a refresh token (used when restoring a session).
  Future<String> refresh(String refreshToken) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: RefreshRequestBody(refreshToken: refreshToken).toJson(),
    );
    return RefreshResponse.fromJson(res.data!).accessToken;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));
