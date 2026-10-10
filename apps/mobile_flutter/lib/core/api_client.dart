import 'dart:async';

import 'package:dio/dio.dart';

import 'auth_storage.dart';
import 'config.dart';

/// True only when the server explicitly rejected the credentials. Network
/// errors, timeouts and 5xx are transient and must not destroy the session.
bool isAuthRejection(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  return status == 401 || status == 403;
}

bool _isAuthEndpoint(String path) => path.startsWith('/auth/');

const _retriedKey = 'sanchalan.retried';

/// Dio client with bearer-token injection and a coalesced token refresh.
/// Port of apps/mobile/lib/api.ts.
class ApiClient {
  ApiClient({
    required this.storage,
    required this.onSessionExpired,
    String? baseUrl,
    Dio? dio,
    Dio? refreshDio,
  })  : dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    final base = baseUrl ?? apiUrl;
    this.dio.options
      ..baseUrl = base
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15);
    // Plain client for /auth/refresh: avoids recursing through our interceptors.
    _refreshDio.options
      ..baseUrl = base
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15);
    this.dio.interceptors.add(InterceptorsWrapper(
          onRequest: _onRequest,
          onError: _onError,
        ));
  }

  final Dio dio;
  final Dio _refreshDio;
  final AuthStorage storage;

  /// Called once the session is dead (refresh rejected). Tokens are already
  /// cleared; the auth layer should send the user back to the phone screen.
  final void Function() onSessionExpired;

  // Concurrent 401s (two screens firing at once) share one refresh call.
  Future<String?>? _refreshFuture;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthEndpoint(options.path)) {
      final token = await storage.getAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Resolves to null if the session is dead (no token or the server rejected
  /// it); throws on transient failures so callers keep the tokens.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) {
      await _endSession();
      return null;
    }
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final accessToken = res.data!['accessToken'] as String;
      await storage.setAccessToken(accessToken);
      return accessToken;
    } catch (e) {
      if (isAuthRejection(e)) {
        await _endSession();
        return null;
      }
      rethrow;
    }
  }

  /// The session is dead: clear local tokens and tell the auth layer. Runs
  /// inside the shared refresh, so concurrent requests trigger it only once.
  Future<void> _endSession() async {
    await storage.clear();
    onSessionExpired();
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final canRefresh = error.response?.statusCode == 401 &&
        !_isAuthEndpoint(request.path) &&
        request.extra[_retriedKey] != true;
    if (!canRefresh) return handler.next(error);

    request.extra[_retriedKey] = true;
    final future = _refreshFuture ??= _refreshAccessToken().whenComplete(() {
      _refreshFuture = null;
    });

    String? newAccessToken;
    try {
      newAccessToken = await future;
    } catch (_) {
      // Transient failure (offline, timeout, 5xx): keep the session.
      return handler.next(error);
    }

    if (newAccessToken != null) {
      request.headers['Authorization'] = 'Bearer $newAccessToken';
      try {
        return handler.resolve(await dio.fetch<dynamic>(request));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }

    // Refresh itself failed: the session is dead (already cleared in _endSession).
    handler.next(error);
  }
}
