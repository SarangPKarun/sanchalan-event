import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/api_client.dart';
import 'package:sanchalan/core/auth_storage.dart';

typedef Handler = Future<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  int count(String path) => requests.where((r) => r.path == path).length;
}

ResponseBody jsonBody(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  late AuthStorage storage;
  late int expiredCalls;

  Future<(ApiClient, FakeAdapter)> build(Handler handler) async {
    final adapter = FakeAdapter(handler);
    final client = ApiClient(
      storage: storage,
      baseUrl: 'http://test',
      dio: Dio()..httpClientAdapter = adapter,
      refreshDio: Dio()..httpClientAdapter = adapter,
      onSessionExpired: () => expiredCalls++,
    );
    return (client, adapter);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = AuthStorage();
    await storage.setTokens(accessToken: 'old', refreshToken: 'refresh-1');
    expiredCalls = 0;
  });

  test('adds bearer token to normal calls but not to /auth/*', () async {
    final (client, adapter) = await build((o) async => jsonBody({'ok': true}, 200));
    await client.dio.get('/organizers/me');
    await client.dio.post('/auth/otp/request', data: {});

    expect(adapter.requests[0].headers['Authorization'], 'Bearer old');
    expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
  });

  test('3 concurrent 401s trigger exactly one refresh and all are retried', () async {
    final (client, adapter) = await build((o) async {
      if (o.path == '/auth/refresh') {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return jsonBody({'accessToken': 'new'}, 200);
      }
      if (o.headers['Authorization'] == 'Bearer new') return jsonBody({'ok': o.path}, 200);
      return jsonBody({'error': 'expired'}, 401);
    });

    final results = await Future.wait([
      client.dio.get<Map<String, dynamic>>('/a'),
      client.dio.get<Map<String, dynamic>>('/b'),
      client.dio.get<Map<String, dynamic>>('/c'),
    ]);

    expect(results.map((r) => r.data!['ok']), ['/a', '/b', '/c']);
    expect(adapter.count('/auth/refresh'), 1);
    expect(await storage.getAccessToken(), 'new');
    expect(await storage.getRefreshToken(), 'refresh-1');
    expect(expiredCalls, 0);
  });

  test('rejected refresh clears the session and signals expiry once', () async {
    final (client, _) = await build((o) async {
      if (o.path == '/auth/refresh') return jsonBody({'error': 'revoked'}, 401);
      return jsonBody({'error': 'expired'}, 401);
    });

    await expectLater(
      Future.wait([client.dio.get('/a'), client.dio.get('/b')]),
      throwsA(isA<DioException>()),
    );
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
    expect(expiredCalls, 1);
  });

  test('5xx on refresh keeps the session', () async {
    final (client, _) = await build((o) async {
      if (o.path == '/auth/refresh') return jsonBody({'error': 'boom'}, 503);
      return jsonBody({'error': 'expired'}, 401);
    });

    await expectLater(client.dio.get('/a'), throwsA(isA<DioException>()));
    expect(await storage.getRefreshToken(), 'refresh-1');
    expect(expiredCalls, 0);
  });

  test('network error on refresh keeps the session', () async {
    final (client, _) = await build((o) async {
      if (o.path == '/auth/refresh') {
        throw DioException.connectionError(requestOptions: o, reason: 'offline');
      }
      return jsonBody({'error': 'expired'}, 401);
    });

    await expectLater(client.dio.get('/a'), throwsA(isA<DioException>()));
    expect(await storage.getRefreshToken(), 'refresh-1');
    expect(expiredCalls, 0);
  });

  test('a 401 after the retry is surfaced, not looped', () async {
    final (client, adapter) = await build((o) async {
      if (o.path == '/auth/refresh') return jsonBody({'accessToken': 'new'}, 200);
      return jsonBody({'error': 'still no'}, 401);
    });

    await expectLater(client.dio.get('/a'), throwsA(isA<DioException>()));
    expect(adapter.count('/a'), 2);
    expect(adapter.count('/auth/refresh'), 1);
  });

  test('401 from /auth/* is not refreshed', () async {
    final (client, adapter) = await build((o) async => jsonBody({'error': 'bad otp'}, 401));

    await expectLater(client.dio.post('/auth/otp/verify', data: {}), throwsA(isA<DioException>()));
    expect(adapter.count('/auth/refresh'), 0);
    expect(expiredCalls, 0);
  });

  test('no stored refresh token: session is treated as dead', () async {
    FlutterSecureStorage.setMockInitialValues({accessTokenKey: 'old'});
    final (client, adapter) = await build((o) async => jsonBody({'error': 'expired'}, 401));

    await expectLater(client.dio.get('/a'), throwsA(isA<DioException>()));
    expect(adapter.count('/auth/refresh'), 0);
    expect(expiredCalls, 1);
  });
}
