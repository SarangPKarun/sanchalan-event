import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/api_client.dart';
import 'package:sanchalan/core/providers.dart';
import 'package:sanchalan/features/auth/auth_controller.dart';
import 'package:sanchalan/features/auth/auth_state.dart';

import 'fake_adapter.dart';

/// A ProviderContainer whose API client talks to a [FakeAdapter] and whose
/// secure storage is in memory (seeded with [secure]).
(ProviderContainer, FakeAdapter) makeContainer(
  Handler handler, {
  Map<String, String> secure = const {},
}) {
  FlutterSecureStorage.setMockInitialValues(Map.of(secure));
  final adapter = FakeAdapter(handler);
  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        storage: ref.watch(authStorageProvider),
        baseUrl: 'http://test',
        dio: Dio()..httpClientAdapter = adapter,
        refreshDio: Dio()..httpClientAdapter = adapter,
        onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).bump(),
      ),
    ),
  ]);
  addTearDown(container.dispose);
  return (container, adapter);
}

/// Waits until the auth controller leaves `loading` (session restore finished).
Future<AuthState> settledAuth(ProviderContainer container) async {
  final sub = container.listen(authControllerProvider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 100; i++) {
    final s = container.read(authControllerProvider);
    if (s.status != AuthStatus.loading) return s;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('auth never settled');
}
