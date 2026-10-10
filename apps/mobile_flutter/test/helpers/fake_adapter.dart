import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Handler = Future<ResponseBody> Function(RequestOptions options);

/// Dio adapter that records requests and answers through [handler].
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

  int count(String path, {String? method}) => requests
      .where((r) => r.path == path && (method == null || r.method == method))
      .length;

  RequestOptions last(String path, {String? method}) => requests
      .lastWhere((r) => r.path == path && (method == null || r.method == method));
}

ResponseBody jsonBody(Object? body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

/// A recorded backend response from test/fixtures/live/.
Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/live/$name.json').readAsStringSync());

ResponseBody fixtureBody(String name, [int status = 200]) => jsonBody(fixture(name), status);

typedef Route = FutureOr<ResponseBody> Function(RequestOptions options);

/// Routes by "METHOD /path"; anything unmatched is a 404.
Handler routes(Map<String, Route> table) => (options) async {
      final route = table['${options.method} ${options.path}'];
      if (route == null) return jsonBody({'error': 'no route'}, 404);
      return route(options);
    };
