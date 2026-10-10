import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/enums.dart';

const accessTokenKey = 'sanchalan.accessToken';
const refreshTokenKey = 'sanchalan.refreshToken';
const roleKey = 'sanchalan.role';

/// Secure storage for the session: access token, refresh token and role.
/// Same keys as the React Native app's authStorage.ts.
class AuthStorage {
  AuthStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> getAccessToken() => _storage.read(key: accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: refreshTokenKey);

  Future<AuthRole?> getRole() async {
    final value = await _storage.read(key: roleKey);
    for (final role in AuthRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  Future<void> setTokens({required String accessToken, required String refreshToken}) async {
    await Future.wait([
      _storage.write(key: accessTokenKey, value: accessToken),
      _storage.write(key: refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<void> setAccessToken(String accessToken) =>
      _storage.write(key: accessTokenKey, value: accessToken);

  Future<void> setRole(AuthRole role) => _storage.write(key: roleKey, value: role.name);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: accessTokenKey),
      _storage.delete(key: refreshTokenKey),
      _storage.delete(key: roleKey),
    ]);
  }
}
