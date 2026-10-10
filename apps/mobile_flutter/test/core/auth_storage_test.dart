import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/auth_storage.dart';
import 'package:sanchalan/models/enums.dart';

void main() {
  late AuthStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = AuthStorage();
  });

  test('stores and reads tokens and role', () async {
    await storage.setTokens(accessToken: 'a', refreshToken: 'r');
    await storage.setRole(AuthRole.vendor);

    expect(await storage.getAccessToken(), 'a');
    expect(await storage.getRefreshToken(), 'r');
    expect(await storage.getRole(), AuthRole.vendor);
  });

  test('missing or unknown role reads as null', () async {
    expect(await storage.getRole(), isNull);
    FlutterSecureStorage.setMockInitialValues({roleKey: 'banana'});
    expect(await AuthStorage().getRole(), isNull);
  });

  test('setAccessToken keeps the refresh token', () async {
    await storage.setTokens(accessToken: 'a', refreshToken: 'r');
    await storage.setAccessToken('b');
    expect(await storage.getAccessToken(), 'b');
    expect(await storage.getRefreshToken(), 'r');
  });

  test('clear removes everything', () async {
    await storage.setTokens(accessToken: 'a', refreshToken: 'r');
    await storage.setRole(AuthRole.organizer);
    await storage.clear();
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
    expect(await storage.getRole(), isNull);
  });
}
